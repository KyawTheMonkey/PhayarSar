#if os(iOS) || os(macOS)
import DesignKit
import SpriteKit
import SwiftUI

/// Draws the mala hanging over an unseen finger. No hand is drawn at all: the
/// finger shows only in what it does to the beads. They bend round it in a
/// half circle that never moves, the ones resting on it carry its warmth in
/// their reflection, and the ones coming up beneath it pass through its
/// shadow before they climb into the light.
///
/// The scene covers the whole screen so nothing clips at the edge of the
/// strand's region; SwiftUI tells it where that region is. Lattice points on
/// the closed strand are mapped to a small pool of bead sprites each frame.
/// The pool holds identity only and every visual property is set from the
/// slot, so a mala of any length reuses the same few nodes.
@MainActor
final class BeadsRitualScene: SKScene {
  /// A head bead's fittings, and where its tassel has swung to. The tassel is
  /// a weight on a thread of its own: it lags the bead it hangs from and
  /// swings on after the bead has stopped, which is what makes a shake read
  /// as cloth and not as a drawing being rotated.
  @MainActor
  private final class Head {
    let tower: SKSpriteNode
    let tassel = SKShapeNode()
    let binding = SKShapeNode()
    var end = SIMD2<Double>.zero
    var previous = SIMD2<Double>.zero
    var isHanging = false

    init(tower: SKSpriteNode) { self.tower = tower }
  }

  private weak var motion: BeadsRitualMotion?
  private let strand = SKNode()
  private let cordShade = SKShapeNode()
  private let cord = SKShapeNode()
  private let label = SKLabelNode()
  private var beads: [SKSpriteNode] = []
  private var heads: [Head] = []
  private let beadMaterial = BeadsSpriteAssets.beadShader()
  private var geometry: BeadsRailGeometry?
  private var pendingSize: CGSize?
  private var pendingGeometry: BeadsRailGeometry?
  private var pendingScheme: ColorScheme?
  private var pendingMaterial: BeadsMaterial?
  private var scheme: ColorScheme?
  private var material: BeadsMaterial?
  private var tasselColor = SKColor.white
  private var bindingColor = SKColor.white
  private var lastUpdate: TimeInterval?
  private var frameTime = 0.0
  private var tasselSpeed = 0.0
  private var quiet = 0.0

