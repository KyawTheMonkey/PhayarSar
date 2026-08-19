import DesignKit
import PrayersKit
import SwiftUI

// MARK: - Metrics

enum PrayerCoverMetrics {
  /// Square, and roughly half the width of a phone, so the hero reads as
  /// artwork rather than as an oversized list thumbnail.
  static let size: CGFloat = 176
  /// Album-art corners rather than the app's usual soft ones — the gallery is
  /// meant to read as sleeves standing in a rack.
  static let cornerRadius: CGFloat = 12

  /// The angle every cover off the centre stands at.
  ///
  /// Fixed, not progressive — this is what makes Cover Flow look like Cover Flow
  /// rather than like a curve. A cover turns from flat to this over the single
  /// step it takes to leave the middle, and then holds it however far back in
  /// the stack it goes. The result reads as two flat walls either side of one
  /// cover facing you, which is exactly what the iTunes gallery is.
  static let flankAngle: Double = 64

  /// Gap from the centred cover's middle to the first turned cover's middle.
  ///
  /// Set so the flanking cover clears the centred one instead of tucking under
  /// it: a turned cover is about 66pt wide on screen, so at this distance its
  /// near edge stops a little short of the centred cover's, leaving the front
  /// of the gallery reading as one sleeve rather than three fused together.
  static let centreGap: CGFloat = 134

  /// Step between one turned cover and the next, once both are in the wall.
  ///
  /// Still smaller than ``centreGap`` — the wall is meant to stack — but wide
  /// enough that each sleeve shows a clear band of itself rather than only the
  /// sliver its neighbour doesn't cover. A turned cover is about 66pt wide on
  /// screen, so this leaves roughly a third of each one overlapped.
  static let flankStep: CGFloat = 44

  /// How much of its size a cover keeps once it has turned into the wall, and
  /// how much more it loses for each place further back.
  static let flankScale: CGFloat = 0.86
  static let depthFalloff: Double = 0.93

  /// How far the strip scrolls to bring the next cover to the front.
  static let pitch: CGFloat = 120

  /// Layout gap, backed out of ``pitch``. Deeply negative: the covers overlap
  /// heavily on screen, so they have to overlap in the layout too or the strip
  /// would scroll far further than it looks like it should.
  static var spacing: CGFloat { pitch - size }

  /// How near the camera sits for a cover's own turn. Only ever applied to an
  /// in-place rotation — no depth translation, so nothing can cross the camera
  /// plane and stop drawing.
  static let perspective: CGFloat = 0.55

  /// How much of its opacity a cover keeps once it has turned into the wall,
  /// and how much more it gives up for each place further back.
  ///
  /// The fade starts at the very first cover off centre, rather than holding a
  /// few at full strength. On iTunes' black background the flanking covers
  /// recede by going dark; on a light background the equivalent is going pale,
  /// and it has to start immediately — held at full opacity, a row of
  /// overlapping covers in one flat colour merges into a single silhouette with
  /// no depth in it at all.
  static let flankOpacity: Double = 0.5
  static let opacityFalloff: Double = 0.7

  /// Past this many covers out, there is nothing left worth drawing.
  static let hiddenCovers: Double = 5

  /// Height of the mirrored reflection under each cover.
  ///
  /// Measured off the shelf's top surface rather than off the cover, because the
  /// reflection lies *on* that surface — reflecting the iTunes third of a cover
  /// would run the image over the front lip and down the face of the slab. Kept
  /// a little shorter still, so the near strip of shelf stays clear and the
  /// surface reads as continuing in front of the artwork.
  static var reflectionHeight: CGFloat { PrayerShelfMetrics.topDepth - 7 }

  /// How much of the artwork's colour the shelf gives back.
  ///
  /// Faint, and fainter than a mirror would be: the slab is a matte surface with
  /// a sheen, not glass, and at this size a strong reflection stops reading as
  /// an image in the shelf and starts reading as a second object lying on it.
  static let reflectionStrength: Double = 0.16

