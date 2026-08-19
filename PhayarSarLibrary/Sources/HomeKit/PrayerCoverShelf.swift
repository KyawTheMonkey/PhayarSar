import DesignKit
import PrayersKit
import SwiftUI

// MARK: - Metrics

/// Layout constants for `PrayerCoverShelf`.
///
/// The carousel budgets its own height from these — see
/// ``PrayerCoverMetrics/bottomInset`` — so the shelf can never be taller than
/// the room the covers leave it.
enum PrayerShelfMetrics {
  /// Depth of the top surface: how much shelf shows *in front of* the covers
  /// standing on it.
  ///
  /// This is also how long a cover's reflection is, since the reflection lies on
  /// this surface and a reflection running off the front lip would read as the
  /// cover hanging over the edge.
  static let topDepth: CGFloat = 26

  /// The front lip, seen face on. Shallow: the shelf is being looked at from
  /// slightly above, so most of what shows is the top rather than the edge.
  static let faceHeight: CGFloat = 14

  /// Room under the slab for the shadow it casts.
  static let shadowHeight: CGFloat = 22

  /// How far the slab stops short of the carousel's edges. Enough for both ends
  /// to be on screen — a shelf that ran off both sides would read as a floor.
  static let sideInset: CGFloat = 6

  /// How much narrower the back edge of the top surface is than the front, at
  /// each end.
  ///
  /// The whole of the perspective, and the reason the shelf reads as a solid
  /// seen from above rather than as two stacked bars. Set against the covers:
  /// much more and the taper is steeper than the near-frontal angle the covers
  /// are drawn at, and the two stop agreeing about where the viewer is standing.
  static let backNarrowing: CGFloat = 16

  /// Rounding on the two front corners of the lip.
  static let cornerRadius: CGFloat = 7

  /// The dark patch a cover sits in, where it meets the shelf. Tight and wide:
  /// a cover meets the surface along its bottom edge, so the shadow it drops is
  /// a line thickened by the light being broad, not a pool.
  static let contactWidth: CGFloat = 160
  static let contactHeight: CGFloat = 13

  static var height: CGFloat { topDepth + faceHeight + shadowHeight }
}

// MARK: - Shelf

/// The slab the cover gallery stands on.
///
/// Drawn behind the carousel and never scrolls with it: the covers move past a
/// shelf that stays put, which is what gives the strip somewhere to be rather
/// than leaving it floating in the page.
///
/// Three bands, back to front — the top surface the covers stand on and reflect
/// in, the lip below it, and the shadow the slab casts on the page. All of it is
/// built from ``AppColor/surface`` plus black and white at low opacity rather
/// than from fixed greys, so the same shelf works on the light page and the dark
/// one: what changes between them is only how hard the shading has to be pushed
/// to read.
struct PrayerCoverShelf: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      Surface()
      Lip()
      CastShadow()
    }
    .frame(height: PrayerShelfMetrics.height)
    .padding(.horizontal, PrayerShelfMetrics.sideInset)
    // Decorative, and it lies under the covers — without this it would swallow
    // the taps that page the carousel.
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  // MARK: Bands

  /// The top of the slab: a trapezoid, dark at the back where the covers meet it
  /// and clean at the front where the light falls.
  @ViewBuilder
  private func Surface() -> some View {
    let shape = ShelfSurfaceShape()

    shape
      .fill(shading.slab)
      .frame(height: PrayerShelfMetrics.topDepth)
      .overlay {
        // The covers block the light: the surface is darkest where it disappears
        // behind them and recovers over the depth of the shelf.
        LinearGradient(
          colors: [.black.opacity(shading.occlusion), .clear],
          startPoint: .top,
          endPoint: .bottom
        )
        .clipShape(shape)
      }
      .overlay {
        Contact()
      }
      .overlay {
        shape
          .stroke(AppColor.border, lineWidth: 0.5)
      }
  }

  /// The patch of shadow directly under the centred cover.
  ///
  /// Only the centred one gets it. The flanking covers are turned nearly edge-on
  /// and touch the shelf along a line rather than a face, so the band of
  /// occlusion above is all the contact they have to show — and a row of five
  /// identical smudges would say the gallery is a wall of equals, which is the
  /// one thing Cover Flow is not.
  @ViewBuilder
  private func Contact() -> some View {
    Ellipse()
      .fill(.black.opacity(shading.contact))
      .frame(
        width: PrayerShelfMetrics.contactWidth,
        height: PrayerShelfMetrics.contactHeight
      )
      // Centred on the back edge, so the near half lies on the shelf and the far
      // half is behind the cover casting it.
      .offset(y: -PrayerShelfMetrics.contactHeight / 2)
      .blur(radius: 6)
      // Grown back to the surface's own box before the clip. A `clipShape` is
      // drawn in the frame of the view it is applied to, and up to here that
      // frame is the ellipse's 160×13 — so clipping straight to the surface
      // shape drew the shelf's taper *inside the shadow*, at a sixth of the
      // width it was designed for. What reached the screen was a hard-edged
      // trapezoid plate under the cover, which is what a shadow is least
      // supposed to look like.
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      // Blurred first, then clipped: the blur has to be allowed to run past the
      // front lip before the lip cuts it, or the shadow would fade out early and
      // stop short of an edge it is supposed to be cut off by.
      .clipShape(ShelfSurfaceShape())
  }

  /// The front edge of the slab, seen face on.
  @ViewBuilder
  private func Lip() -> some View {
    let shape = UnevenRoundedRectangle(
      bottomLeadingRadius: PrayerShelfMetrics.cornerRadius,
      bottomTrailingRadius: PrayerShelfMetrics.cornerRadius,
      style: .continuous
    )

    shape
      .fill(shading.slab)
      .frame(height: PrayerShelfMetrics.faceHeight)
      .overlay {
        // Falls off downwards, away from the light.
        LinearGradient(
          colors: [.clear, .black.opacity(shading.lipFalloff)],
          startPoint: .top,
          endPoint: .bottom
        )
        .clipShape(shape)
      }
      .overlay(alignment: .top) {
        // The break between the top and the front: the brightest line on the
        // shelf, and the thing that makes the two bands read as one solid with
        // an edge rather than as two flat rectangles.
        Rectangle()
          .fill(.white.opacity(shading.lipHighlight))
          .frame(height: 0.75)
      }
  }

  /// What the slab throws on the page below it.
  @ViewBuilder
  private func CastShadow() -> some View {
    Ellipse()
      .fill(.black.opacity(shading.cast))
      .frame(height: PrayerShelfMetrics.shadowHeight)
      // Narrower than the slab, so the shadow gathers under the middle instead
      // of squaring off at the ends and drawing a second shelf under the first.
      .padding(.horizontal, PrayerShelfMetrics.sideInset * 2)
      .blur(radius: 12)
      // Lifted into the slab: a shelf this shallow sits close to what it is
      // mounted on, and a shadow hanging clear below it would read as a plank
      // floating in the middle of the screen.
      .offset(y: -PrayerShelfMetrics.shadowHeight / 3)
  }

  // MARK: Shading

  private var shading: ShelfShading {
    ShelfShading(colorScheme: colorScheme)
  }
}

