import SwiftUI

/// Tuned for a card a few hundred points wide. The reference effect this is
/// adapted from carries a whole phone screen; every distance here is roughly
/// two fifths of its counterpart there, and the wave is a touch quicker, since
/// it has much less far to travel.
public enum AppDistortionRevealMetrics {
  public static let frameInterval: TimeInterval = 1.0 / 60
  // MARK: Timing
  /// Seconds the content is drawn toward the origin before the front leaves it.
  public static let anticipation: TimeInterval = 0.26
  /// Seconds the front takes to cross the card and settle past its far corner.
  public static let travel: TimeInterval = 1.7
  /// Seconds after the launch before the colour on the edges starts to clear.
  public static let linger: TimeInterval = 0.1
  public static let rimFade: TimeInterval = 1.2
  public static let hairlineLinger: TimeInterval = 0.3
  public static let hairlineFade: TimeInterval = 1.0
  public static var duration: TimeInterval {
    anticipation + max(travel, linger + hairlineLinger + hairlineFade) + 0.15
  }
  // MARK: Front
  /// Where the ring starts: this far below the card's top edge, at its centre.
  public static let sourceDepth: CGFloat = 6
  public static let launchRadius: CGFloat = 10
  /// How far out the colour gathers before falling onto the launch radius.
  public static let inhale: CGFloat = 26
  /// Scale of the x axis in the field. Under 1 the ring is wider than tall, so
  /// the front crosses the card as a bowed line instead of a tight circle.
  public static let squash: CGFloat = 0.7
  public static let overshoot: CGFloat = 40
  // MARK: Wave
  public static let pull: CGFloat = 12
  public static let amplitude: CGFloat = 16
  public static let lensWidth: CGFloat = 72
  public static let aberration: CGFloat = 0.35
  public static let swell: CGFloat = 12
  public static let blur: CGFloat = 12
  public static let nearBlur: CGFloat = 5
  public static let blurAhead: CGFloat = 36
  public static let blurBehind: CGFloat = 100
  /// Half the zone over which the two sides crossfade.
  public static let coverZone: CGFloat = 24
  // MARK: Colour
  public static let lead: CGFloat = 50
  public static let tail: CGFloat = 120
  public static let strength: Float = 0.9
  public static let rimWidth: CGFloat = 8
  public static let rimStrength: Float = 0.85
  public static let rimSoftness: CGFloat = 120
  public static let hairlineWidth: CGFloat = 1.2
  public static let hairlineOpacity: Float = 0.9
  // MARK: Layout
  /// Transparent room round a side's content for the swell and the blur to be
  /// drawn into. Part of the sampled layer, never of the layout.
  public static var sampleMargin: CGFloat { amplitude + blur * 2 }
}

public enum AppDistortionRevealSide: Sendable {
  /// What the card showed before: visible ahead of the front, taken by it.
  case outgoing
  /// What the card shows now: visible behind the front, drives the layout.
  case revealed
}

// MARK: - Public API

extension View {
  /// A one-shot wave that sweeps down an `AppListSection`, bending and blurring
  /// what it passes, with the brand colour riding the front and then clinging
  /// to the card's edges before it clears. Apply it to the section; mark the
  /// content inside the card with `appDistortionRevealSide(_:)`.
  ///
  /// The trigger is an explicit confirmation event, not the content value:
  /// confirming the same passage can replay it, while returning from a
  /// cancelled picker must not. `onRevealStarted` fires the moment the wave
  /// leaves rest, which is where the host swaps the laid-out content with an
  /// animation, so the card grows while the front crosses it rather than
  /// offscreen when the choice was made.
  ///
  /// The section is clipped to its card for the wave's lifetime, because the
  /// revealed text is laid out at its final size while the card is still
  /// growing toward it.
  public func appDistortionReveal(
    trigger: UUID?,
    isActive: Bool = true,
    shouldAnimate: Bool = true,
    cornerRadius: CGFloat = AppListSectionMetrics.cornerRadius,
    onRevealStarted: @escaping () -> Void = {},
    onRevealCompleted: @escaping () -> Void = {}
  ) -> some View {
    modifier(AppDistortionRevealModifier(
      trigger: trigger, isActive: isActive, shouldAnimate: shouldAnimate,
      cornerRadius: cornerRadius,
      onRevealStarted: onRevealStarted, onRevealCompleted: onRevealCompleted
    ))
  }