  /// How far the reflection is smeared.
  ///
  /// The other half of matte. A sharp mirror image carries the cover's corners
  /// and edges intact, and a crisp shape below a cover is a shape, whatever its
  /// opacity — this is what turns it back into a sheen.
  static let reflectionBlur: CGFloat = 2

  /// Room above the covers, for the flare perspective gives a turned cover's
  /// near edge, and below them for the shelf. A `ScrollView` clips to its
  /// bounds, so whatever isn't budgeted here gets sliced off.
  static let topInset: CGFloat = 20
  static var bottomInset: CGFloat { PrayerShelfMetrics.height }

  /// Where the covers stand, measured down from the top of the carousel. The
  /// shelf's own top surface starts on this line.
  static var shelfLine: CGFloat { topInset + size }

  /// How many times the catalog is repeated to build the looping strip: one
  /// run of padding cells before, the real run, one run after.
  ///
  /// Padding a *whole* catalog either side rather than two or three covers is
  /// what keeps the seam out of reach. The strip is only re-centred once the
  /// scroll leaves the middle run, so with a full run of slack that can't happen
  /// mid-flick however hard the reader throws it — it would take thirty-odd
  /// pages in one gesture.
  static let copies = 3

  /// Total height the carousel occupies in the hero.
  static var height: CGFloat { size + topInset + bottomInset }
}

// MARK: - Cover

/// One prayer's cover art, standing on its own reflection.
///
/// A plain grey square until real artwork exists. The reflection hangs below the
/// cover as an overlay rather than sitting under it in a stack, so the view's
/// layout box stays the cover alone — which keeps the carousel's rotations
/// pivoting about the middle of the art and not about the middle of art plus
/// floor.
struct PrayerCover: View {
  var body: some View {
    face
      .overlay(alignment: .bottom) {
        reflection
          .offset(y: PrayerCoverMetrics.reflectionHeight)
          .allowsHitTesting(false)
      }
  }

  /// The artwork, with nothing on it.
  private var art: some View {
    RoundedRectangle(cornerRadius: PrayerCoverMetrics.cornerRadius, style: .continuous)
      .fill(AppColor.grey300)
      .frame(width: PrayerCoverMetrics.size, height: PrayerCoverMetrics.size)
  }

  private var face: some View {
    art
      // The covers in the wall overlap by design, and until there is real
      // artwork they are all the same flat grey — so without a lit edge to
      // separate one from the next the whole stack reads as a single shape.
      .overlay(
        RoundedRectangle(cornerRadius: PrayerCoverMetrics.cornerRadius, style: .continuous)
          .strokeBorder(.white.opacity(0.55), lineWidth: 1)
      )
  }

  /// What the shelf gives back of the cover standing on it: the artwork flipped
  /// about the line where the two meet, cropped to the near strip of surface,
  /// smeared, and faded out as it goes.
  ///
  /// ``art`` rather than ``face``, and this is the whole difference between a
  /// reflection and a plate lying on the shelf. The lit edge is a highlight on
  /// the sleeve, not part of the picture on it; mirrored along with everything
  /// else it drew a crisp outline around the reflection — and an outlined shape
  /// with rounded corners under a cover reads as an object, however faint it is.
  private var reflection: some View {
    art
      .scaleEffect(x: 1, y: -1)
      // Before the crop, so the smear is cut off by the edge of the strip rather
      // than bleeding up over the cover standing on it.
      .blur(radius: PrayerCoverMetrics.reflectionBlur)
      // Taken from the top of the flipped copy, which is the bottom edge of the
      // cover: a reflection continues from where the object meets the floor.
      .frame(height: PrayerCoverMetrics.reflectionHeight, alignment: .top)
      .clipped()
      .mask(
        LinearGradient(
          colors: [.black.opacity(PrayerCoverMetrics.reflectionStrength), .clear],
          startPoint: .top,
          endPoint: .bottom
        )
      )
  }
}

