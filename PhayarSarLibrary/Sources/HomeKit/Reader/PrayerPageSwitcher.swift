import DesignKit
import LocalisationKit
import PrayersKit
import SwiftUI
import UtilKit

// MARK: - Direction

/// Which way a one-step nudge goes.
enum PrayerPageDirection {
  case previous
  case next

  /// Step to add to a position in the catalog.
  var step: Int {
    switch self {
    case .previous:
      return -1
    case .next:
      return 1
    }
  }
}

// MARK: - Commit

/// How a prayer was arrived at, which decides whether the page turns or simply
/// changes.
enum PrayerPageCommit {
  /// Live under the finger, while the shut pill is being scrubbed. The page
  /// changes outright, with no turn: a half-second dissolve per tick crossed
  /// would be a strobe, and the reader is using the page itself to see where
  /// they are.
  case tracking
  /// The finger has lifted, or the choice was made some other way. The page
  /// turns.
  case settled
}

// MARK: - Metrics

/// Layout and feel constants for the floating page switcher.
enum PrayerPageSwitcherMetrics {
  /// What the pill measures when it is fully shut. The open height is not here
  /// because it is *measured* — see ``PrayerPageSwitcher/openHeight``.
  ///
  /// Square, so that the radius rule below — half the height until the tray is
  /// tall enough to want less — makes the shut state a circle without anything
  /// having to decide that it is one.
  static let shutHeight: CGFloat = 40

  /// Stand-ins for the two measured ends of the morph, used for the one layout
  /// pass before the real sizes come back. Close enough that the first frame is
  /// not visibly wrong.
  static let openHeightGuess: CGFloat = 100
  static let shutWidthGuess: CGFloat = shutStripWidth + shutStripInset * 2

  /// Open, the tray sizes itself: the title inside it grows with Dynamic Type,
  /// and a fixed height would clip it.
  ///
  /// Not as tight as it could be drawn, because the tray is not only something
  /// to look at. Every point of it is also somewhere a thumb can take hold and
  /// haul the thing up or down, and a tray trimmed to its contents leaves a
  /// band a few points tall between the ruler and the edge where that is the
  /// only thing a drag could mean. The padding here is grip.
  static let trayInset: CGFloat = 14
  static let trayVerticalPadding: CGFloat = 18
  /// Between the header and the strip under it. Also grip: this band belongs to
  /// neither control, so a drag starting in it is unambiguous.
  static let trayRowSpacing: CGFloat = 14
  /// Between the title and the counter beside it.
  static let headerSpacing: CGFloat = 10

  /// Clearance from the bottom safe area.
  ///
  /// Well clear of it rather than just past it. A control sitting on the safe
  /// area's edge is at the very bottom of the screen, which is the one place a
  /// thumb has to stretch *down* to reach and the one place the home
  /// indicator's own gesture is listening — a pull-up starting there is a pull
  /// up from the worst possible spot. Lifting it into the pad of the thumb's
  /// natural arc costs a little of the page and buys the whole gesture.
  ///
  /// ``PrayerReaderMetrics/bottomInset`` is derived from this plus
  /// ``shutHeight``, so raising it moves the reader's last line up to match
  /// without anything else having to be touched.
  static let bottomPadding: CGFloat = 32

  // MARK: Opening

  /// How much upward travel takes the tray from shut to open.
  ///
  /// The whole gesture is measured against this one number, which is what makes
  /// every point between the two states reachable and holdable — the tray is
  /// never *animating* open under the finger, it is simply as open as the hand
  /// has made it.
  static let openSpan: CGFloat = 90

  /// Where a released gesture settles to. Compared against the *projected*
  /// openness rather than the actual one, so a flick counts for as much as a
  /// haul — see `PrayerPageSwitcher.pullAndScrub`.
  static let openThreshold: CGFloat = 0.5

  /// Corner radius once the tray is tall enough to want one. Below that the
  /// radius is simply half the height, which is what makes the shut pill a
  /// capsule without anything having to decide that it is one.
  static let openRadius: CGFloat = 22

  /// How far a drag has to reach for the control to have given all it is going
  /// to. Also the scale of the rubber band — see `resisted(_:)`.
  ///
  /// Generous. This is the travel a reader gets *after* the tray is already as
  /// open as it goes, and a short one reads as the control having stopped
  /// listening — the finger is still moving and nothing on screen is. Half a
  /// tray's height of give is enough to feel like something being held against
  /// a spring rather than something that has hit a wall.
  static let giveSpan: CGFloat = 64
  /// How much of a sideways drag the control takes as bodily movement. The rest
  /// of it is scrubbing; this is only the part that says the hand is on it.
  static let sidewaysGive: CGFloat = 0.25
  /// How much the control swells at the far end of a give.
  static let giveLift: CGFloat = 0.03

  // MARK: Surface

  /// The open tray is its own surface, not a tinted piece of the page.
  ///
  /// A scrubber is an instrument, and an instrument reads as one by being made
  /// of something other than what it is measuring. It also settles the contrast
  /// question the four page colours keep reopening: white on black holds over
  /// classic, yellow, grey and black alike, where ink-on-paper had to be
  /// re-derived for each of them.
  ///
  /// The shut pill is the opposite case — a mark on the page rather than an
  /// instrument over it — so it keeps taking the page's own colours, and the
  /// two wash into each other across the morph.
  static let trayTint = Color.black
  /// Held just short of solid, so a trace of the page still moves under it.
  static let trayTintOpacity: Double = 0.9
  /// Tint strength for the glass path, which is doing its own darkening on top.
  static let trayGlassTintOpacity: Double = 0.55
  static let trayInk = Color.white
  static let pageWashOpacity: Double = 0.72

  // MARK: Direction cues

