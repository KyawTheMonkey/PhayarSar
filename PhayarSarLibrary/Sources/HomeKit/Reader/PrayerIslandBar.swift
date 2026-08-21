import DesignKit
import LocalisationKit
import PrayersKit
import SwiftUI
import UtilKit

// MARK: - Metrics

/// Layout and colour for the chrome that docks to the Dynamic Island.
///
/// Where ``PrayerPlaybackMetrics`` derives nearly everything from the page — the
/// switcher's height, the page's ink, the paper behind it — almost nothing here
/// does. This control's ground is the hardware cutout, and the cutout is black
/// on every paper the reader can choose. That is a constraint at first glance
/// and a gift on second: the bottom bar has a long note about how hard it is to
/// find a marker colour that survives six papers, and up here the question does
/// not arise.
enum PrayerIslandMetrics {

  // MARK: Where it hangs

  /// How far below the cutout the pill comes to rest.
  ///
  /// Fourteen rather than twelve, to leave room under the soft edge of the mask
  /// — see ``maskSoftness``. A blurred edge needs somewhere to finish.
  static let gap: CGFloat = 14

  static var shutTop: CGFloat { AppDynamicIsland.cutoutBottom + gap }

  // MARK: The island's stand-in

  /// A capsule drawn over the cutout, so the hardware can appear to move.
  ///
  /// The island itself cannot be animated — it is a hole, not a view. But a
  /// black capsule lying exactly over a black hole is indistinguishable from it,
  /// and a black capsule slightly *larger* than the hole reads as the hole
  /// having grown. That is the whole trick: this sits invisible on the hardware
  /// until something needs to pass through it, swells to let that happen, and
  /// springs back.
  ///
  /// Cut a shade inside the measured cutout at rest, because the error can only
  /// be afforded in one direction. Smaller than the hole is invisible; larger is
  /// a black rim around somebody's Dynamic Island.
  static let proxyInset: CGFloat = 2

  /// How far it swells while something is crossing. Wider than it is taller,
  /// because the island's own animations are: it is a shape that stretches
  /// sideways and barely thickens.
  static let bulgeWidth: CGFloat = 24
  static let bulgeHeight: CGFloat = 10

  static var cutoutCentre: CGFloat {
    AppDynamicIsland.cutoutTop + AppDynamicIsland.cutoutSize.height / 2
  }

  static func proxy(in bounds: CGRect, bulge: CGFloat) -> CGRect {
    let width = AppDynamicIsland.cutoutSize.width - proxyInset * 2 + bulgeWidth * bulge
    let height = AppDynamicIsland.cutoutSize.height - proxyInset * 2 + bulgeHeight * bulge

    return CGRect(
      x: bounds.midX - width / 2,
      y: cutoutCentre - height / 2,
      width: width,
      height: height
    )
  }

  /// How long the island takes to gather itself before it squeezes.
  ///
  /// The only part of a crossing that happens on its own. Everything after it is
  /// one movement.
  static let gather: TimeInterval = 0.22

  /// The squeeze: the island contracting and the pill leaving, on one curve.
  ///
  /// One curve because it is one action. The first version shrank the island
  /// *after* the pill had already gone, which left nothing pushing it — the
  /// island puffed, the pill wandered out, and the island deflated behind it,
  /// three unrelated events. Driving both from a single `withAnimation` is what
  /// makes the contraction read as the thing that ejects the pill.
  ///
  /// Loose enough to overshoot, and the overshoot is free: undershooting takes
  /// the stand-in *smaller* than the hardware, where it is inside the hole and
  /// cannot be seen anyway.
  static let eject: Animation = .spring(response: 0.30, dampingFraction: 0.55)

  /// And taking something back in, which is not a pop and should not bounce like
  /// one. The island opens as the pill arrives rather than before it — the same
  /// three beats in reverse.
  static let receive: Animation = .spring(response: 0.40, dampingFraction: 0.82)

  /// How long the island stays open behind something it has just taken in,
  /// before closing up.
  static let swallowHold: TimeInterval = 0.34
  static let closeUp: TimeInterval = 0.22

  // MARK: Shut

  /// The cutout's own width — the one measurement of the hardware this control
  /// still borrows, and it borrows it for looks rather than for fit. Two objects
  /// of the same width read as a pair; two of different widths read as one thing
  /// and a coincidence.
  static var shutWidth: CGFloat { AppDynamicIsland.cutoutSize.width }

  static let shutHeight: CGFloat = 34

  /// A capsule, like the thing above it.
  static var shutRadius: CGFloat { shutHeight / 2 }

  static let shutHorizontalPadding: CGFloat = 14

  /// Small. Up here the glyph is a status light as much as a button, and the
  /// count beside it is set at the same size so the two read as a pair rather
  /// than as a control and a caption.
  static let shutGlyphSize: CGFloat = 12

  /// The transport button's target on the shut pill, and no larger.
  ///
  /// Twenty-eight points at the far left of a hundred-and-twenty-six point pill,
  /// which leaves the other ninety-eight to open the sheet. It used to be the
  /// full height of the row and reached far enough into the middle that a tap
  /// meant as "show me the controls" kept stopping the reading instead.
  static let shutControlSize: CGFloat = 28

  /// Where the shut pill sits in a screen of this size.
  ///
  /// Out here rather than inside the view because the window needs it too — see
  /// ``PrayerIslandWindow/interactiveRect``, which is the only part of the
  /// screen that window will take a touch in.
  static func shutRect(in bounds: CGRect) -> CGRect {
    CGRect(
      x: bounds.midX - shutWidth / 2,
      y: shutTop,
      width: shutWidth,
      height: shutHeight
    )
  }

