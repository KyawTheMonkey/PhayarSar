#if os(iOS) || os(macOS)
import SpriteKit
import SwiftUI

@MainActor
final class BeadsSpriteCoordinator {
  let scene: BeadsRitualScene
  private let motion: BeadsRitualMotion

  init(motion: BeadsRitualMotion) {
    self.motion = motion
    scene = BeadsRitualScene(motion: motion)
  }

  func prepare(_ view: SKView) {
    // The app's background gradient is drawn by SwiftUI behind this
    // screen-wide scene. An opaque SKView would replace them with a flat fill.
    view.allowsTransparency = true
    #if os(iOS)
    view.isOpaque = false
    view.backgroundColor = .clear
    #endif
    view.ignoresSiblingOrder = true
    view.shouldCullNonVisibleNodes = true
    // Align scene callbacks with the UI actor. Configurations are queued by
    // SwiftUI and consumed in update(_:), never dispatched into a render pass.
    view.isAsynchronous = false
    view.preferredFramesPerSecond = BeadsSpriteMetrics.preferredFramesPerSecond
    view.presentScene(scene)
    motion.onWake { [weak view, weak scene] in
      scene?.wake()
      view?.isPaused = false
    }
  }

  func configure(_ view: SKView, size: CGSize, geometry: BeadsRailGeometry, scheme: ColorScheme, material: BeadsMaterial) {
    scene.request(size: size, geometry: geometry, scheme: scheme, material: material)
    scene.wake()
    view.isPaused = false
  }
}

#if os(iOS)
struct BeadsSpriteView: UIViewRepresentable {
  let motion: BeadsRitualMotion
  let size: CGSize
  let geometry: BeadsRailGeometry
  let scheme: ColorScheme
  let material: BeadsMaterial

  func makeCoordinator() -> BeadsSpriteCoordinator { BeadsSpriteCoordinator(motion: motion) }

  func makeUIView(context: Context) -> SKView {
    let view = SKView(frame: .zero)
    view.isUserInteractionEnabled = false
    view.isAccessibilityElement = false
    motion.hostView = view
    context.coordinator.prepare(view)
    context.coordinator.configure(view, size: size, geometry: geometry, scheme: scheme, material: material)
    return view
  }

  func updateUIView(_ view: SKView, context: Context) {
    motion.hostView = view
    context.coordinator.configure(view, size: size, geometry: geometry, scheme: scheme, material: material)
  }

  static func dismantleUIView(_ view: SKView, coordinator: BeadsSpriteCoordinator) {
    view.isPaused = true
    view.presentScene(nil)
  }
}
#else
struct BeadsSpriteView: NSViewRepresentable {
  let motion: BeadsRitualMotion
  let size: CGSize
  let geometry: BeadsRailGeometry
  let scheme: ColorScheme
  let material: BeadsMaterial

  func makeCoordinator() -> BeadsSpriteCoordinator { BeadsSpriteCoordinator(motion: motion) }

  func makeNSView(context: Context) -> SKView {
    let view = SKView(frame: .zero)
    context.coordinator.prepare(view)
    context.coordinator.configure(view, size: size, geometry: geometry, scheme: scheme, material: material)
    return view
  }

  func updateNSView(_ view: SKView, context: Context) {
    context.coordinator.configure(view, size: size, geometry: geometry, scheme: scheme, material: material)
  }

  static func dismantleNSView(_ view: SKView, coordinator: BeadsSpriteCoordinator) {
    view.isPaused = true
    view.presentScene(nil)
  }
}
#endif
#endif