  /// The arrows either end of the strip. Not controls — they say which way the
  /// strip answers to, and nothing more.
  static let cueWidth: CGFloat = 12
  static let cueSpacing: CGFloat = 7
  static let cueOpacity: Double = 0.35
  /// What a cue fades to at the end it points at, where there is nothing
  /// further to reach.
  static let cueSpentOpacity: Double = 0.08

  // MARK: Tick strip

  /// Centre-to-centre spacing of the ticks — and, because the scrub is one to
  /// one, how much finger travel brings the next prayer to the needle.
  ///
  /// Fixed rather than divided out of the strip's width. The strip is a window
  /// onto a ruler that runs past both edges, so its width has no say in how far
  /// apart the marks are — and a constant is what lets the gesture and the
  /// drawing agree without measuring anything.
  ///
  /// Wide enough that landing on one particular prayer is a matter of aim
  /// rather than of luck. This is the whole feel of the control: the scrub is
  /// one to one with the ruler, so this number is simultaneously how far apart
  /// the marks look and how much finger it costs to cross one, and those two
  /// cannot be tuned against each other. A tighter ruler shows more of the
  /// catalog at once and is correspondingly twitchier to stop on a prayer.
  static let tickPitch: CGFloat = 20

  /// How wide the row of dots on the shut pill is, before its padding, and how
  /// much air sits either side of it.
  ///
  /// Sized against ``PrayerTickStrip/Scale/mini``'s pitch so that about three
  /// dots stand clear of the fade at once: the prayer being read, and the one
  /// either side of it.
  static let shutStripWidth: CGFloat = 64
  static let shutStripInset: CGFloat = 12

  /// How strongly the needle glows. Shared by both scales; the radius is not,
  /// and lives on ``PrayerTickStrip/Scale``.
  static let tickGlowOpacity: Double = 0.5

  static let tickOpacitySection: Double = 0.55
  static let tickOpacity: Double = 0.28

  /// How many ticks either side of the needle take some of its emphasis, and
  /// how much of it they can take.
  ///
  /// A lens around the centre. It also does the work a travelling marker would:
  /// with the needle fixed, the only way the strip can show that something is
  /// arriving is for the marks to lift as they come into it.
  ///
  /// Counted in ticks, so it has to come down as ``tickPitch`` goes up or the
  /// lens spreads across the window and stops reading as a lens at all. Two and
  /// a half marks at the current pitch is about fifty points either side of the
  /// needle, which is roughly where it has always been in the hand.
  static let tickFalloff: CGFloat = 2.5
  static let tickNeighbourLift: CGFloat = 0.35

  /// How far past either end the strip will go before it stops giving, in
  /// prayers. The ruler runs out but the gesture does not, and this is what
  /// says so.
  static let overshootSpan: CGFloat = 2.5

  /// Far enough to be a drag rather than a slipped tap, and no further: with
  /// no axis to lock there is nothing to wait for beyond that.
  static let dragSlop: CGFloat = 4

  // MARK: Fades

  /// Where each of the two layouts holds the floor during the morph.
  ///
  /// They overlap in the middle rather than handing straight over: a
  /// cross-fade with no overlap is a cut with extra steps, and one with too
  /// much shows two layouts at once for most of the gesture.
  static let shutFadeRange: ClosedRange<CGFloat> = 0.05 ... 0.45
  static let openFadeRange: ClosedRange<CGFloat> = 0.35 ... 0.85

  /// How far out of focus each layout goes at the far end of its fade.
  ///
  /// The two layouts are different shapes of thing — a number, and a titled
  /// ruler — so a straight cross-fade leaves a stretch in the middle where both
  /// are legible and neither is meant. Blurring the one on its way out and
  /// bringing the other in from out of focus makes the middle read as one thing
  /// resolving into another rather than as two things overlaid.
  static let contentBlur: CGFloat = 6

  /// How much more horizontal than vertical a drag has to be before it is taken
  /// as scrubbing rather than as moving the control.
  ///
  /// Biased towards moving. Opening and shutting is the more consequential of
  /// the two and the harder to undo, so a drag that is not clearly sideways
  /// belongs to it.
  static let scrubBias: CGFloat = 1.1

  /// A travel, rubber-banded: it gives at once and then gives less and less.
  ///
  /// The control is hinged, not loose. Tracking a finger one to one would let
  /// it be dragged half way up the page, which reads as something that has come
  /// off rather than something being worked.
  static func resisted(_ travel: CGFloat) -> CGFloat {
    let magnitude = abs(travel)
    let damped = magnitude / (1 + magnitude / giveSpan)
    return travel < 0 ? -damped : damped
  }

  /// A scrub position, held inside the ruler with give at both ends.
  ///
  /// In prayers rather than points, so the same damping reads the same however
  /// far apart the ticks are drawn.
  static func resisted(position raw: CGFloat, total: Int) -> CGFloat {
    let last = CGFloat(max(0, total - 1))

    if raw < 0 {
      return -damped(-raw)
    }
    if raw > last {
      return last + damped(raw - last)
    }
    return raw
  }

  private static func damped(_ overshoot: CGFloat) -> CGFloat {
    overshoot / (1 + overshoot / overshootSpan)
  }
}

// MARK: - Measurement