  /// What the pill shrinks to while it is inside the island.
  ///
  /// Well inside the hardware on both axes, which it has to be: nothing masks
  /// the pill any more, so being invisible at rest means genuinely fitting
  /// within the hole. A capsule the cutout's own width tucked into the cutout's
  /// own capsule is inside it by about a twentieth of a point at the place they
  /// nearly meet — the two curves are almost the same curve — so it is cut down
  /// until there is room to be wrong.
  ///
  /// Growing to full size on the way out is not a compromise, either. Something
  /// squeezed through an opening should arrive larger than the gap it came from.
  static let hiddenWidth: CGFloat = 100
  static let hiddenHeight: CGFloat = 24

  static func hiddenRect(in bounds: CGRect) -> CGRect {
    CGRect(
      x: bounds.midX - hiddenWidth / 2,
      y: cutoutCentre - hiddenHeight / 2,
      width: hiddenWidth,
      height: hiddenHeight
    )
  }

  // MARK: The seed
  /// The size the sheet grows out of and shrinks back into, sitting in the
  /// cutout.
  ///
  /// Cut well inside the hardware on both axes. A shape the cutout's own width
  /// tucked into the cutout's own capsule is inside it by about a twentieth of a
  /// point at the place they nearly meet — the two curves are almost the same
  /// curve — so any error in the measured hardware would show its shoulders
  /// against the page. This is small enough to be safely invisible, which is all
  /// it has to be: it is only ever on screen for the instant before the sheet
  /// grows out of it.
  static var seedWidth: CGFloat { shutWidth - 12 }
  static var seedHeight: CGFloat { shutHeight - 8 }

  static func seed(in bounds: CGRect) -> CGRect {
    CGRect(
      x: bounds.midX - seedWidth / 2,
      y: AppDynamicIsland.cutoutTop + (AppDynamicIsland.cutoutSize.height - seedHeight) / 2,
      width: seedWidth,
      height: seedHeight
    )
  }

  /// The two halves of opening, and of shutting.
  ///
  /// Opening is not one movement but two: the pill travels back up into the
  /// island, and only once it is home does it grow into the sheet. Shutting runs
  /// the same pair backwards. Splitting them is what makes the sheet look like
  /// it came out of the island rather than out of a pill floating below it.
  /// Long enough for the pill to have travelled back inside the island before
  /// the sheet starts growing out of it.
  static let retract: TimeInterval = 0.44
  static let release: TimeInterval = 0.30

  // MARK: Open

  /// Side margins when open.
  static let openInset: CGFloat = 12

  /// The sheet hangs from the cutout's own top edge, because that is where the
  /// pill has travelled back to before it opens. It covers the clock while it is
  /// down, exactly as the system's own expanded island does.
  static var openTop: CGFloat { AppDynamicIsland.cutoutTop }

  /// Fixed rather than intrinsic, so the growth has a number to animate to. The
  /// title earns its one line by scaling instead.
  static let openHeight: CGFloat = 152

  static let openRadius: CGFloat = 28

  /// How far below the sheet's own top edge anything may be drawn: past the
  /// hardware it has opened around, and a breath more.
  static var openContentTop: CGFloat {
    AppDynamicIsland.cutoutBottom - openTop + 8
  }

  static func sheet(in bounds: CGRect) -> CGRect {
    CGRect(
      x: openInset,
      y: openTop,
      width: max(bounds.width - openInset * 2, shutWidth),
      height: openHeight
    )
  }

  static let openHorizontalPadding: CGFloat = 20
  static let openBottomPadding: CGFloat = 16

  /// The two halves of a change of layout: the old one softening away, and the
  /// new one resolving.
  ///
  /// Sequential rather than a cross-fade, which is the whole difference. Two
  /// layouts fading past one another are both on screen together in the middle,
  /// and these two have nothing in common — a row of two things against a title,
  /// a count and seven controls. Blurring one out, exchanging it while there is
  /// nothing to see, and bringing the other back is the same trick the page turn
  /// uses on a whole prayer, for the same reason. See
  /// `PrayerReaderMetrics.pageDissolve`.
  static let swapOut: TimeInterval = 0.14
  static let swapIn: TimeInterval = 0.22

  /// How the verse count rolls over as the reading moves on.
  ///
  /// Quick and barely sprung. This fires once per verse for the length of a
  /// prayer, and anything with a bounce in it would be a small animation going
  /// off over and over in the corner of a page somebody is trying to read.
  static let count: Animation = .spring(response: 0.28, dampingFraction: 0.9)

  /// How soft the contents go as they arrive and leave.
  ///
  /// Enough to be unreadable at the ends of the change, which is the point: a
  /// row of controls that cross-fades legibly is two rows of controls on screen
  /// at once for a moment. Out of focus they read as one thing resolving into
  /// another.
  static let contentBlur: CGFloat = 8

  /// How far the screen behind is taken down while the sheet is open. Enough to
  /// say the page is not the thing being addressed, light enough that the reader
  /// can still see the line they were on.
  static let scrimOpacity: Double = 0.3

  // MARK: Controls

  /// A control's tap target in the open sheet. The same 36 the bottom bar uses —
  /// the two are the same controls in a different place, and a thumb that has
  /// learned one size should not have to learn another.
  static let controlSize: CGFloat = PrayerPlaybackMetrics.controlSize

