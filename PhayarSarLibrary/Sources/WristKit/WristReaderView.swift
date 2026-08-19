#if os(watchOS)
import DesignKit
import RemoteKit
import SwiftUI

/// The remote itself.
///
/// Laid out to fit one screen without scrolling, which is not a stylistic
/// choice: the Digital Crown is driving the *phone's* page, so it is not
/// available to scroll this one. Anything that does not fit here belongs behind
/// the title, which opens the catalog.
struct WristReaderView: View {

  @ObservedObject var remote: WristRemote

  /// The crown's raw value. Meaningless on its own — only the change between
  /// two readings is used, as a distance to scroll the phone by.
  @State private var crown: Double = 0

  private var state: PrayerRemoteState { remote.state }

  private var strings: WristStrings { remote.strings }

  var body: some View {
    VStack(spacing: WristMetrics.sectionSpacing) {
      header

      // The one element that gives. Everything else on this screen has a fixed
      // height, and the total of those heights plus three lines of verse
      // overflows a 41mm watch — so the verse takes whatever is left over and
      // shows as much of itself as fits, which on a 41mm is about two lines and
      // on an Ultra is four.
      //
      // Hand-tuning the numbers to fit the smallest watch was the alternative,
      // and it would have wasted a third of the Ultra's screen to do it.
      glance
        .frame(maxHeight: .infinity)

      controls
      prayerSteps
    }
    .padding(.horizontal, 4)
    .focusable()
    .digitalCrownRotation(
      $crown,
      // A range wide enough that a long reading never reaches either end, with
      // `isContinuous` off so it cannot wrap and produce one enormous delta at
      // the seam.
      from: -1_000_000,
      through: 1_000_000,
      by: 0.25,
      sensitivity: .medium,
      isContinuous: false,
      // The haptics are played by `WristRemote` against the page actually
      // moving, not against the crown turning — at either end of a prayer the
      // crown still turns and the page does not, and a tick there would be the
      // watch claiming something happened.
      isHapticFeedbackEnabled: false
    )
    // The crown's absolute value means nothing — it is a running total against
    // a range picked only to be too wide to reach. What the phone is sent is
    // the *change*, which is what `onChange`'s two values give directly.
    .onChange(of: crown) { previous, value in
      remote.crownDidRotate(by: value - previous)
    }
  }

  // MARK: - Header

  /// The prayer's name, and how far through it the page is.
  ///
  /// The whole thing is the way into the catalog. A toolbar button would cost a
  /// row this screen does not have, and the title is where a reader looks when
  /// they want a different prayer anyway.
  private var header: some View {
    NavigationLink {
      WristCatalogView(remote: remote)
    } label: {
      VStack(spacing: 2) {
        Text(state.prayerTitle ?? strings.noPrayer)
          .font(AppFont.jasmine(size: WristMetrics.titleSize))
          .foregroundStyle(AppColor.textPrimary)
          .lineLimit(1)
          .truncationMode(.tail)

        if let verseIndex = state.verseIndex, state.verseCount > 0 {
          Text("\(verseIndex + 1) / \(state.verseCount)")
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textSecondary)
            .monospacedDigit()
        }

        progressBar
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.plain)
  }

  /// How far through the prayer the page is.
  ///
  /// The count above it is the exact answer and this is the felt one — a reader
  /// glancing down mid-recitation reads a bar in less time than two numbers, and
  /// "nearly there" is usually all they were asking.
  @ViewBuilder
  private var progressBar: some View {
    if let progress = state.progress {
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(AppColor.primarySoft)

          Capsule()
            .fill(AppColor.primary)
            .frame(width: proxy.size.width * progress)
        }
      }
      .frame(height: WristMetrics.progressHeight)
      // Animated because the page it tracks moves continuously under the crown,
      // and a bar that jumped verse to verse would read as a different control
      // from the one the reader is turning.
      .animation(.easeOut(duration: 0.2), value: progress)
    }
  }

  // MARK: - Glance

  /// The verse under the middle of the phone's page.
  ///
  /// Not the point of the screen — the phone is — but a remote that cannot tell
  /// you where it has got to leaves the reader looking up to check every time
  /// they press anything.
  @ViewBuilder
  private var glance: some View {
    if let text = state.verseText, !text.isEmpty {
      VStack(spacing: 3) {
        // Only some verses are named, and only the named ones show it — see
        // `Prayer.Verse.name`. Where there is one it is the fastest way to know
        // which part of a long prayer the page is in, faster than reading the
        // verse itself.
        if let name = state.verseName, !name.isEmpty {
          Text(name)
            .font(AppFont.jasmine(size: WristMetrics.verseNameSize))
            .foregroundStyle(AppColor.primary)
            .lineLimit(1)
        }

        Text(text)
          .font(AppFont.jasmine(size: WristMetrics.verseSize))
          .foregroundStyle(AppColor.textPrimary.opacity(0.9))
          .multilineTextAlignment(.center)
          // A ceiling, not a target — the flexible frame above decides how many
          // lines there is actually room for. This only stops a very long verse
          // from claiming the whole screen on an Ultra.
          .lineLimit(WristMetrics.verseLineLimit)
          // Burmese sets long, and a verse whose first word will not fit the
          // width would otherwise truncate to nothing legible.
          .minimumScaleFactor(WristMetrics.verseMinimumScale)
      }
      .frame(maxWidth: .infinity)
    } else if !state.isReaderOpen {
      Text(strings.readerClosed)
        .font(AppFont.caption)
        .foregroundStyle(AppColor.textSecondary)
        .multilineTextAlignment(.center)
    }
  }

  // MARK: - Controls

  /// Verse back, a push down the page, verse forward.
  ///
  /// Scrolling *up* is left to the crown, which does it better than a button
  /// could and in both directions. The row is for the three moves a reader
  /// makes going forward through a prayer, which is nearly all of them.
  private var controls: some View {
    HStack(spacing: WristMetrics.controlSpacing) {
      WristControlButton(
        systemImage: "chevron.up.2",
        isEnabled: canControlPage
      ) {
        remote.stepVerse(-1)
      }
      .accessibilityLabel(strings.previousVerse)

      WristControlButton(
        systemImage: "chevron.down",
        isProminent: true,
        isEnabled: canControlPage
      ) {
        remote.scrollPage(WristMetrics.buttonScroll)
      }
      .accessibilityLabel(strings.scrollDown)

      WristControlButton(
        systemImage: "chevron.down.2",
        isEnabled: canControlPage
      ) {
        remote.stepVerse(1)
      }
      .accessibilityLabel(strings.nextVerse)
    }
  }

  /// The prayer either side of this one.
  private var prayerSteps: some View {
    HStack(spacing: WristMetrics.controlSpacing) {
      WristControlButton(
        systemImage: "backward.end",
        height: WristMetrics.secondaryControlHeight,
        isEnabled: remote.isReachable && state.canStepPrayerBack
      ) {
        remote.stepPrayer(-1)
      }
      .accessibilityLabel(strings.previousPrayer)

      WristControlButton(
        systemImage: "forward.end",
        height: WristMetrics.secondaryControlHeight,
        isEnabled: remote.isReachable && state.canStepPrayerForward
      ) {
        remote.stepPrayer(1)
      }
      .accessibilityLabel(strings.nextPrayer)
    }
  }

  /// Whether the page controls have a page to act on. They stay visible but
  /// dimmed when they do not, so the screen keeps its shape.
  private var canControlPage: Bool {
    remote.isReachable && state.isReaderOpen
  }
}
#endif
