import SwiftUI

public enum AppWavingFlagMetrics {
  public static let glyphSize: CGFloat = 34
  public static let samplePadding: CGFloat = 8
  public static let horizontalDisplacement: Float = 1.2
  public static let edgeCurvature: Float = 4
  public static let verticalDisplacement: Float = 3
  public static let downwardDrape: Float = 4
  public static let waveCount: Float = 1.15
  public static let period: TimeInterval = 1.8
  public static let periodStep: TimeInterval = 0.23
  public static let timingVariantCount: UInt32 = 5
  public static let phaseVariantCount: UInt32 = 11
  public static let foldShading: Float = 0.16
  public static let frameInterval: TimeInterval = 1.0 / 30
}

/// The emoji is the artwork: sampling its rendered layer preserves Apple's
/// native flag details instead of approximating each country with shapes.
/// Only this small layer animates, so the row's text and checkmark stay still.
/// The hoist edge stays pinned while the ripple grows toward a draped free edge.
///
/// The shader lives in DesignKit's resource bundle, not the app's default
/// library. Some SwiftPM build backends copy Metal source without compiling
/// it, so a missing metallib must take the same static path as older OSes.
/// Reduce Motion also removes the timeline entirely, rather than scheduling
/// frames for an effect that cannot be seen.
public struct AppWavingFlag: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var isVisible = false
  @State private var startedAt = Date()

  private let emoji: String
  private let period: TimeInterval
  private let phaseOffset: Double
  private typealias Metrics = AppWavingFlagMetrics

  public init(_ emoji: String) {
    self.emoji = emoji
    // Stable per-emoji timing keeps neighbouring flags out of step without
    // re-randomising their motion whenever SwiftUI recreates the row. Different
    // periods, as well as phases, keep them from settling into a shared beat.
    let seed = emoji.unicodeScalars.reduce(UInt32(0)) { $0 &+ $1.value }
    period = Metrics.period + Double(seed % Metrics.timingVariantCount) * Metrics.periodStep
    phaseOffset = Double(seed % Metrics.phaseVariantCount) / Double(Metrics.phaseVariantCount)
  }

  public var body: some View {
    artwork
      .accessibilityHidden(true)
      .allowsHitTesting(false)
      .onAppear {
        startedAt = .now
        isVisible = true
      }
      .onDisappear { isVisible = false }
  }

  @ViewBuilder
  private var artwork: some View {
    #if os(iOS) || os(macOS)
    if #available(iOS 17, macOS 14, *),
       !reduceMotion, isVisible, scenePhase == .active,
       Bundle.module.url(forResource: "default", withExtension: "metallib") != nil {
      TimelineView(.animation(minimumInterval: Metrics.frameInterval)) { context in
        // Bound elapsed time before converting to Float, so long sessions
        // cannot lose the precision that keeps a small ripple smooth.
        let time = context.date.timeIntervalSince(startedAt)
          .truncatingRemainder(dividingBy: period)
        glyph
          .padding(Metrics.samplePadding)
          .drawingGroup()
          .layerEffect(
            ShaderLibrary.bundle(.module).appFlagWave(
              .boundingRect,
              .float(Float(time / period + phaseOffset)),
              .float(Float(Metrics.samplePadding)),
              .float(Metrics.horizontalDisplacement),
              .float(Metrics.edgeCurvature),
              .float(Metrics.verticalDisplacement),
              .float(Metrics.downwardDrape),
              .float(Metrics.waveCount),
              .float(Metrics.foldShading)
            ),
            maxSampleOffset: CGSize(
              width: CGFloat(Metrics.horizontalDisplacement + Metrics.edgeCurvature),
              height: CGFloat(Metrics.verticalDisplacement + Metrics.downwardDrape)
            )
          )
          // Give the shader transparent pixels to wave into without changing
          // row height or clipping the free edge at the emoji's original box.
          .padding(-Metrics.samplePadding)
      }
    } else {
      glyph
    }
    #else
    glyph
    #endif
  }

  private var glyph: some View {
    Text(verbatim: emoji)
      .font(AppFont.emoji(size: Metrics.glyphSize))
      .frame(width: Metrics.glyphSize, height: Metrics.glyphSize)
  }
}

#Preview("Waving flags") {
  AppWavingFlagPreview()
}

private struct AppWavingFlagPreview: View {
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    HStack(spacing: AppSettingsRowMetrics.iconSpacing) {
      AppWavingFlag("🇬🇧")
      AppWavingFlag("🇲🇲")
    }
    .padding(AppSettingsRowMetrics.verticalPadding)
    .background(AppColor.background)
  }
}
