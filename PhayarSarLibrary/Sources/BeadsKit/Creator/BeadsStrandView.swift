import DesignKit
import Inject
import SwiftUI

enum BeadsStrandMetrics {
  static let height: CGFloat = 240
  static let drawingWidth: CGFloat = 340
  static let centerX = drawingWidth / 2
  static let centerY = height / 2
  static let maximumVisibleBeads = 108
  static let samples = 540
  static let maximumDiameter: CGFloat = 43
  static let minimumDiameter: CGFloat = 12
  static let beadsPerCoil = 36
  static let minimumRadius: CGFloat = 22
  static let maximumRadius: CGFloat = 100
  static let radiusPerBead: CGFloat = 8.8
  static let coilHorizontalSpread: CGFloat = 16
  static let coilVerticalSpread: CGFloat = 28
  static let threadWidth: CGFloat = 1.5
  static let rippleSlide: CGFloat = 0.28
  static let animationResponse: Double = 0.48
  static let animationDamping: Double = 0.87
}

/// Each index keeps its identity as the length changes, so its position and
/// size interpolate instead of replacing the entire bracelet. A preset change
/// uses one animation for the whole strand, never a bead-by-bead delay.
struct BeadsStrandView: View {
  @ObserveInjection private var injectionObserver
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var previewMaterial: BeadsMaterial
  @State private var morph: BeadsMaterialMorph?
  let count: Int
  let material: BeadsMaterial

  init(count: Int, material: BeadsMaterial) {
    self.count = count
    self.material = material
    _previewMaterial = State(initialValue: material)
  }

  private var visibleCount: Int {
    min(max(count, 1), BeadsStrandMetrics.maximumVisibleBeads)
  }

  var body: some View {
    let images = (morph?.materials ?? [previewMaterial]).reduce(into: [BeadsMaterial: [CGImage?]]()) { images, finish in
      images[finish] = (0..<finish.patterns).map { BeadsMaterialArtwork.image(for: finish, pattern: $0) }
    }
    GeometryReader { proxy in
      let scale = min(proxy.size.width / BeadsStrandMetrics.drawingWidth, 1)
      let geometry = BeadsStrandGeometry(count: visibleCount)

      BeadsStrandLoop(
        frame: BeadsStrandFrame(geometry: geometry), count: count,
        material: previewMaterial, morph: morph, images: images
      )
      .scaleEffect(scale)
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .frame(height: BeadsStrandMetrics.height)
    .animation(
      reduceMotion ? nil : .spring(
        response: BeadsStrandMetrics.animationResponse, dampingFraction: BeadsStrandMetrics.animationDamping
      ),
      value: count
    )
    .onChange(of: material) { next in
      morph = BeadsMaterialMorph(
        from: previewMaterial, to: next, interrupting: morph,
        visibleCount: visibleCount, reduceMotion: reduceMotion
      )
      previewMaterial = next
    }
    .onChange(of: reduceMotion) { enabled in
      if enabled { morph = nil }
    }
    .task(id: morph?.start) {
      guard let morph else { return }
      do {
        try await ContinuousClock().sleep(until: morph.end)
      } catch {
        return
      }
      if self.morph?.start == morph.start { self.morph = nil }
    }
    // The adjustable count beneath the illustration is the accessible control;
    // announcing every decorative sphere would make it unusable.
    .accessibilityHidden(true)
    .allowsHitTesting(false)
    .enableInjection()
  }
}

// MARK: - Strand geometry

struct BeadsStrandGeometry {
  struct Bead {
    let position: CGPoint
    let diameter: CGFloat

    var bounds: CGRect {
      CGRect(x: position.x - diameter / 2, y: position.y - diameter / 2, width: diameter, height: diameter)
    }
  }

  let radius: CGFloat
  let coils: CGFloat
  let perspective: CGFloat
  let beads: [Bead]
  let head: Bead

  var bounds: CGRect {
    let fittings = BeadsHeadGeometry(diameter: head.diameter).bounds.offsetBy(
      dx: head.position.x - BeadsHeadMetrics.anchor.x,
      dy: head.position.y - BeadsHeadMetrics.anchor.y
    )
    return beads.reduce(fittings) { $0.union($1.bounds) }
  }