/// The open tray's natural height, and the shut pill's natural width.
///
/// Both ends of the morph have to be real numbers before the shape can
/// interpolate between them. Guessing either one shows up as the tray arriving
/// with a jolt where the guess and the layout disagree.
private struct TrayOpenHeightKey: PreferenceKey {
  static var defaultValue: CGFloat { 0 }

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct TrayShutWidthKey: PreferenceKey {
  static var defaultValue: CGFloat { 0 }

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

// MARK: - Animation

extension Animation {
  /// What a released gesture settles on, whether that is open, shut, back onto
  /// a tick, or all three at once.
  ///
  /// A spring with real bounce left in it — looser than the nissaya deck's, and
  /// nothing like the detail screen's `.smooth`. The control has been held
  /// against a hinge and let go of, and the overshoot is what says the hinge
  /// was there.
  ///
  /// Nothing reaches for this *during* a gesture. Everything the finger is
  /// doing is drawn at the value the finger has put it at, which is the whole
  /// point of openness being a number rather than a state.
  static var readerPageSettle: Animation {
    .spring(response: 0.42, dampingFraction: 0.72)
  }

  /// The curve the strip lifts and settles on as marks pass through the needle.
  ///
  /// Short enough that it never lags behind the finger — the scrub is one to
  /// one with the ruler, so a mark has to *be* under the needle when the finger
  /// has carried it there, not be on its way. This animates how a tick looks,
  /// never where it is.
  static var readerTickLift: Animation {
    .easeOut(duration: 0.14)
  }

  /// The two halves of a page turn: softening out, and settling back.
  ///
  /// Eased at both ends rather than sprung, which is the one place in this
  /// control that does *not* borrow the tray's curve. A spring overshoots, and
  /// overshoot is a small unrequested movement — harmless on a pill somebody is
  /// holding, unkind on a full page of scripture somebody is about to read.
  static var readerPageDissolve: Animation {
    .easeInOut(duration: PrayerReaderMetrics.pageDissolve)
  }

  static var readerPageResolve: Animation {
    .easeInOut(duration: PrayerReaderMetrics.pageResolve)
  }

  /// How the title under the needle changes over.
  ///
  /// Short, because during a scrub this fires on every tick that passes: a
  /// longer curve would leave three titles blurring through one another at once
  /// and none of them readable.
  static var readerTitleSwap: Animation {
    .easeOut(duration: 0.18)
  }
}

// MARK: - Tray background

/// Liquid Glass on 26, material and a wash below — washing from the page's own
/// colour to near-black as the tray opens.
///
/// Two genuinely different treatments rather than one with a fallback colour.
/// Glass samples what is behind it and reacts to touch, so it takes a tint
/// rather than a coat — a near-solid fill laid over glass is a slab, which is
/// the one thing glass exists in order not to be.
///
/// Both washes are stacked and cross-faded on ``openness`` rather than switched
/// between, so the surface has a real value at every point of the morph. The
/// closed pill's wash is the *page* colour rather than `AppColor.background` —
/// which is what `AppFadeBlurBackground` would have brought — because the page
/// is a reading preference and can be black while the app is in light mode.
private struct PrayerTrayBackground: ViewModifier {
  let shape: RoundedRectangle
  let openness: CGFloat
  let pageColor: Color
  let pageInk: Color

  func body(content: Content) -> some View {
    if #available(iOS 26.0, macOS 26.0, *) {
      content.glassEffect(glass, in: shape)
    } else {
      content
        .background {
          shape
            .fill(.regularMaterial)
            .overlay {
              shape.fill(
                pageColor.opacity(
                  PrayerPageSwitcherMetrics.pageWashOpacity * Double(1 - openness)
                )
              )
            }
            .overlay {
              shape.fill(
                PrayerPageSwitcherMetrics.trayTint.opacity(
                  PrayerPageSwitcherMetrics.trayTintOpacity * Double(openness)
                )
              )
            }
            // Close to the only shadow in the app — everywhere else an edge is
            // a hairline. This is chrome floating over text, and a stroke on
            // its own leaves it sitting *in* the page rather than above it.
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
        .overlay {
          shape.strokeBorder(pageInk.opacity(0.12 * Double(1 - openness)), lineWidth: 0.5)
        }
        .overlay {
          shape.strokeBorder(
            PrayerPageSwitcherMetrics.trayInk.opacity(0.12 * Double(openness)),
            lineWidth: 0.5
          )
        }
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  private var glass: Glass {
    .regular
      .tint(
        PrayerPageSwitcherMetrics.trayTint.opacity(
          PrayerPageSwitcherMetrics.trayGlassTintOpacity * Double(openness)
        )
      )
      .interactive()
  }
}

// MARK: - Tick strip

/// The ruler: one mark per prayer, running past both edges of whatever window
/// it is given, with a fixed needle at the centre.
///
/// One implementation at two scales. The dots resting on the shut pill and the
/// full-width ruler inside the open tray are the same strip run through the same
/// fixed centre — which is what stops the pill being a *picture* of the control.
/// It is the control, wearing less.
struct PrayerTickStrip: View {
  /// Everything that differs between the two.
  ///
  /// Sizes, and whether the marks are round. The opacities, the falloff and the
  /// needle's glow strength are shared, because those are what make it
  /// recognisably the same instrument at either size.
  struct Scale {
    /// Centre to centre. At full size this is also the scrub rate — see
    /// ``PrayerPageSwitcherMetrics/tickPitch``.
    let pitch: CGFloat
    /// The box a mark is positioned in. The needle draws wider and overflows it
    /// evenly, so the spacing maths stays about one number.
    let markWidth: CGFloat
    let markHeight: CGFloat
    /// The first prayer of a category — a landmark, so a scrub has something to
    /// aim between rather than 34 identical marks.
    let sectionHeight: CGFloat
    let needleWidth: CGFloat
    let needleHeight: CGFloat
    let glowRadius: CGFloat
    let areaHeight: CGFloat
    /// How much of each end the marks fade out over, as a fraction of the
    /// width. Marks running off a hard edge would read as the ruler ending
    /// there rather than as it continuing past the window.
    let edgeFade: CGFloat

    /// Whether marks are drawn round, with their width following their height,
    /// rather than as bars of a fixed width.
    ///
    /// This is the whole difference between a ruler and a row of dots. A bar
    /// says "a position on a scale", which is what the tray is for; a dot says
    /// "one of these", which is what a reader glancing at the shut pill wants
    /// to know. Same mechanism either way — the marks still run under a fixed
    /// centre — but the smaller one stops pretending to be a measuring
    /// instrument at a size where it could not be read as one.
    let isRound: Bool

    /// The marks are taller than they need to be to be counted, and the area
    /// taller still than the marks. Both are deliberate: a ruler this wide
    /// apart reads as sparse unless the marks have some length to them, and the
    /// air above and below them is where a thumb can rest without the strip
    /// mistaking a haul for a scrub.
    static let full = Scale(
      pitch: PrayerPageSwitcherMetrics.tickPitch,
      markWidth: 2,
      markHeight: 8,
      sectionHeight: 15,
      needleWidth: 4,
      needleHeight: 26,
      glowRadius: 5,
      areaHeight: 28,
      edgeFade: 0.12,
      isRound: false
    )

    /// Dots, spaced so that about three of them are clear of the fade at once:
    /// the one being read and its neighbour either side. Far wider apart than
    /// the ruler's marks relative to their size, because dots crowd where bars
    /// only get denser.
    ///
    /// `sectionHeight` matches `markHeight` on purpose. Where a category begins
    /// is a fact about the catalog worth marking on something the reader is
    /// navigating *by*; on a pill showing three dots it would just be one
    /// mysteriously larger dot.
    static let mini = Scale(
      pitch: 18,
      markWidth: 5,
      markHeight: 5,
      sectionHeight: 5,
      needleWidth: 8,
      needleHeight: 8,
      glowRadius: 3,
      areaHeight: 12,
      edgeFade: 0.25,
      isRound: true
    )
  }

  let total: Int
  /// Where the ruler is sitting, in prayers. Whole numbers are marks under the
  /// needle; the value is continuous so the strip can follow a finger between
  /// them.
  let position: CGFloat
  /// The mark nearest the needle, which is the one drawn as the needle.
  let displayIndex: Int
  let sectionStarts: Set<Int>
  let ink: Color
  let scale: Scale
  /// How a mark changes as it comes into the centre. `nil` under Reduce Motion.
  let lift: Animation?

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        ForEach(0 ..< total, id: \.self) { place in
          mark(at: place)
            .offset(x: CGFloat(place) * scale.pitch)
        }
      }
      .frame(maxHeight: .infinity)
      // The whole ruler slides so that `position` lands under the needle. The
      // half-mark takes the box into account: marks are laid out from their
      // leading edge, and it is their centre that has to line up.
      .offset(x: proxy.size.width / 2 - position * scale.pitch - scale.markWidth / 2)
    }
    .frame(height: scale.areaHeight)
    .mask { edgeFade }
  }

  private var edgeFade: some View {
    LinearGradient(
      stops: [
        .init(color: .clear, location: 0),
        .init(color: .black, location: scale.edgeFade),
        .init(color: .black, location: 1 - scale.edgeFade),
        .init(color: .clear, location: 1)
      ],
      startPoint: .leading,
      endPoint: .trailing
    )
  }

  private func mark(at place: Int) -> some View {
    let isNeedle = place == displayIndex
    let isSectionStart = sectionStarts.contains(place)

    // 1 at the needle, falling to 0 by the time the falloff runs out — the lens
    // that lifts marks as they come into the centre. With the needle fixed,
    // this is the only way the strip can show that something is arriving.
    let nearness = max(
      0,
      1 - CGFloat(abs(place - displayIndex)) / PrayerPageSwitcherMetrics.tickFalloff
    )
    let lifted = nearness * PrayerPageSwitcherMetrics.tickNeighbourLift

    let restingHeight = isSectionStart ? scale.sectionHeight : scale.markHeight
    let height = isNeedle
      ? scale.needleHeight
      : restingHeight + (scale.needleHeight - restingHeight) * lifted

    let restingOpacity = isSectionStart
      ? PrayerPageSwitcherMetrics.tickOpacitySection
      : PrayerPageSwitcherMetrics.tickOpacity
    let opacity = isNeedle ? 1 : restingOpacity + (1 - restingOpacity) * Double(lifted)

    // Round marks take their width from their height, so that a dot lifted by
    // the lens swells as a circle rather than stretching into an ellipse.
    let bar = isNeedle ? scale.needleWidth : scale.markWidth
    let width = scale.isRound ? height : bar

    return Capsule(style: .continuous)
      .fill(ink.opacity(opacity))
      .frame(width: width, height: height)
      // A glow, so the needle reads as lit rather than merely large.
      .shadow(
        color: ink.opacity(isNeedle ? PrayerPageSwitcherMetrics.tickGlowOpacity : 0),
        radius: scale.glowRadius
      )
      // The positioning box stays one mark wide whatever is drawn inside it, so
      // the needle overflows evenly and the spacing maths stays about a single
      // number.
      .frame(width: scale.markWidth, height: scale.areaHeight)
      .animation(lift, value: displayIndex)
  }
}

// MARK: - Switcher

/// The floating page switcher: a small round mark on the page which opens into
/// a scrubber for reaching any prayer in the catalog.
///
/// **Shut and open are the same control at two ends of one number.** ``openness``
/// runs from 0 to 1, and the height, the width, the corner radius, the surface
/// colour and which of the two layouts is showing are all read off it. There is
/// no moment where one thing is replaced by another: a drag holds the control at
/// 0.4 for as long as the finger stays there, and it looks like exactly that.
///
/// A drag is one of two things, decided once at the start of it and held for
/// the rest — see ``Grip``. Either the hand is **moving the control**, in which
/// case it follows in both axes at once and its vertical travel opens or shuts
/// it while the ruler inside sits perfectly still; or the hand is **scrubbing
/// the ruler**, in which case the marks run under the needle and the control
/// itself does not budge. The two never happen together: a tray being carried
/// about should not be changing the reader's place while it goes, and a ruler
/// being read should not be sliding out from under the finger reading it.
///
/// Releasing a move settles the tray to whichever end its *projected* travel is
/// nearer — projected, so a flick counts for as much as a haul. Releasing a
/// scrub shuts it: the finger coming off the ruler *is* the choice, and the
/// tray has nothing further to offer once it has been made.
///
/// Open, it is a dark instrument laid over the page: a ruler of one tick per
/// prayer running past both edges of its window, a fixed needle at the centre,
/// and the title of whatever is under that needle written above it. **The needle
/// does not move; the ruler does** — dragging carries the strip under the centre
/// the way a finger carries any scroll view, right for earlier and left for
/// later, one tick of pitch to one tick of finger.
///
/// Nothing behind the tray moves while a scrub is in progress. That is the point
/// of scrubbing rather than turning pages: the reader can travel the length of
/// the catalog and change their mind without the page underneath being rebuilt
/// once, and only the title above the strip has to keep up.
///
/// Its gesture lives on the control, and only on the control. That is the whole
/// reason this floats rather than being a swipe on the page: the verses
/// underneath keep every horizontal gesture they have, or will have, to
/// themselves.
struct PrayerPageSwitcher: View {
  /// The catalog in reading order. Held whole because the tray names the prayer
  /// under the needle, which is any of them — and because it is a reference to
  /// storage `PrayerCatalog` is holding anyway.
  let prayers: [Prayer]

