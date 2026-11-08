import DesignKit
import EnvironmentKit
import Inject
import PrayersKit
import SwiftUI

public enum BeadsPrayerSelectionMetrics {
  public static let horizontalInset: CGFloat = 20
  public static let verticalInset: CGFloat = 16
  public static let fontSize: CGFloat = 20
  public static let lineSpacing: CGFloat = 8
  public static let doneJiggleAngle: Double = 2
  public static let doneJigglePeriod: TimeInterval = 0.28
  public static let doneJiggleFrameInterval: TimeInterval = 1.0 / 30
  public static let selectedTextJiggleAngle: CGFloat = 0.75
  public static let selectedTextJigglePeriod: TimeInterval = 0.65
}

public struct BeadsPrayerSelectionScreen: View {
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var navigator: AppNavigatorModel
  @EnvironmentObject private var draft: BeadsRecitationDraft
  @State private var selection: PrayerPassage?
  @State private var didFailToSave = false
  private let document: PrayerPassageDocument?
  private let initialSelection: NSRange?

  public init(prayerID: String, initialPassage: PrayerPassageLocation? = nil) {
    let document = PrayerCatalog.shared.prayer(id: prayerID).map(PrayerPassageDocument.init)
    let range = initialPassage.flatMap { document?.range(for: $0) }
    self.document = document
    self.initialSelection = range
    _selection = State(initialValue: range.flatMap { document?.passage(in: $0) })
  }

  public var body: some View {
    Group {
      if let document {
        VStack(alignment: .leading, spacing: AppListSectionMetrics.labelGap) {
          Text(selection?.location.verseLabel ?? L10n.beadsPrayerSelectionHint)
            .font(AppFont.subheadline)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.horizontal, BeadsPrayerSelectionMetrics.horizontalInset)
            .padding(.top, BeadsPrayerSelectionMetrics.verticalInset)
          #if os(iOS)
          BeadsSelectablePrayerText(
            document: document, initialSelection: initialSelection, selection: $selection
          )
          #else
          Text(L10n.beadsPrayerSelectionUnavailable)
            .font(AppFont.body)
            .padding()
          Spacer()
          #endif
          if didFailToSave {
            Text(L10n.beadsSaveError)
              .font(AppFont.subheadline)
              .foregroundStyle(AppColor.error)
              .padding(.horizontal, BeadsPrayerSelectionMetrics.horizontalInset)
          }
        }
      } else {
        AppEmptyStateView(systemImage: "book.closed", title: L10n.prayerNotFound)
      }
    }
    .appBackground()
    .navigationTitle(document?.prayer.title ?? L10n.prayerNotFound)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        BeadsSelectionDoneButton(isEnabled: selection != nil, action: finish)
      }
    }
    .enableInjection()
  }

  private func finish() {
    guard let selection else { return }
    do {
      if let beadsID = draft.beadsID {
        try BeadsStore.shared.updateRecitation(id: beadsID, recitation: .prayer(selection))
        navigator.dismissSheet()
      } else {
        draft.pick(selection)
        navigator.popSheetToRoot()
      }
    } catch {
      didFailToSave = true
    }
  }
}

/// Animate only the CTA, not the selection screen: handle adjustments can
/// publish dozens of selections a second and must not restart the cue. A
/// paused timeline also stops immediately on deselection, navigation away or
/// Reduce Motion, without leaving a repeat-forever animation in the toolbar.
private struct BeadsSelectionDoneButton: View {
  @ObserveInjection private var injectionObserver
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var isVisible = false
  let isEnabled: Bool
  let action: () -> Void

  private var shouldJiggle: Bool {
    isEnabled && isVisible && !reduceMotion && scenePhase == .active
  }

