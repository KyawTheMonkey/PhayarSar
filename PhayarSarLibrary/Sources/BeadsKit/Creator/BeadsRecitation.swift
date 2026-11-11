import DesignKit
import EnvironmentKit
import Inject
import PrayersKit
import SwiftUI

enum BeadsRecitation: Hashable, Codable, Sendable {
  case typed(String)
  case prayer(PrayerPassage)

  var text: String {
    switch self {
    case let .typed(text): text
    case let .prayer(passage): passage.text
    }
  }
}

@MainActor
final class BeadsRecitationDraft: ObservableObject {
  enum Mode { case typed, prayer }
  @Published var mode = Mode.typed
  @Published var typedText = ""
  @Published var passage: PrayerPassage?
  @Published private(set) var passageRevealID: UUID?
  private(set) var revealedPassageID: UUID?
  private(set) var beadsID: UUID?
  /// The passage-only editor commits on Done. The full form must return to
  /// its draft instead, or choosing a passage would save through Cancel.
  let commitsRecitationImmediately: Bool

  init(
    beadsID: UUID? = nil, prayerID: String? = nil, verseID: Int? = nil,
    commitsRecitationImmediately: Bool = false
  ) {
    self.beadsID = beadsID
    self.commitsRecitationImmediately = commitsRecitationImmediately
    if let beadsID,
       let recitation = BeadsStore.shared.beads.first(where: { $0.id == beadsID })?.recitation {
      switch recitation {
      case let .typed(text):
        self.typedText = text
      case let .prayer(passage):
        self.mode = .prayer
        self.passage = passage
      }
    } else if beadsID == nil, let prayerID, let verseID,
              let prayer = PrayerCatalog.shared.prayer(id: prayerID) {
      // Use the same source document as the picker: a verse spans every reader
      // row derived from it, regardless of pronunciation or display settings.
      let document = PrayerPassageDocument(prayer: prayer)
      if let range = document.verses.first(where: { $0.verseID == verseID })?.range,
         let passage = document.passage(in: range) {
        pick(passage)
      }
    }
  }

  /// Called when a pushed editor first appears. Returning from its picker
  /// must reuse the current draft; reopening the set starts a fresh one.
  func prepareToEdit(beadsID: UUID) {
    guard self.beadsID != beadsID else { return }
    self.beadsID = beadsID
    mode = .typed
    typedText = ""
    passage = nil
    passageRevealID = nil
    revealedPassageID = nil
    switch BeadsStore.shared.beads.first(where: { $0.id == beadsID })?.recitation {
    case let .typed(text): typedText = text
    case let .prayer(passage):
      mode = .prayer
      self.passage = passage
    case nil: break
    }
  }

  func endEditing() {
    beadsID = nil
    mode = .typed
    typedText = ""
    passage = nil
    passageRevealID = nil
    revealedPassageID = nil
  }

  var recitation: BeadsRecitation? {
    switch mode {
    case .typed:
      let text = typedText.trimmingCharacters(in: .whitespacesAndNewlines)
      return text.isEmpty ? nil : .typed(text)
    case .prayer:
      return passage.map(BeadsRecitation.prayer)
    }
  }

  func pick(_ passage: PrayerPassage) {
    self.passage = passage
    mode = .prayer
    passageRevealID = UUID()
  }

  func didRevealPassage() {
    revealedPassageID = passageRevealID
  }
}

/// Navigation destinations are siblings, so injecting the draft on the editor
/// alone would leave its pushed browser without it. Keep the draft above the
/// tab stacks, and discard it only when its editor leaves the navigator's path.
/// Add sheets install their own `BeadsCreatorContext` and remain independent.
public struct BeadsNavigationContext<Content: View>: View {
  @EnvironmentObject private var navigator: AppNavigatorModel
  @StateObject private var draft = BeadsRecitationDraft()
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .environmentObject(draft)
      .onChange(of: navigator.paths) { paths in
        guard let beadsID = draft.beadsID else { return }
        let isEditing = paths.values.contains { $0.contains(.beadsEditor(beadsID: beadsID)) }
        if !isEditing { draft.endEditing() }
      }
  }
}

/// Owns a draft for the lifetime of the entire modal stack, not an individual
/// screen. Browser pushes and breadcrumb detours inherit the same object, and
/// dismissing the sheet drops both inactive and active source drafts together.
public struct BeadsCreatorContext<Content: View>: View {
  @StateObject private var draft: BeadsRecitationDraft
  private let content: Content

  public init(
    beadsID: UUID? = nil, prayerID: String? = nil, verseID: Int? = nil,
    commitsRecitationImmediately: Bool = false,
    @ViewBuilder content: () -> Content
  ) {
    _draft = StateObject(wrappedValue: BeadsRecitationDraft(
      beadsID: beadsID, prayerID: prayerID, verseID: verseID,
      commitsRecitationImmediately: commitsRecitationImmediately
    ))
    self.content = content()
  }

  public var body: some View {
    content.environmentObject(draft)
  }
}

public enum BeadsRecitationMetrics {
  public static let editorHeight: CGFloat = 160
  public static let contentSpacing: CGFloat = 12
  public static let selectionSize: CGFloat = 22
  public static let editorPlaceholderInset: CGFloat = 5
  /// The card growing to a newly chosen passage: underdamped on purpose, so
  /// it overshoots and bounces back as the swell passes through it, and done
  /// bouncing before the front has settled past the bottom edge.
  public static let growth = Animation.spring(response: 0.6, dampingFraction: 0.58)
}

struct BeadsRecitationSection: View {
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var draft: BeadsRecitationDraft
  @EnvironmentObject private var navigator: AppNavigatorModel