  static let controlSpacing: CGFloat = 6

  /// Air either side of a speed, and how tall its marker is.
  static let speedInset: CGFloat = 9
  static let speedHeight: CGFloat = 28

  // MARK: Ink

  /// Black, because the island is black.
  ///
  /// The pill no longer pretends to *be* the island, but it is still the island's
  /// sibling and should look like one. Black also sidesteps what the bottom bar
  /// has a long note about: this floats over six different papers, three of them
  /// nearly the colour of their own ink, and black with white on it is legible
  /// over all six.
  static let ground = Color.black

  static let ink = Color.white

  /// What the speeds that are not chosen fade to, and what the verse count is
  /// set in when it is a caption rather than the headline.
  static let dimmedInk = Color.white.opacity(0.55)

  /// The chosen speed, in the same pairing the bottom bar picked and for the
  /// same reason — black and yellow is the fastest thing the eye can find. The
  /// two are simply the other way up here, because the ground is already the
  /// black.
  static let speedActiveFill = Color.yellow
  static let speedActiveInk = Color.black

  /// The one edge on the shape.
  ///
  /// The open sheet hangs over a page that can itself be black — `midnight` and
  /// `ink` are two of the six papers — and a black shape on black paper with no
  /// edge is a shape that has vanished. A hairline this faint is invisible
  /// against every light paper and is the only thing holding the sheet together
  /// against the dark ones.
  static let edge = Color.white.opacity(0.12)

  /// How the pill travels out from under the island, and how it opens.
  ///
  /// Bouncy in both directions now, which it could not be while the chrome was
  /// wrapped around the hardware: back then the resting size *was* the cutout,
  /// so any overshoot on the way to rest showed the bare island coming out of
  /// the middle of the pill, and the retreat had to be critically damped to
  /// prevent it. Detached, there is nothing underneath to reveal — an overshoot
  /// upward just tucks the pill further behind the island, where it was going
  /// anyway.
  static let motion: Animation = .spring(response: 0.42, dampingFraction: 0.62)

  /// And the same change for a reader who has asked for less of it. Not `nil`,
  /// which would snap the pill through forty points of travel between two
  /// frames — the request is for no *bounce*, and a short ease is not bounce.
  static let reducedMotion: Animation = .easeInOut(duration: 0.2)
}

// MARK: - Bar

/// Play, pause and where the reading has got to, in a pill under the Dynamic
/// Island.
///
/// An extended view rather than an extension of the hardware. An earlier version
/// wrapped the cutout and painted itself the island's own black so the two read
/// as one swollen object, and the illusion cost more than it returned: the
/// island is a live system control that grows under a touch, with no API to say
/// when or by how much, so a shape sharing its edge is a shape that will
/// eventually be caught out. This one hangs eight points clear and shares
/// nothing but a width and a colour.
///
/// It has two states. Shut, it is a capsule the width of the cutout carrying the
/// transport glyph and the verse the reading is on. Open, it is a sheet reaching
/// nearly the full width of the screen with the prayer's name, the count again,
/// and every control the bottom bar has. A tap anywhere on it but the pause
/// button opens it; a tap anywhere off it shuts it again, and using any control
/// inside it shuts it too.
///
/// Between readings it waits inside the island's own outline, masked away, and
/// travels down from behind it when a reading starts. Nothing is faded in or
/// out as a whole: the mask has a soft edge shaped like the hardware, so the
/// pill dissolves into the island rather than appearing in front of it — which
/// is also why the entrance survives the cutout constants being a point or two
/// off.
///
/// Shown only where there is an island to hang from, and only while the phone is
/// upright. Everywhere else ``PrayerPlaybackBar`` keeps the job it has always
/// had. See ``AppDynamicIsland/docks(verticalSizeClass:)``.
struct PrayerIslandBar: View {
  let state: PrayerPlaybackState

  /// How fast the page is reading itself.
  let speed: PrayerPlaybackSpeed

  /// How far in it has got, if it is reading at all.
  let progress: PrayerPlaybackProgress?

  /// The prayer's name, for the open sheet.
  ///
  /// Shown here rather than left to the navigation bar because the navigation
  /// bar gives its title up for the length of a reading — this chrome hangs
  /// where the title was, and two of them would be one too many.
  let title: String

  /// Whether the sheet is down.
  ///
  /// Held by the screen rather than here, because the window this is drawn in
  /// needs the answer as well: shut, it takes touches only inside the pill, and
  /// open, it takes them anywhere so the scrim can hear a tap. See
  /// ``PrayerIslandPresenter``.
  @Binding var isOpen: Bool

  /// Play when paused, pause when playing.
  let onToggle: () -> Void

  /// Puts the page back the way it was found.
  let onStop: () -> Void

  /// Changes the pace, from the line after the one being read.
  let onSpeed: (PrayerPlaybackSpeed) -> Void

  /// How far the chrome has travelled out from under the island: 0 sitting
  /// inside it, 1 at rest below it.
  @State private var travel: CGFloat = 0

  /// How far it has grown into the sheet: 0 a pill, 1 the sheet.
  @State private var openness: CGFloat = 0

  /// The second half of an open or a shut, held so that a sheet opened and
  /// closed again mid-flight replaces it rather than landing on top of it.
  @State private var stageWork: DispatchWorkItem?

  /// How far the island's stand-in has swollen: 0 the hardware's own size, 1
  /// open enough for something to pass through.
  @State private var bulge: CGFloat = 0

