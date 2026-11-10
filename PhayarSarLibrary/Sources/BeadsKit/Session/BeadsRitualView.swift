import DesignKit
import Inject
import LocalisationKit
import SwiftUI

/// The touchable region around the mala. A pull anywhere in it moves the
/// bead in hand, so the thumb does not have to land on the bead itself. Down
/// is forward, as the thumb draws a bead toward the body; up brings it back.
/// The drawing lives in the screen-wide backdrop; this view only reports its
/// bounds and takes the gesture.
struct BeadsRitualView: View {
  @ObserveInjection private var injectionObserver
  @ObservedObject var motion: BeadsRitualMotion
  @GestureState private var isDragging = false
  let accessibilityValue: String

  var body: some View {
    GeometryReader { proxy in
      Color.clear
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: BeadsRitualMetrics.minimumGestureDistance, coordinateSpace: .local)
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
              if !motion.isPulling { motion.beginPull(time: value.time) }
              motion.updatePull(translation: value.translation.height, time: value.time)
            }
            .onEnded { value in
              motion.endPull(translation: value.translation.height, time: value.time)
            }
        )
        .onChange(of: isDragging) { dragging in
          // GestureState resets on cancellation without onEnded; a normal end
          // has already cleared the pull, so this is a no-op then.
          if !dragging { motion.cancelPull() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.beadsSessionCount)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(L10n.beadsSessionPullHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { motion.accessibleCount() }
        .accessibilityAction(named: Text(L10n.beadsSessionCount)) { motion.accessibleCount() }
        .accessibilityAction(named: Text(L10n.beadsSessionUndo)) { motion.accessibleUndo() }
    }
    .anchorPreference(key: BeadsRitualBoundsKey.self, value: .bounds) { $0 }
    .enableInjection()
  }
}

/// Resolving the strand region in the screen's background keeps rotation and
/// safe areas in one coordinate space, without a layout/state feedback loop.
struct BeadsRitualBoundsKey: PreferenceKey {
  static var defaultValue: Anchor<CGRect>? { nil }

  static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
    value = nextValue() ?? value
  }
}

/// The app's own background gradient with the SpriteKit stage on top, so the
/// session sits in the same room as every other screen and follows the
/// chosen theme. No hand and no glow of its own.
struct BeadsStageBackdrop: ViewModifier {
  @ObserveInjection private var injectionObserver
  @ObservedObject var motion: BeadsRitualMotion
  let stageScheme: ColorScheme
  let material: BeadsMaterial

  func body(content: Content) -> some View {
    content.backgroundPreferenceValue(BeadsRitualBoundsKey.self) { anchor in
      GeometryReader { proxy in
        ZStack {
          AppBackgroundGradient()
          #if os(iOS) || os(macOS)
          if let anchor {
            BeadsSpriteView(
              motion: motion, size: proxy.size,
              geometry: BeadsRailGeometry(region: proxy[anchor]), scheme: stageScheme, material: material
            )
          }
          #endif
        }
      }
      .ignoresSafeArea()
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
    .enableInjection()
  }
}
