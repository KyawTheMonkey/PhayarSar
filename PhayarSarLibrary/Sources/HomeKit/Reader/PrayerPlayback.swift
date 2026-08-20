import DesignKit
import LocalisationKit
import PrayersKit
import SwiftUI
import UtilKit

// MARK: - State

/// Whether the page is reading itself, and if it has been stopped or only
/// halted.
///
/// Three states rather than a `Bool` and a second `Bool`, because the middle one
/// is a real place: paused is not "stopped, quietly" — the page keeps the line
/// it had got to, keeps the rest of the prayer stepped back around it, and keeps
/// its gestures out of the reader's way. It is playback holding its breath.
///
/// Shared between the SwiftUI shell that owns the controls and the UIKit reader
/// that does the moving, which is why it is out here rather than nested in
/// either — and why it is outside the platform guard the reader lives behind.
enum PrayerPlaybackState {
  /// The ordinary reading page. Nothing is moving on its own.
  case stopped

  /// Stepping down the prayer a line at a time.
  case playing

  /// Stopped where it stands, and ready to go on from there.
  case paused
}

// MARK: - Speed

/// What each pace costs the page in time.
///
/// The pace itself is ``PrayerPlaybackSpeed``, which lives in `PrayersKit`
/// because it is stored per prayer alongside the theme. What a multiple of the
/// ordinary pace works out to in seconds is the reader's business, and the
/// reader is here.
extension PrayerPlaybackSpeed {
  /// What the page holds each line for at this pace.
  var interval: TimeInterval {
    PrayerReaderMetrics.playbackInterval / rawValue
  }

  /// And how long the step into the next line takes.
  ///
  /// Scaled with the pace rather than fixed, so the whole reading speeds up and
  /// slows down as one thing rather than the page travelling at a constant rate
  /// and waiting longer between journeys. Held inside bounds at both ends: the
  /// step has to finish well before the line's time is up, and it has to be long
  /// enough to be a movement rather than a cut.
  var scroll: TimeInterval {
    min(max(PrayerReaderMetrics.playbackScroll / rawValue, 0.2), 0.9)
  }
}

// MARK: - Metrics

/// Layout and feel constants for the playback bar.
enum PrayerPlaybackMetrics {
  /// Between the two controls. Wide enough that a thumb aiming for pause does
  /// not stop the reading instead.
  static let controlSpacing: CGFloat = 4

  /// Air either side of the pair, so the pill has an edge rather than ending at
  /// the glyphs.
  static let controlInset: CGFloat = 6

  /// A control's tap target, and the size the glyph is centred in. Square and a
  /// touch narrower than the pill is tall, which is what keeps the two circles
  /// clear of its ends.
  static let controlSize: CGFloat = 36

  /// The bar is the shut pill's height, and shares its corner rule — it arrives
  /// where the switcher left, and a control of a different height there would
  /// read as the page having jumped.
  static var height: CGFloat { PrayerPageSwitcherMetrics.shutHeight }

  /// Between the two pills. Enough that they read as two controls rather than
  /// one control with a seam in it — they answer different questions, and the
  /// gap is what says so.
  static let pillSpacing: CGFloat = 8

  /// Air either side of a speed, and the corner its marker is drawn with.
  ///
  /// Tighter than the transport controls' targets, and it has to be: five of
  /// these sit beside a pill that is already 84 points wide, on a screen that
  /// can be 320 points across.
  static let speedInset: CGFloat = 7
  static let speedHeight: CGFloat = 26

  /// The chosen speed's own colours, and the only two in the reader that are
  /// neither the page's nor the app's.
  ///
  /// Fixed rather than derived from the page, which is the point of them. The
  /// pill floats over six different papers and the marker has to be
  /// unmistakable on all six at a glance, mid-recitation, from arm's length —
  /// and ink-on-paper cannot be, because on three of those papers the ink *is*
  /// nearly this pill. Black and yellow is the pairing the eye finds fastest,
  /// which is why every warning sign ever made is made of it.
  static let speedActiveFill = Color.black
  static let speedActiveInk = Color.yellow

  /// What the speeds that are not chosen fade to. Legible, because the reader
  /// is choosing between them and has to be able to read the one they are aiming
  /// for; well back, because only one of them is true.
  static let speedRestingOpacity: Double = 0.45

  /// How the bar and the switcher hand over to one another.
  static let handover: Animation = .readerPageSettle
}

// MARK: - Bar

/// Pause and stop, floating where the page switcher rests.
///
/// In the switcher's place rather than beside it, for two reasons. The strip is
/// no use while the page is reading itself — scrubbing to another prayer would
/// be asking playback to abandon the one it is in the middle of — and this is
/// where the thumb already is. A reader who wants to stop should not have to
/// find a new corner of the screen to do it in.
///
/// Wearing the switcher's own surface, by way of ``PrayerTrayBackground`` at
/// zero openness: the shut pill's wash of the page's colour, its hairline, and
/// its shadow. The two are the same object as far as the reader is concerned,
/// showing whichever controls the page currently answers to.
struct PrayerPlaybackBar: View {
  let state: PrayerPlaybackState