  /// The swell's own schedule — when to let go, and when to spring back. Its own
  /// item because it overlaps the phase staging above rather than following it.
  @State private var crossWork: DispatchWorkItem?

  /// Whether the chrome is currently the sheet rather than the pill.
  ///
  /// Two shapes rather than one that changes, because each needs something the
  /// other must not have. The pill is masked by the hardware's own outline so
  /// that it can slide out from behind the island; the sheet must not be, because
  /// it opens *around* the cutout and reaches above it.
  /// The sheet also wants corners concentric with the display, which only a real
  /// shape in the hierarchy can strike — see ``sheetShape``.
  ///
  /// They hand over at the one moment their pictures agree: the pill tucked
  /// behind the island, and the sheet still at its seed size inside the hole.
  /// Neither is visible there, so the swap cannot be seen.
  ///
  /// Held as state rather than derived from `openness`, because `openness`
  /// carries its *target* in the view's body — a shut that read it directly
  /// would swap shapes on the first frame and the sheet would vanish instead of
  /// drawing back.
  @State private var isSheet = false

  /// Which layout is actually drawn, which lags ``isOpen`` by the first half of
  /// the change — the shape starts resizing at once, and the contents are
  /// exchanged behind the blur while there is nothing legible to see.
  @State private var showsSheet = false

  /// How far through that exchange the contents are: 0 sharp and here, 1 soft
  /// and gone.
  @State private var swap: CGFloat = 0

  /// The pending exchange, held so a sheet opened and shut again mid-blur
  /// replaces it rather than landing on top of it.
  @State private var swapWork: DispatchWorkItem?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var isPlaying: Bool { state == .playing }

  /// Whether the page is given over to playback, paused or not — and so whether
  /// there is anything for this control to be.
  ///
  /// Kept in the hierarchy while it is `false` rather than removed, exactly as
  /// the switcher and the bottom bar are kept past one another: it is what lets
  /// the pill *grow* out of the cutout when a reading starts and draw back into
  /// it when one ends, instead of appearing at full size already there.
  private var isActive: Bool { state != .stopped }

  private var motion: Animation {
    reduceMotion ? PrayerIslandMetrics.reducedMotion : PrayerIslandMetrics.motion
  }

  var body: some View {
    GeometryReader { proxy in
      let bounds = CGRect(origin: .zero, size: proxy.size)
      let rect = frame(in: bounds)

      ZStack(alignment: .topLeading) {
        // Anywhere off the sheet shuts it, exactly as a tap outside the theme
        // sheet dismisses that. Only in the hierarchy while the sheet is down:
        // the window hands every other touch straight back to the page.
        if isOpen {
          Color.black.opacity(PrayerIslandMetrics.scrimOpacity)
            .frame(width: bounds.width, height: bounds.height)
            .contentShape(Rectangle())
            .onTapGesture { setOpen(false) }
            .transition(.opacity)
        }

        // The black.
        //
        // Two branches, and neither is about looks — each can do something the
        // other cannot. The pill has to be masked by the hardware's outline so
        // it can slide out from behind the island; the sheet must *not* be,
        // because it opens around the cutout and reaches above it. The sheet
        // also wants corners concentric with the display, which only a real
        // `ConcentricRectangle` in the hierarchy can strike.
        //
        // They hand over at the one moment they agree — see ``isSheet``.
        if isSheet {
          sheetShape
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)
        } else {
          // The island itself, standing in for the hardware so that it can
          // appear to swell and let the pill through. Invisible unless it is
          // doing that — see ``PrayerIslandMetrics/proxy(in:bulge:)``.
          Capsule(style: .circular)
            .fill(PrayerIslandMetrics.ground)
            .frame(
              width: PrayerIslandMetrics.proxy(in: bounds, bulge: bulge).width,
              height: PrayerIslandMetrics.proxy(in: bounds, bulge: bulge).height
            )
            .offset(
              x: PrayerIslandMetrics.proxy(in: bounds, bulge: bulge).minX,
              y: PrayerIslandMetrics.proxy(in: bounds, bulge: bulge).minY
            )
            .allowsHitTesting(false)

          Capsule(style: .circular)
            .fill(PrayerIslandMetrics.ground)
            .overlay {
              Capsule(style: .circular)
                .strokeBorder(PrayerIslandMetrics.edge, lineWidth: 0.5)
            }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)
        }

        // And what is written on it, riding along on top. Positioned from the
        // same two numbers the canvas draws from, so the two cannot drift.
        contents
          .blur(radius: contentBlur)
          // Nothing is written on the pill until it is out. Inside the island
          // the pill is black on a black hole and invisible, but white glyphs on
          // it would not be — so they arrive with it rather than waiting there
          // to be carried out.
          .opacity(Double(emergence) * (1 - Double(swap)))
          .frame(width: rect.width, height: rect.height)
          .clipShape(outline)
          .offset(x: rect.minX, y: rect.minY)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    // The window this is drawn in has no navigation bar and no safe area worth
    // respecting — it exists precisely to be the whole screen. See
    // `PrayerIslandPresenter`.
    .ignoresSafeArea()
    // The glyph changes under the finger that changed it, so the click belongs
    // to the control rather than to the page starting or stopping.
    .appSelectionFeedback(trigger: state)
    // A reading that ends while the sheet is down leaves the sheet with nothing
    // to control. Shut rather than left hanging, so the next reading opens from
    // the pill the reader last saw it as.
    .onValueChange(state) { if state == .stopped { setOpen(false) } }
    .onValueChange(isActive, perform: retarget)
    .onValueChange(isOpen) {
      // Opening the sheet halts the reading, always.
      //
      // A reader who reaches for these controls has stopped following the page
      // — they are choosing a pace, or deciding to stop, and the prayer walking
      // on underneath while they do it is a stretch of recitation they have
      // missed. It is the same argument `PrayerViewController` already makes for
      // pausing when the app stops being the active one.
      //
      // Nothing resumes on the way out. They came here to intervene, so the page
      // waits until they say otherwise — and the pill's glyph is showing play by
      // then, which is one tap away.
      if isOpen, isPlaying {
        onToggle()
      }

      // One call now. The contents used to be exchanged here, on their own
      // clock; `retarget` owns both halves so they cannot drift apart.
      retarget()
    }
    .onDisappear {
      swapWork?.cancel()
      stageWork?.cancel()
      crossWork?.cancel()
    }
  }