// MARK: - Carousel

/// The cover art, paged through the catalog in order, wrapping at both ends.
///
/// Swiping settles on a neighbouring prayer and writes it back through
/// `selectedID`, which is what re-points the rest of the screen — title, chips,
/// about, specs and the navigation title all follow from that one value.
///
/// The loop is real rather than drawn: the strip holds
/// ``PrayerCoverMetrics/copies`` runs of the catalog end to end, the reader is
/// kept in the middle run, and settling anywhere else slides silently back to
/// the matching cover in the middle. Because every run is identical and the
/// slide is an exact whole number of runs, the cover under the centre never
/// moves — so the seam has nothing to show.
///
/// Below iOS 17 this is the single static cover instead. Paging that snaps to an
/// item narrower than the scroll view, with the neighbours peeking and scaling
/// as they pass, needs `scrollTargetBehavior`, `scrollTransition` and
/// `scrollPosition` — all iOS 17. The alternatives on iOS 16 are a free-scrolling
/// strip that never settles anywhere, or a hand-written drag-and-spring
/// carousel; a still cover reads as a deliberate design, and the other two read
/// as a broken one.
struct PrayerCoverCarousel: View {
  let prayers: [Prayer]
  /// The prayer the screen was opened on, held apart from ``selectedID``
  /// because the binding can be written to before the carousel has reached it —
  /// see `PagingCovers.anchorToOpeningPrayer`.
  let openingID: Prayer.ID
  @Binding var selectedID: Prayer.ID

  var body: some View {
    ZStack(alignment: .top) {
      // Outside the scroll view, so it holds still while the covers slide past
      // it. Inside, it would scroll with them and the gallery would look like it
      // was carrying its own floor around.
      PrayerCoverShelf()
        .padding(.top, PrayerCoverMetrics.shelfLine)

      Covers()
    }
    .frame(height: PrayerCoverMetrics.height)
  }

  @ViewBuilder
  private func Covers() -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      PagingCovers(prayers: prayers, openingID: openingID, selectedID: $selectedID)
    } else {
      PrayerCover()
        .frame(height: PrayerCoverMetrics.height)
    }
  }
}

// MARK: - Paging implementation

/// One position in the looping strip.
///
/// Identity is the position, not the prayer: every prayer appears once per run,
/// and a `ForEach` given the same id three times would collapse the three into
/// one.
private struct LoopCell: Identifiable {
  let id: Int
  let prayer: Prayer
}

@available(iOS 17.0, macOS 14.0, *)
private struct PagingCovers: View {
  let prayers: [Prayer]
  @Binding var selectedID: Prayer.ID

  /// The catalog repeated end to end. Built once per view value rather than in
  /// `body`, which runs far more often.
  private let cells: [LoopCell]

  /// Where the opening prayer sits in the middle run.
  private let openingCell: Int

  /// Position in ``cells``, not in the catalog — the same prayer has one of
  /// these per run, and the difference between them is exactly what the
  /// re-centring uses.
  @State private var scrolledCell: Int?

  /// Whether the opening prayer has been scrolled to. One-shot: `onAppear` also
  /// fires on the way back from a pushed screen, and re-anchoring then would
  /// throw away whatever the reader had paged to before leaving.
  @State private var hasAnchored = false

  init(prayers: [Prayer], openingID: Prayer.ID, selectedID: Binding<Prayer.ID>) {
    self.prayers = prayers
    self._selectedID = selectedID

    let count = prayers.count
    self.cells = (0 ..< count * PrayerCoverMetrics.copies).map { position in
      LoopCell(id: position, prayer: prayers[position % count])
    }

    // Opening in the middle run, so there is a full catalog of slack to page
    // through in either direction before anything needs re-centring.
    let opening = prayers.firstIndex { $0.id == openingID } ?? 0
    self.openingCell = opening + count
    _scrolledCell = State(initialValue: opening + count)
  }