  /// How fast the page is reading itself.
  let speed: PrayerPlaybackSpeed

  /// For the page's own ink and paper — the bar is a mark on the page, and the
  /// page can be black while the app is in light mode.
  let settings: PrayerSettings

  /// Play when paused, pause when playing.
  let onToggle: () -> Void

  /// Puts the page back the way it was found: the whole prayer at full strength,
  /// and every gesture back in the reader's hands.
  let onStop: () -> Void

  /// Changes the pace. Takes effect from the line after the one being read.
  let onSpeed: (PrayerPlaybackSpeed) -> Void

  private var ink: Color { settings.background.foreground }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: PrayerPlaybackMetrics.height / 2, style: .continuous)
  }

  private var isPlaying: Bool { state == .playing }

  var body: some View {
    // Two pills rather than one long one. They answer different questions —
    // whether the page is reading, and how fast — and a reader reaching for
    // pause in the middle of a recitation should not have to pick it out of a
    // row of seven things.
    HStack(spacing: PrayerPlaybackMetrics.pillSpacing) {
      transport
      speeds
    }
    // The pair are their own width, centred in the strip the switcher fills.
    .frame(maxWidth: .infinity)
    // The glyph changes under the finger that changed it, so the click belongs
    // to the control rather than to the page starting or stopping.
    .appSelectionFeedback(trigger: state)
  }

  /// Pause and stop.
  private var transport: some View {
    HStack(spacing: PrayerPlaybackMetrics.controlSpacing) {
      // Live in both states, and the only control that is: the reading can be
      // held and let go as often as the reader likes, and neither of those is
      // the end of it.
      control(
        systemImage: isPlaying ? "pause.fill" : "play.fill",
        label: isPlaying ? L10n.pausePrayer : L10n.playPrayer,
        action: onToggle
      )

      // The one way out, and the only red in the reader.
      //
      // Red because it is the only control here that does not simply change
      // what is happening — it ends it, gives the page back, and loses the line
      // the reading had got to. Pause is a rest; this is a decision, and the
      // colour is what tells the two apart at a glance in the middle of a
      // recitation.
      control(
        systemImage: "stop.fill",
        label: L10n.stopPrayer,
        tint: AppColor.error,
        action: onStop
      )
    }
    .padding(.horizontal, PrayerPlaybackMetrics.controlInset)
    .frame(height: PrayerPlaybackMetrics.height)
    .modifier(surface)
  }

  /// The pace, all five of them at once.
  ///
  /// Laid out rather than cycled through by tapping one thing, and not hidden
  /// behind a menu either. The reader picking a pace is choosing *between*
  /// these — a quarter speed to learn a line, double to run through something
  /// they know — and a control that shows the alternatives is one they can aim
  /// at rather than count taps through.
  private var speeds: some View {
    HStack(spacing: 0) {
      ForEach(PrayerPlaybackSpeed.allCases, id: \.self) { option in
        Button {
          onSpeed(option)
        } label: {
          Text(option.label)
            .font(.system(size: 12, weight: option == speed ? .semibold : .regular))
            // So the row does not shuffle sideways as the marker moves: every
            // label keeps its width whatever weight it is drawn at.
            .monospacedDigit()
            .foregroundStyle(
              option == speed
                ? PrayerPlaybackMetrics.speedActiveInk
                : ink.opacity(PrayerPlaybackMetrics.speedRestingOpacity)
            )
            // The last resort on a 320-point screen, where five of these sit
            // beside the transport pill. It costs a fraction of a point of type
            // rather than dropping a speed or wrapping the row.
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, PrayerPlaybackMetrics.speedInset)
            .frame(height: PrayerPlaybackMetrics.speedHeight)
            .background {
              if option == speed {
                Capsule().fill(PrayerPlaybackMetrics.speedActiveFill)
              }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(option == speed ? .isSelected : [])
      }
    }
    .padding(.horizontal, PrayerPlaybackMetrics.controlInset - PrayerPlaybackMetrics.speedInset)
    .frame(height: PrayerPlaybackMetrics.height)
    .modifier(surface)
    // The marker slides between speeds rather than blinking from one to the
    // next, which is the only thing that says the five are one control.
    .animation(PrayerPlaybackMetrics.handover, value: speed)
    .appSelectionFeedback(trigger: speed)
  }

  /// The shut pill's own surface — see ``PrayerTrayBackground``.
  private var surface: PrayerTrayBackground {
    PrayerTrayBackground(
      shape: shape,
      openness: 0,
      pageColor: settings.background.color,
      pageInk: ink
    )
  }

  private func control(
    systemImage: String,
    label: String,
    tint: Color? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .semibold))
        // The page's own ink unless the control has something of its own to
        // say — the bar is a mark on the page, and the page can be black while
        // the app is in light mode.
        .foregroundStyle(tint ?? ink)
        .frame(
          width: PrayerPlaybackMetrics.controlSize,
          height: PrayerPlaybackMetrics.controlSize
        )
        // The whole square, not the glyph: a stop symbol is a small target, and
        // the space around it is target the control has already been given.
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