  /// 0-based position of the prayer actually being read.
  let index: Int

  /// Positions in ``prayers`` where a new category begins.
  let sectionStarts: Set<Int>

  /// For the page colour, which the shut pill is drawn in.
  let settings: PrayerSettings

  /// 0 shut, 1 open, and every value between a state the control can be held
  /// at. Bound rather than owned because the screen behind needs to know how
  /// much of itself is covered.
  @Binding var openness: CGFloat

  let onCommit: (Int, PrayerPageCommit) -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// What the hand took hold of when the current drag began.
  ///
  /// Decided once and held, rather than re-read as the drag wanders: a grip
  /// that could change mid-gesture would let a scrub that drifted upwards start
  /// opening the tray under the finger, and a haul that drifted sideways start
  /// changing which prayer is being read.
  private enum Grip {
    /// The control itself. It follows the hand in both axes, and its vertical
    /// travel is what opens and shuts it. The ruler inside does not move.
    case move
    /// The ruler. The marks run under the needle; the control holds still.
    case scrub
  }

  /// The live drag, or `nil` between gestures.
  @State private var drag: CGSize?

  /// Where the ruler was left when the choice was made, held until the reading
  /// catches up with it.
  ///
  /// The page is exchanged a beat *after* the finger lifts — the reader softens
  /// out first, see ``PrayerReaderMetrics/pageDissolve`` — so for that beat
  /// ``index`` still names the prayer being left. Falling back to it would spring
  /// the strip all the way back to where the scrub began and then carry it
  /// forward again when the exchange landed: two journeys for one choice, the
  /// second of them under a pill that has already shut.
  ///
  /// Cleared when the next gesture starts, which is the only moment it could go
  /// stale — everything that moves ``index`` sets this first.
  @State private var landedIndex: Int?

