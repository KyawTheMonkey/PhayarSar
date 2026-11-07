import DesignKit
import Inject
import SwiftUI

enum BeadsStrandMetrics {
  static let height: CGFloat = 240
  static let drawingWidth: CGFloat = 340
  static let maximumVisibleBeads = 108
  static let samples = 540
  static let maximumDiameter: CGFloat = 34
  static let minimumDiameter: CGFloat = 12
  static let beadsPerCoil = 36
  static let minimumRadius: CGFloat = 22
  static let maximumRadius: CGFloat = 116
  static let radiusPerBead: CGFloat = 6.8
  static let coilHorizontalSpread: CGFloat = 16
  static let coilVerticalSpread: CGFloat = 28
  static let threadWidth: CGFloat = 1.5
  static let shadowRadius: CGFloat = 2
  static let shadowOffset: CGFloat = 3
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

  private var visibleCount: Int {
    min(max(count, 1), BeadsStrandMetrics.maximumVisibleBeads)
  }

  /// Larger custom sets show a window onto the joining end, named explicitly
  /// beneath the presets. Advancing that window preserves a visible insertion
  /// on every + tap without mounting thousands of overlapping sphere views.
  private var firstIndex: Int { max(0, count - visibleCount) }

  var body: some View {
    GeometryReader { proxy in
      let scale = min(proxy.size.width / BeadsStrandMetrics.drawingWidth, 1)
      let geometry = BeadsStrandGeometry(count: visibleCount)

      ZStack {
        BeadsThread(radius: geometry.radius, coils: geometry.coils, perspective: geometry.perspective)
          .stroke(AppColor.Beads.thread, lineWidth: BeadsStrandMetrics.threadWidth)

        ForEach(firstIndex..<(firstIndex + visibleCount), id: \.self) { index in
          let bead = geometry.beads[index - firstIndex]
          PolishedBead()
            .frame(width: bead.diameter, height: bead.diameter)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.05).combined(with: .opacity))
            .position(bead.position)
            .zIndex(bead.position.y)
        }
      }
      .frame(width: BeadsStrandMetrics.drawingWidth, height: BeadsStrandMetrics.height)
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

// MARK: - Material

private struct PolishedBead: View {
  var body: some View {
    GeometryReader { proxy in
      let diameter = proxy.size.width
      Circle()
        .fill(
          RadialGradient(
            stops: [
              .init(color: AppColor.Beads.rim, location: 0),
              .init(color: AppColor.Beads.warmth, location: 0.3),
              .init(color: AppColor.Beads.core, location: 0.7),
              .init(color: AppColor.Beads.warmth, location: 1),
            ],
            center: UnitPoint(x: 0.28, y: 0.22),
            startRadius: 0,
            endRadius: diameter * 0.95
          )
        )
        .overlay {
          Circle()
            .strokeBorder(
              LinearGradient(
                colors: [AppColor.Beads.reflection.opacity(0.65), AppColor.Beads.core, AppColor.Beads.rim.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: diameter * 0.025
            )
        }
        .overlay(alignment: .topLeading) {
          Ellipse()
            .fill(
              LinearGradient(
                colors: [AppColor.Beads.reflection.opacity(0.95), AppColor.Beads.reflection.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: diameter * 0.28, height: diameter * 0.17)
            .rotationEffect(.degrees(-38))
            .offset(x: diameter * 0.19, y: diameter * 0.15)
        }
        .overlay(alignment: .bottomTrailing) {
          Ellipse()
            .fill(AppColor.Beads.rim.opacity(0.35))
            .frame(width: diameter * 0.34, height: diameter * 0.07)
            .rotationEffect(.degrees(-28))
            .offset(x: -diameter * 0.13, y: -diameter * 0.15)
        }
        .shadow(
          color: AppColor.Beads.shadow,
          radius: BeadsStrandMetrics.shadowRadius,
          y: BeadsStrandMetrics.shadowOffset
        )
    }
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
      beads = [Bead(
        position: CGPoint(x: BeadsStrandMetrics.drawingWidth / 2, y: BeadsStrandMetrics.height / 2),
        diameter: BeadsStrandMetrics.maximumDiameter
      )]
      return
    }

    // Uniform angles bunch up the beads at an oval's ends. Sampling its arc
    // length keeps the physical gaps even, including where the coils cross.
    let points = (0...BeadsStrandMetrics.samples).map { sample in
      Self.point(fraction: CGFloat(sample) / CGFloat(BeadsStrandMetrics.samples), radius: radius, coils: coils, perspective: perspective)
    }
    var distances: [CGFloat] = [0]
    for index in 1..<points.count {
      distances.append(distances[index - 1] + hypot(points[index].x - points[index - 1].x, points[index].y - points[index - 1].y))
    }
    let length = distances.last ?? 0
    let diameter = min(
      BeadsStrandMetrics.maximumDiameter,
      max(BeadsStrandMetrics.minimumDiameter, length / CGFloat(count) * 0.96)
    )
    var cursor = 1
    beads = (0..<count).map { index in
      let target = CGFloat(index) / CGFloat(count) * length
      while cursor < distances.count - 1, distances[cursor] < target { cursor += 1 }
      let previous = cursor - 1
      let fraction = (target - distances[previous]) / max(distances[cursor] - distances[previous], 0.001)
      let position = CGPoint(
        x: points[previous].x + (points[cursor].x - points[previous].x) * fraction,
        y: points[previous].y + (points[cursor].y - points[previous].y) * fraction
      )
      let depth = (position.y - BeadsStrandMetrics.height / 2) / BeadsStrandMetrics.height
      return Bead(position: position, diameter: diameter * (1 + depth * 0.32))
    }
  }

  static func point(fraction: CGFloat, radius: CGFloat, coils: CGFloat, perspective: CGFloat) -> CGPoint {
    let phase = fraction * .pi * 2
    let angle = phase * coils - .pi / 2
    let spread = min(1, max(0, coils - 1))
    let localRadius = radius + cos(phase) * BeadsStrandMetrics.coilHorizontalSpread * spread
    return CGPoint(
      x: BeadsStrandMetrics.drawingWidth / 2 + cos(angle) * localRadius,
      y: BeadsStrandMetrics.height / 2 + sin(angle) * localRadius * perspective + sin(phase) * BeadsStrandMetrics.coilVerticalSpread * spread
    )
  }
}

/// Interpolates the thread alongside the spheres when a bracelet grows into a
/// coil. The closing segment stays under the joining beads at either endpoint.
private struct BeadsThread: Shape {
  var radius: CGFloat
  var coils: CGFloat
  var perspective: CGFloat

  var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
    get { AnimatablePair(radius, AnimatablePair(coils, perspective)) }
    set {
      radius = newValue.first
      coils = newValue.second.first
      perspective = newValue.second.second
    }
  }

  func path(in rect: CGRect) -> Path {
    Path { path in
      for sample in 0...BeadsStrandMetrics.samples {
        let point = BeadsStrandGeometry.point(
          fraction: CGFloat(sample) / CGFloat(BeadsStrandMetrics.samples),
          radius: radius,
          coils: coils,
          perspective: perspective
        )
        if sample == 0 { path.move(to: point) } else { path.addLine(to: point) }
      }
      path.closeSubpath()
    }
  }
}
