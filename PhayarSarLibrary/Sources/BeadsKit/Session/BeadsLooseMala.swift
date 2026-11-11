import Foundation

public enum BeadsLooseMalaMetrics {
  public static let damping = 0.985
  public static let iterations = 10
  /// How much of a landing's speed comes back up. A mala is beads on a cord,
  /// not a ball: it thuds, shifts once and lies still.
  public static let restitution = 0.18
  /// Points per second a bead must be falling at for its landing to count.
  public static let impactSpeed = 140.0
  /// The share of sideways speed a bead on the floor loses each step. Low
  /// enough that tilting the phone still slides the heap about.
  public static let floorFriction = 0.04
}

/// The mala after it has slipped off the finger: every bead a free weight,
/// joined to its neighbours by a cord that can go slack but not stretch,
/// falling onto the floor of the stage and coming to rest against the others.
///
/// This is a separate model from `BeadsMala` on purpose. That one is a cord
/// pinned to a finger, and its whole character comes from the two pins. Here
/// nothing is pinned, the beads must not pass through each other, and there
/// is a floor. Folding both into one type meant every line asking which of
/// the two it was.
///
/// The cord is never cut. A broken mala means something to the people who use
/// one, so the joke is that it was dropped, and a dropped mala is still whole.
struct BeadsLooseMala: Sendable {
  typealias Vector = SIMD2<Double>

  /// One point per bead, in order round the closed cord. Same space as
  /// `BeadsMala`: points from the finger's axis, y down.
  private(set) var points: [Vector]
  private var previous: [Vector]
  private var grounded: [Bool]
  private var remainder = 0.0
  let link: Double
  let radius: Double
  /// The lowest a bead's centre may go, and the furthest to either side.
  let floor: Double
  let wall: Double

  init(points: [Vector], link: Double, radius: Double, floor: Double, wall: Double) {
    self.points = points
    previous = points
    grounded = Array(repeating: false, count: points.count)
    self.link = link
    self.radius = radius
    self.floor = floor
    self.wall = wall
  }

  /// A change of velocity for every bead, in points per second.
  mutating func kick(_ impulse: Vector) {
    for index in previous.indices { previous[index] -= impulse * BeadsMalaMetrics.step }
  }

  /// Returns how many beads landed during this stretch of time.
  mutating func advance(by elapsed: Double, down: Vector, shove: Vector) -> Int {
    guard elapsed.isFinite, elapsed > 0 else { return 0 }
    remainder += elapsed
    let acceleration = (down - shove * BeadsMalaMetrics.shakeGain) * BeadsMalaMetrics.gravity
    var landings = 0
    while remainder >= BeadsMalaMetrics.step {
      landings += integrate(acceleration)
      remainder -= BeadsMalaMetrics.step
    }
    return landings
  }

  private mutating func integrate(_ acceleration: Vector) -> Int {
    let step = BeadsMalaMetrics.step
    let count = points.count
    var falling = Array(repeating: 0.0, count: count)
    for index in 0..<count {
      let velocity = (points[index] - previous[index]) * BeadsLooseMalaMetrics.damping
      previous[index] = points[index]
      points[index] += velocity + acceleration * (step * step)
      falling[index] = velocity.y / step
    }
    let apart = radius * 2
    for _ in 0..<BeadsLooseMalaMetrics.iterations {
      // The cord: slack is allowed, stretch is not.
      for index in 0..<count {
        let next = (index + 1) % count
        let delta = points[next] - points[index]
        let distance = max(1e-6, BeadsMala.length(delta))
        guard distance > link else { continue }
        let correction = delta * ((distance - link) / distance * 0.5)
        points[index] += correction
        points[next] -= correction
      }
      // The beads: none may sit inside another.
      for index in 0..<count {
        for other in (index + 1)..<count {
          let delta = points[other] - points[index]
          let distance = BeadsMala.length(delta)
          guard distance < apart else { continue }
          // Two beads in exactly the same place have no direction to part in.
          let direction = distance > 1e-6 ? delta / distance : Vector(1, 0)
          let correction = direction * ((apart - distance) * 0.5)
          points[index] -= correction
          points[other] += correction
        }
      }
      for index in 0..<count {
        points[index].y = min(floor, points[index].y)
        points[index].x = min(wall, max(-wall, points[index].x))
      }
    }
    var landings = 0
    for index in 0..<count {
      let touching = points[index].y >= floor - 0.5
      if touching {
        if !grounded[index], falling[index] > BeadsLooseMalaMetrics.impactSpeed {
          landings += 1
          previous[index].y = points[index].y + falling[index] * step * BeadsLooseMalaMetrics.restitution
        }
        previous[index].x += (points[index].x - previous[index].x) * BeadsLooseMalaMetrics.floorFriction
      }
      grounded[index] = touching
    }
    return landings
  }
}
