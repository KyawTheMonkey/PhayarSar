import SwiftUI

// MARK: - Metrics

/// Layout constants for `AppSliderRow`. Public because default arguments on a
/// `public init` can't reference `fileprivate` declarations.
public enum AppSliderRowMetrics {
  /// Width reserved for a row's leading glyph. The symbols that land here vary
  /// in width by nearly 2× — an `arrow.left.and.right` against a `text.quote` —
  /// so they get a fixed column and the labels beside them stay aligned down
  /// the card. Matches `PrayerDetailScreen`'s spec grid, which sets the same
  /// glyphs in the same column.
  public static let iconColumnWidth: CGFloat = 16

  /// Gap between the glyph and the label it names.
  public static let iconSpacing: CGFloat = 8

  /// Gap between the label line and the slider under it. Tight — the two are
  /// one control, and any more air starts to read as the gap to the next row.
  public static let labelSpacing: CGFloat = 2

  /// Gap between one slider row and the next, for a caller stacking several in
  /// a single section. Wide enough that a row reads as label-over-slider rather
  /// than slider-over-label.
  public static let rowSpacing: CGFloat = 18
}

// MARK: - Value formatting

extension Double {
  /// A reader setting as it appears in the UI: `15`, not `15.0`, but `2.5` kept
  /// intact when a slider lands between two whole numbers.
  ///
  /// Lives here rather than beside either call site so that the editor's
  /// readout and the detail screen's spec grid cannot drift apart — they are
  /// the same number shown twice, and a reader who sets 2.5 should not find it
  /// summarised as 3 one screen later.
  public var settingValueText: String {
    self == rounded() ? String(Int(self)) : String(format: "%.1f", self)
  }
}

// MARK: - Row

/// A labelled slider: the setting's name and its current value on one line,
/// the track beneath them.
///
/// ```swift
/// AppSliderRow(
///   L10n.lineSpacing,
///   systemImage: "arrow.up.and.down",
///   value: $settings.lineSpacing,
///   in: 0...40
/// )
/// ```
///
/// The value is read out as text as well as drawn, because the track alone
/// cannot say where it is — and because these settings are set by eye against a
/// preview, so the number is the thing to return to when the eye was wrong.
///
/// Draws no card of its own: put it inside an `AppListSection`, and stack
/// several with ``AppSliderRowMetrics/rowSpacing``.
public struct AppSliderRow: View {
  private let title: String
  private let systemImage: String?
  @Binding private var value: Double
  private let range: ClosedRange<Double>
  private let step: Double

  /// - Parameters:
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///   - systemImage: Optional SF Symbol shown before the title, in the fixed
  ///     column that keeps a stack of rows aligned.
  ///   - step: The slider's detent. Pass a value the range divides into evenly,
  ///     or the top of the track will be unreachable.
  public init(
    _ title: String,
    systemImage: String? = nil,
    value: Binding<Double>,
    in range: ClosedRange<Double>,
    step: Double = 1
  ) {
    self.title = title
    self.systemImage = systemImage
    self._value = value
    self.range = range
    self.step = step
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: AppSliderRowMetrics.labelSpacing) {
      HStack(spacing: AppSliderRowMetrics.iconSpacing) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppColor.textTertiary)
            .frame(width: AppSliderRowMetrics.iconColumnWidth)
        }

        Text(title)
          .font(AppFont.subheadline)
          .foregroundStyle(AppColor.textPrimary)

        Spacer(minLength: AppSliderRowMetrics.iconSpacing)

        Text(value.settingValueText)
          .font(AppFont.captionBold)
          .foregroundStyle(AppColor.textSecondary)
          // Digits are proportional in Inter, so without this the readout
          // twitches sideways as the value runs 9 → 10 under the finger.
          .monospacedDigit()
      }

      Slider(value: $value, in: range, step: step)
        .tint(AppColor.primary)
    }
    // One stop that reads "Line spacing, 15", rather than a label the user
    // lands on and a track they land on separately.
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
    .accessibilityValue(value.settingValueText)
  }
}

// MARK: - Previews

#Preview("Variants") {
  AppSliderRowPreview()
}

private struct AppSliderRowPreview: View {
  @State private var textSize: Double = 28
  @State private var letterSpacing: Double = 2
  @State private var lineSpacing: Double = 15
  @State private var verseSpacing: Double = 10

  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    ScrollView {
      VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
        AppListSection("With icons") {
          VStack(spacing: AppSliderRowMetrics.rowSpacing) {
            AppSliderRow(
              "Letter spacing",
              systemImage: "arrow.left.and.right",
              value: $letterSpacing,
              in: 0...12,
              step: 0.5
            )

            AppSliderRow(
              "Line spacing",
              systemImage: "arrow.up.and.down",
              value: $lineSpacing,
              in: 0...40
            )

            AppSliderRow(
              "Verse spacing",
              systemImage: "text.quote",
              value: $verseSpacing,
              in: 0...40
            )
          }
        }

        AppListSection("No icon", footer: "The glyph column collapses when no symbol is given.") {
          AppSliderRow("Text size", value: $textSize, in: 14...42, step: 2)
        }
      }
      .padding(.vertical)
    }
    .background(AppColor.background.ignoresSafeArea())
  }
}
