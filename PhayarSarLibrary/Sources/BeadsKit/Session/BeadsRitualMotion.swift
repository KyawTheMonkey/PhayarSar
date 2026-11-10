import Combine
import Foundation
import SwiftUI
#if os(iOS)
import CoreMotion
import UIKit
#endif

public enum BeadsRitualMetrics {
  /// Beads are sized to a finger, about half its width, as on a real mala.
  public static let beadRadius: CGFloat = 13
  public static let pitch: CGFloat = 28
  public static let fingerRadius: CGFloat = 21
  /// The pad of the unseen thumb, from the pinch: it presses from above.
  public static let thumbPad = CGPoint(x: 10, y: -28)
  public static let headScale: CGFloat = 1.22
  public static let towerScale: CGFloat = 0.46
  public static let tasselLength: CGFloat = 50
  public static let tasselThreads = 13
  public static let tasselSpread: CGFloat = 11
  public static let tasselClearance = 9.0
  /// How far to one side the tassel's tip must be before it drapes fully
  /// that way. Wide enough that a swing across the middle is a glide.
  public static let tasselSideSoftness = 12.0
  public static let tasselDamping = 0.988
  public static let tasselRestSpeed = 4.0
  /// How long the stage must be still before it stops drawing.
  public static let restDelay = 0.5
  /// The bead in hand is a touch larger; one on the far side of the finger a
  /// touch smaller; a held bead gives slightly under the thumb.
  public static let currentScale = 0.1
  public static let farScale = 0.1
  public static let gripScale = 0.05
  public static let gripResponse = 0.09
  public static let commitFraction = 0.5
  public static let flickFraction = 0.16
  public static let flickVelocity = 460.0
  public static let giveFraction = 0.3
  public static let settleFrequency = 30.0
  public static let turnDuration = 0.8
  public static let turnLift = 10.0
  public static let dissolveDuration = 2.6
  /// Each bead's share of the finish: swell, flare, then fade. Beads start in
  /// order of distance from the thumb, so the release ripples outward.
  public static let dissolveBeadDuration = 1.0
  public static let dissolveBeadStagger = 0.07
  public static let labelHoldDuration = 0.8
  public static let labelFadeDuration = 0.45
  public static let labelRiseDuration = 0.14
  public static let labelInset: CGFloat = 16
  public static let condenseDuration = 0.9
  public static let entranceRise: CGFloat = 30
  public static let countKick = 36.0
  public static let turnKick = 60.0
  public static let sensorInterval = 1.0 / 60
  public static let sensorSmoothing = 0.1
  public static let shakeThreshold = 0.035
  /// Raw accelerometer samples are noisy from one to the next. The strand is
  /// given a short running average of them, capped so a knock cannot fling it.
  public static let shakeSmoothing = 0.35
  public static let maximumShake = 2.2
  public static let tiltThreshold = 0.008
  public static let maximumFrameTime = 1.0 / 20
  public static let minimumGestureDistance: CGFloat = 3
  public static let restEnergy = 0.0005
}

/// Which bead a slot on the strand holds. One head bead opens every round, so
/// slot `r * (count + 1)` is a head and the following `count` slots are beads.
enum BeadsSlotKind: Equatable {
  case head(round: Int)
  case bead(number: Int, round: Int)
}

struct BeadsSessionShape: Equatable, Sendable {
  var count: Int
  var rounds: Int
  var completed: Int

  var total: Int { count * rounds }
  var isComplete: Bool { completed >= total }
}

struct BeadsRitualActions {
  var count: () -> Bool = { false }
  var undo: () -> Bool = { false }
}

/// The region the mala is drawn in, in the backdrop's coordinates (y down).
/// The unseen finger lies across the top of it and the mala hangs from there.
struct BeadsRailGeometry: Equatable {
  var region: CGRect
}

