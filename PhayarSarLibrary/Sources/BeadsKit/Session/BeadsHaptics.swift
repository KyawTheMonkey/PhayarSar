#if os(iOS)
import CoreHaptics
import UIKit

enum BeadsHapticsMetrics {
  static let slideIntensity: Float = 0.18
  static let slideSharpness: Float = 0.28
  static let slideDuration: TimeInterval = 30
  static let clickIntensity: Float = 0.95
  static let clickSharpness: Float = 0.6
  static let settleIntensity: Float = 0.32
  static let settleDelay: TimeInterval = 0.028
  static let headIntensity: Float = 0.85
  static let headSharpness: Float = 0.34
  static let headSpacing: TimeInterval = 0.11
  static let releaseIntensity: Float = 0.26
  static let tickIntensity: Float = 0.5
  static let tickSharpness: Float = 0.55
  static let strainIntensity: Float = 0.8
  static let strainSharpness: Float = 0.08
  static let strainSpacing: TimeInterval = 0.08
  static let bloomDuration: TimeInterval = 1.4
}

/// A bead is a small hard object passing over skin and stopping against its
/// neighbour. UIKit's selection tick is a generic interface sound; these
/// patterns are shaped like the material instead: a faint continuous texture
/// while the bead slides, a sharp strike with a softer settle a few
/// milliseconds later, a rounder double for the head bead, and a long decay
/// when the practice completes. Devices without an engine stay silent rather
/// than falling back to a tick that would contradict the visual.
@MainActor
final class BeadsHaptics {
  private var engine: CHHapticEngine?
  private var slide: CHHapticAdvancedPatternPlayer?
  private var isRunning = false
  private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

  func prepare() {
    guard supported, engine == nil else { return }
    do {
      let engine = try CHHapticEngine()
      engine.playsHapticsOnly = true
      engine.isAutoShutdownEnabled = false
      engine.resetHandler = { [weak self] in
        Task { @MainActor in self?.restart() }
      }
      engine.stoppedHandler = { [weak self] _ in
        Task { @MainActor in
          self?.isRunning = false
          self?.slide = nil
        }
      }
      try engine.start()
      self.engine = engine
      isRunning = true
    } catch {
      engine = nil
    }
  }

  func stop() {
    endSlide()
    engine?.stop()
    engine = nil
    isRunning = false
  }

  private func restart() {
    guard let engine else { return }
    slide = nil
    do {
      try engine.start()
      isRunning = true
    } catch {
      isRunning = false
    }
  }

  // MARK: - Slide

  func beginSlide() {
    guard let engine, isRunning else { return }
    let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
      CHHapticEventParameter(parameterID: .hapticIntensity, value: 0),
      CHHapticEventParameter(parameterID: .hapticSharpness, value: BeadsHapticsMetrics.slideSharpness),
    ], relativeTime: 0, duration: BeadsHapticsMetrics.slideDuration)
    do {
      let player = try engine.makeAdvancedPlayer(with: CHHapticPattern(events: [event], parameters: []))
      try player.start(atTime: CHHapticTimeImmediate)
      slide = player
    } catch {
      slide = nil
    }
  }

  /// Speed is in pitches per second. The texture only rises with movement, so
  /// a resting finger feels nothing.
  func updateSlide(speed: Double) {
    guard let slide else { return }
    let intensity = Float(min(1, speed / 3)) * BeadsHapticsMetrics.slideIntensity
    try? slide.sendParameters([
      CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0),
    ], atTime: CHHapticTimeImmediate)
  }

  func endSlide() {
    try? slide?.stop(atTime: CHHapticTimeImmediate)
    slide = nil
  }

  // MARK: - Events

  func click() {
    play([
      transient(BeadsHapticsMetrics.clickIntensity, BeadsHapticsMetrics.clickSharpness, at: 0),
      transient(BeadsHapticsMetrics.settleIntensity, 0.3, at: BeadsHapticsMetrics.settleDelay),
    ])
  }

  func head() {
    play([
      transient(BeadsHapticsMetrics.headIntensity, BeadsHapticsMetrics.headSharpness, at: 0),
      transient(BeadsHapticsMetrics.headIntensity * 0.8, BeadsHapticsMetrics.headSharpness, at: BeadsHapticsMetrics.headSpacing),
    ])
  }

  /// A bead running back past the thumb: lighter than a counted click, so a
  /// string of them reads as beads slipping by and not as counts.
  func tick() {
    play([transient(BeadsHapticsMetrics.tickIntensity, BeadsHapticsMetrics.tickSharpness, at: 0)])
  }

  /// The cord pulling taut: low and blunt, nothing like a counted bead.
  func strain() {
    play([
      transient(BeadsHapticsMetrics.strainIntensity, BeadsHapticsMetrics.strainSharpness, at: 0),
      transient(BeadsHapticsMetrics.strainIntensity * 0.7, BeadsHapticsMetrics.strainSharpness, at: BeadsHapticsMetrics.strainSpacing),
    ])
  }

  func release() {
    play([transient(BeadsHapticsMetrics.releaseIntensity, 0.2, at: 0)])
  }

  func bloom() {
    let duration = BeadsHapticsMetrics.bloomDuration
    let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
      CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
      CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
    ], relativeTime: 0.03, duration: duration)
    let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
      .init(relativeTime: 0, value: 1),
      .init(relativeTime: duration * 0.35, value: 0.55),
      .init(relativeTime: duration, value: 0),
    ], relativeTime: 0.03)
    let strike = transient(BeadsHapticsMetrics.clickIntensity, BeadsHapticsMetrics.clickSharpness, at: 0)
    guard let engine, isRunning,
          let pattern = try? CHHapticPattern(events: [strike, event], parameterCurves: [fade]),
          let player = try? engine.makePlayer(with: pattern) else { return }
    try? player.start(atTime: CHHapticTimeImmediate)
  }

  private func transient(_ intensity: Float, _ sharpness: Float, at time: TimeInterval) -> CHHapticEvent {
    CHHapticEvent(eventType: .hapticTransient, parameters: [
      CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
      CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
    ], relativeTime: time)
  }

  private func play(_ events: [CHHapticEvent]) {
    guard let engine, isRunning,
          let pattern = try? CHHapticPattern(events: events, parameters: []),
          let player = try? engine.makePlayer(with: pattern) else { return }
    try? player.start(atTime: CHHapticTimeImmediate)
  }
}
#endif
