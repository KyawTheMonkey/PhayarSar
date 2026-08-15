import SwiftUI

// MARK: - Metrics

/// Layout constants for `AppFadeBlurBackground`. Public for the same reason as
/// `AppListSectionMetrics` — default arguments on a `public init` can't
/// reference `fileprivate` declarations.
public enum AppFadeBlurMetrics {
  /// Fraction of the height that stays fully blurred before the fade begins.
  public static let solidStop: CGFloat = 0.55

  /// Peak opacity of the tint wash layered under the blur. Enough to hold text
  /// contrast when a light card scrolls underneath, without reading as a bar.
  public static let tintOpacity: CGFloat = 0.7
}

// MARK: - Background

/// A blur that is strongest at the top and fades to nothing at the bottom, for
/// putting behind a floating nav bar so content stays legible as it scrolls
/// underneath.
///
/// ```swift
/// .safeAreaInset(edge: .top) {
///   MyNavBar()
///     .background(AppFadeBlurBackground(intensity: progress).ignoresSafeArea(edges: .top))
/// }
/// ```
///
/// Designed to sit over `AppBackgroundGradient`. A solid `AppColor.background`
/// fill would visibly mismatch there — the gradient's top half carries a warm
/// `primarySoft` tint — which is why this is a material plus a soft wash rather
/// than an opaque bar.
///
/// **On the blur being uniform:** the app ships to iOS 16, which has no public
/// variable-radius blur (`.visualEffect` is iOS 17, Metal `.layerEffect` iOS 17).
/// This is a fixed-radius material whose *coverage* fades spatially — the same
/// approach behind most shipped "progressive blur" nav bars. Swapping in a true
/// variable radius later (4–5 stacked layers, each masked to its own band) is a
/// drop-in change behind this type's API.
public struct AppFadeBlurBackground: View {
  private let intensity: CGFloat
  private let solidStop: CGFloat

  /// - Parameters:
  ///   - intensity: `0` hides the background entirely, `1` shows it at full
  ///     strength. Values outside `0...1` are clamped. Drive it from scroll
  ///     progress so the bar is invisible at rest.
  ///   - solidStop: Fraction of the height that stays fully blurred before the
  ///     fade begins. Pass `1` for a hard bottom edge — needed when another
  ///     blurred surface docks directly beneath this one, so the two read as a
  ///     single continuous pane instead of two bands with a seam between them.
  public init(
    intensity: CGFloat = 1,
    solidStop: CGFloat = AppFadeBlurMetrics.solidStop
  ) {
    self.intensity = min(max(intensity, 0), 1)
    self.solidStop = min(max(solidStop, 0), 1)
  }

  public var body: some View {
    ZStack {
      Rectangle()
        .fill(.regularMaterial)

      tint
    }
    .mask(fade)
    .opacity(intensity)
    // Purely decorative — must never swallow taps meant for the bar's buttons.
    .allowsHitTesting(false)
  }

  /// Contrast wash under the blur.
  ///
  /// Holds full strength through `solidStop` and only then falls away, matching
  /// the mask. A plain top-to-bottom ramp would thin out the wash exactly where
  /// two of these panes meet, leaving a visible soft band at the join.
  private var tint: some View {
    LinearGradient(
      stops: [
        .init(color: tintColor, location: 0),
        .init(color: tintColor, location: solidStop),
        .init(
          color: solidStop >= 1 ? tintColor : AppColor.background.opacity(0),
          location: 1
        )
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private var tintColor: Color {
    AppColor.background.opacity(AppFadeBlurMetrics.tintOpacity)
  }

  /// Opaque through `solidStop`, then ramps to clear at the bottom edge so there
  /// is no hard seam where the blur ends. At `solidStop == 1` there is no ramp
  /// at all, which is the docked case.
  private var fade: LinearGradient {
    LinearGradient(
      stops: [
        .init(color: .black, location: 0),
        .init(color: .black, location: solidStop),
        .init(color: .black.opacity(solidStop >= 1 ? 1 : 0), location: 1)
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }
}

// MARK: - Previews

#Preview("Intensities") {
  AppFadeBlurBackgroundPreview()
}

private struct AppFadeBlurBackgroundPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        ForEach(Array(stride(from: 0.0, through: 1.0, by: 0.25)), id: \.self) { intensity in
          Text("Nav title over content · intensity \(intensity, specifier: "%.2f")")
            .font(AppFont.listItemTitle)
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppFadeBlurBackground(intensity: intensity))
            .background(sampleContent)
        }
      }
    }
    .appBackground()
  }

  /// Stands in for list cards scrolling under the bar.
  private var sampleContent: some View {
    HStack(spacing: 8) {
      ForEach(0..<6, id: \.self) { _ in
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(AppColor.primary)
      }
    }
  }
}
