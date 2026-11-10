import DesignKit
import Inject
import SwiftUI

enum BeadsHeadMetrics {
  static let diameterScale: CGFloat = 1.16
  static let joinClearance: CGFloat = 1.15
  static let leadingReach: CGFloat = 64
  static let trailingReach: CGFloat = 24
  static let topReach: CGFloat = 24
  static let bottomReach: CGFloat = 76
  static let bindingLength: CGFloat = 6
  static let bindingWidth: CGFloat = 2.2
  static let tasselWidth: CGFloat = 1.1
  static let tasselLean: CGFloat = 11
  static let tasselBend: CGFloat = 12
  static let kick: CGFloat = 6
  static let springStiffness: Double = 95
  static let springDamping: Double = 8
  static let swayDuration: Double = 1.5
  static let width = leadingReach + trailingReach
  static let height = topReach + bottomReach

  static var anchor: CGPoint { CGPoint(x: leadingReach, y: topReach) }
}

/// The head stays at the leading join; gravity takes the soft cord below it.
/// Keeping the cord in drawing coordinates avoids the rigid, sideways pendant
/// silhouette that rotating an entire bottom-hanging assembly produced.
struct BeadsHeadView: View {
  @ObserveInjection private var injectionObserver
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var motionStart: Date?
  @State private var deflection: CGFloat = 0
  @State private var previousCount: Int?
  let diameter: CGFloat
  let count: Int
  let blend: BeadsMaterialBlend
  let images: [BeadsMaterial: [CGImage?]]
  let rippleSway: CGFloat

  var body: some View {
    TimelineView(.animation(paused: motionStart == nil || reduceMotion)) { timeline in
      blend.render { finish in
        BeadsHeadAssembly(
          diameter: diameter, sway: sway(at: timeline.date) + rippleSway,
          material: finish, image: images[finish]?[0] ?? nil
        )
        // Flatten each finish before fading it so the connector stays
        // behind its two beads through the blend.
        .compositingGroup()
      }
    }
    .task(id: MotionTrigger(count: count, reduceMotion: reduceMotion)) {
      let oldCount = previousCount
      previousCount = count
      guard let oldCount, oldCount != count, !reduceMotion else {
        motionStart = nil
        return
      }

      deflection = count > oldCount ? -BeadsHeadMetrics.kick : BeadsHeadMetrics.kick
      motionStart = .now
      do {
        try await Task.sleep(for: .seconds(BeadsHeadMetrics.swayDuration))
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      motionStart = nil
    }
    .enableInjection()
  }

  /// The strand supplies an already interpolated diameter and placement.
  /// Drive only the cord's local deflection with elapsed time: starting another
  /// implicit spring here would also reanimate those incoming frame values,
  /// letting the head lag behind the string during a preset change.
  private func sway(at date: Date) -> CGFloat {
    guard !reduceMotion, let motionStart else { return 0 }
    let elapsed = max(0, date.timeIntervalSince(motionStart))
    let decay = BeadsHeadMetrics.springDamping / 2
    let frequency = sqrt(BeadsHeadMetrics.springStiffness - decay * decay)
    return deflection * exp(-decay * elapsed)
      * (cos(frequency * elapsed) + decay / frequency * sin(frequency * elapsed))
  }

  private struct MotionTrigger: Hashable {
    let count: Int
    let reduceMotion: Bool
  }
}

/// The preview centres on the visible fittings at rest. Use the same
/// attachment points for drawing and measuring them, including the tassel.
struct BeadsHeadGeometry {
  let diameter: CGFloat

  var towerDiameter: CGFloat { diameter * BeadsRitualMetrics.towerScale }

  var tower: CGPoint {
    CGPoint(
      x: BeadsHeadMetrics.anchor.x - (diameter + towerDiameter) / 2,
      y: BeadsHeadMetrics.anchor.y - diameter * 0.17
    )
  }

  var tip: CGPoint {
    CGPoint(x: tower.x - towerDiameter * 0.6, y: tower.y - towerDiameter * 0.38)
  }

  func tasselEnd(thread: Int, sway: CGFloat = 0) -> CGPoint {
    let offset = CGFloat(thread) / CGFloat(BeadsRitualMetrics.tasselThreads - 1) - 0.5
    let uneven = CGFloat((thread * 37) % 7)
    return CGPoint(
      x: tip.x - BeadsHeadMetrics.tasselLean + sway + offset * BeadsRitualMetrics.tasselSpread,
      y: tip.y + BeadsRitualMetrics.tasselLength + uneven
    )
  }

  var bounds: CGRect {
    func bounds(around point: CGPoint, diameter: CGFloat) -> CGRect {
      CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter)
    }
    let fittings = bounds(around: BeadsHeadMetrics.anchor, diameter: diameter)
      .union(bounds(around: tower, diameter: towerDiameter))
      .union(bounds(around: tip, diameter: BeadsHeadMetrics.bindingLength))
    return (0..<BeadsRitualMetrics.tasselThreads).reduce(fittings) { result, thread in
      result.union(bounds(around: tasselEnd(thread: thread), diameter: BeadsHeadMetrics.tasselWidth))
    }
  }
}

/// The strand owns interpolation. Animating the incoming diameter or
/// placement a second time would make the fittings drift off the join.
private struct BeadsHeadAssembly: View {
  let diameter: CGFloat
  let sway: CGFloat
  let material: BeadsMaterial
  let image: CGImage?

  var body: some View {
    let palette = material.palette
    let geometry = BeadsHeadGeometry(diameter: diameter)
    let tip = geometry.tip
    ZStack(alignment: .topLeading) {
      Path { path in
        path.move(to: tip)
        path.addLine(to: geometry.tower)
        path.addLine(to: BeadsHeadMetrics.anchor)
      }
      .stroke(palette.cord, style: StrokeStyle(lineWidth: BeadsStrandMetrics.threadWidth, lineCap: .round))

      Path { path in
        for thread in 0..<BeadsRitualMetrics.tasselThreads {
          path.move(to: tip)
          path.addQuadCurve(
            to: geometry.tasselEnd(thread: thread, sway: sway),
            control: CGPoint(
              x: tip.x - BeadsHeadMetrics.tasselLean + sway * 0.3,
              y: tip.y + BeadsHeadMetrics.tasselBend
            )
          )
        }
      }
      .stroke(palette.tassel, style: StrokeStyle(lineWidth: BeadsHeadMetrics.tasselWidth, lineCap: .round))

      Capsule()
        .fill(palette.binding)
        .frame(width: BeadsHeadMetrics.bindingLength, height: BeadsHeadMetrics.bindingWidth)
        .rotationEffect(.degrees(-35))
        .position(tip)

      BeadsMaterialBead(material: material, diameter: geometry.towerDiameter, image: image)
        .position(geometry.tower)

      BeadsMaterialBead(material: material, diameter: diameter, image: image)
        .position(BeadsHeadMetrics.anchor)
    }
    .frame(width: BeadsHeadMetrics.width, height: BeadsHeadMetrics.height)
    .transaction {
      $0.animation = nil
      $0.disablesAnimations = true
    }
  }
}
