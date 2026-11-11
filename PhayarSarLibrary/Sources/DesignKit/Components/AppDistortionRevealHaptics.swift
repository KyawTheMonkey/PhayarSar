#if os(iOS)
import CoreHaptics
import Foundation

public enum AppDistortionRevealHapticsMetrics {
  /// The pull before the launch, felt as a rumble gathering from nothing.
  public static let pullIntensity: Float = 0.32
  public static let pullSharpness: Float = 0.12
  /// The front leaving the origin: one blunt strike, then the swell.
  public static let launchIntensity: Float = 0.9
  public static let launchSharpness: Float = 0.3
  public static let launchSettleIntensity: Float = 0.4
  public static let launchSettleDelay: TimeInterval = 0.04
  /// The swell crossing the card, following the shaders' energy curve.
  public static let swellIntensity: Float = 0.7
  public static let swellSharpness: Float = 0.2
  /// How many points of the energy curve are handed to Core Haptics, which
  /// caps a parameter curve at sixteen control points.
  static let curveSamples = 16
}

/// The wave as felt. Everything on screen is derived from `AppDistortionRevealFront`
/// at an elapsed time, so the haptic is authored the same way: a pattern whose
/// intensity curve is sampled from the front's own gravity and energy, played
/// once from the same instant the clock starts. Driving the engine frame by
/// frame from the timeline instead would put the haptic a render behind the
/// picture and tie it to the display refresh rate.
///
/// The pattern is a single continuous event under a parameter curve rather than
/// a run of transients: a swell is one pressure moving through the hand, and a
/// string of taps reads as counting, which already means something in this app.
@MainActor
final class AppDistortionRevealHaptics {
  typealias Metrics = AppDistortionRevealHapticsMetrics

  private var engine: CHHapticEngine?
  private var player: CHHapticPatternPlayer?
  private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

  /// Starts the wave's pattern now; `card` only shapes how long the front takes
  /// to cross, which is what the energy curve is sampled from.
  func play(card: CGRect) {
    guard supported, let engine = preparedEngine() else { return }
    stop()
    guard let pattern = Self.pattern(card: card),
          let player = try? engine.makePlayer(with: pattern) else { return }
    try? player.start(atTime: CHHapticTimeImmediate)
    self.player = player
  }

  /// Deactivation mid-wave (the screen is pushed over, the app resigns) stops
  /// the picture, so the feel must stop with it.
  func stop() {
    try? player?.stop(atTime: CHHapticTimeImmediate)
    player = nil
  }

  private func preparedEngine() -> CHHapticEngine? {
    if let engine {
      if (try? engine.start()) != nil { return engine }
      return nil
    }
    guard let engine = try? CHHapticEngine() else { return nil }
    engine.playsHapticsOnly = true
    // One wave at a time, seconds apart: let the engine put itself to sleep
    // between them rather than holding the hardware for the editor's lifetime.
    engine.isAutoShutdownEnabled = true
    engine.resetHandler = { [weak self] in
      Task { @MainActor in self?.player = nil }
    }
    guard (try? engine.start()) != nil else { return nil }
    self.engine = engine
    return engine
  }

  private static func pattern(card: CGRect) -> CHHapticPattern? {
    typealias Front = AppDistortionRevealFront
    typealias Reveal = AppDistortionRevealMetrics
    let anticipation = Reveal.anticipation
    // The swell has settled by the time the energy curve reaches zero; nothing
    // after that is felt, however long the rim lingers on screen.
    let end = anticipation + Reveal.travel * 0.85
    let strike = CHHapticEvent(eventType: .hapticTransient, parameters: [
      CHHapticEventParameter(parameterID: .hapticIntensity, value: Metrics.launchIntensity),
      CHHapticEventParameter(parameterID: .hapticSharpness, value: Metrics.launchSharpness),
    ], relativeTime: anticipation)
    let settle = CHHapticEvent(eventType: .hapticTransient, parameters: [
      CHHapticEventParameter(parameterID: .hapticIntensity, value: Metrics.launchSettleIntensity),
      CHHapticEventParameter(parameterID: .hapticSharpness, value: Metrics.launchSharpness * 0.6),
    ], relativeTime: anticipation + Metrics.launchSettleDelay)
    let body = CHHapticEvent(eventType: .hapticContinuous, parameters: [
      CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
      CHHapticEventParameter(parameterID: .hapticSharpness, value: Metrics.swellSharpness),
    ], relativeTime: 0, duration: end)

    // Half the samples go to the short anticipation, where the pull rises from
    // nothing, and half to the swell, so neither phase is reduced to a ramp.
    var points: [CHHapticParameterCurve.ControlPoint] = []
    let half = Metrics.curveSamples / 2
    for i in 0..<half {
      let t = anticipation * Double(i) / Double(half)
      let front = Front(elapsed: t, card: card)
      let pull = Float(front.gravity / Reveal.pull) * Metrics.pullIntensity
      points.append(.init(relativeTime: t, value: pull))
    }
    for i in 0..<half {
      let t = anticipation + (end - anticipation) * Double(i + 1) / Double(half)
      let front = Front(elapsed: t, card: card)
      let swell = Float(front.energy) * Metrics.swellIntensity
      points.append(.init(relativeTime: t, value: swell))
    }
    let curve = CHHapticParameterCurve(
      parameterID: .hapticIntensityControl, controlPoints: points, relativeTime: 0
    )
    return try? CHHapticPattern(events: [body, strike, settle], parameterCurves: [curve])
  }
}
#endif