/// The ritual is a one-dimensional transport round a closed strand: a pull
/// draws the next bead to the thumb and moves every bead exactly one place.
/// No hand is drawn. The mala lies over an unseen finger and the thumb is the
/// person's own.
///
/// The bead in hand is the last one counted, so the numeral beside it is the
/// count so far, and a round begins with the head bead in hand at the top of
/// the loop. `transport` tracks the next bead to arrive; the bead at the
/// pinch is the one before it (`inHand`).
///
/// At the end of a round the head bead is next, and it is never pulled past.
/// The mala is turned around in the hand and counted back the other way, as
/// it is in practice; on screen the loop spins half a revolution and comes
/// back with the head bead in hand again.
///
/// The strand is still unless something moves it: a pull, a tilt of the
/// phone, or a shake. Core Motion only ever supplies forces to the hanging
/// cord. It has no path to the counter.
///
/// Per-session animation state, not a shared singleton. The screen keeps it
/// alive across layout changes and idles it, sensors included, when covered.
/// SpriteKit owns the clock and calls `step` from its frame callback; nothing
/// here is published per frame, only on touch and lifecycle boundaries.
@MainActor
final class BeadsRitualMotion: ObservableObject {
  enum Completion: Equatable { case none, dissolving, settled }

  private struct Turn {
    var direction: Int
    var progress = 0.0
    var applied = false
  }

  @Published private(set) var isPulling = false
  @Published private(set) var completion = Completion.none
  @Published private(set) var presentationRevision = 0

  var actions = BeadsRitualActions()
  private(set) var shape = BeadsSessionShape(count: 1, rounds: 1, completed: 0)
  private(set) var strand = BeadsMala(lattice: 2)
  private(set) var passedHead = false
  private(set) var transport = 1.0
  /// How close the mala is drawn. A short one is brought nearer.
  private(set) var zoom = 1.0
  private(set) var grip = 0.0
  private(set) var dissolve = 0.0
  private(set) var condense = 0.0
  private(set) var renderedFrameCount = 0
  private(set) var isActive = false
  private(set) var reduceMotion = false
  private(set) var labelText = ""
  private(set) var labelAlpha = 0.0
  var formatNumber: (Int) -> String = { String($0) }
  private var turn: Turn?
  private var height = 0.0
  private var labelRaised = false
  private var labelHold = 0.0
  private var transportVelocity = 0.0
  private var lastTime: TimeInterval?
  private var pull: BeadsPullInput?
  private var dissolveStart: TimeInterval?
  private var wakeRequest: (() -> Void)?
  #if os(iOS)
  private let haptics = BeadsHaptics()
  private let sensors = CMMotionManager()
  weak var hostView: UIView?
  #endif

  // MARK: - Slots

  var isComplete: Bool { shape.isComplete }

  /// Where the strand sits at rest, in slots: the bead at the pinch.
  var inHand: Double { transport - 1 }

  /// The next slot to arrive at the pinch. After a completed round that is
  /// the head bead, until the mala is turned; the turn is not a recitation.
  var restSlot: Int {
    let round = min(shape.rounds, shape.completed / max(1, shape.count))
    let atHead = shape.completed > 0 && shape.completed % shape.count == 0 && !passedHead
    return shape.completed + round + (atHead ? 0 : 1)
  }

  /// Slots run on in both directions round a closed loop, so this must hold
  /// for the negative ones behind the first bead as well.
  func kind(of slot: Int) -> BeadsSlotKind {
    let stride = shape.count + 1
    let position = ((slot % stride) + stride) % stride
    let round = Int((Double(slot - position) / Double(stride)).rounded())
    return position == 0 ? .head(round: round) : .bead(number: position, round: round)
  }

  func isHead(_ slot: Int) -> Bool {
    if case .head = kind(of: slot) { return true }
    return false
  }

  /// Count and round as a person would say them. Once the mala has been
  /// turned the next round has begun, so it reads as zero of that round.
  var positionInRound: (count: Int, round: Int) {
    let completed = shape.completed
    guard completed > 0 else { return (0, 1) }
    if completed < shape.total, completed % shape.count == 0, passedHead {
      return (0, completed / shape.count + 1)
    }
    return ((completed - 1) % shape.count + 1, (completed - 1) / shape.count + 1)
  }

