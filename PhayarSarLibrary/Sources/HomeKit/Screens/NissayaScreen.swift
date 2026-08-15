import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI
import UtilKit

/// Layout constants for `NissayaScreen`.
private enum NissayaMetrics {
  /// Gap above the deck. Small — the cards carry their own margin, and the
  /// navigation bar is already a boundary.
  static let deckTopPadding: CGFloat = 8

  /// Gap between the deck and the pager below it.
  static let pagerTopPadding: CGFloat = 12

  static let pagerBottomPadding: CGFloat = 8

  /// Gap between the pager's chevrons and the counter between them.
  static let pagerSpacing: CGFloat = 16

  /// Tap target for a chevron. Below Apple's 44pt the buttons would be the one
  /// thing on the screen that is hard to hit.
  static let stepButtonSize: CGFloat = 44

  static let progressTrackHeight: CGFloat = 4

  /// Gap between the counter and the track under it.
  static let counterSpacing: CGFloat = 7
}

/// The study screen — each verse against its translation.
///
/// The prayer as a deck of cards rather than as a page: one verse faces the
/// reader at a time, swiped through like a Smart Stack (see
/// ``NissayaCardStack``), with the Pali and its meaning side by side inside each
/// card wherever there is width for two columns.
///
/// A separate screen from ``PrayerScreen`` rather than a mode of it. That one is
/// for reciting — a continuous scroll, sized and coloured to be read aloud from
/// — and this one is for study, where the unit is a single verse and the point
/// is what it says. The two want opposite layouts, so they are two screens.
///
/// Pushed from ``PrayerDetailScreen``'s "Nissaya" quick action, via
/// `RouterDestination.nissaya(prayerID:)`.
public struct NissayaScreen: View {
  @ObserveInjection private var injectionObserver

  /// Resolved from the id the route carried rather than passed in whole — see
  /// `RouterDestination`, whose payloads are ids so that routes stay `Codable`.
  private let prayer: Prayer?

  /// Which verse is facing the reader. Owned here rather than in the deck
  /// because the pager below it steps through the same value.
  @State private var index = 0

  public init(prayerID: String) {
    self.prayer = PrayerCatalog.shared.prayer(id: prayerID)
  }

  public var body: some View {
    Group {
      // An empty body is folded in with the missing prayer on purpose: a deck
      // with no cards in it has nothing to say either, and both are the same
      // "this build can't show you that" to the reader.
      if let prayer, !prayer.body.isEmpty {
        Deck(prayer)
      } else {
        PrayerNotFoundView()
      }
    }
    .navigationTitle(prayer?.title ?? L10n.prayerNotFound)
    // No navigation bar on macOS, so no display mode to set either.
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    // Also set on the detail screen this is pushed from, but the tab bar would
    // otherwise sit under the pager and compete with it for the same thumb.
    .hideTabBar()
    .appBackground()
    .enableInjection()
  }

  // MARK: - Deck

  @ViewBuilder
  private func Deck(_ prayer: Prayer) -> some View {
    VStack(spacing: 0) {
      NissayaCardStack(verses: prayer.body, index: $index)
        .padding(.top, NissayaMetrics.deckTopPadding)

      Pager(total: prayer.body.count)
    }
  }

  // MARK: - Pager

  /// Where the reader is in the prayer, and the other way of moving through it.
  ///
  /// The chevrons are not just a convenience. A swipe is unreachable under
  /// VoiceOver and awkward on a Mac, and this screen's whole content is behind
  /// one — so the deck needs a control that is a plain, labelled button.
  @ViewBuilder
  private func Pager(total: Int) -> some View {
    HStack(spacing: NissayaMetrics.pagerSpacing) {
      StepButton(
        icon: "chevron.left",
        label: L10n.previousVerse,
        isEnabled: index > 0
      ) {
        step(to: index - 1, total: total)
      }

      VStack(spacing: NissayaMetrics.counterSpacing) {
        Text("\(index + 1) / \(total)")
          .font(AppFont.captionBold)
          // Otherwise the counter jostles sideways every time it steps between
          // digits of different widths.
          .monospacedDigit()
          .foregroundStyle(AppColor.textSecondary)

        ProgressTrack(fraction: Double(index + 1) / Double(max(1, total)))
      }
      // Read as one thing. Split, VoiceOver announces a bare "3 / 12" with no
      // idea what it counts, then a progress bar saying the same again.
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(L10n.verses), \(index + 1) / \(total)")

      StepButton(
        icon: "chevron.right",
        label: L10n.nextVerse,
        isEnabled: index < total - 1
      ) {
        step(to: index + 1, total: total)
      }
    }
    .appHorizontalInset()
    .padding(.top, NissayaMetrics.pagerTopPadding)
    .padding(.bottom, NissayaMetrics.pagerBottomPadding)
  }

  /// Moves the deck, on the same curve a swipe settles on so the two ways of
  /// turning a card are indistinguishable once the finger is off the glass.
  private func step(to target: Int, total: Int) {
    let clamped = min(max(target, 0), total - 1)
    guard clamped != index else { return }

    withAnimation(.nissayaCardSettle) {
      index = clamped
    }
  }
}

// MARK: - Pieces

/// One end of the pager: a chevron that turns the deck by a card.
private struct StepButton: View {
  let icon: String
  let label: String
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(AppFont.headline)
        .foregroundStyle(isEnabled ? AppColor.primary : AppColor.textTertiary)
        .frame(
          width: NissayaMetrics.stepButtonSize,
          height: NissayaMetrics.stepButtonSize
        )
        // Without it the tap target is the glyph's own ink, not the frame
        // around it.
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    // The glyph is the whole label, so VoiceOver gets the words instead.
    .accessibilityLabel(label)
  }
}

/// How far through the prayer the deck has been read.
///
/// A bar rather than a row of dots: prayers run to 40-odd verses, and that many
/// dots is a texture rather than a count.
private struct ProgressTrack: View {
  let fraction: Double

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule(style: .continuous)
          .fill(AppColor.border)

        Capsule(style: .continuous)
          .fill(AppColor.primary)
          .frame(width: proxy.size.width * min(max(fraction, 0), 1))
      }
    }
    .frame(height: NissayaMetrics.progressTrackHeight)
    // A `GeometryReader` is greedy vertically, and inside the pager's `VStack`
    // it would otherwise claim every point the row could give it.
    .fixedSize(horizontal: false, vertical: true)
  }
}

// MARK: - Previews

#Preview {
  NavigationStack {
    NissayaScreen(prayerID: "Khandha")
  }
}

#Preview("Named verses") {
  NavigationStack {
    NissayaScreen(prayerID: "ပဋ္ဌာန်းအကျယ်")
  }
}

#Preview("Long meanings") {
  NavigationStack {
    NissayaScreen(prayerID: "ဓဇဂ္ဂသုတ်")
  }
}

#Preview("Not found") {
  NavigationStack {
    NissayaScreen(prayerID: "no-such-prayer")
  }
}