  private var isEditorVisible: Bool {
    if navigator.presentedSheet != nil { return navigator.sheetPath.isEmpty }
    guard let beadsID = draft.beadsID else { return false }
    return navigator.paths[navigator.selectedTab]?.last == .beadsEditor(beadsID: beadsID)
  }

  var body: some View {
    VStack(spacing: BeadsRecitationMetrics.contentSpacing) {
      AppListSection(L10n.beadsRecitation) {
        modeRow(.typed, title: L10n.beadsRecitationType)
        AppDivider()
        modeRow(.prayer, title: L10n.beadsRecitationPick)
      }
      if draft.mode == .typed {
        AppListSection {
          TextEditor(text: $draft.typedText)
            .scrollDismissesKeyboard(.interactively)
            .font(AppFont.body)
            .frame(minHeight: BeadsRecitationMetrics.editorHeight)
            .scrollContentBackground(.hidden)
            .accessibilityLabel(L10n.beadsRecitationType)
            .overlay(alignment: .topLeading) {
              if draft.typedText.isEmpty {
                Text(L10n.beadsRecitationPlaceholder)
                  .foregroundStyle(AppColor.textTertiary)
                  .padding(.top, AppListSectionMetrics.labelGap)
                  .padding(.leading, BeadsRecitationMetrics.editorPlaceholderInset)
                  .allowsHitTesting(false)
              }
            }
        }
      } else {
        BeadsPassageSection(isRevealActive: isEditorVisible)
      }
      Text(L10n.beadsRecitationCountHint)
        .font(AppFont.caption)
        .foregroundStyle(AppColor.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appHorizontalInset()
    }
    .enableInjection()
  }

  private func modeRow(_ mode: BeadsRecitationDraft.Mode, title: String) -> some View {
    Button { draft.mode = mode } label: {
      HStack(spacing: AppSettingsRowMetrics.iconSpacing) {
        Image(systemName: draft.mode == mode ? "largecircle.fill.circle" : "circle")
          .font(AppFont.body)
          .foregroundStyle(draft.mode == mode ? AppColor.primary : AppColor.textTertiary)
          .frame(width: BeadsRecitationMetrics.selectionSize)
        Text(title)
          .font(AppFont.body)
          .foregroundStyle(AppColor.textPrimary)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }
      .padding(.vertical, AppSettingsRowMetrics.verticalPadding)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(draft.mode == mode ? .isSelected : [])
  }
}

/// The card lays out what it last revealed, not the draft's current passage.
/// The picker updates the draft while the editor is still underneath it, and a
/// card that re-laid itself out then would have finished growing before anyone
/// saw it. The swap happens as the wave leaves rest, animated, so the card grows
/// toward the new text while the front crosses it; what the card showed before
/// rides ahead of the front as an overlay until the wave has taken it.
private struct BeadsPassageSection: View {
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var draft: BeadsRecitationDraft
  @EnvironmentObject private var navigator: AppNavigatorModel
  @State private var shownPassage: PrayerPassage?
  @State private var outgoing: Outgoing?
  let isRevealActive: Bool

  /// Distinguishes "nothing is outgoing" from "the choose row is outgoing".
  private struct Outgoing {
    let passage: PrayerPassage?
  }

  private var hasPendingReveal: Bool {
    draft.passageRevealID != draft.revealedPassageID
  }

  var body: some View {
    AppListSection {
      side(shownPassage)
        .appDistortionRevealSide(.revealed)
        .overlay(alignment: .topLeading) {
          if let outgoing {
            side(outgoing.passage)
              .appDistortionRevealSide(.outgoing)
          }
        }
    }
    .appDistortionReveal(
      trigger: draft.passageRevealID,
      isActive: isRevealActive,
      shouldAnimate: hasPendingReveal,
      onRevealStarted: {
        outgoing = Outgoing(passage: shownPassage)
        withAnimation(BeadsRecitationMetrics.growth) { shownPassage = draft.passage }
      },
      onRevealCompleted: {
        outgoing = nil
        draft.didRevealPassage()
      }
    )
    .onAppear {
      if !hasPendingReveal { shownPassage = draft.passage }
    }
    .onChange(of: draft.passage) { passage in
      // Reopening a set, or a cancelled picker, changes the passage with no
      // confirmation event: show it at once, with nothing to reveal.
      if !hasPendingReveal { shownPassage = passage }
    }
    .enableInjection()
  }

  /// Full width whatever it holds, so an outgoing overlay laid over a short
  /// one-line passage wraps exactly as it did when it was the card's content.
  @ViewBuilder
  private func side(_ passage: PrayerPassage?) -> some View {
    Group {
      if let passage {
        BeadsPassageView(passage: passage) {
          navigator.navigate(to: [
            .beadsPrayerBrowser,
            .beadsPrayerSelection(prayerID: passage.prayerID, location: passage.location)
          ])
        }
      } else {
        AppSettingsRow(L10n.beadsPrayerChoose, systemImage: "book") {
          navigator.navigate(to: .beadsPrayerBrowser)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct BeadsPassageView: View {
  @ObserveInjection private var injectionObserver
  let passage: PrayerPassage
  let openPicker: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: BeadsRecitationMetrics.contentSpacing) {
      Button(action: openPicker) {
        // One link, with wrapping text rather than a horizontal chain that
        // clips long Burmese titles at accessibility sizes.
        Text("\(passage.prayerTitle) › \(passage.location.verseLabel)")
          .font(AppFont.subheadline)
          .foregroundStyle(AppColor.primary)
          .underline()
          .multilineTextAlignment(.leading)
          .padding(.vertical, AppListSectionMetrics.labelGap)
      }
      .buttonStyle(.plain)
      .accessibilityHint(L10n.beadsRecitationSourceHint)
      Text(passage.text)
        .font(AppFont.body)
        .foregroundStyle(AppColor.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }
    .enableInjection()
  }
}