  init(count: Int) {
    let count = min(max(count, 1), BeadsStrandMetrics.maximumVisibleBeads)
    let coils = CGFloat(max(1, Int(ceil(Double(count) / Double(BeadsStrandMetrics.beadsPerCoil)))))
    let radius: CGFloat = count == 1 ? 0 : min(
      BeadsStrandMetrics.maximumRadius,
      max(BeadsStrandMetrics.minimumRadius, CGFloat(count) / coils * BeadsStrandMetrics.radiusPerBead)
    )
    self.coils = coils
    self.radius = radius
    let perspective = min(0.85, max(0.52, 1 - CGFloat(count) * 0.055))
    self.perspective = perspective

    if count == 1 {
      let diameter = BeadsStrandMetrics.maximumDiameter
      let beadX = BeadsStrandMetrics.centerX + diameter * BeadsHeadMetrics.diameterScale / 2
      beads = [Bead(
        position: CGPoint(x: beadX, y: BeadsStrandMetrics.centerY),
        diameter: diameter
      )]
      head = Bead(
        position: CGPoint(x: beadX - diameter * (1 + BeadsHeadMetrics.diameterScale) / 2, y: BeadsStrandMetrics.centerY),
        diameter: diameter * BeadsHeadMetrics.diameterScale
      )
      return
    }

    // Uniform angles bunch up the beads at an oval's ends. Sampling its arc
    // length keeps the physical gaps even, including where the coils cross.
    let samples = (0..<BeadsStrandMetrics.samples).map { sample in
      Self.point(fraction: CGFloat(sample) / CGFloat(BeadsStrandMetrics.samples), radius: radius, coils: coils, perspective: perspective)
    }

    // The head belongs to the leading join, including on a coiled strand.
    // Start the arc there and leave room for it *in addition* to the selected
    // counting beads; replacing the first sphere would silently display one
    // fewer counting bead than the value the user chose.
    let joinIndex = samples.indices.min { samples[$0].x < samples[$1].x } ?? 0
    var points = Array(samples[joinIndex...]) + Array(samples[..<joinIndex])
    points.append(points[0])
    var distances: [CGFloat] = [0]
    for index in 1..<points.count {
      distances.append(distances[index - 1] + hypot(points[index].x - points[index - 1].x, points[index].y - points[index - 1].y))
    }
    let length = distances.last ?? 0
    let diameter = min(
      BeadsStrandMetrics.maximumDiameter,
      max(BeadsStrandMetrics.minimumDiameter, length / (CGFloat(count) + BeadsHeadMetrics.diameterScale) * 0.96)
    )
    let headDiameter = diameter * BeadsHeadMetrics.diameterScale
    head = Bead(position: points[0], diameter: headDiameter)
    let headClearance = headDiameter * BeadsHeadMetrics.joinClearance
    var cursor = 1
    beads = (0..<count).map { index in
      let target = headClearance / 2 + (CGFloat(index) + 0.5) / CGFloat(count) * (length - headClearance)
      while cursor < distances.count - 1, distances[cursor] < target { cursor += 1 }
      let previous = cursor - 1
      let fraction = (target - distances[previous]) / max(distances[cursor] - distances[previous], 0.001)
      let position = CGPoint(
        x: points[previous].x + (points[cursor].x - points[previous].x) * fraction,
        y: points[previous].y + (points[cursor].y - points[previous].y) * fraction
      )
      let depth = (position.y - BeadsStrandMetrics.centerY) / BeadsStrandMetrics.height
      return Bead(position: position, diameter: diameter * (1 + depth * 0.32))
    }
  }

  static func point(fraction: CGFloat, radius: CGFloat, coils: CGFloat, perspective: CGFloat) -> CGPoint {
    let phase = fraction * .pi * 2
    let angle = phase * coils - .pi / 2
    let spread = min(1, max(0, coils - 1))
    let localRadius = radius + cos(phase) * BeadsStrandMetrics.coilHorizontalSpread * spread
    return CGPoint(
      x: BeadsStrandMetrics.centerX + cos(angle) * localRadius,
      y: BeadsStrandMetrics.centerY + sin(angle) * localRadius * perspective + sin(phase) * BeadsStrandMetrics.coilVerticalSpread * spread
    )
  }
}

/// A fixed set of slots lets one spring interpolate the entire loop, including
/// beads entering or leaving it. Inactive slots collapse into the head with
/// zero size and opacity, so the thread never jumps to a newly inserted bead's
/// destination while its neighbours are still travelling there.
private struct BeadsStrandFrame: VectorArithmetic {
  private static let stride = 4
  private static let strandValueCount = 5
  private static let valueCount = strandValueCount + BeadsStrandMetrics.maximumVisibleBeads * stride
  var values: [Double]

  init(geometry: BeadsStrandGeometry) {
    let bounds = geometry.bounds
    values = [
      Double(geometry.head.position.x), Double(geometry.head.position.y),
      Double(geometry.head.diameter), Double(bounds.midX), Double(bounds.midY)
    ]
    for index in 0..<BeadsStrandMetrics.maximumVisibleBeads {
      let bead = geometry.beads.indices.contains(index) ? geometry.beads[index] : nil
      values.append(contentsOf: [
        Double(bead?.position.x ?? geometry.head.position.x),
        Double(bead?.position.y ?? geometry.head.position.y),
        Double(bead?.diameter ?? 0),
        bead == nil ? 0 : 1
      ])
    }
  }

