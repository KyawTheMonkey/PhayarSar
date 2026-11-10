import SwiftUI

struct BeadsMaterialMorph {
  struct Sample {
    let blend: BeadsMaterialBlend
    let pull: CGFloat
  }

  let start: ContinuousClock.Instant
  let end: ContinuousClock.Instant
  let materials: Set<BeadsMaterial>
  private let source: Sample
  private let interrupted: [Sample]?
  private let target: BeadsMaterial
  private let visibleCount: Int
  private let travel: Double
  private static let pullPeak = 0.38

  init(
    from material: BeadsMaterial, to target: BeadsMaterial, interrupting previous: Self?,
    visibleCount: Int, reduceMotion: Bool
  ) {
    let now = ContinuousClock.now
    start = now
    end = now + (reduceMotion ? .milliseconds(150) : .milliseconds(400))
    travel = !reduceMotion && visibleCount > 1 ? 0.52 : 0
    source = Sample(blend: BeadsMaterialBlend(material), pull: 0)
    self.target = target
    self.visibleCount = visibleCount

    // Sample the finish and pull of each slot when the next swatch is
    // tapped. A retargeted wave can start without snapping beads home.
    if let previous, now < previous.end {
      let samples = (0...BeadsStrandMetrics.maximumVisibleBeads).map {
        previous.sample(at: $0, time: now)
      }
      interrupted = samples
      materials = Set(samples.flatMap { $0.blend.weights.keys }).union([target])
    } else {
      interrupted = nil
      materials = [material, target]
    }
  }

  /// Slot zero is the head. Spread the delay over the length of the strand
  /// so a coiled 108-bead set takes the same time as a short loop.
  func sample(at slot: Int, time: ContinuousClock.Instant) -> Sample {
    let position = min(Double(slot) / Double(visibleCount), 1)
    let elapsed = (time - start) / (end - start)
    let phase = (elapsed - position * travel) / (1 - travel)
    let previous = interrupted?[slot] ?? source
    let blend = previous.blend.fading(to: target, amount: Self.ease(phase))
    guard travel > 0 else { return Sample(blend: blend, pull: 0) }

    let peak = Self.pullPeak
    let tug = Self.ease(phase / peak)
    let release = Self.ease((phase - peak) / (1 - peak))
    // Let the interrupted tug relax while the new one approaches. Keeping
    // the sum bounded leaves every bead on its own segment of the cord.
    let carry = previous.pull * CGFloat(1 - Self.ease(elapsed / (1 - travel)))
    let pull = carry + (1 - carry) * CGFloat(tug * (1 - release))
    return Sample(blend: blend, pull: pull)
  }

  private static func ease(_ fraction: Double) -> Double {
    let t = min(1, max(0, fraction))
    return t * t * (3 - 2 * t)
  }
}

struct BeadsMaterialBlend {
  fileprivate let weights: [BeadsMaterial: Double]

  init(_ material: BeadsMaterial) {
    weights = [material: 1]
  }

  private init(weights: [BeadsMaterial: Double]) {
    self.weights = weights
  }

  func fading(to material: BeadsMaterial, amount: Double) -> Self {
    if amount == 0 { return self }
    if amount == 1 || weights[material] == 1 { return Self(material) }
    var mixed = weights.mapValues { $0 * (1 - amount) }
    mixed[material, default: 0] += amount
    return Self(weights: mixed)
  }

  @MainActor
  @ViewBuilder
  func render<Content: View>(@ViewBuilder content: @escaping (BeadsMaterial) -> Content) -> some View {
    if weights.count == 1, let material = weights.keys.first {
      content(material)
    } else {
      // Add the weighted layers in isolation. A normal stack of two
      // half-opacity sprites would let the background show through the bead.
      ZStack {
        ForEach(BeadsMaterial.allCases) { material in
          if let weight = weights[material] {
            content(material)
              .opacity(weight)
              .blendMode(.plusLighter)
          }
        }
      }
      .compositingGroup()
    }
  }
}
