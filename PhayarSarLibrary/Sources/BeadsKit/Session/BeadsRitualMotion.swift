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
  /// Starting over winds the beads back past the thumb. A few beads take a
  /// moment each; a long mala is capped so the rewind never becomes a wait.
  public static let rewindBaseDuration = 0.3
  public static let rewindBeadDuration = 0.1
  public static let rewindMaximumDuration = 1.8
  /// Ticks closer together than this blur into a buzz.
  public static let rewindTickInterval = 0.05
  public static let rewindKick = 40.0
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
  /// Beads counted closer together than this cannot each have had a
  /// recitation said over them: it is more than four a second. One quick pair
  /// means nothing, so the pace has to hold for `paceRun` gaps in a row, five
  /// beads, before the mala objects, and for `slipRun` before it is dropped.
  public static let paceInterval = 0.25
  public static let paceRun = 4
  public static let slipRun = 7
  /// On a round too short for those, the fewest fast gaps that still count
  /// as a pace, and how many beads of warning must come before a drop.
  public static let minimumPaceRun = 2
  public static let slipWarning = 2
  /// How long the warning outlives the last bead that was too fast.
  public static let strainHold = 1.6
  public static let strainResponse = 0.12
  /// A taut cord gives less to the thumb, so each bead needs a longer pull.
  public static let strainDrag = 0.25
  public static let strainNarrowing = 0.28
  public static let strainStretch = 0.05
  public static let strainTremor = 1.3
  public static let strainTremorFrequency = 17.0
  /// From leaving the finger to being picked up again, then the lift itself.
  public static let slipFloorDuration = 2.0
  public static let slipRiseDuration = 1.0
  public static let slipImpactInterval = 0.045
  /// How long beads being put back take to get going. 1 is an even ease;
  /// higher holds them back longer and brings them in faster.
  public static let gatherPower = 1.8
  public static let slipRiseRelaxation = 6
  public static let slipKick = SIMD2<Double>(70, 40)
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

  private struct Rewind {
    var from: Double
    var duration: Double
    var progress = 0.0
    var sinceTick = 0.0
  }

  /// How the mala is taking the pace it is being counted at.
  enum Pace: Equatable { case steady, strained, dropped }

  /// A bead off the finger. `slot` is which bead it is, fixed for the whole
  /// fall so a bead cannot change into another one on the floor; `distance` is
  /// where on the strand it will be put back.
  struct LooseBead {
    var slot: Int
    var point: SIMD2<Double>
    var distance: Double
  }

  private struct Slip {
    var mala: BeadsLooseMala
    var elapsed = 0.0
    var sinceImpact = 0.0
    var rise: Double?
    var from: [SIMD2<Double>] = []
  }

  private struct Turn {
    var direction: Int
    var progress = 0.0
    var applied = false
  }

  @Published private(set) var isPulling = false
  @Published private(set) var completion = Completion.none
  @Published private(set) var presentationRevision = 0
  @Published private(set) var pace = Pace.steady
  /// Counts the times the mala has made its entrance, so that what SwiftUI
  /// draws can make the same entrance at the same moment. The entrance itself
  /// runs on the scene's clock and is never published frame by frame.
  @Published private(set) var entranceRevision = 0

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
  /// How taut the cord is drawn, and the shiver that goes with it.
  private(set) var tension = 0.0
  private(set) var tremor = 0.0
  /// The beads while the mala is off the finger, and how far off it is:
  /// 1 on the floor, easing to 0 as it is lifted back.
  private(set) var loose: [LooseBead]?
  private(set) var looseness = 0.0
  private var turn: Turn?
  private var rewind: Rewind?
  private var slip: Slip?
  private var lastCountTime: TimeInterval?
  private var fastRun = 0
  private var burstBase = 0
  private var hasSlipped = false
  private var paceToken = 0
  private var clock = 0.0
  private var height = 0.0
  private var width = 0.0
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
    countDidChange()
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
    // Starting over mid-practice is shown, not cut to: the beads counted in
    // this round run back past the thumb until the head bead is in hand
    // again. Earlier rounds need no unwinding. Every bead but the head is
    // alike, and a turned mala looks the same as an unturned one, so the head
    // bead is only ever this round's count away from the thumb.
    let counted = positionInRound.count
    let startsOver = isActive && !reduceMotion && completion == .none
      && newShape.completed == 0 && previous.completed > 0
      && newShape.count == previous.count && newShape.rounds == previous.rounds
    shape = newShape
    if newShape.completed == 0 { passedHead = false }
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
    countDidChange()
    if startsOver, counted > 0 {
      beginRewind(beads: counted)
    } else if pull == nil, turn == nil, rewind == nil {
      transport = Double(restSlot)
    }
    wake()
  }

  private func beginRewind(beads: Int) {
    cancelPull()
    turn = nil
    labelRaised = false
    labelHold = 0
    transportVelocity = 0
    // The same picture as before the reset, counted from the new first bead.
    transport = Double(restSlot + beads)
    rewind = Rewind(from: transport, duration: min(BeadsRitualMetrics.rewindMaximumDuration,
      BeadsRitualMetrics.rewindBaseDuration + BeadsRitualMetrics.rewindBeadDuration * Double(beads)))
    publish()
  }

  /// The scene reports how tall the stage is. A mala that fits is drawn
  /// whole and as large as the stage allows; one that does not hangs off
  /// the bottom.
  func layout(height: CGFloat, width: CGFloat) {
    self.width = Double(width)
    guard abs(Double(height) - self.height) > 0.5 else { return }
    self.height = Double(height)
    rebuildStrand()
  }

  private func rebuildStrand() {
    guard height > 0 else { return }
    // Not while the mala is off the finger. The loose beads are the strand's
    // own, one for one, and a strand restrung under them leaves the scene
    // with nothing it can match them to. This was found the hard way: a line
    // leaving the footer at the moment of the drop made the stage a little
    // taller, a long mala was restrung to suit, and the fall never showed.
    // The new size is taken up when the mala is back.
    guard slip == nil else { return }
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
      if rewind != nil {
        rewind = nil
        transport = Double(restSlot)
      }
      endSlip()
      paceToken &+= 1
      pace = .steady
      tension = 0
      lastCountTime = nil
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
    guard isActive, pull == nil, turn == nil, rewind == nil, slip == nil else { return }
    pull = BeadsPullInput(startTime: time.timeIntervalSinceReferenceDate)
    isPulling = true
    showCount(raised: true)
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
    let pitches = input.translation / (strand.pitch * zoom) * drag
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
    let pitches = input.translation / (strand.pitch * zoom) * drag
    let velocity = input.velocity / (strand.pitch * zoom)
    let forward = pitches >= BeadsRitualMetrics.commitFraction
      || (pitches >= BeadsRitualMetrics.flickFraction && input.velocity >= BeadsRitualMetrics.flickVelocity)
    let backward = pitches <= -BeadsRitualMetrics.commitFraction
      || (pitches <= -BeadsRitualMetrics.flickFraction && input.velocity <= -BeadsRitualMetrics.flickVelocity)
    if forward, canPullForward {
      commitForward(paced: true)
    } else if backward, canUndo {
      commitUndo()
    } else {
      #if os(iOS)
      if abs(pitches) > 0.08 { haptics.release() }
      #endif
    }
    if turn == nil, slip == nil { transportVelocity = min(3, max(-3, velocity * 0.4)) }
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
    guard isActive, canPullForward, turn == nil, rewind == nil, slip == nil else { return }
    let turning = isHead(restSlot)
    commitForward()
    if !turning { transport = Double(restSlot) - 1 + 0.6 }
    if reduceMotion { settleInstantly() }
    publish()
    wake()
  }

  func accessibleUndo() {
    guard isActive, canUndo, turn == nil, rewind == nil, slip == nil else { return }
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

  /// `paced` is a bead counted by a pull of the thumb. VoiceOver and Switch
  /// Control count through an action, at whatever speed their own gesture
  /// allows, and are never told they are going too fast.
  private func commitForward(paced: Bool = false) {
    let slot = restSlot
    guard !isHead(slot) else {
      startTurn(1)
      return
    }
    guard actions.count() else { return }
    shape.completed += 1
    if shape.completed % shape.count == 0 { passedHead = false }
    countDidChange()
    showCount(raised: false)
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
      if paced { notePace() }
    }
  }

  // MARK: - Pace

  /// The floor of the stage in the strand's own space, while the mala is on it.
  var looseFloor: Double? { slip.flatMap { $0.mala.floor.isFinite ? $0.mala.floor + $0.mala.radius : nil } }

  private var drag: Double { 1 - BeadsRitualMetrics.strainDrag * tension }

  /// Too fast is judged on counted beads only, and only on a run of them.
  /// The threshold means impossible, not quick: a short mantra said briskly
  /// must never be scolded.
  private func notePace() {
    let now = ProcessInfo.processInfo.systemUptime
    defer { lastCountTime = now }
    guard let last = lastCountTime, now - last <= BeadsRitualMetrics.paceInterval else {
      fastRun = 0
      // What the count was before this burst, should it turn out to be one.
      burstBase = shape.completed - 1
      return
    }
    fastRun += 1
    // A burst cannot run past the head bead: turning the mala takes longer
    // than the pace allows. So on a short mala the most a person can do is
    // hurry through one whole round, and that is what drops it. The cord
    // still tightens at least two beads sooner, because a drop that comes
    // without a warning is a punishment and not a joke; a round too short to
    // leave room for the warning only ever tightens.
    let slipRun = min(BeadsRitualMetrics.slipRun, shape.count - 1)
    let paceRun = min(BeadsRitualMetrics.paceRun, max(BeadsRitualMetrics.minimumPaceRun, slipRun - BeadsRitualMetrics.slipWarning))
    guard fastRun >= paceRun else { return }
    // Dropped once. After that the cord only tightens: a joke told twice in
    // one sitting is an obstacle.
    if fastRun >= slipRun, slipRun > paceRun, !hasSlipped, !reduceMotion, height > 0 {
      beginSlip()
    } else {
      strain()
    }
  }

  private func strain() {
    if pace != .strained {
      pace = .strained
      #if os(iOS)
      haptics.strain()
      #endif
    }
    paceToken &+= 1
    let token = paceToken
    // A timer and not the frame clock: with Reduce Motion there are no frames,
    // and the warning must still lift once the person slows down.
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(BeadsRitualMetrics.strainHold * 1_000_000_000))
      guard let self, self.paceToken == token, self.pace == .strained else { return }
      self.pace = .steady
      self.wake()
    }
  }

  /// The mala comes off the finger whole and falls. The beads counted in the
  /// burst are given back first, so what is picked up again is the mala as it
  /// was before the hurry, at the bead the person was really on.
  private func beginSlip() {
    let length = strand.length
    guard length > 0 else { return }
    hasSlipped = true
    cancelPull()
    let count = strand.lattice
    let pitch = length / Double(count)
    let hand = inHand
    let first = Int((hand - 1e-6).rounded(.up))
    // Exactly the beads as they are drawn at this instant.
    var beads = (0..<count).map { index -> LooseBead in
      let distance = length - (Double(first + index) - hand) * pitch
      let slot = distance < strand.bottom ? first + index - count : first + index
      return LooseBead(slot: slot, point: strand.point(at: distance), distance: distance)
    }

    while shape.completed > max(0, burstBase), actions.undo() {
      shape.completed -= 1
      if shape.completed > 0, shape.completed % shape.count == 0 { passedHead = true }
    }
    countDidChange()
    fastRun = 0
    lastCountTime = nil
    labelRaised = false
    labelHold = 0
    transport = Double(restSlot)
    transportVelocity = 0
    let restored = inHand
    for index in beads.indices {
      var distance = (length - (Double(first + index) - restored) * pitch).truncatingRemainder(dividingBy: length)
      if distance <= 0 { distance += length }
      beads[index].distance = distance
    }

    let radius = Double(BeadsRitualMetrics.beadRadius)
    // A mala too long for the stage already hangs out of sight below it. A
    // floor at the bottom of the stage would be above those beads, and they
    // would be shoved up onto it and stack upwards: a mala falling against
    // gravity. It has no floor at all: it slides away off the bottom of the
    // screen, past the footer, and is drawn back up.
    let stageFloor = height / zoom - BeadsMala.headroom - radius
    let lowest = beads.map(\.point.y).max() ?? 0
    var mala = BeadsLooseMala(points: beads.map(\.point), link: pitch, radius: radius,
      floor: lowest > stageFloor ? .infinity : stageFloor,
      wall: width > 0 ? max(radius, width / 2 / zoom - radius) : .infinity)
    mala.kick(BeadsRitualMetrics.slipKick)
    slip = Slip(mala: mala)
    loose = beads
    looseness = 1
    paceToken &+= 1
    pace = .dropped
    #if os(iOS)
    haptics.release()
    #endif
    publish()
    wake()
  }

  private func endSlip() {
    guard slip != nil else { return }
    slip = nil
    loose = nil
    looseness = 0
    if pace == .dropped { pace = .steady }
    rebuildStrand()
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
    countDidChange()
    showCount(raised: false)
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
    entranceRevision &+= 1
    wake()
  }

  private func settleInstantly() {
    if let turn, !turn.applied { applyTurn(turn.direction) }
    turn = nil
    rewind = nil
    endSlip()
    tension = 0
    transport = Double(restSlot)
    transportVelocity = 0
    grip = 0
    condense = 0
    labelAlpha = labelRaised || labelHold > 0 ? 1 : 0
    if completion == .dissolving { dissolve = 1; completion = .settled }
  }

  /// The footer reads its count from here, but it is drawn by SwiftUI, which
  /// only looks again when told to. The store's own publish is not a safe
  /// signal to lean on: it fires from inside the save, before `shape` has
  /// moved, and a turn at the head bead changes the count without saving
  /// anything at all. So every change to the count, or to which side of the
  /// head bead it is on, announces itself here after the fact.
  private func countDidChange() { objectWillChange.send() }

  /// The numeral beside the bead in hand is the count so far, the same
  /// number the footer shows, at every moment. It once named the bead being
  /// pulled instead, which ran one ahead of the footer through every drag and
  /// two ahead of where a reverse pull was going.
  private func showCount(raised: Bool) {
    let count = positionInRound.count
    guard count > 0 else {
      labelRaised = false
      labelHold = 0
      return
    }
    labelText = formatNumber(count)
    labelRaised = raised
    if !raised { labelHold = BeadsRitualMetrics.labelHoldDuration }
  }

  // MARK: - Clock

  var hasEnergy: Bool {
    guard isActive else { return false }
    if reduceMotion { return false }
    return isPulling || turn != nil || rewind != nil || slip != nil || pace == .strained
      || tension > BeadsRitualMetrics.restEnergy || condense > 0 || grip > 0 || completion == .dissolving
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
    clock += elapsed

    let taut = pace == .strained ? 1.0 : 0.0
    tension += (taut - tension) * (1 - exp(-elapsed / BeadsRitualMetrics.strainResponse))
    if abs(tension - taut) < BeadsRitualMetrics.restEnergy { tension = taut }
    tremor = sin(clock * 2 * .pi * BeadsRitualMetrics.strainTremorFrequency) * tension

    if var current = slip, var beads = loose {
      current.elapsed += elapsed
      if let rise = current.rise {
        // Lifted back over the finger, each bead to its own place.
        let progress = min(1, rise + elapsed / BeadsRitualMetrics.slipRiseDuration)
        let eased = Self.gather(progress)
        for index in beads.indices {
          beads[index].point = current.from[index] + (strand.point(at: beads[index].distance) - current.from[index]) * eased
        }
        // A straight line from where a bead lay to where it belongs can take
        // it through its neighbours: the heap and the loop are not the same
        // way round. Beads are solid, so they shoulder past each other.
        let apart = Double(BeadsRitualMetrics.beadRadius) * 2
        for _ in 0..<BeadsRitualMetrics.slipRiseRelaxation {
          for index in beads.indices {
            for other in (index + 1)..<beads.count {
              let delta = beads[other].point - beads[index].point
              let distance = BeadsMala.length(delta)
              guard distance < apart else { continue }
              let direction = distance > 1e-6 ? delta / distance : SIMD2(1, 0)
              let correction = direction * ((apart - distance) * 0.5)
              beads[index].point -= correction
              beads[other].point += correction
            }
          }
        }
        looseness = 1 - eased
        if progress >= 1 {
          endSlip()
          strand.kick(SIMD2(0, BeadsRitualMetrics.countKick))
          #if os(iOS)
          haptics.release()
          #endif
          publish()
        } else {
          current.rise = progress
          slip = current
          loose = beads
        }
      } else {
        let landings = current.mala.advance(by: elapsed, down: strand.down, shove: strand.shove)
        for index in beads.indices { beads[index].point = current.mala.points[index] }
        current.sinceImpact += elapsed
        if landings > 0, current.sinceImpact >= BeadsRitualMetrics.slipImpactInterval {
          current.sinceImpact = 0
          #if os(iOS)
          haptics.tick()
          #endif
        }
        if current.elapsed >= BeadsRitualMetrics.slipFloorDuration {
          current.from = current.mala.points
          current.rise = 0
        }
        slip = current
        loose = beads
      }
    }

    if var current = rewind {
      let before = transport
      let target = Double(restSlot)
      current.progress = min(1, current.progress + elapsed / current.duration)
      current.sinceTick += elapsed
      transport = target + (current.from - target) * (1 - Self.gather(current.progress))
      if current.progress >= 1 {
        // The head bead is back under the thumb.
        transport = target
        rewind = nil
        strand.kick(SIMD2(0, BeadsRitualMetrics.rewindKick))
        #if os(iOS)
        haptics.head()
        #endif
        publish()
      } else {
        // One tick as each bead passes the thumb, as far as they can be told apart.
        let passed = Int(before.rounded(.up)) - Int(transport.rounded(.up))
        if passed > 0, current.sinceTick >= BeadsRitualMetrics.rewindTickInterval {
          current.sinceTick = 0
          #if os(iOS)
          haptics.tick()
          #endif
        }
        rewind = current
      }
    } else if pull == nil {
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

  /// For beads being put back where they belong: after a drop, and when
  /// starting over. They set off slowly, gather speed, and are moving fast
  /// when they arrive, then settle. An even ease in and out made the return
  /// look carried; this makes it look let go of. The start is stretched and
  /// the stop is left as it was, so the last bead still lands softly.
  private static func gather(_ value: Double) -> Double {
    smooth(pow(min(1, max(0, value)), BeadsRitualMetrics.gatherPower))
  }

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
