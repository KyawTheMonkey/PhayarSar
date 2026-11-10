import Foundation

public enum BeadsMalaMetrics {
  public static let segment = 6.0
  public static let step = 1.0 / 120
  public static let damping = 0.982
  public static let gravity = 1_400.0
  public static let iterations = 26
  public static let settleSteps = 360
  public static let arcSamples = 14
  public static let maximumZoom = 2.6
  /// A mala that nearly fits is drawn a little smaller and whole. Below
  /// this the beads would be too small to hold, so it hangs off instead.
  public static let minimumZoom = 0.72
  /// Room above the loop for the numeral, and below it for a tassel.
  public static let labelRoom = 34.0
  public static let footRoom = 60.0
  /// How hard a shake of the phone throws the strand, relative to gravity.
  public static let shakeGain = 1.3
  public static let shakeDecay = 9.0
  /// A vertical shake lifts the loop toward the finger and lets it drop back.
  /// The cord cannot stretch and hangs taut, so on its own it would ignore an
  /// up or down nudge entirely; this spring is what answers one. It is kept
  /// well below the sideways swing: a nudge, not a second pendulum.
  public static let bounceGain = 22.0
  public static let bounceFrequency = 21.0
  public static let bounceDamping = 0.3
  public static let maximumLift = 0.1
  public static let maximumDrop = 0.025
  public static let bounceWidening = 0.35
  /// How much of a vertical shake still reaches the cord itself.
  public static let verticalShare = 0.25
  public static let bounceRest = 0.0006
  /// A phone lying flat has no meaningful "down"; the strand never hangs
  /// further from straight than this lets it.
  public static let minimumDown = 0.35
  /// The shortest cord that can still dip below the finger between its two
  /// sides. A mala with too few beads to reach that far is strung with more
  /// cord between them rather than with more beads.
  public static let minimumHang = 96.0
  public static let offscreenMargin = 80.0
  public static let fitMargin = 12.0
  /// Points per second below which the strand counts as hanging still.
  public static let restSpeed = 3.0
}

/// The mala as a closed strand in the plane of the screen. It lies over an
/// unseen finger in a half circle that never moves, and everything below that
/// is a hanging cord: a chain of points under gravity, pinned where it leaves
/// the finger on either side. The thumb rests on top of the finger, so the
/// bead in hand is the one at the crown of that half circle. Coordinates are
/// points from the finger's axis, y down.
///
/// The half circle is what makes the finger noticeable. A shape that stays
/// put while the loop beneath it swings reads as something solid, so the two
/// pins are deliberately the only parts that a tilt or a shake cannot move.
///
/// Time advances in fixed steps, so neither the display's refresh rate nor a
/// dropped frame changes how heavy the strand feels.
struct BeadsMala: Sendable {
  typealias Vector = SIMD2<Double>

  /// Beads round the closed strand, the head bead included.
  let lattice: Int
  /// The distance along the strand from one bead to the next.
  let pitch: Double
  /// Unit vector toward the ground as the screen sees it.
  var down = Vector(0, 1)
  /// The phone's own acceleration in the screen plane, in g.
  var shove = Vector.zero
  private(set) var speed = 0.0
  /// How far the loop is lifted toward the finger, as a fraction of its hang.
  private(set) var bounce = 0.0
  private var bounceVelocity = 0.0
  /// The whole strand in the direction a counted bead travels: from the
  /// pinch down the near side, round the bottom, up the far side, and over
  /// the finger back to the pinch.
  private(set) var path: [Vector] = []
  private(set) var cumulative: [Double] = []
  /// Distance along `path` to its lowest point.
  private(set) var bottom = 0.0
  private var rope: [Vector] = []
  private var previous: [Vector] = []
  private var segmentLength = BeadsMalaMetrics.segment
  private var remainder = 0.0

