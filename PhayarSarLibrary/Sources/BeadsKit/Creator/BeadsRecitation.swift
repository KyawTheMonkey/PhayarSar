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
  let beadsID: UUID?

  init(beadsID: UUID? = nil, prayerID: String? = nil, verseID: Int? = nil) {
    self.beadsID = beadsID
    if let beadsID,
       case let .prayer(passage)? = BeadsStore.shared.beads.first(where: { $0.id == beadsID })?.recitation {
      self.mode = .prayer
      self.passage = passage
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

/// Owns a draft for the lifetime of the entire modal stack, not an individual
/// screen. Browser pushes and breadcrumb detours inherit the same object, and
/// dismissing the sheet drops both inactive and active source drafts together.
public struct BeadsCreatorContext<Content: View>: View {
  @StateObject private var draft: BeadsRecitationDraft
  private let content: Content

  public init(
    beadsID: UUID? = nil, prayerID: String? = nil, verseID: Int? = nil,
    @ViewBuilder content: () -> Content
  ) {
    _draft = StateObject(wrappedValue: BeadsRecitationDraft(
      beadsID: beadsID, prayerID: prayerID, verseID: verseID
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
}

struct BeadsRecitationSection: View {
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var draft: BeadsRecitationDraft
  @EnvironmentObject private var navigator: AppNavigatorModel

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
        AppListSection {
          if let passage = draft.passage {
            BeadsPassageView(
              passage: passage, revealTrigger: draft.passageRevealID,
              isRevealActive: navigator.sheetPath.isEmpty,
              shouldReveal: draft.passageRevealID != draft.revealedPassageID,
              onRevealCompleted: draft.didRevealPassage
            ) {
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

struct BeadsPassageView: View {
  @ObserveInjection private var injectionObserver
  let passage: PrayerPassage
  var revealTrigger: UUID? = nil
  var isRevealActive = true
  var shouldReveal = true
  var onRevealCompleted: () -> Void = {}
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
        .appParticleReveal(
          trigger: revealTrigger, shaderBundle: .module,
          isActive: isRevealActive,
          shouldAnimate: shouldReveal, onRevealCompleted: onRevealCompleted
        )
    }
    .enableInjection()
  }
}
