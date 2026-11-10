import DesignKit
import SwiftUI
#if os(iOS) || os(macOS)
import Metal
import SpriteKit
#endif

enum BeadsMaterialArtworkMetrics {
  static let renderRadius: CGFloat = 24
  static let fallbackHighlight = UnitPoint(x: 0.28, y: 0.22)
}

/// The session shades every moving bead in SpriteKit. In the creator each
/// finish only needs a few stills, cached by pattern so that count springs and
/// swatches can reuse them without keeping a second render loop alive.
@MainActor
enum BeadsMaterialArtwork {
  #if os(iOS) || os(macOS)
  private static let renderer: SKView? = {
    guard MTLCreateSystemDefaultDevice() != nil else { return nil }
    let side = BeadsSpriteMetrics.quadSide
    let view = SKView(frame: CGRect(x: 0, y: 0, width: side, height: side))
    view.allowsTransparency = true
    view.isPaused = true
    return view
  }()
  private static let shader = BeadsSpriteAssets.beadShader()
  private static var cache: [BeadsMaterial: [Int: CGImage]] = [:]
  #endif

  static func image(for material: BeadsMaterial, pattern: Int = 0) -> CGImage? {
    #if os(iOS) || os(macOS)
    if let cached = cache[material]?[pattern] { return cached }
    guard let renderer else { return nil }
    shader.apply(material)
    let bead = shader.makeSprite(
      radius: BeadsMaterialArtworkMetrics.renderRadius, seed: Float(pattern + 1), visible: true
    )
    guard let image = renderer.texture(from: bead)?.cgImage() else { return nil }
    cache[material, default: [:]][pattern] = image
    return image
    #else
    return nil
    #endif
  }
}

struct BeadsMaterialBead: View {
  let material: BeadsMaterial
  let diameter: CGFloat
  let image: CGImage?

  var body: some View {
    Group {
      #if os(iOS) || os(macOS)
      if let image {
        // The artwork includes room for the shadow. Reserve only the bead's
        // body in layout so the cached sprite does not open gaps in the strand.
        let side = diameter * BeadsSpriteMetrics.quadSide / (2 * BeadsMaterialArtworkMetrics.renderRadius)
        Image(decorative: image, scale: 1)
          .resizable()
          .frame(width: side, height: side)
      } else {
        fallback
      }
      #else
      fallback
      #endif
    }
    .frame(width: diameter, height: diameter)
  }

  private var fallback: some View {
    let palette = material.palette
    return Circle().fill(RadialGradient(
      colors: [AppColor.Beads.reflection, palette.pale, palette.deep, AppColor.Beads.shadow],
      center: BeadsMaterialArtworkMetrics.fallbackHighlight,
      startRadius: 0, endRadius: diameter
    ))
  }
}