  /// A round is complete: the head bead is next and the mala waits to be turned.
  var isAtHead: Bool { !isComplete && turn == nil && isHead(restSlot) }

  var canPullForward: Bool { !isComplete }

  var canUndo: Bool {
    let below = restSlot - 1
    guard below >= 1 else { return false }
    return isHead(below) ? passedHead : shape.completed > 0
  }

  // MARK: - Turning

  /// How wide the loop appears mid-turn, from 1 through 0 and back, and how
  /// far it is lifted off the finger while it turns.
  var spin: Double {
    guard let turn else { return 1 }
    return abs(cos(.pi * Self.smooth(turn.progress)))
  }

  var lift: Double {
    guard let turn else { return 0 }
    return sin(.pi * Self.smooth(turn.progress)) * BeadsRitualMetrics.turnLift
  }

  private func startTurn(_ direction: Int) {
    guard turn == nil else { return }
    if reduceMotion {
      applyTurn(direction)
    } else {
      turn = Turn(direction: direction)
    }
    publish()
    wake()
  }

  /// The beads are alike, so turning the mala leaves every bead where one
  /// was. Only the head bead visibly changes sides of the thumb.
  private func applyTurn(_ direction: Int) {
    passedHead = direction > 0
    transport += Double(direction)
    transportVelocity = 0
    strand.kick(SIMD2(0, BeadsRitualMetrics.turnKick))
    #if os(iOS)
    haptics.head()
    #endif
  }

  // MARK: - Lifecycle

  func sync(_ newShape: BeadsSessionShape) {
    let previous = shape
    shape = newShape
    if newShape.count != previous.count || newShape.rounds != previous.rounds {
      passedHead = false
      turn = nil
      rebuildStrand()
    }
    if newShape.completed % max(1, newShape.count) != 0 { passedHead = false }
    if newShape.isComplete {
      if completion == .none { beginDissolve() }
    } else if completion != .none {
      completion = .none
      dissolve = 0
      dissolveStart = nil
      beginCondense()
    }
    if pull == nil, turn == nil { transport = Double(restSlot) }
    wake()
  }

  /// The scene reports how tall the stage is. A mala that fits is drawn
  /// whole and as large as the stage allows; one that does not hangs off
  /// the bottom.
  func layout(height: CGFloat) {
    guard abs(Double(height) - self.height) > 0.5 else { return }
    self.height = Double(height)
    rebuildStrand()
  }

  private func rebuildStrand() {
    guard height > 0 else { return }
    let fit = BeadsMala.fit(count: shape.count, height: height)
    zoom = fit.zoom
    let lattice = fit.lattice
    guard lattice != strand.lattice else { return }
    let down = strand.down
    strand = BeadsMala(lattice: lattice)
    strand.down = down
    wake()
  }

  func setActive(_ active: Bool, reduceMotion: Bool) {
    guard active != isActive || reduceMotion != self.reduceMotion else { return }
    let wasActive = isActive
    self.reduceMotion = reduceMotion
    isActive = active
    #if os(iOS)
    sensors.stopDeviceMotionUpdates()
    #endif
    if active {
      #if os(iOS)
      haptics.prepare()
      startSensors()
      #endif
      if !wasActive { beginCondense() }
    } else {
      cancelPull()
      #if os(iOS)
      haptics.stop()
      #endif
      lastTime = nil
    }
    if reduceMotion { settleInstantly() }
    publish()
  }

  func stop() { setActive(false, reduceMotion: reduceMotion) }

  func onWake(_ handler: @escaping () -> Void) { wakeRequest = handler }

  // MARK: - Pulling

  func beginPull(time: Date) {
    guard isActive, pull == nil, turn == nil else { return }
    pull = BeadsPullInput(startTime: time.timeIntervalSinceReferenceDate)
    isPulling = true
    raiseLabel(for: restSlot)
    #if os(iOS)
    haptics.beginSlide()
    #endif
    wake()
  }

