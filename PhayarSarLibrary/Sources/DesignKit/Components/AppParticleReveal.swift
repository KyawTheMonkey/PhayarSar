import SwiftUI

public enum AppParticleRevealMetrics {
  public static let duration: TimeInterval = 1.35
  public static let frameInterval: TimeInterval = 1.0 / 60
  public static let initialProgress: Double = 0.08
  public static let scatterDistance: CGFloat = 18
  public static let particleSpacing: CGFloat = 3.4
  public static let particleRadius: CGFloat = 0.9
  public static let particleFeather: CGFloat = 0.5
  public static let lightHaloStrength: Float = 0.035
  public static let darkHaloStrength: Float = 0.18
  public static let fallbackBlur: CGFloat = 3
  public static var sampleMargin: CGFloat { scatterDistance + particleSpacing }
}

extension View {
  /// A one-shot reveal of the actual rendered glyphs, so Burmese shaping and
  /// line wrapping remain the text system's job. A trigger is an explicit
  /// confirmation event, not the text value: confirming the same passage can
  /// replay it, while returning from a cancelled picker must not.
  public func appParticleReveal(
    trigger: UUID?,
    shaderBundle: Bundle,
    isActive: Bool = true,
    shouldAnimate: Bool = true,
    onRevealCompleted: @escaping () -> Void = {}
  ) -> some View {
    modifier(AppParticleRevealModifier(
      trigger: trigger, shaderBundle: shaderBundle, isActive: isActive,
      hasShaderLibrary: shaderBundle.url(forResource: "default", withExtension: "metallib") != nil,
      shouldAnimate: shouldAnimate, onRevealCompleted: onRevealCompleted
    ))
  }
}