  /// Which of the two things this drag is doing. `nil` between gestures.
  @State private var grip: Grip?

  /// Where the control and the ruler were when the current drag began. Both
  /// gestures are relative, and both ends have to be remembered or a drag that
  /// crosses a commit would measure itself against the result of its own work.
  @State private var opennessAtStart: CGFloat = 0
  @State private var indexAtStart = 0

  /// The two ends of the morph, measured rather than assumed.
  @State private var openHeight = PrayerPageSwitcherMetrics.openHeightGuess
  @State private var shutWidth = PrayerPageSwitcherMetrics.shutWidthGuess

  private var total: Int { prayers.count }

  // MARK: Derived geometry

  /// Openness as the finger is asking for it, which can be outside 0…1.
  ///
  /// Only a ``Grip/move`` asks. A scrub holds the tray exactly as open as it
  /// found it however far up or down the finger strays while it runs — and then
  /// shuts it outright on release, which is a decision about the gesture ending
  /// rather than about anything the finger did during it.
  private var rawOpenness: CGFloat {
    guard let drag, grip == .move else { return openness }
    return opennessAtStart + (-drag.height) / PrayerPageSwitcherMetrics.openSpan
  }

  private var trayHeight: CGFloat {
    lerp(PrayerPageSwitcherMetrics.shutHeight, openHeight, openness)
  }

  private func trayWidth(container: CGFloat) -> CGFloat {
    lerp(shutWidth, max(container, shutWidth), openness)
  }

  /// Half the height until the tray is tall enough to want less, which is what
  /// makes the shut pill a capsule and the open tray a card without either
  /// state having to be named.
  private var shape: RoundedRectangle {
    RoundedRectangle(
      cornerRadius: min(trayHeight / 2, PrayerPageSwitcherMetrics.openRadius),
      style: .continuous
    )
  }

  /// What the control gives bodily, over and above what the drag is doing to
  /// the openness.
  ///
  /// Zero under a scrub. The ruler is what is moving then, and a strip being
  /// read while the window around it slides is unreadable.
  private var give: CGSize {
    guard let drag, grip == .move else { return .zero }

    // Whatever the openness could not take, shown as the control lifting out of
    // its end stop rather than as the drag having no effect.
    let beyond = (rawOpenness - openness) * PrayerPageSwitcherMetrics.openSpan

    return CGSize(
      width: PrayerPageSwitcherMetrics.resisted(drag.width)
        * PrayerPageSwitcherMetrics.sidewaysGive,
      height: -PrayerPageSwitcherMetrics.resisted(beyond)
    )
  }