  /// Translation is positive toward the person: down the screen.
  func updatePull(translation: CGFloat, time: Date) {
    guard var input = pull else { return }
    input.update(translation: Double(translation), time: time.timeIntervalSinceReferenceDate)
    pull = input
    // The finger travels one bead spacing as drawn per bead, so the bead
    // stays under the thumb however the mala is strung or how near it is.
    let pitches = input.translation / (strand.pitch * zoom)
    transport = Double(restSlot) + resolvedOffset(pitches)
    transportVelocity = 0
    #if os(iOS)
    haptics.updateSlide(speed: abs(input.velocity) / (strand.pitch * zoom))
    #endif
    if reduceMotion { publish() }
    wake()
  }

  func endPull(translation: CGFloat, time: Date) {
    guard pull != nil else { return }
    updatePull(translation: translation, time: time)
    guard let input = pull else { return }
    pull = nil
    isPulling = false
    #if os(iOS)
    haptics.endSlide()
    #endif
    // Judged on the finger's own travel: a turn at the head bead has no slide
    // of the strand to measure.
    let pitches = input.translation / (strand.pitch * zoom)
    let velocity = input.velocity / (strand.pitch * zoom)
    let forward = pitches >= BeadsRitualMetrics.commitFraction
      || (pitches >= BeadsRitualMetrics.flickFraction && input.velocity >= BeadsRitualMetrics.flickVelocity)
    let backward = pitches <= -BeadsRitualMetrics.commitFraction
      || (pitches <= -BeadsRitualMetrics.flickFraction && input.velocity <= -BeadsRitualMetrics.flickVelocity)
    if forward, canPullForward {
      commitForward()
    } else if backward, canUndo {
      commitUndo()
    } else {
      #if os(iOS)
      if abs(pitches) > 0.08 { haptics.release() }
      #endif
    }
    if turn == nil { transportVelocity = min(3, max(-3, velocity * 0.4)) }
    labelRaised = false
    if reduceMotion { settleInstantly() }
    publish()
    wake()
  }

  func cancelPull() {
    guard pull != nil else { return }
    pull = nil
    isPulling = false
    labelRaised = false
    labelHold = 0
    #if os(iOS)
    haptics.endSlide()
    #endif
    if reduceMotion { settleInstantly() }
    publish()
    wake()
  }

  /// VoiceOver and Switch Control count without a drag.
  func accessibleCount() {
    guard isActive, canPullForward, turn == nil else { return }
    let turning = isHead(restSlot)
    commitForward()
    if !turning { transport = Double(restSlot) - 1 + 0.6 }
    if reduceMotion { settleInstantly() }
    publish()
    wake()
  }

  func accessibleUndo() {
    guard isActive, canUndo, turn == nil else { return }
    let turning = isHead(restSlot - 1)
    commitUndo()
    if !turning { transport = Double(restSlot) + 1 - 0.6 }
    if reduceMotion { settleInstantly() }
    publish()
    wake()
  }

  /// The head bead does not slide: it only gives a little, then the mala
  /// turns on release.
  private func resolvedOffset(_ pitches: Double) -> Double {
    if pitches >= 0 {
      guard canPullForward, !isHead(restSlot) else { return give(pitches) }
      return pitches <= 1 ? pitches : 1 + give(pitches - 1)
    } else {
      guard canUndo, !isHead(restSlot - 1) else { return -give(-pitches) }
      return pitches >= -1 ? pitches : -1 - give(-pitches - 1)
    }
  }

  /// A rubber band that never exceeds a fraction of a pitch, so a blocked pull
  /// still answers the finger without pretending a bead has moved.
  private func give(_ distance: Double) -> Double {
    let limit = BeadsRitualMetrics.giveFraction
    return limit * (1 - exp(-distance / limit))
  }

  private func commitForward() {
    let slot = restSlot
    guard !isHead(slot) else {
      startTurn(1)
      return
    }
    guard actions.count() else { return }
    shape.completed += 1
    if shape.completed % shape.count == 0 { passedHead = false }
    labelHold = BeadsRitualMetrics.labelHoldDuration
    strand.kick(SIMD2(0, BeadsRitualMetrics.countKick))
    if shape.isComplete {
      #if os(iOS)
      haptics.bloom()
      #endif
      beginDissolve()
    } else {
      #if os(iOS)
      haptics.click()
      #endif
    }
  }

