import DesignKit
import Inject
import SwiftUI

enum BeadsStrandMetrics {
  static let height: CGFloat = 240
  static let drawingWidth: CGFloat = 340
  /// Reserve room for the cord at the leading edge while keeping the whole
  /// object, rather than just the counting loop, centred in its viewport.
  static let centerX = drawingWidth / 2 + BeadsHeadMetrics.leadingReach / 2
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
  static let animationResponse: Double = 0.48
  static let animationDamping: Double = 0.87
}

/// Each index keeps its identity as the length changes, so its position and
/// size interpolate instead of replacing the entire bracelet. A preset change
/// uses one animation for the whole strand, never a bead-by-bead delay.
struct BeadsStrandView: View {
  @ObserveInjection private var injectionObserver
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let count: Int
  let material: BeadsMaterial

  private var visibleCount: Int {
    min(max(count, 1), BeadsStrandMetrics.maximumVisibleBeads)
  }

  var body: some View {
    let images = (0..<material.patterns).map { BeadsMaterialArtwork.image(for: material, pattern: $0) }
    GeometryReader { proxy in
      let scale = min(proxy.size.width / BeadsStrandMetrics.drawingWidth, 1)
      let geometry = BeadsStrandGeometry(count: visibleCount)

      BeadsStrandLoop(frame: BeadsStrandFrame(geometry: geometry), count: count, material: material, images: images)
        .scaleEffect(scale)
        .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .frame(height: BeadsStrandMetrics.height)
    .animation(
      reduceMotion ? nil : .spring(
        response: BeadsStrandMetrics.animationResponse,
        dampingFraction: BeadsStrandMetrics.animationDamping
      ),
      value: count
    )
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
  }

  let radius: CGFloat
  let coils: CGFloat
  let perspective: CGFloat
  let beads: [Bead]
  let head: Bead

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
  private static let headValueCount = 3
  private static let valueCount = headValueCount + BeadsStrandMetrics.maximumVisibleBeads * stride
  var values: [Double]

  init(geometry: BeadsStrandGeometry) {
    values = [
      Double(geometry.head.position.x), Double(geometry.head.position.y),
      Double(geometry.head.diameter)
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

  func bead(at index: Int) -> BeadsStrandGeometry.Bead {
    let offset = Self.headValueCount + index * Self.stride
    return .init(
      position: CGPoint(x: values[offset], y: values[offset + 1]),
      diameter: max(0, values[offset + 2])
    )
  }

  func opacity(at index: Int) -> Double {
    min(1, max(0, values[Self.headValueCount + index * Self.stride + 3]))
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
  let images: [CGImage?]

  nonisolated var animatableData: BeadsStrandFrame {
    get { frame }
    set { frame = newValue }
  }

  var body: some View {
    ZStack {
      Path { path in
        path.move(to: frame.head)
        for index in 0..<BeadsStrandMetrics.maximumVisibleBeads {
          path.addLine(to: frame.bead(at: index).position)
        }
        path.closeSubpath()
      }
      .stroke(material.palette.cord, lineWidth: BeadsStrandMetrics.threadWidth)

      ForEach(0..<BeadsStrandMetrics.maximumVisibleBeads, id: \.self) { index in
        let bead = frame.bead(at: index)
        BeadsMaterialBead(material: material, diameter: bead.diameter, image: images[index % images.count])
          .opacity(frame.opacity(at: index))
          .position(bead.position)
          .zIndex(bead.position.y)
      }

      BeadsHeadView(diameter: frame.headDiameter, count: count, material: material, image: images[0])
        .position(
          x: frame.head.x + BeadsHeadMetrics.width / 2 - BeadsHeadMetrics.anchor.x,
          y: frame.head.y + BeadsHeadMetrics.height / 2 - BeadsHeadMetrics.anchor.y
        )
        .zIndex(.infinity)
    }
    .frame(width: BeadsStrandMetrics.drawingWidth, height: BeadsStrandMetrics.height)
    // Derive centering from the interpolated head too. A separate offset or
    // head animation can reach its destination before the loop does.
    .offset(y: BeadsStrandMetrics.centerY - frame.head.y)
    // Positions, material sizes and opacity already represent this animation
    // frame. A second child animation would put them out of step again.
    .transaction {
      $0.animation = nil
      $0.disablesAnimations = true
    }
  }
}
