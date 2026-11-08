import DesignKit
import SwiftUI

/// Depth sorting includes the cord links, so a foreground thread can pass in
/// front of a rear bead without making that solid bead translucent. Spheres
/// share the main strand's material and a fixed light source in both schemes.
struct BeadsRoundsIcon: View, Animatable {
  nonisolated var twist: CGFloat
  nonisolated var tasselSwing: CGFloat
  nonisolated var asymmetry: CGFloat = 0
  nonisolated var sway: CGFloat = 0

  nonisolated var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
    get { AnimatablePair(AnimatablePair(twist, tasselSwing), AnimatablePair(asymmetry, sway)) }
    set {
      twist = newValue.first.first
      tasselSwing = newValue.first.second
      asymmetry = newValue.second.first
      sway = newValue.second.second
    }
  }

  private enum Part {
    case bead(Int)
    case link(Int)
    case tassel
  }

  var body: some View {
    Canvas { context, _ in
      let geometry = BeadsRoundsGeometry(twist: twist, asymmetry: asymmetry, sway: sway)
      let beads = geometry.beads
      let bottom = BeadsRoundsIconMetrics.beadCount / 4
      var parts: [(part: Part, depth: CGFloat)] = []
      for index in beads.indices {
        parts.append((.bead(index), beads[index].z))
        parts.append((.link(index), (beads[index].z + beads[(index + 1) % beads.count].z) / 2))
      }
      parts.append((.tassel, beads[bottom].z))
      // Stable tie order keeps an untwisted strand deterministic, too.
      let sorted = parts.enumerated().sorted {
        $0.element.depth == $1.element.depth
          ? $0.offset < $1.offset : $0.element.depth < $1.element.depth
      }
      for element in sorted {
        switch element.element.part {
        case .link(let index):
          let start = beads[index]
          let end = beads[(index + 1) % beads.count]
          let difference = end - start
          let inset = difference * (BeadsRoundsIconMetrics.beadDiameter / (2 * difference.length))
          var path = Path()
          path.move(to: BeadsRoundsGeometry.project(start + inset))
          path.addLine(to: BeadsRoundsGeometry.project(end - inset))
          context.stroke(path, with: .color(AppColor.Beads.thread), style: StrokeStyle(
            lineWidth: BeadsRoundsIconMetrics.cordWidth, lineCap: .round
          ))
        case .bead(let index):
          let bead = beads[index]
          let center = BeadsRoundsGeometry.project(bead)
          let radius = BeadsRoundsIconMetrics.beadDiameter / 2 * BeadsRoundsGeometry.scale(at: bead)
          let outline = Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2
          ))
          context.fill(outline, with: .radialGradient(
            Gradient(colors: [AppColor.Beads.reflection, AppColor.Beads.warmth, AppColor.Beads.core]),
            center: CGPoint(
              x: center.x - radius * BeadsRoundsIconMetrics.highlightOffset,
              y: center.y - radius * BeadsRoundsIconMetrics.highlightOffset
            ),
            startRadius: 0, endRadius: radius * 2
          ))
          context.stroke(outline, with: .color(AppColor.Beads.rim), lineWidth: BeadsRoundsIconMetrics.beadRimWidth)
        case .tassel:
          let attachment = beads[bottom]
          let knot = attachment + .init(x: 0, y: BeadsRoundsIconMetrics.knotDrop, z: 0)
          var path = Path()
          path.move(to: BeadsRoundsGeometry.project(attachment + .init(
            x: 0, y: BeadsRoundsIconMetrics.beadDiameter / 2, z: 0
          )))
          path.addLine(to: BeadsRoundsGeometry.project(knot))
          for thread in -1...1 {
            let spread = CGFloat(thread) * BeadsRoundsIconMetrics.tasselSpread
            let end = knot + .init(
              x: sin(tasselSwing) * BeadsRoundsIconMetrics.tasselLength + spread,
              y: cos(tasselSwing) * BeadsRoundsIconMetrics.tasselLength, z: 0
            )
            let control = knot + .init(
              x: spread * BeadsRoundsIconMetrics.tasselBend,
              y: BeadsRoundsIconMetrics.tasselLength * BeadsRoundsIconMetrics.tasselBend, z: 0
            )
            path.move(to: BeadsRoundsGeometry.project(knot))
            path.addQuadCurve(
              to: BeadsRoundsGeometry.project(end), control: BeadsRoundsGeometry.project(control)
            )
          }
          context.stroke(path, with: .color(AppColor.Beads.thread), style: StrokeStyle(
            lineWidth: BeadsRoundsIconMetrics.cordWidth, lineCap: .round, lineJoin: .round
          ))
        }
      }
    }
  }
}

// MARK: - Previews

#Preview("Rounds motion") {
  BeadsRoundsIconPreview()
}

private struct BeadsRoundsIconPreview: View {
  @State private var rounds = 1
  @State private var isValid = true

  init() { Typography.registerFonts() }

  var body: some View {
    BeadsRoundsPicker(rounds: $rounds, isValid: $isValid)
      .appBackground()
  }
}