  /// The control swells a little as it is worked, so the give reads as it
  /// answering rather than as it sliding.
  /// How far the whole control lifts off the foot of the page as it opens.
  ///
  /// Whatever the growth does not already account for. The tray grows upward
  /// from a fixed bottom edge, so opening it carries its top edge up by the
  /// difference between the two heights on its own — about sixty points — while
  /// the finger that is opening it has to travel ``openSpan``, ninety. Left
  /// there, the top of the tray comes up at two thirds the speed of the hand
  /// pulling it, which is exactly the "capped to a small amount" feeling: the
  /// control is opening, but it is not *following*.
  ///
  /// Lifting the body by the remainder makes the two the same number, so the
  /// top edge sits under the finger the whole way up. Derived rather than
  /// fixed, because the growth is measured and changes with Dynamic Type — at
  /// larger text the tray grows more and needs to lift less.
  private var openRise: CGFloat {
    max(0, PrayerPageSwitcherMetrics.openSpan - (openHeight - PrayerPageSwitcherMetrics.shutHeight))
  }

  /// Where the control sits vertically: lifted by however far it is open, plus
  /// whatever a drag is asking for past the end stops.
  private var verticalOffset: CGFloat {
    -openRise * openness + give.height
  }

  private var giveScale: CGFloat {
    guard !reduceMotion else { return 1 }

    let reach = min(hypot(give.width, give.height) / PrayerPageSwitcherMetrics.giveSpan, 1)
    return 1 + reach * PrayerPageSwitcherMetrics.giveLift
  }

  /// How far each layout has travelled through its own fade, 0 to 1.
  private var shutFade: CGFloat {
    smoothstep(PrayerPageSwitcherMetrics.shutFadeRange, openness)
  }

  private var openFade: CGFloat {
    smoothstep(PrayerPageSwitcherMetrics.openFadeRange, openness)
  }

  private var shutOpacity: Double { Double(1 - shutFade) }
  private var openOpacity: Double { Double(openFade) }

  /// Each layout goes out of focus exactly as it goes out of sight, and arrives
  /// in focus as it arrives. Held at zero under Reduce Motion, where a
  /// cross-fade on its own is the gentler change.
  private var shutBlur: CGFloat {
    reduceMotion ? 0 : PrayerPageSwitcherMetrics.contentBlur * shutFade
  }

  private var openBlur: CGFloat {
    reduceMotion ? 0 : PrayerPageSwitcherMetrics.contentBlur * (1 - openFade)
  }

  // MARK: Derived position

  /// Where the ruler is sitting, in prayers. Whole numbers are ticks under the
  /// needle.
  ///
  /// Continuous rather than a tick index: the strip has to follow the finger
  /// between marks, or a one-to-one scrub would move in whole-tick jerks.
  ///
  /// Only a ``Grip/scrub`` moves it. Under a move the ruler sits on the prayer
  /// being read and stays there — which is also what keeps the haptic silent,
  /// since the tick that fires it is derived from this.
  private var position: CGFloat {
    guard let drag, grip == .scrub, total > 0 else {
      return CGFloat(landedIndex ?? index)
    }

    return Self.position(carrying: drag.width, from: indexAtStart, total: total)
  }

  /// Where a drag of this width leaves the ruler, in prayers.
  ///
  /// Static, and taking its inputs rather than reading them, so that the
  /// gesture can work out where it has got to without depending on a `@State`
  /// write it made a line earlier being readable again straight away.
  ///
  /// Subtracted rather than added: the strip moves *with* the finger, so
  /// dragging right carries it right and brings earlier prayers into the centre
  /// — the way every scroll view behaves.
  private static func position(carrying width: CGFloat, from start: Int, total: Int) -> CGFloat {
    let raw = CGFloat(start) - width / PrayerPageSwitcherMetrics.tickPitch
    return PrayerPageSwitcherMetrics.resisted(position: raw, total: total)
  }

  private static func landing(carrying width: CGFloat, from start: Int, total: Int) -> Int {
    let place = position(carrying: width, from: start, total: total)
    return min(max(Int(place.rounded()), 0), max(0, total - 1))
  }

  /// Whether the page itself is the readout for this scrub.
  ///
  /// Shut, the dots say that the reader is somewhere in a catalog and nothing
  /// whatever about where — so the page has to say it, and it follows the
  /// finger. Open, the title above the ruler already names every prayer the
  /// needle passes, and rebuilding the page under a tray nobody is reading
  /// through would be work done for no one.
  private var isTracking: Bool {
    openness < PrayerPageSwitcherMetrics.openThreshold
  }

  /// The prayer the tray is currently *describing* — the one nearest the
  /// needle, which during a scrub is not yet the one being read.
  private var displayIndex: Int {
    min(max(Int(position.rounded()), 0), max(0, total - 1))
  }

  private var pageInk: Color { settings.background.foreground }
  private var trayInk: Color { PrayerPageSwitcherMetrics.trayInk }

  /// `nil` under Reduce Motion, which is how SwiftUI is told to make a change
  /// without animating it — the same shape `AppSegmentedPicker` uses.
  private func motion(_ animation: Animation) -> Animation? {
    reduceMotion ? nil : animation
  }

  // MARK: - Body

