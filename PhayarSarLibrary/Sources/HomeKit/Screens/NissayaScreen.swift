import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI
import UtilKit

/// Layout constants for `NissayaScreen`.
private enum NissayaMetrics {
  /// Clearance kept at each end of the deck, so a card tall enough to hit its
  /// cap still stops short of the navigation bar and the home indicator rather
  /// than running under them.
  ///
  /// Taken out of the height the deck is offered rather than applied as
  /// padding — see `deckRoom(in:)`. Padding would push a tall card down instead
  /// of making it shorter.
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

  /// How tall the pager turned out to be, so the deck can be told how much room
  /// is left for it. `0` until the first layout pass.
  @State private var pagerHeight: CGFloat = 0

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

  /// The deck and its pager, as one block centred in the screen.
  ///
  /// Centred as a *pair* rather than laid out top-to-bottom. Now that a card is
  /// only as tall as its verse, a pager pinned to the bottom of an iPad would
  /// sit some 300pt below the card it drives — near enough to look like it
  /// belongs to something else. Closed up, the two read as one object with room
  /// around it, which is what the space is for.
  ///
  /// The screen owns the only `GeometryReader` here, and hands the room down.
  /// One inside the deck would fill whatever it was offered, which is exactly
  /// what this layout needs it not to do.
  @ViewBuilder
  private func Deck(_ prayer: Prayer) -> some View {
    GeometryReader { proxy in
      VStack(spacing: NissayaMetrics.pagerTopPadding) {
        NissayaCardStack(
          verses: prayer.body,
          index: $index,
          available: CGSize(
            width: proxy.size.width,
            height: deckRoom(in: proxy.size.height)
          )
        )

        Pager(total: prayer.body.count)
          // Measured rather than assumed: the row is 44pt tall at the default
          // text size, but the counter inside it grows with Dynamic Type, and a
          // hard-coded number would start cropping the card at the largest
          // sizes.
          .background {
            GeometryReader { geometry in
              Color.clear.preference(
                key: PagerHeightKey.self,
                value: geometry.size.height
              )
            }
          }
      }
      // Centres the pair. No padding on top of this — the clearance the deck
      // needs is taken out of the height it is offered instead, in
      // `deckRoom(in:)`, so that a tall card is capped short of the navigation
      // bar rather than pushed into it.
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .onPreferenceChange(PagerHeightKey.self) { pagerHeight = $0 }
  }

  /// How tall the deck may grow, given the whole screen.
  ///
  /// Everything the deck does not own comes off first: the pager, the gap above
  /// it, and a margin at each end so a full-height card still clears the
  /// navigation bar and the home indicator.
  private func deckRoom(in totalHeight: CGFloat) -> CGFloat {
    let reserved = pagerHeight
      + NissayaMetrics.pagerTopPadding
      + NissayaMetrics.deckTopPadding * 2

    return max(NissayaCardMetrics.minCardHeight, totalHeight - reserved)
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

/// The pager's measured height, so the deck knows how much room is left.
private struct PagerHeightKey: PreferenceKey {
  static var defaultValue: CGFloat { 0 }

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

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
