import DesignKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI

/// Layout constants for `PrayerDetailScreen`.
private enum PrayerDetailMetrics {
  /// Cover art. Square and roughly half the width of a phone, so the hero reads
  /// as artwork rather than as an oversized list thumbnail.
  static let coverSize: CGFloat = 176
  static let coverCornerRadius: CGFloat = 28

  /// Gap between the cover and the title block beneath it.
  static let heroSpacing: CGFloat = 20

  /// Diameter of a quick action's tinted icon circle. Kept under the row's own
  /// height so the circle sits inside the line of text rather than setting the
  /// row's rhythm.
  static let actionIconDiameter: CGFloat = 32

  static let ctaCornerRadius: CGFloat = 16

  /// How much of the about text shows before the "Show more" toggle takes over.
  static let aboutCollapsedLineLimit = 5

  /// Above this many characters the about text is assumed not to fit in
  /// ``aboutCollapsedLineLimit`` lines, and the toggle is offered.
  ///
  /// A count rather than a real truncation measurement: `ViewThatFits` can't
  /// decide this inside a `ScrollView`, which proposes unbounded height, so
  /// every candidate would "fit". The threshold sits well above the ~200
  /// characters five lines actually hold, which biases towards not showing a
  /// toggle that would reveal nothing.
  static let aboutExpandThreshold = 240
}

public struct PrayerDetailScreen: View {
  @ObserveInjection private var injectionObserver

  /// Resolved from the id the route carried rather than passed in whole — see
  /// `RouterDestination`, whose payloads are ids so that routes stay `Codable`.
  private let prayer: Prayer?

  public init(prayerID: String) {
    self.prayer = PrayerCatalog.shared.prayer(id: prayerID)
  }

  public var body: some View {
    Group {
      if let prayer {
        PrayerContent(prayer)
      } else {
        PrayerNotFoundView()
      }
    }
    .navigationTitle(prayer?.title ?? L10n.prayerNotFound)
    // No navigation bar on macOS, so no display mode to set either.
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .appBackground()
    .enableInjection()
  }

  // MARK: - Content

  @ViewBuilder
  private func PrayerContent(_ prayer: Prayer) -> some View {
    ScrollView {
      VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
        Hero(prayer)

        if !prayer.about.isEmpty {
          PrayerAboutSection(about: prayer.about)
        }

        QuickActions()
      }
      .padding(.top, 8)
      .padding(.bottom, AppListSectionMetrics.recommendedSectionSpacing)
    }
    .safeAreaInset(edge: .bottom) {
      StartBar()
    }
  }

  // MARK: - Hero

  @ViewBuilder
  private func Hero(_ prayer: Prayer) -> some View {
    VStack(spacing: PrayerDetailMetrics.heroSpacing) {
      RoundedRectangle(
        cornerRadius: PrayerDetailMetrics.coverCornerRadius,
        style: .continuous
      )
      .fill(AppColor.grey300)
      .frame(
        width: PrayerDetailMetrics.coverSize,
        height: PrayerDetailMetrics.coverSize
      )
      .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
      .accessibilityHidden(true)

      VStack(spacing: 12) {
        Text(prayer.title)
          .font(AppFont.title)
          .foregroundStyle(AppColor.textPrimary)
          .multilineTextAlignment(.center)

        HStack(spacing: 8) {
          MetaChip(
            icon: "clock",
            text: "\(prayer.estimatedMinutes) \(L10n.minutesUnit)",
            accessibilityLabel: "\(L10n.duration), \(prayer.estimatedMinutes) \(L10n.minutesUnit)"
          )

          MetaChip(
            icon: "list.bullet",
            text: "\(prayer.body.count) \(L10n.verses)",
            accessibilityLabel: "\(prayer.body.count) \(L10n.verses)"
          )
        }
      }
    }
    .frame(maxWidth: .infinity)
    .appHorizontalInset()
  }

  // MARK: - Quick actions

  /// The quick actions, in tap order. Nissaya sits with Add to plan because
  /// both act on the prayer itself; the two below it are about the app's
  /// handling of it.
  ///
  /// No destinations yet: `RouterDestination` and `SheetDestination` don't
  /// carry these screens, so the rows are wired but land nowhere until they do.
  private var quickActions: [(icon: String, title: String)] {
    [
      ("calendar.badge.plus", L10n.addToPlan),
      ("character.book.closed", L10n.nissaya),
      ("paintpalette", L10n.themeAndSettings),
      ("exclamationmark.bubble", L10n.reportError)
    ]
  }

  @ViewBuilder
  private func QuickActions() -> some View {
    AppListSection(L10n.quickActions) {
      ForEach(Array(quickActions.enumerated()), id: \.offset) { index, action in
        if index > 0 {
          Divider()
            .padding(.vertical, 8)
        }

        QuickActionRow(icon: action.icon, title: action.title) {}
      }
    }
  }

  // MARK: - Start CTA

  @ViewBuilder
  private func StartBar() -> some View {
    Button {
      // The reading screen doesn't exist yet.
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "play.fill")
        Text(L10n.startReading)
      }
      .font(AppFont.headline)
      .foregroundStyle(AppColor.buttonPrimaryText)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .background(
        AppColor.buttonPrimaryBackground,
        in: RoundedRectangle(
          cornerRadius: PrayerDetailMetrics.ctaCornerRadius,
          style: .continuous
        )
      )
    }
    .buttonStyle(PressableButtonStyle())
    .appHorizontalInset()
    .padding(.top, 12)
    .padding(.bottom, 8)
    .background {
      // `AppFadeBlurBackground` is built for a top bar — strongest at its top
      // edge, fading downward. Turning it over puts the solid end against the
      // screen's bottom and the fade against the content, which is what a
      // bottom bar needs.
      AppFadeBlurBackground()
        .rotationEffect(.degrees(180))
        .ignoresSafeArea(edges: .bottom)
    }
  }
}