private struct AppParticleRevealModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.colorScheme) private var colorScheme
  @State private var isVisible = false
  @State private var playedTrigger: UUID?
  @State private var startedAt: Date?
  @State private var startedTrigger: UUID?
  @State private var playbackID: UUID?
  let trigger: UUID?
  let shaderBundle: Bundle
  let isActive: Bool
  let hasShaderLibrary: Bool
  let shouldAnimate: Bool
  let onRevealCompleted: () -> Void

  private struct Run: Hashable {
    let trigger: UUID?
    let isActive: Bool
    let isVisible: Bool
    let shouldAnimate: Bool
  }

  func body(content: Content) -> some View {
    ZStack(alignment: .topLeading) {
      // Keep the sampled text and effect in the same render subtree while the
      // picker slides away. Starting a new shader layer only after appearance
      // left a blank card during its first texture/pipeline preparation.
      TimelineView(.animation(
        minimumInterval: AppParticleRevealMetrics.frameInterval,
        paused: startedAt == nil
      )) { context in
        if shouldRenderReveal {
          let elapsed = startedAt.map { context.date.timeIntervalSince($0) } ?? 0
          let fraction = min(max(elapsed / AppParticleRevealMetrics.duration, 0), 1)
          let progress = AppParticleRevealMetrics.initialProgress
            + fraction * (1 - AppParticleRevealMetrics.initialProgress)
          reveal(content, progress: progress)
        } else {
          #if os(iOS) || os(macOS)
          content.textSelection(.enabled)
          #else
          content
          #endif
        }
      }
    }
    #if os(iOS)
    .background {
      AppParticleRevealVisibility { isVisible = $0 }
        .allowsHitTesting(false)
    }
    #else
    .onAppear { isVisible = true }
    .onDisappear { isVisible = false }
    #endif
    .task(id: Run(
      trigger: trigger, isActive: isActive && scenePhase == .active,
      isVisible: isVisible, shouldAnimate: shouldAnimate
    )) {
      guard isActive, scenePhase == .active, let trigger,
            trigger != playedTrigger, shouldAnimate else {
        startedAt = nil
        startedTrigger = nil
        return
      }
      guard !reduceMotion else {
        guard isVisible else { return }
        playedTrigger = trigger
        onRevealCompleted()
        return
      }
      let playback = UUID()
      playbackID = playback
      if startedTrigger != trigger || startedAt == nil {
        startedTrigger = trigger
        startedAt = .now
      }
      // Start as navigation returns, rather than waiting for viewDidAppear.
      // NavigationStack may cancel/recreate this task while reparenting the
      // card. Reuse the event's clock so that handoff never restarts the dust;
      // only acknowledge completion once UIKit confirms the card is visible.
      let elapsed = startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
      let remaining = max(0, AppParticleRevealMetrics.duration - elapsed)
      do {
        try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        try Task.checkCancellation()
        guard playbackID == playback, isVisible else { return }
        playedTrigger = trigger
        startedAt = nil
        startedTrigger = nil
        onRevealCompleted()
      } catch {
        // Preserve the clock for a reparented task; deactivation resets it.
      }
    }
  }

  private var shouldRenderReveal: Bool {
    !reduceMotion && (startedAt != nil || (trigger != nil && trigger != playedTrigger && shouldAnimate))
  }

  @ViewBuilder
  private func reveal(_ content: Content, progress: Double) -> some View {
    #if os(iOS) || os(macOS)
    if #available(iOS 17, macOS 14, *), hasShaderLibrary {
      // The transparent margin is part of the sampled layer, not the layout.
      // It gives particles space to gather outside a letter's final outline.
      content
        .padding(AppParticleRevealMetrics.sampleMargin)
        .layerEffect(
          ShaderLibrary.bundle(shaderBundle).appParticleAssemble(
            .float(Float(progress)), .boundingRect,
            .float(Float(AppParticleRevealMetrics.scatterDistance)),
            .float(Float(AppParticleRevealMetrics.particleSpacing)),
            .float(Float(AppParticleRevealMetrics.particleRadius)),
            .float(Float(AppParticleRevealMetrics.particleFeather)),
            .float(colorScheme == .dark
              ? AppParticleRevealMetrics.darkHaloStrength : AppParticleRevealMetrics.lightHaloStrength),
            .color(AppColor.ParticleReveal.rose),
            .color(AppColor.ParticleReveal.violet),
            .color(AppColor.ParticleReveal.blue)
          ),
          maxSampleOffset: CGSize(
            width: AppParticleRevealMetrics.scatterDistance + AppParticleRevealMetrics.particleSpacing,
            height: AppParticleRevealMetrics.scatterDistance + AppParticleRevealMetrics.particleSpacing
          )
        )
        .padding(-AppParticleRevealMetrics.sampleMargin)
    } else {
      content.opacity(progress).blur(radius: (1 - progress) * AppParticleRevealMetrics.fallbackBlur)
    }
    #else
    content.opacity(progress)
    #endif
  }
}

#if os(iOS)
import UIKit

/// SwiftUI's onAppear runs while the picker is still sliding away, and its
/// task may be cancelled when NavigationStack reparents the returning screen.
/// UIKit's completed appearance confirms the event was actually presented;
/// animation can start during the transition without consuming it offscreen.
/// Keep this observer outside the changing text/shader subtree.
private struct AppParticleRevealVisibility: UIViewControllerRepresentable {
  let onVisibilityChange: (Bool) -> Void

  func makeUIViewController(context: Context) -> Observer {
    let observer = Observer()
    observer.onVisibilityChange = onVisibilityChange
    return observer
  }

  func updateUIViewController(_ controller: Observer, context: Context) {
    controller.onVisibilityChange = onVisibilityChange
  }

  final class Observer: UIViewController {
    var onVisibilityChange: ((Bool) -> Void)?

    override func loadView() {
      let view = UIView()
      view.isUserInteractionEnabled = false
      view.accessibilityElementsHidden = true
      self.view = view
    }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      onVisibilityChange?(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
      onVisibilityChange?(false)
      super.viewWillDisappear(animated)
    }
  }
}
#endif
