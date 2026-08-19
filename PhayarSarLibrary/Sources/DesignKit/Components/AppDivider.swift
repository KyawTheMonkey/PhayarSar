import SwiftUI

// MARK: - Metrics

/// Layout constants for `AppDivider`.
public enum AppDividerMetrics {
  /// A hairline, like every other edge in the app. Fixed rather than
  /// `1 / displayScale`, so the rule keeps the same weight on every screen —
  /// `AppColor.divider` is toned for exactly this thickness.
  public static let thickness: CGFloat = 0.5
}

// MARK: - Divider

/// A horizontal rule between rows, in the app's own separator colour.
///
/// SwiftUI's `Divider()` paints the system separator, which is mixed for a
/// plain background and all but vanishes on top of `AppColor.surface` — the
/// translucent card every list row in this app sits on. This draws the same
/// hairline in `AppColor.divider` instead, which is toned to stay legible on a
/// card in both appearances without turning into a hard line.
///
/// ```swift
/// VStack(spacing: 0) {
///   Row()
///   AppDivider()
///   Row()
/// }
/// ```
///
/// Sizes itself like `Divider()` does: full width, hairline tall.
public struct AppDivider: View {
  public init() {}

  public var body: some View {
    Rectangle()
      .fill(AppColor.divider)
      .frame(maxWidth: .infinity)
      .frame(height: AppDividerMetrics.thickness)
      // The rule carries no meaning a screen reader needs to announce; it is
      // the rows either side of it that matter.
      .accessibilityHidden(true)
  }
}

// MARK: - Preview

#Preview("On a card") {
  VStack(spacing: 0) {
    ForEach(0..<3) { index in
      Text("Row \(index + 1)")
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)

      if index < 2 {
        AppDivider()
      }
    }
  }
  .padding(.horizontal, 16)
  .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  .padding(16)
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(AppColor.background)
}