  // MARK: - Where the chrome is

  /// The chrome's rectangle right now.
  ///
  /// Which of the two journeys it is on depends on ``isSheet``, and the two
  /// never overlap: the pill only travels while shut, and the sheet only grows
  /// once the pill is home.
  private func frame(in bounds: CGRect) -> CGRect {
    guard isSheet else {
      // Behind the island, or on its way out from there. Constant size — coming
      // and going is pure travel.
      return interpolate(
        PrayerIslandMetrics.hiddenRect(in: bounds),
        PrayerIslandMetrics.shutRect(in: bounds),
        travel
      )
    }

    return interpolate(
      PrayerIslandMetrics.seed(in: bounds),
      PrayerIslandMetrics.sheet(in: bounds),
      openness
    )
  }

  private func interpolate(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
    CGRect(
      x: a.minX + (b.minX - a.minX) * t,
      y: a.minY + (b.minY - a.minY) * t,
      width: a.width + (b.width - a.width) * t,
      height: a.height + (b.height - a.height) * t
    )
  }

  // MARK: - The two-phase change

  /// Puts the chrome on its way to wherever it now belongs.
  ///
  /// Opening and shutting are each two movements rather than one, and the order
  /// is the whole effect. To open, the pill travels back up into the island and
  /// only then grows into the sheet — so the sheet appears to come out of the
  /// hardware rather than out of a pill floating below it. To shut, the sheet
  /// draws back into the island first and the pill separates out afterwards.
  ///
  /// Starting a reading and ending one are single movements, because there is
  /// nothing to open or shut.
  private func retarget() {
    stageWork?.cancel()
    stageWork = nil

    guard isActive else {
      // The reading is over. Everything goes back into the island together —
      // there is nothing to exchange on the way, because nothing is going to be
      // looked at afterwards. `emergence` blurs the contents away as the pill
      // withdraws.
      withAnimation(motion) { openness = 0 }
      isSheet = false
      showsSheet = false
      swallow()
      return
    }

    guard isOpen else {
      guard isSheet else {
        // A reading starting. The island gathers, then squeezes the pill out,
        // and `emergence` blurs its contents in as it comes.
        spit()
        return
      }

      // Shutting. The sheet draws back into the island first, and only then is
      // the pill squeezed out again.
      withAnimation(motion) { openness = 0 }
      exchange(at: PrayerIslandMetrics.release, to: false) {
        isSheet = false
        spit()
      }
      return
    }

    // Opening. The island takes the pill back, and once it is inside the sheet
    // grows out of it.
    swallow()
    exchange(at: PrayerIslandMetrics.retract, to: true) {
      isSheet = true
      withAnimation(motion) { openness = 1 }
    }
  }

  /// The island gathers itself, then contracts and the pill comes out.
  ///
  /// Two beats rather than three, and that is the whole revision. The gather is
  /// a wind-up and happens alone; the contraction and the pill's flight are a
  /// single `withAnimation` on a single curve, so the island is visibly the
  /// thing doing the pushing. A shrink that ran *after* the pill had already
  /// left — which is what this did before — is three unrelated events in a row,
  /// and reads as one.
  private func spit() {
    crossWork?.cancel()

    guard !reduceMotion else {
      withAnimation(motion) {
        bulge = 0
        travel = 1
      }
      crossWork = nil
      return
    }

    withAnimation(.easeInOut(duration: PrayerIslandMetrics.gather)) { bulge = 1 }

    let squeeze = DispatchWorkItem {
      withAnimation(PrayerIslandMetrics.eject) {
        bulge = 0
        travel = 1
      }
      crossWork = nil
    }

    crossWork = squeeze
    DispatchQueue.main.asyncAfter(
      deadline: .now() + PrayerIslandMetrics.gather,
      execute: squeeze
    )
  }

  /// And the same in reverse: the island opens as the pill arrives, and closes
  /// once it is in.
  ///
  /// The opening is not a wind-up here — nothing is being launched — so it runs
  /// *with* the pill rather than ahead of it, and the closing is what happens
  /// on its own afterwards. Time-reverse a spit and this is what you get.
  private func swallow() {
    crossWork?.cancel()

    guard !reduceMotion else {
      withAnimation(motion) {
        bulge = 0
        travel = 0
      }
      crossWork = nil
      return
    }

    withAnimation(PrayerIslandMetrics.receive) {
      bulge = 1
      travel = 0
    }

    let close = DispatchWorkItem {
      withAnimation(.easeInOut(duration: PrayerIslandMetrics.closeUp)) { bulge = 0 }
      crossWork = nil
    }

    crossWork = close
    DispatchQueue.main.asyncAfter(
      deadline: .now() + PrayerIslandMetrics.swallowHold,
      execute: close
    )
  }