// MARK: - Pieces

/// The prayer's background text, clamped to a few lines with a toggle when it
/// runs long.
///
/// A view of its own rather than a method on the screen so that it owns the
/// expansion state. Held on the screen, a tap would re-evaluate the whole
/// screen's `body` — the hero's shadowed cover art and the CTA's masked
/// material blur included — none of which has anything to do with this toggle.
private struct PrayerAboutSection: View {
  private let about: String

  /// Settled at init rather than read from `body`. `String.count` walks the
  /// whole string with Unicode segmentation (0.15ms for the longest `about` on
  /// a Mac), and `body` runs far more often than this text changes, which is
  /// never.
  private let canExpand: Bool

  @State private var isExpanded = false

  init(about: String) {
    self.about = about
    self.canExpand = about.count > PrayerDetailMetrics.aboutExpandThreshold
  }

  var body: some View {
    AppListSection(L10n.prayerAbout) {
      VStack(alignment: .leading, spacing: 12) {
        Text(about)
          .font(AppFont.body)
          .foregroundStyle(AppColor.textSecondary)
          // Burmese script stacks diacritics above and below the baseline, so
          // the default leading crowds consecutive lines.
          .lineSpacing(6)
          .lineLimit(isExpanded ? nil : PrayerDetailMetrics.aboutCollapsedLineLimit)
          .frame(maxWidth: .infinity, alignment: .leading)

        if canExpand {
          // Bare toggle, no `withAnimation`. Animating a line-limit change
          // animates the paragraph's height, and SwiftUI re-runs the text
          // layout at every intermediate height it passes through — thousands
          // of characters of Burmese, reshaped once a frame for the whole
          // transition. That was the hitch. Snapping the reflow lays the text
          // out once; the chevron below carries the motion instead.
          Button {
            withAnimation(.smooth) {
              isExpanded.toggle()
            }
          } label: {
            HStack(spacing: 4) {
              Text(isExpanded ? L10n.showLess : L10n.showMore)
              Image(systemName: "chevron.down")
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .font(AppFont.button)
            .foregroundStyle(AppColor.primary)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

/// A capsule of one fact about the prayer — its length, its size.
private struct MetaChip: View {
  let icon: String
  let text: String
  /// The icon carries meaning the label doesn't spell out, so VoiceOver is
  /// given the full phrase rather than the bare number.
  let accessibilityLabel: String

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: icon)
        .font(AppFont.caption)
      Text(text)
        .font(AppFont.caption)
    }
    .foregroundStyle(AppColor.textSecondary)
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
    .background(AppColor.surface, in: Capsule(style: .continuous))
    .overlay(Capsule(style: .continuous).strokeBorder(AppColor.border, lineWidth: 0.5))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }
}

/// One quick action: a tinted icon, its label, and a disclosure chevron.
private struct QuickActionRow: View {
  let icon: String
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AppColor.primary)
          .frame(
            width: PrayerDetailMetrics.actionIconDiameter,
            height: PrayerDetailMetrics.actionIconDiameter
          )
          .background(AppColor.primarySoft, in: Circle())

        Text(title)
          .font(AppFont.body)
          .foregroundStyle(AppColor.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textTertiary)
      }
      // Without this the label only covers the icon and text, leaving the gap
      // before the chevron dead.
      .contentShape(Rectangle())
    }
    // Rows highlight rather than shrink: scaling something this wide reads as
    // the card itself flexing.
    .buttonStyle(PressableButtonStyle(pressedScale: 1))
  }
}

/// `.plain` with the press feedback put back — plain leaves a filled control
/// looking dead under the finger.
private struct PressableButtonStyle: ButtonStyle {
  /// `1` for full-width rows, where only the dimming should show.
  var pressedScale: CGFloat = 0.97

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.7 : 1)
      .scaleEffect(configuration.isPressed ? pressedScale : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

/// Shown when the route's id matches no bundled prayer.
///
/// Reachable state rather than a programmer error: with id-carrying routes, a
/// notification payload or a restored stack can name a prayer that a later
/// build no longer ships.
private struct PrayerNotFoundView: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "questionmark.circle")
        .font(.largeTitle)
      Text(L10n.prayerNotFound)
        .multilineTextAlignment(.center)
    }
    .foregroundStyle(.secondary)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Previews

#Preview {
  NavigationStack {
    PrayerDetailScreen(prayerID: "Khandha")
  }
}

#Preview("Long about") {
  NavigationStack {
    PrayerDetailScreen(prayerID: "သရဏဂုံ")
  }
}

#Preview("No about") {
  NavigationStack {
    PrayerDetailScreen(prayerID: "အမျှဝေ")
  }
}

#Preview("Not found") {
  NavigationStack {
    PrayerDetailScreen(prayerID: "no-such-prayer")
  }
}
