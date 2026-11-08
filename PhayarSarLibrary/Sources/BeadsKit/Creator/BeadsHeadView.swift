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
  static let wrapWidth: CGFloat = 4
  static let wrapHeight: CGFloat = 7
  static let cordWidth: CGFloat = 1.7
  static let cordHighlightWidth: CGFloat = 0.45
  static let terminalWidth: CGFloat = 3.5
  static let terminalHeight: CGFloat = 6
  static let kick: CGFloat = 6
  static let springStiffness: Double = 95
  static let springDamping: Double = 8
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
  @State private var sway: CGFloat = 0
  @State private var previousCount: Int?
  let diameter: CGFloat
  let count: Int

  private var root: CGPoint {
    CGPoint(
      x: BeadsHeadMetrics.anchor.x - diameter / 2 - BeadsHeadMetrics.wrapWidth / 2,
      y: BeadsHeadMetrics.anchor.y + BeadsHeadMetrics.wrapWidth / 2
    )
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      // A low, broad reflection keeps this slightly larger bead from reading
      // as an eye beside the connector and cord.
      PolishedBead(diameter: diameter, reflectionStrength: 0.42)
        .frame(width: diameter, height: diameter)
        .scaleEffect(x: 1, y: 0.94)
        .position(BeadsHeadMetrics.anchor)

      BeadsDrapedCord(root: root, sway: sway)
        .stroke(
          AppColor.Beads.warmth,
          style: StrokeStyle(lineWidth: BeadsHeadMetrics.cordWidth, lineCap: .round, lineJoin: .round)
        )
        .overlay {
          BeadsDrapedCord(root: root, sway: sway)
            .stroke(
              AppColor.Beads.thread.opacity(0.6),
              style: StrokeStyle(lineWidth: BeadsHeadMetrics.cordHighlightWidth, lineCap: .round)
            )
        }

      wrappedEnd(width: BeadsHeadMetrics.wrapWidth, height: BeadsHeadMetrics.wrapHeight)
        .rotationEffect(.degrees(68))
        .position(root)

      wrappedEnd(width: BeadsHeadMetrics.terminalWidth, height: BeadsHeadMetrics.terminalHeight)
        .rotationEffect(.degrees(-32 + Double(sway)))
        .position(BeadsDrapedCord.firstEnd(root: root, sway: sway))

      wrappedEnd(width: BeadsHeadMetrics.terminalWidth, height: BeadsHeadMetrics.terminalHeight)
        .rotationEffect(.degrees(16 + Double(sway) * 0.6))
        .position(BeadsDrapedCord.secondEnd(root: root, sway: sway))
    }
    .frame(width: BeadsHeadMetrics.width, height: BeadsHeadMetrics.height)
    .task(id: MotionTrigger(count: count, reduceMotion: reduceMotion)) {
      let oldCount = previousCount
      previousCount = count

      var transaction = Transaction(animation: nil)
      transaction.disablesAnimations = true
      guard let oldCount, oldCount != count, !reduceMotion else {
        withTransaction(transaction) { sway = 0 }
        return
      }

      withTransaction(transaction) {
        sway = count > oldCount ? -BeadsHeadMetrics.kick : BeadsHeadMetrics.kick
      }

      // Give the deflection one frame before releasing it. Cancelling this
      // task on the next count change makes rapid +/- taps restart the same
      // small gesture instead of queuing up a long series of swings.
      do {
        try await Task.sleep(for: .milliseconds(30))
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      withAnimation(.interpolatingSpring(
        stiffness: BeadsHeadMetrics.springStiffness,
        damping: BeadsHeadMetrics.springDamping
      )) {
        sway = 0
      }
    }
    .enableInjection()
  }

  private func wrappedEnd(width: CGFloat, height: CGFloat) -> some View {
    Capsule()
      .fill(
        LinearGradient(
          colors: [AppColor.Beads.warmth, AppColor.Beads.thread.opacity(0.8), AppColor.Beads.warmth],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(width: width, height: height)
  }

  private struct MotionTrigger: Hashable {
    let count: Int
    let reduceMotion: Bool
  }
}

/// Both ends hang on the same side of the join with different lengths and
/// curvature. The moving control points bend the cord itself, rather than
/// rotating a rigid fork, and the root remains attached throughout the sway.
private struct BeadsDrapedCord: Shape {
  var root: CGPoint
  var sway: CGFloat

  var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
    get { AnimatablePair(sway, AnimatablePair(root.x, root.y)) }
    set {
      sway = newValue.first
      root = CGPoint(x: newValue.second.first, y: newValue.second.second)
    }
  }

  static func firstEnd(root: CGPoint, sway: CGFloat) -> CGPoint {
    CGPoint(x: root.x - 12 + sway, y: root.y + 43 - sway * 0.2)
  }

  static func secondEnd(root: CGPoint, sway: CGFloat) -> CGPoint {
    CGPoint(x: root.x - 24 + sway * 0.8, y: root.y + 56 + sway * 0.15)
  }

  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: root)
      path.addCurve(
        to: CGPoint(x: root.x - 27 + sway * 0.5, y: root.y + 23),
        control1: CGPoint(x: root.x - 14, y: root.y - 3),
        control2: CGPoint(x: root.x - 34 + sway * 0.3, y: root.y + 10)
      )
      path.addCurve(
        to: Self.firstEnd(root: root, sway: sway),
        control1: CGPoint(x: root.x - 27 + sway * 0.7, y: root.y + 33),
        control2: CGPoint(x: root.x - 12 + sway, y: root.y + 34)
      )

      path.move(to: root)
      path.addCurve(
        to: CGPoint(x: root.x - 23 + sway * 0.4, y: root.y + 29),
        control1: CGPoint(x: root.x - 10, y: root.y + 4),
        control2: CGPoint(x: root.x - 30 + sway * 0.2, y: root.y + 17)
      )
      path.addCurve(
        to: Self.secondEnd(root: root, sway: sway),
        control1: CGPoint(x: root.x - 18 + sway * 0.5, y: root.y + 39),
        control2: CGPoint(x: root.x - 21 + sway * 0.8, y: root.y + 47)
      )
    }
  }
}