/// How hard each piece of the shading has to be pushed for the appearance it is
/// being drawn in.
///
/// The dark page needs more of everything: `AppColor.surface` there is white at
/// 7%, so the slab starts out much closer to what is behind it, and shading that
/// models a solid on the light page disappears into it entirely.
private struct ShelfShading {
  /// What the slab is made of.
  ///
  /// `AppColor.surface` on the light page, where it is the same white every card
  /// on this screen is. Not on the dark one: `surface` there is white at 7%, and
  /// a slab that close to the page behind it has no shading left to give — the
  /// occlusion at its back edge takes it *darker* than the page and the shelf
  /// reads as a hole rather than as a solid.
  let slab: Color

  let occlusion: Double
  let contact: Double
  let lipFalloff: Double
  let lipHighlight: Double
  let cast: Double

  init(colorScheme: ColorScheme) {
    let isDark = colorScheme == .dark

    slab = isDark ? .white.opacity(0.20) : AppColor.surface
    // Light: barely there. The surface has to stay *lighter* than a cover's
    // reflection lying on it, or the reflection — which is a translucent copy of
    // a mid-grey cover — comes out brighter than the shelf it is supposed to be
    // sunk into, and the artwork reads as glowing rather than as reflected.
    // What plants a cover is the contact shadow below, not this.
    occlusion = isDark ? 0.14 : 0.08
    contact = isDark ? 0.50 : 0.30
    lipFalloff = isDark ? 0.22 : 0.12
    // A specular edge rather than a lit surface, so it stays white in the dark —
    // just far less of it, or the line reads as a strip light.
    lipHighlight = isDark ? 0.22 : 0.50
    cast = isDark ? 0.40 : 0.18
  }
}

// MARK: - Shape

/// The top of the shelf: a trapezoid, narrower at the back than the front.
///
/// A drawn taper rather than a `rotation3DEffect` on a rectangle. The rotation
/// would be the honest way to lay a plane down, but it also foreshortens
/// everything painted on it and demands a camera distance that agrees with the
/// carousel's own — and the carousel's perspective is per-cover, not shared. Two
/// unrelated cameras a few points apart look wrong in a way a flat taper does
/// not.
private struct ShelfSurfaceShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let narrowing = PrayerShelfMetrics.backNarrowing

    path.move(to: CGPoint(x: rect.minX + narrowing, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - narrowing, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()

    return path
  }
}

// MARK: - Previews

// The shelf is only ever seen with the gallery standing on it, so the preview is
// the whole hero rather than the slab on its own — what matters is where the
// covers meet it and how their reflections lie on the surface.
#Preview("Shelf") {
  PrayerCoverShelfPreview()
}

private struct PrayerCoverShelfPreview: View {
  private let prayers = PrayerCatalog.shared.orderedPrayers()

  @State private var selectedID: Prayer.ID

  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    let prayers = PrayerCatalog.shared.orderedPrayers()
    _selectedID = State(initialValue: prayers.first?.id ?? "")
    Typography.registerFonts()
  }

  var body: some View {
    PrayerCoverCarousel(
      prayers: prayers,
      openingID: selectedID,
      selectedID: $selectedID
    )
    .frame(maxHeight: .infinity)
    .background(AppColor.background.ignoresSafeArea())
  }
}