  var body: some View {
    GeometryReader { proxy in
      // Where the middle of the carousel falls on screen. Read in `.global`,
      // and each cover reads its own position in `.global` too, so the
      // difference between them needs no coordinate space to be resolved and
      // no two measurements to agree about their origin. Getting that wrong is
      // invisible in the maths and obvious on screen: every cover ends up
      // reporting the same constant error, and the whole gallery slides off to
      // one side.
      let viewportCentreX = proxy.frame(in: .global).midX
      let containerWidth = proxy.size.width

      // Half a container minus half a cover. This is what centres the covers:
      // it leaves a content region exactly one cover wide, so the aligned cover
      // lands in the middle of the screen — and it lets the first and last
      // prayers reach the middle too, rather than stopping against an edge.
      let endInset = max(0, (containerWidth - PrayerCoverMetrics.size) / 2)

      ScrollViewReader { scroller in
        ScrollView(.horizontal) {
          // Deliberately not lazy. `scrollPosition(id:)` can only open on a
          // cover whose view already exists, and a lazy stack has only built
          // the first screenful — so opening on the tenth prayer silently left
          // the scroll view at the start, which it then reported back through
          // the binding, replacing the prayer the reader had tapped with the
          // first in the catalog. A hundred-odd fixed-size rectangles cost
          // nothing to hold; revisit if the covers become downloaded images.
          HStack(spacing: PrayerCoverMetrics.spacing) {
            ForEach(cells) { cell in
              PrayerCover()
                // `visualEffect` rather than `scrollTransition`, because this
                // needs real geometry. A transition phase is normalised to the
                // visible region — it says "most of the way out", not "167pt
                // from the middle" — and an angle around a sphere can't be
                // built from that.
                //
                // The distance comes from the named coordinate space on the
                // scroll view below, the same way `ScrollOffsetReader` measures
                // elsewhere in the app: a cover's `midX` in that space is its
                // position across the viewport, so subtracting the viewport's
                // half-width gives a signed distance from the middle in points.
                .visualEffect { content, proxy in
                  // `containerWidth` is 0 until the first layout pass, and a
                  // cover measured against nothing would be placed as though it
                  // were far out in the wall — turned away and faded off. Left
                  // flat until there is something real to measure against.
                  let travel = containerWidth > 0
                    ? proxy.frame(in: .global).midX - viewportCentreX
                    : 0

                  let place = CoverFlowPlacement(
                    coversFromCentre: Double(travel / PrayerCoverMetrics.pitch)
                  )

                  return content
                    // Anchored at the bottom, which is the shelf line: scaling
                    // about the middle instead would lift a flanking cover's
                    // base clear of the surface by the height it lost, and the
                    // wall would be standing on nothing.
                    .scaleEffect(place.scale, anchor: .bottom)
                    .rotation3DEffect(
                      .degrees(place.turn),
                      axis: (x: 0, y: 1, z: 0),
                      perspective: PrayerCoverMetrics.perspective
                    )
                    // Moved from where the strip laid it out to where the
                    // gallery actually stands it. Subtracting `travel` is what
                    // makes this absolute rather than relative: whatever the
                    // scroll view believes about alignment, the cover with
                    // nothing between it and the middle is drawn *at* the
                    // middle.
                    .offset(x: place.x - travel)
                    .opacity(place.opacity)
                }
                // Writing to the `scrollPosition` binding is what moves the
                // scroll view, so selecting a neighbour and tapping one are the
                // same operation. Tapping the centred cover resolves to itself
                // and does nothing.
                .onTapGesture {
                  withAnimation(.prayerContentSwap) { scrolledCell = cell.id }
                }
                // Nearest the centre draws on top. The spacing above is set so
                // covers never actually cross, and this is the backstop for that
                // being a calculation rather than a guarantee: the clearance is
                // derived from a model of how far perspective flares a turned
                // cover, and if that model is optimistic, this still keeps the
                // centred cover in front of its neighbours instead of behind
                // whichever one happens to come later in the stack.
                .zIndex(depth(of: cell))
                .id(cell.id)
            }
          }
          .scrollTargetLayout()
          .padding(.top, PrayerCoverMetrics.topInset)
          .padding(.bottom, PrayerCoverMetrics.bottomInset)
        }
        .safeAreaPadding(.horizontal, endInset)
        .scrollTargetBehavior(.viewAligned)
        // No `anchor:`. The inset above already leaves a content region one
        // cover wide, so aligning a cover to the *start* of that region is what
        // puts it in the middle of the screen. Asking for `.center` as well
        // centres a second time, over the full width instead of the inset one —
        // which pushed the whole carousel half a screen minus half a cover to
        // the right, and parked the active cover against the right edge.
        .scrollPosition(id: $scrolledCell)
        .scrollIndicators(.hidden)
        .onAppear { anchorToOpeningPrayer(scroller) }
        .onChange(of: scrolledCell) { _, cell in settle(on: cell) }
      }
    }
    .frame(height: PrayerCoverMetrics.height)
    // Fires on settle and on tap alike, since both arrive as a change to
    // `selectedID`. Re-centring across the loop's seam does not change it, so
    // the wrap passes without a stray tick.
    .sensoryFeedback(.selection, trigger: selectedID)
  }