  private init(values: [Double]) { self.values = values }

  static var zero: Self { Self(values: Array(repeating: 0, count: valueCount)) }

  static func + (lhs: Self, rhs: Self) -> Self {
    Self(values: zip(lhs.values, rhs.values).map { $0 + $1 })
  }

  static func - (lhs: Self, rhs: Self) -> Self {
    Self(values: zip(lhs.values, rhs.values).map { $0 - $1 })
  }

  mutating func scale(by rhs: Double) {
    values = values.map { $0 * rhs }
  }

  var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }

  var head: CGPoint { CGPoint(x: values[0], y: values[1]) }
  var headDiameter: CGFloat { max(0, values[2]) }
  var center: CGPoint { CGPoint(x: values[3], y: values[4]) }

  func bead(at index: Int) -> BeadsStrandGeometry.Bead {
    let offset = Self.strandValueCount + index * Self.stride
    return .init(
      position: CGPoint(x: values[offset], y: values[offset + 1]),
      diameter: max(0, values[offset + 2])
    )
  }

  func opacity(at index: Int) -> Double {
    min(1, max(0, values[Self.strandValueCount + index * Self.stride + 3]))
  }
}

/// Thread segments run through sphere centres using the same interpolated
/// frame as the spheres. The short joins are covered by the beads themselves;
/// interpolating coil parameters separately would sweep a very different path
/// from the beads, exposing large empty loops midway through a preset change.
private struct BeadsStrandLoop: View, Animatable {
  nonisolated var frame: BeadsStrandFrame
  let count: Int
  let material: BeadsMaterial
  let morph: BeadsMaterialMorph?
  let images: [BeadsMaterial: [CGImage?]]

  nonisolated var animatableData: BeadsStrandFrame {
    get { frame }
    set { frame = newValue }
  }

  var body: some View {
    TimelineView(.animation(paused: morph == nil)) { _ in
      let now = ContinuousClock.now
      let solid = BeadsMaterialBlend(material)
      let head = morph?.sample(at: 0, time: now)
      let headBlend = head?.blend ?? solid
      let cord = Path { path in
        path.move(to: frame.head)
        for index in 0..<BeadsStrandMetrics.maximumVisibleBeads {
          path.addLine(to: frame.bead(at: index).position)
        }
        path.closeSubpath()
      }
      ZStack {
        headBlend.render { finish in
          cord.stroke(finish.palette.cord, lineWidth: BeadsStrandMetrics.threadWidth)
        }

        ForEach(0..<BeadsStrandMetrics.maximumVisibleBeads, id: \.self) { index in
          let bead = frame.bead(at: index)
          let opacity = frame.opacity(at: index)
          if opacity > 0 {
            let sample = morph?.sample(at: index + 1, time: now)
            let blend = sample?.blend ?? solid
            let previous = index == 0 ? frame.head : frame.bead(at: index - 1).position
            // Slide along the incoming cord segment, so the bead can move
            // independently while the thread continues to hold its shape.
            let slide = BeadsStrandMetrics.rippleSlide * (sample?.pull ?? 0)
            let position = CGPoint(
              x: bead.position.x + (previous.x - bead.position.x) * slide,
              y: bead.position.y + (previous.y - bead.position.y) * slide
            )
            blend.render { finish in
              BeadsMaterialBead(
                material: finish, diameter: bead.diameter,
                image: images[finish]?[index % finish.patterns] ?? nil
              )
            }
            .opacity(opacity)
            .position(position)
            .zIndex(bead.position.y)
          }
        }

        BeadsHeadView(
          diameter: frame.headDiameter, count: count, blend: headBlend,
          images: images, rippleSway: (head?.pull ?? 0) * BeadsHeadMetrics.kick
        )
          .position(
            x: frame.head.x + BeadsHeadMetrics.width / 2 - BeadsHeadMetrics.anchor.x,
            y: frame.head.y + BeadsHeadMetrics.height / 2 - BeadsHeadMetrics.anchor.y
          )
          .zIndex(.infinity)
      }
    }
    .frame(width: BeadsStrandMetrics.drawingWidth, height: BeadsStrandMetrics.height)
    // Interpolate the centre with the slots so the whole assembly stays
    // centred through count changes and a tassel flick never shifts the stage.
    .offset(
      x: BeadsStrandMetrics.centerX - frame.center.x,
      y: BeadsStrandMetrics.centerY - frame.center.y
    )
    // Positions, material sizes and opacity already represent this animation
    // frame. A second child animation would put them out of step again.
    .transaction {
      $0.animation = nil
      $0.disablesAnimations = true
    }
  }
}
