import DesignKit
import PrayersKit
import SwiftUI

// MARK: - Metrics

enum PrayerCoverMetrics {
  /// Square, and roughly half the width of a phone, so the hero reads as
  /// artwork rather than as an oversized list thumbnail.
  static let size: CGFloat = 176
  static let cornerRadius: CGFloat = 28

  /// How far around the sphere one cover sits from the next.
  ///
  /// This, not any scale or offset, is what sets the whole look. Larger turns
  /// the sphere into a barrel with few covers on it; smaller flattens it back
  /// towards a plain row. At 36° there are ten covers around the full
  /// circumference, of which the front five are facing the reader.
  static let degreesPerCover: Double = 36

  /// Radius of the sphere, in points — how far behind the screen its centre sits.
  ///
  /// Derived rather than chosen. For the covers to sit against each other on the
  /// surface, the chord spanning ``degreesPerCover`` has to be one cover wide,
  /// which pins the radius to `size / 2·sin(halfAngle)`. Picking a radius freely
  /// would leave them either overlapping on the surface or floating apart on it.
  static var radius: CGFloat {
    size / (2 * CGFloat(sin(Angle(degrees: degreesPerCover / 2).radians)))
  }

  /// How far the strip scrolls to bring the next cover to the front.
  ///
  /// The chord again, so that a cover's position in the layout and its position
  /// on the sphere are the same point. They needn't agree — the surface is drawn
  /// by transforms that layout knows nothing about — but where they don't, taps
  /// land somewhere other than where the cover appears.
  static var pitch: CGFloat {
    radius * CGFloat(sin(Angle(degrees: degreesPerCover).radians))
  }

  /// Layout gap, backed out of ``pitch`` so the strip scrolls one chord per cover.
  static var spacing: CGFloat { pitch - size }

  /// How near the camera sits. Higher foreshortens harder; at 1 the near edge of
  /// a turned cover flares enough to read as a fisheye.
  static let perspective: CGFloat = 0.9

  /// Turn past which a cover starts fading out, and the turn at which it is gone.
  ///
  /// A cover reaching 90° is edge-on, and past it has swung round to the back of
  /// the sphere where it would be seen inside-out. Fading it away over the last
  /// stretch means it thins to nothing as it turns away, rather than vanishing
  /// mid-surface.
  static let fadeStartAngle: Double = 55
  static let hiddenAngle: Double = 90

  /// Room above and below the covers inside the scroll view.
  ///
  /// Carries the drop shadow, and the extra height perspective gives the near
  /// edge of a turned cover. A `ScrollView` clips to its bounds, so whatever
  /// isn't budgeted here gets sliced off.
  static let verticalInset: CGFloat = 36

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
  static var height: CGFloat { size + verticalInset * 2 }
}

// MARK: - Cover

/// One prayer's cover art.
///
/// A plain grey rectangle until real artwork exists. The shadow is what makes
/// it sit on the background as an object rather than as a gap in the layout.
struct PrayerCover: View {
  var body: some View {
    RoundedRectangle(cornerRadius: PrayerCoverMetrics.cornerRadius, style: .continuous)
      .fill(AppColor.grey300)
      .frame(width: PrayerCoverMetrics.size, height: PrayerCoverMetrics.size)
      .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
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
      // Half a container minus half a cover, so the first and last prayers can
      // reach the centre instead of stopping against the edge.
      let endInset = max(0, (proxy.size.width - PrayerCoverMetrics.size) / 2)

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
                // visible region — it says "most of the way out", not "173pt
                // from the middle" — and an angle around a sphere can't be
                // built from that. The proxy gives the actual distance.
                .visualEffect { content, proxy in
                  let travel = distanceFromCentre(proxy)
                  let turn = PrayerCoverMetrics.degreesPerCover
                    * Double(travel / PrayerCoverMetrics.pitch)

                  return content
                    // Every cover is stacked onto the sphere's front point...
                    .offset(x: -travel)
                    // ...and then swung back out to where it belongs on the
                    // surface. `anchorZ` puts the pivot a radius behind the
                    // screen, so this one rotation carries the whole thing: the
                    // cover arcs sideways along the surface, recedes as it goes,
                    // shrinks under perspective because it is genuinely further
                    // away, and turns to stay flat against the sphere — none of
                    // it faked with separate scale or offset ramps.
                    .rotation3DEffect(
                      .degrees(turn),
                      axis: (x: 0, y: 1, z: 0),
                      anchor: .center,
                      anchorZ: -PrayerCoverMetrics.radius,
                      perspective: PrayerCoverMetrics.perspective
                    )
                    .opacity(facingOpacity(atDegrees: turn))
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
          .padding(.vertical, PrayerCoverMetrics.verticalInset)
        }
        .safeAreaPadding(.horizontal, endInset)
        .scrollTargetBehavior(.viewAligned)
        // `.center`, because the aligned item is the one in the middle here,
        // not the one at the leading edge.
        .scrollPosition(id: $scrolledCell, anchor: .center)
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

  /// Puts the opening prayer in the centre.
  ///
  /// Belt and braces over `scrollPosition(id:)`'s own initial positioning: that
  /// reports where the scroll view *is*, so any failure to honour the opening
  /// cell doesn't just leave the carousel in the wrong place, it feeds the wrong
  /// prayer back into the screen. Scrolling explicitly is the one instruction
  /// that can't be misread, and `openingCell` survives any write-back because it
  /// is a stored `let` rather than the binding.
  private func anchorToOpeningPrayer(_ scroller: ScrollViewProxy) {
    guard !hasAnchored else { return }
    hasAnchored = true

    scroller.scrollTo(openingCell, anchor: .center)

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

/// Where a cover sits on the curved surface the carousel is imagined to wrap
/// around, worked out from how far it is from the centre.
///
/// `phase.value` runs -1 (a page before centre) → 0 (centred) → 1 (a page
/// after). It is clamped either side, so a cover three pages out is posed like
/// one a single page out rather than turning ever further until it is edge-on.
///
/// A plain struct rather than methods on the view: `scrollTransition`'s closure
/// is nonisolated, while anything declared on a `View` picks up `@MainActor`
/// from the conformance — so as methods these would be actor-isolation
/// violations on a path that runs for every cover, every frame of a swipe.
private struct CoverPose {
  let scale: CGFloat
  let opacity: CGFloat
  /// Rotation about the vertical axis. Signed, so a cover on the right turns
  /// its left edge towards the reader and one on the left turns its right —
  /// both facing in towards the centre, the way they would on a barrel.
  let yaw: Double
  /// Lean within the screen plane, matching the slope of the arc at that point.
  let roll: Double
  /// Drop below the centre line.
  let dip: CGFloat

  init(distanceFromCentre phase: Double) {
    let signed = max(-1, min(1, phase))
    let distance = abs(signed)

    scale = 1 - (1 - PrayerCoverMetrics.sideScale) * distance
    opacity = 1 - (1 - PrayerCoverMetrics.sideOpacity) * distance
    yaw = PrayerCoverMetrics.maxYaw * signed
    roll = PrayerCoverMetrics.maxRoll * signed

    // Squared rather than linear. Height on a circle falls off as 1 - cos, so
    // covers leave the centre almost level and drop away faster the further out
    // they get. A linear dip reads as a ramp; this reads as a curve.
    dip = PrayerCoverMetrics.arcDepth * distance * distance
  }
}