  /// Stacking order for a cover: the closer to the centre, the further forward.
  ///
  /// Steps on settle rather than tracking the swipe, since the phase a cover is
  /// at isn't readable from out here. That is enough — it only decides which of
  /// two covers wins where they overlap, and by design they don't.
  private func depth(of cell: LoopCell) -> Double {
    Double(-abs(cell.id - (scrolledCell ?? openingCell)))
  }

  /// Publishes the prayer the strip landed on, then slides the strip back into
  /// the middle run if it has wandered out of it.
  ///
  /// The slide is an exact whole number of runs, so the cover under the centre
  /// is the same cover in the same place — nothing to see. It is also left
  /// unanimated on purpose: this is a change of coordinates, not a movement,
  /// and animating it would turn an invisible correction into a long slide
  /// across the whole catalog.
  private func settle(on cell: Int?) {
    guard let cell, !prayers.isEmpty else { return }

    let count = prayers.count
    let prayerIndex = cell % count

    let landedOn = prayers[prayerIndex].id
    if selectedID != landedOn {
      selectedID = landedOn
    }

    let inMiddleRun = prayerIndex + count
    if cell != inMiddleRun {
      scrolledCell = inMiddleRun
    }
  }

  /// Scrolls to the opening prayer once the strip is on screen.
  ///
  /// This has to be done explicitly. Seeding `scrolledCell` in `init` looks like
  /// it should be enough, but `scrollPosition(id:)` acts on *changes* to its
  /// binding — a value that was already there when the scroll view first laid
  /// out moves nothing. The strip stayed at its content start with the opening
  /// prayer's cover nowhere near it, and because nothing changed, `settle` never
  /// ran to correct the rest of the screen either: the title went on naming a
  /// prayer the carousel wasn't showing, and the wall only existed on one side
  /// because the covers before cell zero don't exist.
  ///
  /// One-shot. `onAppear` fires again on the way back from a pushed screen, and
  /// re-anchoring then would throw away wherever the reader had paged to.
  private func anchorToOpeningPrayer(_ scroller: ScrollViewProxy) {
    guard !hasAnchored else { return }
    hasAnchored = true

    scroller.scrollTo(openingCell, anchor: .center)

    // Repairs the binding if the first layout pass reported some other cell
    // back through it before this ran.
    if scrolledCell != openingCell {
      scrolledCell = openingCell
    }
  }
}

