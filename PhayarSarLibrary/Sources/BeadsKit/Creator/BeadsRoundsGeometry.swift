import Foundation

enum BeadsRoundsIconMetrics {
  static let width: CGFloat = 44
  static let height: CGFloat = 56
  static let centerX: CGFloat = width / 2
  static let centerY: CGFloat = 20
  static let radius: CGFloat = 12
  static let beadCount = 12
  static let beadDiameter: CGFloat = 5.8
  static let perspective: CGFloat = 90
  static let constraintPasses = 100
  static let curveSamples = 240
  static let crossingWidth: CGFloat = 0.62
  static let crossingHeight: CGFloat = 1.2
  static let crossingDepth: CGFloat = 4.2
  static let crossingPhase: CGFloat = 0.5
  static let lobeTimingBias: CGFloat = 0.55
  static let depthBend: CGFloat = 0.4
  static let maximumTwist: CGFloat = .pi * 0.42
  static let cordWidth: CGFloat = 0.65
  static let beadRimWidth: CGFloat = 0.35
  static let highlightOffset: CGFloat = 0.3
  static let knotDrop: CGFloat = 4
  static let tasselLength: CGFloat = 10
  static let tasselSpread: CGFloat = 2.5
  static let tasselBend: CGFloat = 0.65
}

/// The icon uses a small, deterministic position solver rather than a running
/// simulation: every combination has one repeatable pose and returning to zero gives
/// the original loop exactly. Rigid beads move through space; their outlines
/// never get stretched into the thin slivers produced by warping a flat image.
/// The center stays in place while the sides pass across each other into a
/// vertical figure eight. Pinning the left/right beads prevented that crossing
/// and made the earlier pose diamond-shaped. The crossing is separated in depth
/// so this remains one closed strand, not two intersecting loops.
struct BeadsRoundsGeometry {
  struct Point {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat

    static func + (lhs: Self, rhs: Self) -> Self {
      Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
      Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static func * (lhs: Self, rhs: CGFloat) -> Self {
      Self(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    var length: CGFloat { sqrt(x * x + y * y + z * z) }
  }

  let beads: [Point]

  static var linkLength: CGFloat {
    2 * BeadsRoundsIconMetrics.radius * sin(.pi / CGFloat(BeadsRoundsIconMetrics.beadCount))
  }

  init(twist: CGFloat, asymmetry: CGFloat = 0, sway: CGFloat = 0) {
    let count = BeadsRoundsIconMetrics.beadCount
    let progress = min(abs(twist) / BeadsRoundsIconMetrics.maximumTwist, 1)
    let direction: CGFloat = twist < 0 ? -1 : 1
    let samples = BeadsRoundsIconMetrics.curveSamples
    let curve = (0...samples).map { index in
      let angle = CGFloat(index) / CGFloat(samples) * .pi * 2
      let localProgress = progress * (1 + asymmetry * sin(angle) * BeadsRoundsIconMetrics.lobeTimingBias)
      return Point(
        x: BeadsRoundsIconMetrics.radius * (
          cos(angle) * (
            1 - progress + direction * 2 * BeadsRoundsIconMetrics.crossingWidth * localProgress * sin(angle)
          ) + asymmetry * sin(angle) * sin(angle)
        ),
        y: BeadsRoundsIconMetrics.radius * sin(angle) * (
          1 + (BeadsRoundsIconMetrics.crossingHeight - 1) * progress + asymmetry * sin(angle)
        ),
        z: BeadsRoundsIconMetrics.crossingDepth * progress * (
          cos(angle) + asymmetry * BeadsRoundsIconMetrics.depthBend * sin(2 * angle)
        )
      )
    }
    var distances: [CGFloat] = [0]
    for index in 1...samples {
      distances.append(distances[index - 1] + (curve[index] - curve[index - 1]).length)
    }
    let length = distances[samples]
    var cursor = 1
    var positions = (0..<count).map { index in
      let distance = length * (CGFloat(index) + progress * BeadsRoundsIconMetrics.crossingPhase) / CGFloat(count)
      while cursor < samples, distances[cursor] < distance { cursor += 1 }
      let fraction = (distance - distances[cursor - 1]) / (distances[cursor] - distances[cursor - 1])
      return curve[cursor - 1] + (curve[cursor] - curve[cursor - 1]) * fraction
    }
    // Uniform arc-length sampling avoids a pile-up of beads at the crossing.
    // Normalize the closed polygon before relaxing individual links, so making
    // two lobes does not require more cord than the original circular strand.
    let polygonLength = positions.indices.reduce(CGFloat.zero) { total, index in
      total + (positions[(index + 1) % count] - positions[index]).length
    }
    positions = positions.map { $0 * (Self.linkLength * CGFloat(count) / polygonLength) }

    // Alternating sweep direction prevents one side of the loop accumulating
    // the solver's correction. Beads cannot overlap in 3D, although their
    // projected silhouettes can overlap naturally as one passes behind another.
    func separate(_ first: Int, _ second: Int, distance: CGFloat, minimumOnly: Bool) {
      let difference = positions[second] - positions[first]
      let length = difference.length
      guard length > .ulpOfOne, !minimumOnly || length < distance else { return }
      let correction = difference * ((length - distance) / (length * 2))
      positions[first] = positions[first] + correction
      positions[second] = positions[second] - correction
    }

    for pass in 0..<BeadsRoundsIconMetrics.constraintPasses {
      for step in 0..<count {
        let index = pass.isMultiple(of: 2) ? step : count - 1 - step
        separate(index, (index + 1) % count, distance: Self.linkLength, minimumOnly: false)
      }
      for first in 0..<count {
        for second in (first + 1)..<count {
          guard second != first + 1, !(first == 0 && second == count - 1) else { continue }
          separate(first, second, distance: BeadsRoundsIconMetrics.beadDiameter, minimumOnly: true)
        }
      }
    }
    let center = Point(
      x: ((positions.map(\.x).min() ?? 0) + (positions.map(\.x).max() ?? 0)) / 2,
      y: ((positions.map(\.y).min() ?? 0) + (positions.map(\.y).max() ?? 0)) / 2,
      z: positions.reduce(CGFloat.zero) { $0 + $1.z } / CGFloat(count)
    )
    // Sway is a rigid rotation after relaxation: it adds angular follow-through
    // without changing link lengths. The tassel hangs from the moving bead and
    // has its own delayed response rather than rotating with the entire icon.
    beads = positions.map { point in
      let local = point - center
      return Point(
        x: local.x * cos(sway) - local.y * sin(sway),
        y: local.x * sin(sway) + local.y * cos(sway), z: local.z
      )
    }
  }

  static func scale(at point: Point) -> CGFloat {
    BeadsRoundsIconMetrics.perspective / (BeadsRoundsIconMetrics.perspective - point.z)
  }

  static func project(_ point: Point) -> CGPoint {
    let scale = scale(at: point)
    return CGPoint(
      x: BeadsRoundsIconMetrics.centerX + point.x * scale,
      y: BeadsRoundsIconMetrics.centerY + point.y * scale
    )
  }
}