  static let radius = Double(BeadsRitualMetrics.fingerRadius + BeadsRitualMetrics.beadRadius)
  /// Where the thumb presses a bead to the finger, and where the strand
  /// leaves the finger on the near and far sides.
  static let pinch = Vector(0, -radius)
  static let near = Vector(radius, 0)
  static let far = Vector(-radius, 0)
  private static func arc(from start: Double, to end: Double) -> [Vector] {
    (0...BeadsMalaMetrics.arcSamples).map { index in
      let angle = start + (end - start) * Double(index) / Double(BeadsMalaMetrics.arcSamples)
      return Vector(radius * cos(angle), -radius * sin(angle))
    }
  }
  static let nearArc = arc(from: .pi / 2, to: 0)
  static let farArc = arc(from: .pi, to: .pi / 2)
  static let arcLength = Double.pi * radius
  /// From the finger's axis up to the top of everything drawn above it.
  static let headroom = radius + Double(BeadsRitualMetrics.beadRadius * BeadsRitualMetrics.headScale)
    + BeadsMalaMetrics.labelRoom

  /// The loop is the real mala whenever it fits: one bead per count and one
  /// head bead, never a second. It is not padded with repeats to look fuller,
  /// because a mala has exactly one head bead and two would be a lie about
  /// where a round ends. A short mala is instead brought closer, so five
  /// beads are five large beads rather than a small ring in an empty stage.
  /// One far too long to fit hangs off the bottom as two strands. What shows
  /// then is a stretch of the mala no longer than the mala itself, so the head
  /// bead can never appear twice.
  static func fit(count: Int, height: Double) -> (lattice: Int, zoom: Double) {
    let honest = max(2, count + 1)
    let rope = Double(honest) * pitch(lattice: honest) - arcLength
    let chord = 2 * radius
    let dip = rope >= .pi * radius
      ? (rope - .pi * radius) / 2 + radius
      : max(0, rope * rope - chord * chord).squareRoot() / 2
    let extent = headroom + dip + Double(BeadsRitualMetrics.beadRadius) + BeadsMalaMetrics.footRoom
    let zoom = (height - BeadsMalaMetrics.fitMargin) / extent
    if zoom >= BeadsMalaMetrics.minimumZoom { return (honest, min(BeadsMalaMetrics.maximumZoom, zoom)) }
    let hanging = arcLength + 2 * (height - headroom + BeadsMalaMetrics.offscreenMargin) + .pi * radius
    return (min(honest, max(3, Int((hanging / Double(BeadsRitualMetrics.pitch)).rounded(.up)))), 1)
  }

  /// Beads sit shoulder to shoulder unless there are too few to go round.
  static func pitch(lattice: Int) -> Double {
    max(Double(BeadsRitualMetrics.pitch), (arcLength + BeadsMalaMetrics.minimumHang) / Double(max(2, lattice)))
  }

  init(lattice: Int) {
    self.lattice = max(2, lattice)
    pitch = Self.pitch(lattice: self.lattice)
    let ropeLength = Double(self.lattice) * pitch - Self.arcLength
    let count = max(8, Int((ropeLength / BeadsMalaMetrics.segment).rounded()))
    segmentLength = ropeLength / Double(count)
    let depth = max(16, (ropeLength - 2 * Self.radius) / 2)
    rope = (0...count).map { index in
      let t = Double(index) / Double(count)
      let eased = t * t * (3 - 2 * t)
      return Vector(Self.near.x + (Self.far.x - Self.near.x) * eased, sin(t * .pi) * depth)
    }
    previous = rope
    // Settle before the first frame rather than visibly dropping a new mala.
    for _ in 0..<BeadsMalaMetrics.settleSteps { integrate() }
    previous = rope
    speed = 0
    rebuildPath()
  }

  var length: Double { cumulative.last ?? 0 }

  var isBouncing: Bool {
    abs(bounce) > BeadsMalaMetrics.bounceRest || abs(bounceVelocity) > BeadsMalaMetrics.bounceRest * 20
  }

  mutating func advance(by elapsed: Double) {
    guard elapsed.isFinite, elapsed > 0 else { return }
    remainder += elapsed
    var stepped = false
    while remainder >= BeadsMalaMetrics.step {
      integrate()
      remainder -= BeadsMalaMetrics.step
      stepped = true
    }
    shove *= exp(-elapsed * BeadsMalaMetrics.shakeDecay)
    if stepped { rebuildPath() }
  }