// MARK: - Content swap

extension Animation {
  /// The curve everything on the detail screen changes on when the carousel
  /// lands on another prayer — the scroll itself when a cover is tapped, and the
  /// content swapping underneath it.
  ///
  /// `.smooth` is a spring with the bounce taken out: it settles without the
  /// overshoot `.spring` gives, which on a whole screen of content re-flowing
  /// would read as a wobble rather than as motion.
  static var prayerContentSwap: Animation {
    if #available(iOS 17.0, macOS 14.0, *) {
      return .smooth(duration: 0.35)
    } else {
      return .easeInOut(duration: 0.3)
    }
  }
}

extension View {
  /// Swaps this view out for the next prayer's version of it, blurring through
  /// the change rather than cutting.
  ///
  /// The `.id` is what makes the swap a replacement rather than an update —
  /// without it SwiftUI reuses the view in place and there is no transition to
  /// run.
  func prayerContentTransition(id: Prayer.ID) -> some View {
    modifier(PrayerContentTransition(id: id))
  }
}

private struct PrayerContentTransition: ViewModifier {
  let id: Prayer.ID

  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      content
        .id(id)
        .transition(.blurReplace)
    } else {
      // No `blurReplace` below iOS 17, and no carousel either — this path only
      // runs if something else ever changes the selection.
      content
        .id(id)
        .transition(.opacity)
    }
  }
}

/// Where a cover stands in the gallery, given how many covers it is from the
/// one facing the reader.
///
/// Two regimes, which is the whole shape of Cover Flow. Over the first cover's
/// worth of travel a cover swings from flat to ``PrayerCoverMetrics/flankAngle``
/// and slides out by ``PrayerCoverMetrics/centreGap``. After that it is part of
/// the wall: the angle stops changing and it only steps back by
/// ``PrayerCoverMetrics/flankStep`` at a time, shrinking a little as it goes.
///
/// A plain struct rather than methods on the view: `visualEffect`'s closure is
/// nonisolated, while anything declared on a `View` picks up `@MainActor` from
/// the conformance — so as methods these would be actor-isolation violations on
/// a path that runs for every cover, every frame of a drag.
private struct CoverFlowPlacement {
  /// Position across the screen, in points from the middle.
  let x: CGFloat
  let scale: CGFloat
  /// Rotation about the vertical axis. Signed, so each wall faces inwards.
  let turn: Double
  let opacity: Double

  init(coversFromCentre distance: Double) {
    let side: Double = distance < 0 ? -1 : 1
    let magnitude = abs(distance)

    // Splits the travel into "still leaving the middle" and "already in the
    // wall", which are the two regimes above.
    let leaving = min(magnitude, 1)
    let stacked = max(magnitude - 1, 0)

    x = CGFloat(side) * (
      PrayerCoverMetrics.centreGap * CGFloat(leaving)
        + PrayerCoverMetrics.flankStep * CGFloat(stacked)
    )

    // Negative, so each wall opens *away* from the middle. A flanking sleeve
    // swings its inner edge back behind the centred cover and brings its outer
    // edge forward, which is what makes the two walls fan outwards and the
    // front cover sit proud of them. The opposite sign turns the inner edges
    // towards the reader instead, and the gallery reads as closing in on the
    // middle rather than opening out of it.
    turn = -PrayerCoverMetrics.flankAngle * side * leaving

    let shrunk = 1 - (1 - Double(PrayerCoverMetrics.flankScale)) * leaving
    scale = CGFloat(shrunk * pow(PrayerCoverMetrics.depthFalloff, stacked))

    let paled = 1 - (1 - PrayerCoverMetrics.flankOpacity) * leaving
    opacity = magnitude >= PrayerCoverMetrics.hiddenCovers
      ? 0
      : paled * pow(PrayerCoverMetrics.opacityFalloff, stacked)
  }
}