  private func commitUndo() {
    let below = restSlot - 1
    guard !isHead(below) else {
      startTurn(-1)
      return
    }
    guard actions.undo() else { return }
    shape.completed -= 1
    if shape.completed > 0, shape.completed % shape.count == 0 { passedHead = true }
    // The numeral names the bead in hand, which is now the one before.
    raiseLabel(for: below - 1)
    labelHold = BeadsRitualMetrics.labelHoldDuration
    #if os(iOS)
    haptics.click()
    #endif
  }

  private func beginDissolve() {
    completion = .dissolving
    dissolveStart = nil
    dissolve = reduceMotion ? 1 : 0
    if reduceMotion { completion = .settled }
    wake()
  }

  private func beginCondense() {
    guard !reduceMotion else { condense = 0; return }
    condense = 1
    wake()
  }

  private func settleInstantly() {
    if let turn, !turn.applied { applyTurn(turn.direction) }
    turn = nil
    transport = Double(restSlot)
    transportVelocity = 0
    grip = 0
    condense = 0
    labelAlpha = labelRaised || labelHold > 0 ? 1 : 0
    if completion == .dissolving { dissolve = 1; completion = .settled }
  }

  private func raiseLabel(for slot: Int) {
    guard case let .bead(number, _) = kind(of: slot) else {
      labelRaised = false
      labelHold = 0
      return
    }
    labelText = formatNumber(number)
    labelRaised = true
    labelHold = 0
  }

  // MARK: - Clock

  var hasEnergy: Bool {
    guard isActive else { return false }
    if reduceMotion { return false }
    return isPulling || turn != nil || condense > 0 || grip > 0 || completion == .dissolving
      || strand.speed > BeadsMalaMetrics.restSpeed || strand.isBouncing
      || abs(transport - Double(restSlot)) > BeadsRitualMetrics.restEnergy
      || abs(transportVelocity) > BeadsRitualMetrics.restEnergy
      || labelHold > 0 || abs(labelAlpha - (labelRaised ? 1 : 0)) > BeadsRitualMetrics.restEnergy
  }

  func step(at time: TimeInterval) {
    guard isActive, !reduceMotion else { return }
    renderedFrameCount &+= 1
    let elapsed = min(BeadsRitualMetrics.maximumFrameTime, max(0, time - (lastTime ?? time)))
    lastTime = time
    guard elapsed > 0 else { return }

    if pull == nil {
      // Critically damped: a bead stops dead against its neighbour; it does not
      // bounce. The frequency is high enough that the stop reads as a click.
      let omega = BeadsRitualMetrics.settleFrequency
      let target = Double(restSlot)
      let displacement = transport - target
      let accelerationTowardsRest = -omega * omega * displacement - 2 * omega * transportVelocity
      transportVelocity += accelerationTowardsRest * elapsed
      transport += transportVelocity * elapsed
      if abs(transport - target) < BeadsRitualMetrics.restEnergy, abs(transportVelocity) < BeadsRitualMetrics.restEnergy {
        transport = target
        transportVelocity = 0
      }
    }

    if var current = turn {
      current.progress += elapsed / BeadsRitualMetrics.turnDuration
      // The swap happens edge on, when the loop has no width to show it.
      if !current.applied, current.progress >= 0.5 {
        applyTurn(current.direction)
        current.applied = true
      }
      turn = current.progress >= 1 ? nil : current
      if turn == nil { publish() }
    }

    if labelRaised || labelHold > 0 {
      labelAlpha = min(1, labelAlpha + elapsed / BeadsRitualMetrics.labelRiseDuration)
      if !labelRaised { labelHold = max(0, labelHold - elapsed) }
    } else {
      labelAlpha = max(0, labelAlpha - elapsed / BeadsRitualMetrics.labelFadeDuration)
    }

    let gripTarget = isPulling ? 1.0 : 0.0
    grip += (gripTarget - grip) * (1 - exp(-elapsed / BeadsRitualMetrics.gripResponse))
    if abs(grip - gripTarget) < BeadsRitualMetrics.restEnergy { grip = gripTarget }
    if condense > 0 {
      condense = max(0, condense - elapsed / BeadsRitualMetrics.condenseDuration)
    }
    if completion == .dissolving {
      let start = dissolveStart ?? time
      dissolveStart = start
      dissolve = min(1, (time - start) / BeadsRitualMetrics.dissolveDuration)
      if dissolve >= 1 {
        completion = .settled
        publish()
      }
    }
    strand.advance(by: elapsed)
  }