  init(motion: BeadsRitualMotion) {
    self.motion = motion
    super.init(size: CGSize(width: 390, height: 844))
    scaleMode = .resizeFill
    anchorPoint = .zero
    backgroundColor = .clear
    physicsWorld.gravity = .zero
    addChild(strand)
    for (node, width, depth) in [(cordShade, BeadsSpriteMetrics.cordShadeWidth, 0.0), (cord, BeadsSpriteMetrics.cordWidth, 0.1)] {
      node.lineWidth = width
      node.lineJoin = .round
      node.fillColor = .clear
      node.isAntialiased = true
      node.zPosition = depth
      strand.addChild(node)
    }
    cordShade.strokeColor = .black
    #if os(iOS)
    label.fontName = AppUIFont.statValue.fontName
    #endif
    label.fontSize = BeadsSpriteMetrics.labelFontSize
    label.verticalAlignmentMode = .center
    label.horizontalAlignmentMode = .center
    label.zPosition = 8
    label.alpha = 0
    strand.addChild(label)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  /// Something may be about to move: keep drawing until it has had the
  /// chance to, whatever the last frame looked like.
  func wake() { quiet = 0 }

  func request(size: CGSize, geometry: BeadsRailGeometry, scheme: ColorScheme, material: BeadsMaterial) {
    pendingSize = size
    pendingGeometry = geometry
    pendingScheme = scheme
    pendingMaterial = material
  }

  override func update(_ currentTime: TimeInterval) {
    guard let motion else { view?.isPaused = true; return }
    applyConfiguration(motion)
    frameTime = min(BeadsRitualMetrics.maximumFrameTime, max(0, currentTime - (lastUpdate ?? currentTime)))
    lastUpdate = currentTime
    tasselSpeed = 0
    motion.step(at: currentTime)
    guard geometry != nil, material != nil else { return }
    layoutStrand(motion)
    if let view {
      let preferred = BeadsRitualScene.conserving
        ? BeadsSpriteMetrics.conservingFramesPerSecond : BeadsSpriteMetrics.preferredFramesPerSecond
      if view.preferredFramesPerSecond != preferred { view.preferredFramesPerSecond = preferred }
    }
  }

  override func didFinishUpdate() {
    // At rest nothing on the stage changes, so the render loop stops. Touch,
    // a tilt, a shake and layout changes unpause the view before the next frame.
    // Stillness has to last before it counts. Anything that swings is
    // momentarily motionless at the top of each swing, and a stage that
    // paused on the first still frame froze there, mid-air, until the next
    // touch. A tassel can also still be swinging after the strand has settled.
    let busy = motion?.hasEnergy == true || tasselSpeed >= BeadsRitualMetrics.tasselRestSpeed
    quiet = busy ? 0 : quiet + frameTime
    if quiet >= BeadsRitualMetrics.restDelay {
      view?.isPaused = true
      lastUpdate = nil
    }
  }

  /// During power or thermal pressure, halve redraws. The motion model keeps
  /// its own elapsed time, so the strand settles at the same speed.
  private static var conserving: Bool {
    let process = ProcessInfo.processInfo
    if process.isLowPowerModeEnabled { return true }
    switch process.thermalState {
    case .serious, .critical: return true
    default: return false
    }
  }

  private func applyConfiguration(_ motion: BeadsRitualMotion) {
    if let pendingSize, pendingSize.width > 0, pendingSize.height > 0 {
      if size != pendingSize { size = pendingSize }
      self.pendingSize = nil
    }
    if let pendingGeometry {
      geometry = pendingGeometry
      self.pendingGeometry = nil
      motion.layout(height: pendingGeometry.region.height)
    }
    if let pendingScheme, pendingScheme != scheme {
      let palette = AppColor.BeadsSession.renderingPalette(for: pendingScheme)
      beadMaterial.skin.vectorFloat4Value = BeadsSpriteAssets.vector(palette.skin)
      label.fontColor = BeadsSpriteAssets.native(palette.numeral)
      scheme = pendingScheme
    }
    pendingScheme = nil
    if let pendingMaterial, pendingMaterial != material {
      let palette = pendingMaterial.palette
      beadMaterial.apply(pendingMaterial)
      cord.strokeColor = BeadsSpriteAssets.native(palette.cord)
      tasselColor = BeadsSpriteAssets.native(palette.tassel)
      bindingColor = BeadsSpriteAssets.native(palette.binding)
      for head in heads { head.tassel.strokeColor = tasselColor; head.binding.strokeColor = bindingColor }
      material = pendingMaterial
    }
    pendingMaterial = nil
  }

  // MARK: - Strand

  private func layoutStrand(_ motion: BeadsRitualMotion) {
    guard let material, let geometry, let view else { return }
    // The finger's axis sits far enough below the top of the region for the
    // crown of the loop and the numeral above it, at whatever size the mala
    // is drawn.
    let zoom = CGFloat(motion.zoom)
    let region = geometry.region
    strand.position = CGPoint(x: region.midX, y: size.height - region.minY - CGFloat(BeadsMala.headroom) * zoom)
    strand.setScale(zoom)
    #if os(iOS)
    let pixels = view.contentScaleFactor
    #else
    let pixels = view.convertToBacking(view.bounds).width / max(1, view.bounds.width)
    #endif
    beadMaterial.scale.floatValue = Float(pixels * zoom)
    let model = motion.strand
    let length = model.length
    guard length > 0 else { return }
    let count = model.lattice
    let pitch = length / Double(count)
    let transport = motion.inHand
    let first = Int((transport - 1e-6).rounded(.up))
    let spin = motion.spin, lift = motion.lift, grip = motion.grip
    let entrance = motion.condense
    let finishing = motion.completion != .none
    let finishTime = motion.dissolve * BeadsRitualMetrics.dissolveDuration
    let rise = entrance * Double(BeadsRitualMetrics.entranceRise)
    let radius = BeadsMala.radius
    let beadRadius = Double(BeadsRitualMetrics.beadRadius)
    let thumb = BeadsMala.pinch + SIMD2(Double(BeadsRitualMetrics.thumbPad.x), Double(BeadsRitualMetrics.thumbPad.y))
    let warmth = Double(material.warmth)
    // Strand space is y down from the finger's axis; the node is y up. Mid
    // turn the loop is seen edge on and lifted clear of the finger.
    func placed(_ point: SIMD2<Double>) -> SIMD2<Double> { SIMD2(point.x * spin, point.y - lift + rise) }
    let centre = SIMD2(0, max(0, model.point(at: model.bottom).y) / 2)
    func node(_ point: SIMD2<Double>) -> CGPoint { CGPoint(x: point.x, y: -point.y) }

    let path = CGMutablePath()
    for (index, point) in model.path.enumerated() {
      let position = node(placed(point))
      if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
    }
    path.closeSubpath()
    cord.path = path
    cordShade.path = path
    let live = (1 - entrance) * (finishing ? 1 - Self.smooth(motion.dissolve * 1.8) : 1)
    cord.alpha = CGFloat(0.9 * live)
    cordShade.alpha = BeadsSpriteMetrics.cordShadeOpacity * CGFloat(live)

    while beads.count < count { beads.append(makeBead(radius: BeadsRitualMetrics.beadRadius)) }
    var headsUsed = 0
    for index in 0..<count {
      let bead = beads[index]
      // One bead per lattice point round the closed strand. Past the bottom
      // of the loop a bead is one already counted; before it, one to come.
      let distance = length - (Double(first + index) - transport) * pitch
      let past = distance < model.bottom
      let slot = past ? first + index - count : first + index
      let point = placed(model.point(at: distance))
      let fromPinch = past ? distance : length - distance
      let near = 1 - Self.smooth(fromPinch / pitch)
      var emphasis = past
        ? 1 - 0.5 * Self.smooth(distance / (pitch * 1.2))
        : 0.5 + 0.22 * (1 - Self.smooth(fromPinch / (pitch * 4))) + 0.28 * near
      // The finger's shadow falls on the far strand just beneath it.
      if point.y > 0 { emphasis *= 1 - (1 - Self.smooth((point.y - 4) / 58)) * (point.x < 0 ? 0.62 : 0.08) }
      let fingerDistance = max(1e-6, BeadsMala.length(point))
      let fingerWarmth = warmth * (1 - Self.smooth((fingerDistance - radius - 2) / 30)) * spin
      let toThumb = thumb - point
      let thumbDistance = max(1e-6, BeadsMala.length(toThumb))
      let thumbWarmth = warmth * (0.32 + grip) * (1 - Self.smooth((thumbDistance - 36) / 26))
      var swell = 0.0, gone = 0.0
      if finishing {
        let local = min(1, max(0, (finishTime - abs(Double(slot) - transport) * BeadsRitualMetrics.dissolveBeadStagger)
          / BeadsRitualMetrics.dissolveBeadDuration))
        swell = Self.smooth(local / 0.45)
        gone = Self.smooth((local - 0.4) / 0.6)
      }
      let isHead = motion.isHead(slot)
      let far = Self.smooth(-point.x / radius)
      let size = beadRadius * (1 + BeadsRitualMetrics.currentScale * near) * (1 - BeadsRitualMetrics.gripScale * grip * near)
        * (1 - BeadsRitualMetrics.farScale * far) * (isHead ? Double(BeadsRitualMetrics.headScale) : 1)
      let fade = max(entrance, gone)
      let light = max(emphasis * (0.5 + 0.5 * spin), swell * (1 - gone))
      let seed = Float(((slot % material.patterns) + material.patterns) % material.patterns + 1)
      bead.isHidden = fade >= 1
      bead.position = node(point)
      bead.zPosition = 2 + CGFloat(1 - fromPinch / length)
      bead.setValue(SKAttributeValue(vectorFloat4: SIMD4(Float(size), Float(swell), 0, seed)), forAttribute: "a_shape")
      bead.setValue(SKAttributeValue(vectorFloat4: SIMD4(Float(fade), Float(light), 0, 0)), forAttribute: "a_state")
      // The shader's y runs up; the strand's runs down.
      bead.setValue(SKAttributeValue(vectorFloat4: SIMD4(Float(-point.x / fingerDistance), Float(point.y / fingerDistance),
        Float(fingerWarmth), 0)), forAttribute: "a_finger")
      bead.setValue(SKAttributeValue(vectorFloat4: SIMD4(Float(toThumb.x / thumbDistance), Float(-toThumb.y / thumbDistance),
        Float(thumbWarmth), 0)), forAttribute: "a_thumb")

      if isHead, fade < 1 {
        if headsUsed == heads.count { heads.append(makeHead()) }
        layoutHead(heads[headsUsed], at: point, centre: centre, radius: size, fade: fade, light: light,
          model: model, still: motion.reduceMotion, depth: bead.zPosition)
        headsUsed += 1
      }
    }
    for index in count..<beads.count { beads[index].isHidden = true }
    for index in headsUsed..<heads.count {
      heads[index].tower.isHidden = true
      heads[index].isHanging = false
      heads[index].tassel.isHidden = true
      heads[index].binding.isHidden = true
    }

    let pinch = node(placed(BeadsMala.pinch))
    label.text = motion.labelText
    // Above the bead in hand, and the same size on screen however near the
    // mala is drawn.
    label.position = CGPoint(x: pinch.x, y: pinch.y + BeadsRitualMetrics.beadRadius + BeadsRitualMetrics.labelInset)
    label.setScale(1 / zoom)
    label.alpha = finishing ? 0 : CGFloat(motion.labelAlpha * (1 - entrance))
  }

  /// The head bead carries a small tower bead pointing out of the loop and a
  /// bound tassel. Out of the loop is up at the crown, sideways on the strands
  /// and down at the bottom; a slight bias to one side keeps the tassel from
  /// hanging straight down across its own bead when the head is in hand.
  ///
  /// Everything here is continuous in where the head bead is. An earlier
  /// version chose the tassel's side from the sign of a coordinate, and the
  /// tassel snapped from left to right whenever a swing carried the head
  /// across the middle.
  private func layoutHead(_ head: Head, at point: SIMD2<Double>, centre: SIMD2<Double>, radius: Double, fade: Double,
    light: Double, model: BeadsMala, still: Bool, depth: CGFloat) {
    var out = point - centre + SIMD2(BeadsMala.radius * 0.5, 0)
    out /= max(1e-6, BeadsMala.length(out))
    let towerRadius = radius * Double(BeadsRitualMetrics.towerScale)
    let tower = point + out * (radius + towerRadius * 0.62)
    let tip = tower + out * (towerRadius + 1.5)
    head.tower.isHidden = false
    head.tower.position = CGPoint(x: tower.x, y: -tower.y)
    head.tower.zPosition = depth - 0.01
    head.tower.setValue(SKAttributeValue(vectorFloat4: SIMD4(Float(towerRadius), 0, 0, 1)), forAttribute: "a_shape")
    head.tower.setValue(SKAttributeValue(vectorFloat4: SIMD4(Float(fade), Float(light), 0, 0)), forAttribute: "a_state")

    // Up on the finger the tassel cannot hang straight down: the loop is in
    // the way. It drapes over the outside of it instead, as a real one does.
    // That only applies up there, and eases in with height.
    let clear = BeadsMala.radius + Double(BeadsRitualMetrics.beadRadius) + BeadsRitualMetrics.tasselClearance
    let raised = Self.smooth(-point.y / BeadsMala.radius)
    let side = min(1, max(-1, tip.x / BeadsRitualMetrics.tasselSideSoftness))
    let drape = SIMD2(side * raised * max(0, clear - abs(tip.x)), 0)
    let anchor = tip + out * 5 + drape
    let length = Double(BeadsRitualMetrics.tasselLength)

    // The tassel's weight, on a thread from the anchor. It feels the same
    // gravity and the same shake as the strand, and is dragged by the bead.
    let rest = anchor + model.down * length
    if still || !head.isHanging || BeadsMala.length(head.end - anchor) > length * 2.5 {
      head.end = rest
      head.previous = rest
      head.isHanging = true
    } else {
      let force = (model.down - model.shove * BeadsMalaMetrics.shakeGain) * BeadsMalaMetrics.gravity
      var remaining = frameTime
      while remaining > 1e-4 {
        let step = min(remaining, BeadsMalaMetrics.step)
        remaining -= step
        let velocity = (head.end - head.previous) * pow(BeadsRitualMetrics.tasselDamping, step / BeadsMalaMetrics.step)
        head.previous = head.end
        head.end += velocity + force * (step * step)
        var thread = head.end - anchor
        thread *= length / max(1e-6, BeadsMala.length(thread))
        head.end = anchor + thread
        tasselSpeed = max(tasselSpeed, BeadsMala.length(head.end - head.previous) / step)
      }
    }
    var hang = head.end - anchor
    hang /= max(1e-6, BeadsMala.length(hang))
    let across = SIMD2(-hang.y, hang.x)

    let spread = Double(BeadsRitualMetrics.tasselSpread)
    let threads = BeadsRitualMetrics.tasselThreads
    let tassel = CGMutablePath()
    func cg(_ vector: SIMD2<Double>) -> CGPoint { CGPoint(x: vector.x, y: -vector.y) }
    for thread in 0..<threads {
      let offset = Double(thread) / Double(threads - 1) - 0.5
      let uneven = Double((thread * 37) % 7)
      let end = anchor + hang * (length + uneven) + across * (offset * spread)
      tassel.move(to: cg(tip))
      tassel.addCurve(to: cg(end), control1: cg(tip + out * 9 + drape * 0.35),
        control2: cg(tip + out * 6 + drape * 0.95 + hang * 14 + across * (offset * 3)))
    }
    head.tassel.isHidden = false
    head.tassel.path = tassel
    head.tassel.alpha = CGFloat(1 - fade)
    head.tassel.zPosition = depth - 0.02
    // The binding wraps the threads just past the tip, square to the way
    // they leave it.
    var leaving = out * 9 + drape * 0.35
    leaving /= max(1e-6, BeadsMala.length(leaving))
    let square = SIMD2(-leaving.y, leaving.x)
    let knot = tip + leaving * 4
    let binding = CGMutablePath()
    binding.move(to: cg(knot - square * 2.5))
    binding.addLine(to: cg(knot + square * 2.5))
    head.binding.isHidden = false
    head.binding.path = binding
    head.binding.alpha = CGFloat(1 - fade)
    head.binding.zPosition = depth - 0.015
  }

  private func makeBead(radius: CGFloat) -> SKSpriteNode {
    let node = beadMaterial.makeSprite(radius: radius)
    strand.addChild(node)
    return node
  }

  private func makeHead() -> Head {
    let head = Head(tower: makeBead(radius: BeadsRitualMetrics.beadRadius * BeadsRitualMetrics.towerScale))
    for (node, width, color) in [(head.tassel, BeadsSpriteMetrics.tasselWidth, tasselColor),
      (head.binding, BeadsSpriteMetrics.bindingWidth, bindingColor)] {
      node.lineWidth = width
      node.lineCap = .round
      node.fillColor = .clear
      node.strokeColor = color
      node.isAntialiased = true
      strand.addChild(node)
    }
    return head
  }

  private static func smooth(_ value: Double) -> Double {
    let t = min(1, max(0, value))
    return t * t * (3 - 2 * t)
  }
}
#endif