  /// A change of velocity for the hanging part, in points per second.
  mutating func kick(_ impulse: Vector) {
    guard rope.count > 2 else { return }
    for index in 1..<(rope.count - 1) { previous[index] -= impulse * BeadsMalaMetrics.step }
  }

  func point(at distance: Double) -> Vector {
    guard path.count > 1 else { return Self.pinch }
    let clamped = min(length, max(0, distance))
    var low = 0, high = cumulative.count - 1
    while high - low > 1 {
      let middle = (low + high) / 2
      if cumulative[middle] <= clamped { low = middle } else { high = middle }
    }
    let span = max(1e-6, cumulative[high] - cumulative[low])
    return path[low] + (path[high] - path[low]) * ((clamped - cumulative[low]) / span)
  }

  private mutating func integrate() {
    let step = BeadsMalaMetrics.step
    let felt = Vector(shove.x, shove.y * BeadsMalaMetrics.verticalShare)
    let acceleration = (down - felt * BeadsMalaMetrics.shakeGain) * BeadsMalaMetrics.gravity
    // The phone dropping away leaves the beads behind, so they rise; the
    // spring brings them back down and lets them overshoot a little.
    let omega = BeadsMalaMetrics.bounceFrequency
    bounceVelocity += (shove.y * BeadsMalaMetrics.bounceGain - omega * omega * bounce
      - 2 * BeadsMalaMetrics.bounceDamping * omega * bounceVelocity) * step
    bounce += bounceVelocity * step
    if bounce > BeadsMalaMetrics.maximumLift {
      bounce = BeadsMalaMetrics.maximumLift
      bounceVelocity = min(0, bounceVelocity)
    } else if bounce < -BeadsMalaMetrics.maximumDrop {
      bounce = -BeadsMalaMetrics.maximumDrop
      bounceVelocity = max(0, bounceVelocity)
    }
    let last = rope.count - 1
    var fastest = 0.0
    for index in 1..<last {
      let velocity = (rope[index] - previous[index]) * BeadsMalaMetrics.damping
      previous[index] = rope[index]
      rope[index] += velocity + acceleration * (step * step)
      fastest = max(fastest, Self.length(velocity))
    }
    speed = fastest / step
    // Position-based links keep a hard shake from stretching the cord. The
    // two ends stay exactly where the finger holds them.
    for _ in 0..<BeadsMalaMetrics.iterations {
      rope[0] = Self.near
      rope[last] = Self.far
      for index in 0..<last {
        let delta = rope[index + 1] - rope[index]
        let distance = max(1e-6, Self.length(delta))
        let correction = delta * ((distance - segmentLength) / distance)
        let pinnedStart = index == 0, pinnedEnd = index + 1 == last
        let startShare = pinnedStart ? 0.0 : (pinnedEnd ? 1.0 : 0.5)
        let endShare = pinnedEnd ? 0.0 : (pinnedStart ? 1.0 : 0.5)
        rope[index] += correction * startShare
        rope[index + 1] -= correction * endShare
      }
    }
    rope[0] = Self.near
    rope[last] = Self.far
  }

  private mutating func rebuildPath() {
    // The lift gathers the loop up toward the finger and lets it belly out a
    // little, as slack cord does. It fades to nothing at the finger, so the
    // two ends stay exactly where they are held.
    let hanging = rope.dropFirst().map { point -> Vector in
      let hold = min(1, max(0, point.y / Self.radius))
      let eased = hold * hold * (3 - 2 * hold)
      return Vector(point.x * (1 + bounce * BeadsMalaMetrics.bounceWidening * eased), point.y * (1 - bounce * eased))
    }
    path = Self.nearArc + hanging + Self.farArc.dropFirst()
    cumulative = [0]
    cumulative.reserveCapacity(path.count)
    var lowest = 0
    for index in 1..<path.count {
      cumulative.append(cumulative[index - 1] + Self.length(path[index] - path[index - 1]))
      if path[index].y > path[lowest].y { lowest = index }
    }
    bottom = cumulative[lowest]
  }

  static func length(_ vector: Vector) -> Double { (vector.x * vector.x + vector.y * vector.y).squareRoot() }
}