  var body: some View {
    TimelineView(.animation(
      minimumInterval: BeadsPrayerSelectionMetrics.doneJiggleFrameInterval,
      paused: !shouldJiggle
    )) { context in
      let phase = context.date.timeIntervalSinceReferenceDate
        / BeadsPrayerSelectionMetrics.doneJigglePeriod * 2 * .pi
      Button(L10n.done, action: action)
        .disabled(!isEnabled)
        .rotationEffect(.degrees(shouldJiggle
          ? sin(phase) * BeadsPrayerSelectionMetrics.doneJiggleAngle : 0))
    }
    .onAppear { isVisible = true }
    .onDisappear { isVisible = false }
    .enableInjection()
  }
}

#if os(iOS)
import UIKit

/// A single non-editable text view gives iOS ownership of handles, selection
/// autoscrolling and accessibility. Splitting it into verse cells would trap a
/// selection in one cell, while an editable view would summon a keyboard over
/// the very words someone is trying to pick.
private struct BeadsSelectablePrayerText: UIViewRepresentable {
  let document: PrayerPassageDocument
  let initialSelection: NSRange?
  @Binding var selection: PrayerPassage?
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> BeadsPrayerTextView {
    // TextKit 2 estimates offscreen geometry. On iOS 27.2 a restored range
    // selected correctly but scrolled to an estimate above the actual passage.
    // This picker needs synchronous glyph layout once when following a source
    // link, so choose TextKit 1 up front instead of switching engines on access
    // to `layoutManager` after the user has begun selecting.
    let view = BeadsPrayerTextView.make()
    view.isEditable = false
    view.isSelectable = true
    view.backgroundColor = .clear
    view.tintColor = UIColor(AppColor.primary)
    view.textContainerInset = UIEdgeInsets(
      top: BeadsPrayerSelectionMetrics.verticalInset,
      left: BeadsPrayerSelectionMetrics.horizontalInset,
      bottom: BeadsPrayerSelectionMetrics.verticalInset,
      right: BeadsPrayerSelectionMetrics.horizontalInset
    )
    view.textContainer.lineFragmentPadding = 0
    view.delegate = context.coordinator
    return view
  }

  func updateUIView(_ view: BeadsPrayerTextView, context: Context) {
    view.isSelectionAnimationEnabled = !reduceMotion && scenePhase == .active
    let coordinator = context.coordinator
    coordinator.onSelection = {
      if selection != $0 { selection = $0 }
    }
    let prayerChanged = coordinator.document?.prayer.id != document.prayer.id
    guard prayerChanged
      || coordinator.typeSize != dynamicTypeSize
      || coordinator.colorScheme != view.traitCollection.userInterfaceStyle
    else { return }
    coordinator.isUpdating = true
    let previousRange = view.selectedRange
    let previousOffset = view.contentOffset
    coordinator.document = document
    coordinator.typeSize = dynamicTypeSize
    coordinator.colorScheme = view.traitCollection.userInterfaceStyle
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = BeadsPrayerSelectionMetrics.lineSpacing
    view.attributedText = NSAttributedString(string: document.text, attributes: [
      .font: AppUIFont.jasmine(size: BeadsPrayerSelectionMetrics.fontSize),
      .foregroundColor: UIColor(AppColor.textPrimary),
      .paragraphStyle: paragraph
    ])
    if prayerChanged {
      view.selectionToRestore = initialSelection
      view.setNeedsLayout()
    }
    if previousRange.location != NSNotFound, NSMaxRange(previousRange) <= view.attributedText.length {
      view.selectedRange = previousRange
      view.setContentOffset(previousOffset, animated: false)
    }
    coordinator.isUpdating = false
  }

  final class Coordinator: NSObject, UITextViewDelegate {
    var document: PrayerPassageDocument?
    var typeSize: DynamicTypeSize?
    var colorScheme: UIUserInterfaceStyle?
    var isUpdating = false
    var onSelection: ((PrayerPassage?) -> Void)?

    func textViewDidChangeSelection(_ textView: UITextView) {
      guard !isUpdating, (textView as? BeadsPrayerTextView)?.isRestoringSelection != true else { return }
      let passage = document?.passage(in: textView.selectedRange)
      (textView as? BeadsPrayerTextView)?.selectionDidChange(hasSelection: passage != nil)
      onSelection?(passage)
    }
  }
}

#endif
