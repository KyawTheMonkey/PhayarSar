import Foundation

enum BeadsRoundsMotionMetrics {
  static let amplitude = CGFloat(1)...CGFloat(1.05)
  static let asymmetry = CGFloat(0.14)...CGFloat(0.25)
  static let sway = CGFloat(0.12)...CGFloat(0.23)
  static let tassel = CGFloat(0.2)...CGFloat(0.4)
  static let windUp = 0.16...0.22
  static let hold = 0.03...0.065
  static let lag = 0.035...0.07
  static let release = 0.44...0.62
  static let damping = 0.64...0.77
  static let bendWindUpMultiplier = 1.8
  static let swayWindUpMultiplier = 2.1
  static let bendReleaseMultiplier = 1.15
  static let swayReleaseMultiplier = 1.35
  static let tasselReleaseMultiplier = 1.55
  static let secondaryDamping = 0.64
  static let tasselDamping = 0.58
}

/// Sample once per gesture, never per frame. Independent shape and swing
/// channels keep each gesture coherent while avoiding the identical, mirrored
/// wind-up/release that made the earlier figure eight feel mechanical.
struct BeadsRoundsMotion {
  let amplitude = CGFloat.random(in: BeadsRoundsMotionMetrics.amplitude)
  let asymmetry = CGFloat.random(in: BeadsRoundsMotionMetrics.asymmetry) * (Bool.random() ? 1 : -1)
  let sway = CGFloat.random(in: BeadsRoundsMotionMetrics.sway) * (Bool.random() ? 1 : -1)
  let tassel = CGFloat.random(in: BeadsRoundsMotionMetrics.tassel)
  let windUp = Double.random(in: BeadsRoundsMotionMetrics.windUp)
  let hold = Double.random(in: BeadsRoundsMotionMetrics.hold)
  let lag = Double.random(in: BeadsRoundsMotionMetrics.lag)
  let release = Double.random(in: BeadsRoundsMotionMetrics.release)
  let damping = Double.random(in: BeadsRoundsMotionMetrics.damping)
}