  private func publish() { presentationRevision &+= 1 }

  private func wake() { wakeRequest?() }

  private static func smooth(_ value: Double) -> Double {
    let t = min(1, max(0, value))
    return t * t * (3 - 2 * t)
  }

  // MARK: - Sensors

  #if os(iOS)
  private func startSensors() {
    guard sensors.isDeviceMotionAvailable, !reduceMotion else { return }
    sensors.deviceMotionUpdateInterval = BeadsRitualMetrics.sensorInterval
    // Pushed on the main queue rather than polled: a resting stage has no
    // frame callback to poll from, and a shake must still be able to wake it.
    sensors.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
      guard let sample else { return }
      let gravity = SIMD2(sample.gravity.x, sample.gravity.y)
      let acceleration = SIMD2(sample.userAcceleration.x, sample.userAcceleration.y)
      MainActor.assumeIsolated { self?.receive(gravity: gravity, acceleration: acceleration) }
    }
  }

  /// Core Motion reports in the device's own axes: x toward its right edge,
  /// y toward its top. The strand lives in the interface's axes, y down.
  private func receive(gravity: SIMD2<Double>, acceleration: SIMD2<Double>) {
    func project(_ vector: SIMD2<Double>) -> SIMD2<Double> {
      switch hostView?.window?.windowScene?.interfaceOrientation {
      case .landscapeRight: SIMD2(-vector.y, -vector.x)
      case .landscapeLeft: SIMD2(vector.y, vector.x)
      case .portraitUpsideDown: SIMD2(-vector.x, vector.y)
      default: SIMD2(vector.x, -vector.y)
      }
    }
    var down = project(gravity)
    down.y = max(BeadsMalaMetrics.minimumDown, down.y)
    down /= BeadsMala.length(down)
    let shove = project(acceleration)
    let tilted = BeadsMala.length(down - strand.down) > BeadsRitualMetrics.tiltThreshold
    let shaken = BeadsMala.length(shove) > BeadsRitualMetrics.shakeThreshold
    guard tilted || shaken else { return }
    strand.down += (down - strand.down) * BeadsRitualMetrics.sensorSmoothing
    if shaken {
      var eased = strand.shove + (shove - strand.shove) * BeadsRitualMetrics.shakeSmoothing
      let size = BeadsMala.length(eased)
      if size > BeadsRitualMetrics.maximumShake { eased *= BeadsRitualMetrics.maximumShake / size }
      strand.shove = eased
    }
    wake()
  }
  #endif
}

/// Translation and a short-window velocity along the pull axis, in points.
private struct BeadsPullInput {
  private(set) var translation = 0.0
  private(set) var velocity = 0.0
  private var lastTime: TimeInterval

  init(startTime: TimeInterval) { lastTime = startTime }

  mutating func update(translation: Double, time: TimeInterval) {
    let elapsed = time - lastTime
    if elapsed > 0.004 {
      let instantaneous = (translation - self.translation) / elapsed
      let blend = 1 - exp(-elapsed / 0.04)
      velocity += (instantaneous - velocity) * blend
      lastTime = time
    }
    self.translation = translation
  }
}

/// A hint that has done its job once should not come back.
enum BeadsSessionPreferences {
  private static let hintKey = "beads.session.hint.retired"

  static var isHintRetired: Bool {
    get { UserDefaults.standard.bool(forKey: hintKey) }
    set { UserDefaults.standard.set(newValue, forKey: hintKey) }
  }
}