  private func stage(after delay: TimeInterval, _ change: @escaping () -> Void) {
    let work = DispatchWorkItem(block: change)
    stageWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
  }

  // MARK: - The shape

  /// The sheet, with corners struck concentric with the display's.  /// The sheet, with corners struck concentric with the display's.  /// The sheet, with corners struck concentric with the display's.
  ///
  /// `ConcentricRectangle` is the API for this and there is no other: the
  /// display's corner radius is not readable as a number anywhere in public
  /// UIKit or SwiftUI — only `UIMutableTraits` carries a `displayCornerRadius`,
  /// and that one is for writing. So the radius can never be computed, only
  /// asked for, which is why this has to be a real shape in the hierarchy rather
  /// than a `Path` handed to the canvas. A `Path` has no container to be
  /// concentric *with*.
  ///
  /// `minimum` is the floor for a shape too small or too far from an edge for
  /// concentricity to mean much — the sheet passing through the pill's size on
  /// its way open is exactly that case, and without a floor its corners would
  /// go square on the way there.
  ///
  /// Below iOS 26 there is no such thing, and the sheet takes the fixed corner
  /// it had before.
  @ViewBuilder
  private var sheetShape: some View {
    if #available(iOS 26.0, macOS 26.0, *) {
      let shape = ConcentricRectangle(
        corners: .concentric(minimum: .fixed(PrayerIslandMetrics.openRadius)),
        isUniform: true
      )

      shape
        .fill(PrayerIslandMetrics.ground)
        .overlay { shape.stroke(PrayerIslandMetrics.edge, lineWidth: 0.5) }
    } else {
      let shape = RoundedRectangle(
        cornerRadius: PrayerIslandMetrics.openRadius,
        style: .continuous
      )

      shape
        .fill(PrayerIslandMetrics.ground)
        .overlay { shape.strokeBorder(PrayerIslandMetrics.edge, lineWidth: 0.5) }
    }
  }

  private var outline: RoundedRectangle {
    RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
  }

  /// What the contents are clipped to.
  ///
  /// Only ever the pill's own capsule or something close to the sheet's corner —
  /// the sheet's *drawn* corners come from ``sheetShape`` and may be larger than
  /// this, but nothing is written near enough to a corner for the difference to
  /// show.
  private var cornerRadius: CGFloat {
    guard isSheet else { return PrayerIslandMetrics.shutRadius }

    let seed = PrayerIslandMetrics.seedHeight / 2
    return seed + (PrayerIslandMetrics.openRadius - seed) * openness
  }

  // MARK: - Contents

  @ViewBuilder
  private var contents: some View {
    if showsSheet {
      sheet
    } else {
      shutLayout
    }
  }

  /// How soft the contents are right now.
  ///
  /// Two reasons to be blurred and one number for both: the pill is arriving out
  /// of the cutout or going back into it, or its layout is being exchanged.
  /// Whichever asks for more, gets it.
  /// How far out of the island the pill has come, as far as the things written
  /// on it are concerned.
  ///
  /// Nothing until it is a third of the way, everything by four fifths — the
  /// glyphs should not be legible while they are still crossing the hardware's
  /// own outline.
  private var emergence: CGFloat {
    guard !isSheet else { return 1 }

    return min(max((travel - 0.3) / 0.5, 0), 1)
  }

  private var contentBlur: CGFloat {
    max(
      (1 - emergence) * PrayerIslandMetrics.contentBlur,
      swap * PrayerIslandMetrics.contentBlur
    )
  }

  // MARK: - Shut

  /// The transport glyph and where the reading has got to.
  ///
  /// Laid out as three layers rather than a row, and only because of where the
  /// touches have to land. Anywhere on the pill opens the sheet *except* the
  /// transport button, which keeps a strict twenty-eight points at the far left
  /// and nothing more — a row with the button in it gave the button the row's
  /// full height and enough of its width that a tap meant as "show me the
  /// controls" kept stopping the reading instead.
  private var shutLayout: some View {
    ZStack(alignment: .leading) {
      // The whole pill, underneath everything, opening the sheet. The button
      // above it takes its own touches first; nothing else here takes any.
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture { setOpen(true) }
        .accessibilityHidden(true)

      // Where the reading has got to, rather than how fast it is going.
      //
      // The pace was here first and it was the wrong fact. A reader glancing up
      // mid-recitation wants to know where they are — the pace is something they
      // set once and then stop thinking about, and it is still shown, and still
      // changed, in the sheet a tap away. This changes on its own as the prayer
      // goes by, which is the other half of the argument: it is the one thing up
      // here worth watching.
      counter
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, PrayerIslandMetrics.shutHorizontalPadding)
        // Not a control, and must not behave like one: a `Text` that took the
        // touch would swallow it rather than let the layer beneath open the
        // sheet.
        .allowsHitTesting(false)

      control(
        systemImage: isPlaying ? "pause.fill" : "play.fill",
        label: isPlaying ? L10n.pausePrayer : L10n.playPrayer,
        size: PrayerIslandMetrics.shutGlyphSize,
        action: onToggle
      )
      .frame(
        width: PrayerIslandMetrics.shutControlSize,
        height: PrayerIslandMetrics.shutControlSize
      )
      .padding(.leading, PrayerIslandMetrics.shutHorizontalPadding - 6)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityHint(L10n.expandControls)
  }

  /// `4/22`, rolling over as the reading moves on.
  ///
  /// Latin digits in both languages, the same decision ``PrayerPlaybackSpeed``
  /// makes about its own label: this is a quantity, and it has the width of two
  /// or three characters to say it in.
  ///
  /// Nothing at all until the reader has told us where it is. That is a single
  /// hop at the start of a reading — see `PrayerViewController.reportProgress()`
  /// — and a placeholder held for one frame would be a flicker rather than a
  /// courtesy.
  @ViewBuilder
  private var counter: some View {
    if let progress {
      Text(verbatim: "\(progress.verse)/\(progress.verses)")
        .font(.system(size: PrayerIslandMetrics.shutGlyphSize, weight: .semibold))
        // Both of these matter and for different reasons. The digits are fixed
        // width so that `9/22` becoming `10/22` does not shuffle the label
        // sideways under the reader's eye; the transition is what makes the
        // number roll rather than cut.
        .monospacedDigit()
        .modifier(PrayerIslandCountRoll(value: progress.verse))
        .foregroundStyle(PrayerIslandMetrics.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .animation(PrayerIslandMetrics.count, value: progress.verse)
    }
  }

  // MARK: - Open

  /// Everything the bottom bar has, plus the title the navigation bar gave up.
  private var sheet: some View {
    VStack(alignment: .leading, spacing: 0) {
      // The hole it has opened around. Nothing may be drawn here and nothing can
      // be tapped here, so the layout steps over the whole band.
      Spacer()
        .frame(height: PrayerIslandMetrics.openContentTop)

      Text(title)
        .font(AppFont.listItemTitle)
        .foregroundStyle(PrayerIslandMetrics.ink)
        // One line, whatever it costs the type. See
        // ``PrayerIslandMetrics/openHeight`` — the sheet animates to a fixed
        // height, so it cannot be allowed to follow a title.
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      if let progress {
        // Latin digits in both languages, and the same decision
        // ``PrayerPlaybackSpeed/label`` made: a count is a quantity, and `4 / 22`
        // is `4 / 22` to anybody who has ever read a page number. The generated
        // argument type wants a value per language, so both get the same one.
        Text(
          L10n.verseProgress(
            .both(en: "\(progress.verse)", mm: "\(progress.verse)"),
            .both(en: "\(progress.verses)", mm: "\(progress.verses)")
          )
        )
        .font(AppFont.caption)
        .monospacedDigit()
        .modifier(PrayerIslandCountRoll(value: progress.verse))
        .foregroundStyle(PrayerIslandMetrics.dimmedInk)
        .lineLimit(1)
        .padding(.top, 2)
        .animation(PrayerIslandMetrics.count, value: progress.verse)
      }

      Spacer(minLength: 12)

      HStack(spacing: 0) {
        transport
        Spacer(minLength: 8)
        speeds
      }
    }
    .padding(.horizontal, PrayerIslandMetrics.openHorizontalPadding)
    .padding(.bottom, PrayerIslandMetrics.openBottomPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  /// Pause and stop, the same pair the bottom bar leads with.
  private var transport: some View {
    HStack(spacing: PrayerIslandMetrics.controlSpacing) {
      control(
        systemImage: isPlaying ? "pause.fill" : "play.fill",
        label: isPlaying ? L10n.pausePrayer : L10n.playPrayer,
        action: dismissing(onToggle)
      )
      .frame(width: PrayerIslandMetrics.controlSize)

      // The one way out, and the only red here — see the bottom bar, which makes
      // the same choice at more length. Pause is a rest; this ends the reading
      // and gives the page back.
      control(
        systemImage: "stop.fill",
        label: L10n.stopPrayer,
        tint: AppColor.error,
        action: dismissing(onStop)
      )
      .frame(width: PrayerIslandMetrics.controlSize)
    }
  }

  /// All five paces, laid out rather than cycled through.
  ///
  /// The reason the sheet exists. Shut, the control can show which pace is on
  /// and no more; a reader choosing *between* paces needs to see the ones they
  /// are not on, and there is no room for that under a cutout.
  private var speeds: some View {
    HStack(spacing: 0) {
      ForEach(PrayerPlaybackSpeed.allCases, id: \.self) { option in
        Button(action: dismissing { onSpeed(option) }) {
          Text(option.label)
            .font(.system(size: 12, weight: option == speed ? .semibold : .regular))
            // So the row does not shuffle sideways as the marker moves.
            .monospacedDigit()
            .foregroundStyle(
              option == speed
                ? PrayerIslandMetrics.speedActiveInk
                : PrayerIslandMetrics.dimmedInk
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, PrayerIslandMetrics.speedInset)
            .frame(height: PrayerIslandMetrics.speedHeight)
            .background {
              if option == speed {
                Capsule().fill(PrayerIslandMetrics.speedActiveFill)
              }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(option == speed ? .isSelected : [])
      }
    }
    .frame(height: PrayerIslandMetrics.controlSize)
    // The marker slides between speeds rather than blinking from one to the
    // next, which is the only thing that says the five are one control.
    .animation(motion, value: speed)
    .appSelectionFeedback(trigger: speed)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(L10n.playbackSpeed)
  }

  // MARK: - Pieces

  private func control(
    systemImage: String,
    label: String,
    tint: Color? = nil,
    size: CGFloat = 15,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(tint ?? PrayerIslandMetrics.ink)
        // Play and pause change into one another rather than cutting. The two
        // glyphs are built to do this — a triangle folding into two bars — and
        // it is the difference between a control that answered and a control
        // that was simply redrawn. Stop never changes symbol, so there is
        // nothing here for it to do; what answers a tap on stop is the whole
        // pill withdrawing into the cutout.
        .modifier(PrayerIslandSymbolSwap())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The whole square, not the glyph: a pause symbol is a small target, and
        // the space around it is target this control has already been given.
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  /// Wraps one of the sheet's controls so that using it puts the sheet away.
  ///
  /// The sheet is a detour. A reader opens it to answer one question — hold this,
  /// or read it faster — and once they have answered it the page is what they
  /// came back for, not a panel sitting over the top of it. This is how the
  /// system's own island behaves for the same reason, and it is what stops the
  /// chrome from needing a close button it would then have to find room for.
  ///
  /// Nothing is lost by going straight back. The shut pill carries the pace in
  /// its corner and the transport glyph beside it, so the confirmation the
  /// reader is looking for is already on the thing that replaces the sheet.
  ///
  /// Safe to wrap the shut pill's own controls in as well, though nothing does:
  /// ``setOpen(_:)`` ignores a request for the state it is already in.
  private func dismissing(_ change: @escaping () -> Void) -> () -> Void {
    {
      change()
      setOpen(false)
    }
  }

  /// Softens the contents away, changes them *and the shape they are on* in the
  /// same instant, and brings them back.
  ///
  /// Blurred rather than cross-faded, and driven from a value rather than left
  /// to a `transition`. This view is hosted in a window of its own and its root
  /// is reassigned on every pass — see ``PrayerIslandPresenter`` — and a
  /// transition needs the structural change and the animation to meet in a tree
  /// whose identity has held still. A blur that is simply a number nothing has
  /// to notice is a number that animates whatever else is going on around it.
  ///
  /// Two layouts fading past one another would be legible together in the middle
  /// besides, and they have nothing in common: a row of two things against a
  /// title, a count and seven controls. Out of focus the first loses its shape
  /// before the second finds one.
  ///
  /// - Parameters:
  ///   - moment: How far from now the shape changes. The blur is arranged around
  ///     it, not started at it.
  ///   - sheet: Which layout to change to.
  ///   - change: What to do to the shape at that instant.
  private func exchange(at moment: TimeInterval, to sheet: Bool, _ change: @escaping () -> Void) {
    swapWork?.cancel()

    guard !reduceMotion else {
      // No softening for a reader who has asked for none. The contents are
      // simply the ones they should be, when they should be.
      swap = 0
      stage(after: moment) {
        showsSheet = sheet
        change()
      }
      swapWork = nil
      return
    }

    // The blur has to *finish* as the shape changes, not begin there — so it
    // starts a `swapOut` early and the exchange lands at the bottom of it.
    let lead = max(moment - PrayerIslandMetrics.swapOut, 0)

    let soften = DispatchWorkItem {
      withAnimation(.easeIn(duration: PrayerIslandMetrics.swapOut)) { swap = 1 }

      let resolve = DispatchWorkItem {
        // Both at once. This is the whole of the fix: the contents used to be
        // exchanged when `isOpen` changed and the shape when its phase came due,
        // which put a third of a second between them — long enough for the
        // sheet's title and its seven controls to be drawn, briefly, on a pill
        // a hundred and twenty-six points wide.
        showsSheet = sheet
        change()

        withAnimation(.easeOut(duration: PrayerIslandMetrics.swapIn)) { swap = 0 }
        swapWork = nil
      }

      swapWork = resolve
      DispatchQueue.main.asyncAfter(
        deadline: .now() + PrayerIslandMetrics.swapOut,
        execute: resolve
      )
    }

    swapWork = soften
    DispatchQueue.main.asyncAfter(deadline: .now() + lead, execute: soften)
  }

  private func setOpen(_ open: Bool) {
    guard open != isOpen else { return }

    // A plain write. The curve is attached to the value above.
    isOpen = open
  }
}


// MARK: - Availability shims

/// Turns a change of SF Symbol into the symbol's own animation, where the system
/// has one.
///
/// iOS 17 for `symbolEffect`, and nothing at all below it — the glyph simply
/// changes, which is what it did everywhere in this app before this modifier
/// existed. Written as a modifier rather than inline because the availability
/// check has to wrap the *modifier* and not the view, and a branch on the view
/// would give the two arms different identities and animate the whole image in
/// and out on every state change.
private struct PrayerIslandSymbolSwap: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      content.contentTransition(.symbolEffect(.replace))
    } else {
      content
    }
  }
}

/// Rolls a number over instead of cutting to the next one.
///
/// `numericText` knows what a digit is: it slides the ones that changed and
/// leaves the ones that did not, so `9/22` to `10/22` grows a column rather than
/// redrawing the label. From iOS 17 it can also be told the value, which is what
/// lets it roll the right way when a reading is sent back to the beginning.
///
/// A modifier rather than a branch at the call site, for the same reason
/// ``PrayerIslandSymbolSwap`` is one: two arms of an `if #available` around a
/// *view* are two identities, and the text would animate in and out wholesale on
/// every change instead of rolling.
private struct PrayerIslandCountRoll: ViewModifier {
  let value: Int

  func body(content: Content) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      content.contentTransition(.numericText(value: Double(value)))
    } else {
      content.contentTransition(.numericText())
    }
  }
}