  var body: some View {
    GeometryReader { proxy in
      let container = proxy.size.width

      contents(container: container)
        .frame(width: trayWidth(container: container), height: trayHeight)
        // Clipped to the morphing shape, so the open layout is cut to the pill
        // on its way in rather than spilling out either side of it.
        .clipShape(shape)
        .modifier(
          PrayerTrayBackground(
            shape: shape,
            openness: openness,
            pageColor: settings.background.color,
            pageInk: pageInk
          )
        )
        .contentShape(shape)
        .scaleEffect(giveScale)
        .offset(x: give.width, y: verticalOffset)
        .gesture(workTheTray)
        .onTapGesture { settle(to: 1) }
        .frame(width: container, height: proxy.size.height)
    }
    .frame(height: trayHeight)
    .onPreferenceChange(TrayOpenHeightKey.self) { openHeight = max($0, 1) }
    .onPreferenceChange(TrayShutWidthKey.self) { shutWidth = max($0, 1) }
    // One tick per prayer that passes under the needle. Keyed to what is
    // *shown* rather than to what is being read, so the ruler feels detented
    // under the finger — and so releasing a scrub, which changes the reading
    // without moving the ruler, does not tick a second time for a prayer
    // already announced.
    .appSelectionFeedback(trigger: displayIndex)
    // And the click on top of it. The haptic is the part that carries in a
    // pocket and in silent mode; this is the confirmation for a reader holding
    // the phone in front of them, and everything works without it.
    .appSelectionSound(trigger: displayIndex)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(L10n.prayerPosition(Self.arg(displayIndex + 1), Self.arg(total)))
    .accessibilityAddTraits(openness > 0.5 ? [] : .isButton)
    .accessibilityAction {
      // Only meaningful while shut; open, the strip is the action.
      settle(to: 1)
    }
  }

  // MARK: - Contents

  /// Both layouts, always laid out, cross-faded on ``openness``.
  ///
  /// Both rather than one or the other, because a morph needs something to
  /// morph: swapping the subtree at some threshold would put a cut in the
  /// middle of the very gesture this is all built to keep continuous. They also
  /// measure themselves here — the open layout's height and the shut one's
  /// width are the two numbers the frame interpolates between.
  private func contents(container: CGFloat) -> some View {
    ZStack {
      shutContent
        .fixedSize()
        .background {
          GeometryReader { geometry in
            Color.clear.preference(key: TrayShutWidthKey.self, value: geometry.size.width)
          }
        }
        // Blurred after it is measured, never before: a blur costs the view
        // nothing in layout, but putting it above the probe would still be
        // measuring something other than the thing the frame interpolates to.
        .blur(radius: shutBlur)
        .opacity(shutOpacity)

      openContent
        .frame(width: max(container, 1))
        // Natural height whatever the frame around it is currently doing, or
        // the thing being measured would be the interpolation itself.
        .fixedSize(horizontal: false, vertical: true)
        .background {
          GeometryReader { geometry in
            Color.clear.preference(key: TrayOpenHeightKey.self, value: geometry.size.height)
          }
        }
        .blur(radius: openBlur)
        .opacity(openOpacity)
    }
  }

  /// Three dots, resting on the page: the prayer being read, and the one either
  /// side of it.
  ///
  /// The same strip as the tray's ruler, run through the same fixed centre —
  /// only drawn round and spaced out, so that at pill size it reads as "one of
  /// these, and there are more" rather than as a measuring instrument too small
  /// to measure with. Scrubbing runs the dots under the centre exactly as it
  /// runs the marks, so the pill is never a picture of the control: it is the
  /// control, wearing less.
  ///
  /// Which is what a glyph could not do. An icon says only that something
  /// exists to be opened; these say that, and where in the catalog the reader
  /// is, and what pulling them open is going to feel like.
  private var shutContent: some View {
    PrayerTickStrip(
      total: total,
      position: position,
      displayIndex: displayIndex,
      sectionStarts: sectionStarts,
      ink: pageInk,
      scale: .mini,
      lift: motion(.readerTickLift)
    )
    .frame(width: PrayerPageSwitcherMetrics.shutStripWidth)
    .padding(.horizontal, PrayerPageSwitcherMetrics.shutStripInset)
    .frame(height: PrayerPageSwitcherMetrics.shutHeight)
    // The full ruler inside the tray is the one VoiceOver adjusts; two of them
    // in the same control would be two ways to do one thing.
    .accessibilityHidden(true)
  }

  private var openContent: some View {
    VStack(spacing: PrayerPageSwitcherMetrics.trayRowSpacing) {
      header
      track
    }
    .padding(.horizontal, PrayerPageSwitcherMetrics.trayInset)
    .padding(.vertical, PrayerPageSwitcherMetrics.trayVerticalPadding)
  }