  /// One side of the card's content under an `appDistortionReveal`. An
  /// outgoing side is only ever drawn while a wave is running; keep it out of
  /// the layout (an overlay of the revealed side) so the card's size follows
  /// what it reveals.
  public func appDistortionRevealSide(_ side: AppDistortionRevealSide) -> some View {
    modifier(AppDistortionRevealSideModifier(side: side))
  }
}

// MARK: - Front

/// Where the wave is at a moment of its life: a pure function of elapsed time
/// and the card's rectangle, so both the band over the card and the lens inside
/// it, in different coordinate spaces, agree on every frame.
struct AppDistortionRevealFront {
  typealias Metrics = AppDistortionRevealMetrics

  let origin: CGPoint
  let radius: CGFloat
  let time: TimeInterval
  let energy: Double
  let swell: CGFloat
  let gravity: CGFloat
  let glow: Double
  let clearRadius: CGFloat
  let hairClearRadius: CGFloat
  let rim: Double
  let launched: Bool
  let card: CGRect
  /// 0–1 over the whole life, for the shader-less crossfade.
  let fraction: Double

  init(elapsed: TimeInterval, card: CGRect) {
    let t = min(max(elapsed, 0), Metrics.duration)
    let sinceLaunch = t - Metrics.anticipation
    let gathered = Self.smooth(0, Metrics.anticipation, t)
    let x = min(max(sinceLaunch / Metrics.travel, 0), 1)
    // An ease-out gentle enough that crossing a card a few hundred points
    // tall still takes most of a second; the reference's bezier, tuned for a
    // whole screen, was over the far edge in a quarter of that.
    let moved = 1 - pow(1 - x, 3)

    let origin = CGPoint(x: card.midX, y: card.minY + Metrics.sourceDepth)
    var reach: CGFloat = 0
    for corner in [
      CGPoint(x: card.minX, y: card.minY), CGPoint(x: card.maxX, y: card.minY),
      CGPoint(x: card.minX, y: card.maxY), CGPoint(x: card.maxX, y: card.maxY)
    ] {
      reach = max(reach, hypot((corner.x - origin.x) * Metrics.squash, corner.y - origin.y))
    }
    let crossed = reach + Metrics.swell + Metrics.coverZone
    // The front has crossed the card by the start of this, and from there on it
    // is slowing down too much to carry the swell, the blur and the colour.
    let settling = 1 - Self.smooth(0.45, 0.8, x)
    let gatheredGlow = 0.17

    self.origin = origin
    self.card = card
    self.time = t
    self.radius = sinceLaunch < 0
      ? Metrics.launchRadius + Metrics.inhale * (1 - gathered)
      : Metrics.launchRadius + (crossed + Metrics.overshoot - Metrics.launchRadius) * moved
    self.energy = Self.smooth(0, 0.05, x) * settling
    self.swell = Metrics.swell * Self.smooth(0, 0.3, moved)
    self.gravity = Metrics.pull * gathered * (1 - Self.smooth(0, 0.22, sinceLaunch))
    self.glow = sinceLaunch < 0
      ? gatheredGlow * gathered
      : (gatheredGlow + (1 - gatheredGlow) * Self.smooth(0, 0.07, x)) * settling
    // Starts far enough back that the colour is whole all the way to the origin,
    // and ends as the softness of its edge has left the farthest corner.
    let clearStart = Metrics.launchRadius - Metrics.rimSoftness
    let clearEnd = reach + Metrics.rimSoftness + Metrics.swell
    self.clearRadius = clearStart + (clearEnd - clearStart)
      * Self.smooth(0, 1, (sinceLaunch - Metrics.linger) / Metrics.rimFade)
    self.hairClearRadius = clearStart + (clearEnd - clearStart)
      * Self.smooth(0, 1, (sinceLaunch - Metrics.linger - Metrics.hairlineLinger) / Metrics.hairlineFade)
    self.rim = Double(Metrics.rimStrength) * Self.smooth(0, 0.1, x) * (1 - Self.smooth(0.9, 1, t / Metrics.duration))
    self.launched = sinceLaunch > 0
    self.fraction = t / Metrics.duration
  }