  /// What is under the needle, and where that is.
  ///
  /// One row rather than two stacked. The counter is a footnote to the title —
  /// putting it on its own line cost the tray twenty points of a page someone
  /// is reading, to say something the ruler underneath is already showing.
  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: PrayerPageSwitcherMetrics.headerSpacing) {
      Text(displayIndex < total ? prayers[displayIndex].title : "")
        .font(AppFont.listItemTitle)
        .foregroundStyle(trayInk)
        // One line, truncating. The tray is a control, and a title long enough
        // to wrap would change its height in the middle of a scrub — which,
        // with the height being interpolated, would change the shape too.
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Blurs through the change rather than cutting — the same swap the
        // detail screen's carousel uses, and for the same reason: the title is
        // being *replaced*, not edited, and a cut at scrubbing speed reads as
        // flicker. Falls back to a cross-fade below iOS 17.
        .prayerContentTransition(id: displayIndex < total ? prayers[displayIndex].id : "")

      counter
        .font(AppFont.caption)
        .foregroundStyle(trayInk.opacity(0.6))
        // The digits roll rather than cut. Free at the deployment floor, and it
        // ties the counter to the title changing beside it.
        .contentTransition(.numericText())
        .layoutPriority(1)
    }
    .animation(motion(.readerTitleSwap), value: displayIndex)
  }

  private var counter: Text {
    Text("\(displayIndex + 1) / \(total)")
      .monospacedDigit()
  }

  private var track: some View {
    HStack(spacing: PrayerPageSwitcherMetrics.cueSpacing) {
      cue(.previous)
      ticks
      cue(.next)
    }
  }

  /// Which way the strip answers to. Deliberately not a button: the ruler is
  /// the control, and an arrow that could be tapped as well would make the
  /// whole tray ambiguous about what it wants from the reader.
  private func cue(_ direction: PrayerPageDirection) -> some View {
    Image(systemName: direction == .next ? "chevron.compact.right" : "chevron.compact.left")
      .font(AppFont.headline)
      .foregroundStyle(
        trayInk.opacity(
          canStep(direction)
            ? PrayerPageSwitcherMetrics.cueOpacity
            : PrayerPageSwitcherMetrics.cueSpentOpacity
        )
      )
      .frame(width: PrayerPageSwitcherMetrics.cueWidth)
      .animation(motion(.readerTickLift), value: canStep(direction))
      // The strip beside it carries the spoken position; an arrow that only
      // says "there is more that way" has nothing to add to it.
      .accessibilityHidden(true)
  }

  // MARK: - The ruler

  private var ticks: some View {
    PrayerTickStrip(
      total: total,
      position: position,
      displayIndex: displayIndex,
      sectionStarts: sectionStarts,
      ink: trayInk,
      scale: .full,
      lift: motion(.readerTickLift)
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(displayIndex < total ? prayers[displayIndex].title : "")
    .accessibilityValue(L10n.prayerPosition(Self.arg(displayIndex + 1), Self.arg(total)))
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment:
        nudge(.next)
      case .decrement:
        nudge(.previous)
      @unknown default:
        break
      }
    }
  }

  // MARK: - Stepping

  private func canStep(_ direction: PrayerPageDirection) -> Bool {
    prayers.indices.contains(displayIndex + direction.step)
  }

  /// One prayer either way, for VoiceOver, which cannot scrub a ruler it cannot
  /// see. The ends clamp: the ruler shows them arriving, so a needle that
  /// jumped from one end to the other would read as a glitch rather than as a
  /// wrap.
  private func nudge(_ direction: PrayerPageDirection) {
    guard canStep(direction) else { return }

    // Held for the same reason a scrub is: the exchange is a beat behind, and
    // the strip should not visit the prayer being left on its way to the one
    // being asked for.
    let target = displayIndex + direction.step
    landedIndex = target
    onCommit(target, .settled)
  }

  // MARK: - Gesture

  private var workTheTray: some Gesture {
    DragGesture(minimumDistance: PrayerPageSwitcherMetrics.dragSlop)
      .onChanged { value in
        if grip == nil {
          // Taken once, here. Both behaviours are relative to where the gesture
          // began, and reading these per frame would measure each move against
          // the last one instead of against the beginning.
          opennessAtStart = openness
          // From where the ruler is actually sitting, which for the beat after a
          // choice is not yet where the reading is.
          indexAtStart = landedIndex ?? index
          landedIndex = nil
          grip = Self.grip(for: value.translation)
        }

        drag = value.translation

        // Shut, the page keeps up with the finger — worked out from the drag
        // rather than read back off `drag`, which was only just written.
        if grip == .scrub, isTracking {
          onCommit(
            Self.landing(carrying: value.translation.width, from: indexAtStart, total: total),
            .tracking
          )
        }

        // Unanimated on purpose. The control is as open as the hand has made
        // it, and a curve between here and there would be the control
        // disagreeing with the finger. A scrub leaves it alone entirely —
        // `rawOpenness` returns what is already there.
        guard grip == .move else { return }
        openness = min(max(rawOpenness, 0), 1)
      }
      .onEnded { value in
        // Read before clearing: both are derived from the live drag, and there
        // is nothing left to derive them from a line later.
        let landed = displayIndex
        let wasScrub = grip == .scrub
        let movedRuler = wasScrub && landed != indexAtStart

        // Where the tray lands, which depends on what the hand was doing.
        //
        // A move is settled by velocity, projected from where the drag was
        // *going* rather than where it stopped — the same projection the
        // nissaya deck uses. A flick that travelled twenty points can therefore
        // open the tray that a slow haul of the same distance would not.
        //
        // A scrub shuts it. Lifting the finger off the ruler is the choice
        // being made, and the tray has nothing left to do once it is: leaving
        // it standing over the prayer it was opened to find makes the reader
        // dismiss a control they have finished with. It also puts the tray out
        // of the way of the page turning underneath it, which is the thing
        // actually worth looking at at that moment.
        //
        // Anything else — a gesture that never resolved into either — is left
        // exactly where it was found.
        let settled: CGFloat
        switch grip {
        case .move:
          let projected = opennessAtStart
            + (-value.predictedEndTranslation.height) / PrayerPageSwitcherMetrics.openSpan
          settled = projected >= PrayerPageSwitcherMetrics.openThreshold ? 1 : 0
        case .scrub:
          settled = 0
        case .none:
          settled = opennessAtStart
        }

        withAnimation(motion(.readerPageSettle)) {
          // Inside the settle so that the ruler springs from wherever between
          // marks the finger left it — overshoot included — onto the tick it
          // landed on, rather than cutting there.
          if movedRuler {
            onCommit(landed, .settled)
          }
          // Pinned here rather than left to `index`, which is a page turn
          // behind. The only movement left is the last fraction of a tick the
          // finger stopped short of, which is the settle this animation is for.
          if wasScrub {
            landedIndex = landed
          }
          drag = nil
          grip = nil
          openness = settled
        }
      }
  }

  /// What a drag turned out to be, from the first movement past the slop.
  private static func grip(for translation: CGSize) -> Grip {
    abs(translation.width) > abs(translation.height) * PrayerPageSwitcherMetrics.scrubBias
      ? .scrub
      : .move
  }

  private func settle(to target: CGFloat) {
    guard openness != target else { return }

    withAnimation(motion(.readerPageSettle)) { openness = target }
  }

  /// A number, as a localisation argument.
  ///
  /// `L10n.Arg` is expressible by string *literal* only, so a value worked out
  /// at run time has to be handed over as one. Both languages get the same
  /// digits — the counter reads `12 / 34` either way.
  private static func arg(_ value: Int) -> L10n.Arg {
    L10n.Arg(en: "\(value)", mm: "\(value)")
  }
}