  /// The field as the shaders read it; see the header of `AppDistortionWave.metal`.
  var packed: [Float] {
    [
      Float(origin.x), Float(origin.y), Float(radius), Float(Metrics.squash),
      Float(time), Float(energy), Float(swell), Float(gravity), Float(glow),
      Float(clearRadius), Float(rim), launched ? 1 : 0, Float(hairClearRadius),
      Float(card.minX), Float(card.minY), Float(card.width), Float(card.height),
      Float(Metrics.coverZone)
    ]
  }

  func translated(by offset: CGPoint) -> AppDistortionRevealFront {
    AppDistortionRevealFront(moving: self, by: offset)
  }

  private init(moving front: AppDistortionRevealFront, by offset: CGPoint) {
    origin = CGPoint(x: front.origin.x - offset.x, y: front.origin.y - offset.y)
    card = front.card.offsetBy(dx: -offset.x, dy: -offset.y)
    radius = front.radius
    time = front.time
    energy = front.energy
    swell = front.swell
    gravity = front.gravity
    glow = front.glow
    clearRadius = front.clearRadius
    hairClearRadius = front.hairClearRadius
    rim = front.rim
    launched = front.launched
    fraction = front.fraction
  }

  static func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
  }
}

// MARK: - Shared wave state

/// Handed from the section down to its sides through the environment, so the
/// three shader passes read one clock without the host threading it through.
struct AppDistortionRevealWave {
  let elapsed: TimeInterval
  /// The card's rectangle in the section's named coordinate space.
  let card: CGRect
  let space: UUID
  let usesShaders: Bool
}

private struct AppDistortionRevealWaveKey: EnvironmentKey {
  static let defaultValue: AppDistortionRevealWave? = nil
}

extension EnvironmentValues {
  var appDistortionRevealWave: AppDistortionRevealWave? {
    get { self[AppDistortionRevealWaveKey.self] }
    set { self[AppDistortionRevealWaveKey.self] = newValue }
  }
}

private var hasShaderLibrary: Bool {
  Bundle.module.url(forResource: "default", withExtension: "metallib") != nil
}

private var supportsShaders: Bool {
  #if os(iOS) || os(macOS)
  if #available(iOS 17, macOS 14, *) { return hasShaderLibrary }
  #endif
  return false
}

// MARK: - Section modifier

private struct AppDistortionRevealModifier: ViewModifier {
  typealias Metrics = AppDistortionRevealMetrics

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  #if !os(macOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif
  @State private var isVisible = false
  @State private var playedTrigger: UUID?
  @State private var startedAt: Date?
  @State private var startedTrigger: UUID?
  @State private var playbackID: UUID?
  @State private var space = UUID()
  @State private var size = CGSize.zero
  #if os(iOS)
  @State private var haptics = AppDistortionRevealHaptics()
  #endif
  let trigger: UUID?
  let isActive: Bool
  let shouldAnimate: Bool
  let cornerRadius: CGFloat
  let onRevealStarted: () -> Void
  let onRevealCompleted: () -> Void

  private struct Run: Hashable {
    let trigger: UUID?
    let isActive: Bool
    let isVisible: Bool
    let shouldAnimate: Bool
  }

  /// Matches the card inside an `AppListSection`, which pads its card by the
  /// size class rather than exposing a rectangle.
  private var horizontalInset: CGFloat {
    #if os(macOS)
    AppListSectionMetrics.regularHorizontalInset
    #else
    horizontalSizeClass == .regular
      ? AppListSectionMetrics.regularHorizontalInset
      : AppListSectionMetrics.compactHorizontalInset
    #endif
  }

  private var cardShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
  }

  func body(content: Content) -> some View {
    TimelineView(.animation(minimumInterval: Metrics.frameInterval, paused: startedAt == nil)) { context in
      let elapsed = startedAt.map { context.date.timeIntervalSince($0) }
      let live = elapsed != nil && !reduceMotion
      let card = CGRect(
        x: horizontalInset, y: 0,
        width: max(size.width - 2 * horizontalInset, 1), height: max(size.height, 1)
      )
      content
        .environment(\.appDistortionRevealWave, live ? AppDistortionRevealWave(
          elapsed: elapsed ?? 0, card: card, space: space, usesShaders: supportsShaders
        ) : nil)
        .overlay { band(front: AppDistortionRevealFront(elapsed: elapsed ?? 0, card: card), on: live) }
        .coordinateSpace(name: space)
        .mask(alignment: .center) {
          cardShape.padding(.horizontal, horizontalInset)
        }
    }
    // Measured from behind rather than wrapped in a reader, which would take
    // whatever height the scroll view offered instead of the section's own.
    .background {
      GeometryReader { geometry in
        Color.clear
          .onAppear { size = geometry.size }
          .onChange(of: geometry.size) { size = $0 }
      }
    }
    #if os(iOS)
    .background {
      AppDistortionRevealVisibility { isVisible = $0 }
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
        #if os(iOS)
        haptics.stop()
        #endif
        return
      }
      guard !reduceMotion else {
        guard isVisible else { return }
        playedTrigger = trigger
        onRevealStarted()
        onRevealCompleted()
        return
      }
      let playback = UUID()
      playbackID = playback
      if startedTrigger != trigger || startedAt == nil {
        startedTrigger = trigger
        startedAt = .now
        onRevealStarted()
        // From the same instant as the clock, and only on a fresh start: a
        // task recreated mid-wave keeps the clock and must not strike again.
        #if os(iOS)
        haptics.play(card: CGRect(
          x: horizontalInset, y: 0,
          width: max(size.width - 2 * horizontalInset, 1), height: max(size.height, 1)
        ))
        #endif
      }
      // Start as navigation returns, rather than waiting for viewDidAppear.
      // NavigationStack may cancel/recreate this task while reparenting the
      // card. Reuse the event's clock so that handoff never restarts the wave;
      // only acknowledge completion once UIKit confirms the card is visible.
      let elapsed = startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
      let remaining = max(0, Metrics.duration - elapsed)
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

  @ViewBuilder
  private func band(front: AppDistortionRevealFront, on: Bool) -> some View {
    #if os(iOS) || os(macOS)
    if #available(iOS 17, macOS 14, *), supportsShaders {
      Rectangle()
        .fill(Color.white)
        .colorEffect(
          ShaderLibrary.bundle(.module).appWaveBand(
            .floatArray(front.packed),
            .float(Float(Metrics.lead)),
            .float(Float(Metrics.tail)),
            .float(Metrics.strength),
            .float(Float(Metrics.rimWidth)),
            .float(Float(Metrics.rimSoftness)),
            .float(Float(cornerRadius)),
            .float(Float(Metrics.hairlineWidth)),
            .float(Metrics.hairlineOpacity),
            .color(AppColor.DistortionReveal.base),
            .color(AppColor.DistortionReveal.light),
            .color(AppColor.DistortionReveal.rose)
          ),
          isEnabled: on
        )
        .opacity(on ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    #endif
  }
}

// MARK: - Side modifier

private struct AppDistortionRevealSideModifier: ViewModifier {
  typealias Metrics = AppDistortionRevealMetrics

  @Environment(\.appDistortionRevealWave) private var wave
  @State private var origin = CGPoint.zero
  let side: AppDistortionRevealSide

  func body(content: Content) -> some View {
    Group {
      if let wave {
        let front = AppDistortionRevealFront(elapsed: wave.elapsed, card: wave.card).translated(by: origin)
        if wave.usesShaders {
          lensed(content, front: front)
        } else {
          content.opacity(side == .revealed ? front.fraction : 1 - front.fraction)
        }
      } else {
        switch side {
        case .revealed:
          content
        case .outgoing:
          content.opacity(0).allowsHitTesting(false).accessibilityHidden(true)
        }
      }
    }
    .background {
      if let wave {
        GeometryReader { geometry in
          let frame = geometry.frame(in: .named(wave.space))
          Color.clear
            .onAppear { origin = frame.origin }
            .onChange(of: frame) { origin = $0.origin }
        }
      }
    }
  }

  @ViewBuilder
  private func lensed(_ content: Content, front: AppDistortionRevealFront) -> some View {
    #if os(iOS) || os(macOS)
    if #available(iOS 17, macOS 14, *) {
      let field = front.packed
      let acting = front.energy > 0
      ZStack {
        content
        blurredCopy(content, radius: Metrics.nearBlur, from: 0, to: Metrics.nearBlur, field: field, on: acting)
        blurredCopy(content, radius: Metrics.blur, from: Metrics.nearBlur, to: Metrics.blur, field: field, on: acting)
      }
      .padding(Metrics.sampleMargin)
      // One image: without the group each item goes through the shader alone,
      // and the channels of a half-transparent copy part into coloured bands.
      .compositingGroup()
      .layerEffect(
        ShaderLibrary.bundle(.module).appWaveLens(
          .floatArray(field), .boundingRect,
          .float(Float(Metrics.amplitude)),
          .float(Float(Metrics.lensWidth)),
          .float(Float(Metrics.aberration)),
          .float(side == .outgoing ? 1 : -1)
        ),
        maxSampleOffset: CGSize(width: Metrics.sampleMargin, height: Metrics.sampleMargin)
      )
      .padding(-Metrics.sampleMargin)
      .allowsHitTesting(false)
    } else {
      content
    }
    #else
    content
    #endif
  }

  #if os(iOS) || os(macOS)
  @available(iOS 17, macOS 14, *)
  private func blurredCopy(
    _ content: Content, radius: CGFloat, from: CGFloat, to: CGFloat, field: [Float], on: Bool
  ) -> some View {
    // Flattened first: without the group SwiftUI blurs each text on its own
    // instead of the content as one image. No radius while idle, so a hidden
    // copy costs nothing in the wave's quieter parts.
    content
      .compositingGroup()
      .blur(radius: on ? radius : 0)
      .colorEffect(
        ShaderLibrary.bundle(.module).appWaveBlurMask(
          .floatArray(field),
          .float(Float(Metrics.blur)),
          .float(Float(Metrics.blurAhead)),
          .float(Float(Metrics.blurBehind)),
          .float(Float(from)),
          .float(Float(to))
        ),
        isEnabled: on
      )
      .opacity(on ? 1 : 0)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }
  #endif
}

// MARK: - Visibility

#if os(iOS)
import UIKit

/// SwiftUI's onAppear runs while the picker is still sliding away, and its
/// task may be cancelled when NavigationStack reparents the returning screen.
/// UIKit's completed appearance confirms the event was actually presented;
/// animation can start during the transition without consuming it offscreen.
/// Keep this observer outside the changing content/shader subtree.
private struct AppDistortionRevealVisibility: UIViewControllerRepresentable {
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
