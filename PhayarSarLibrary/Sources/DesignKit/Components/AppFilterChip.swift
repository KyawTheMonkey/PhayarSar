import SwiftUI

// MARK: - Style

/// How loudly an `AppFilterChip` speaks.
public enum AppFilterChipStyle: Sendable {
  /// A bordered capsule that fills solid when selected. For a row that decides
  /// what the rest of the screen shows — Home's All / Prayers / Audio.
  case prominent

  /// Bare text that only picks up a faint capsule when selected. For a row of
  /// shortcuts inside content the user has already chosen, where a second set
  /// of bordered capsules would compete with the first.
  case subtle
}

// MARK: - Metrics

/// Layout constants for `AppFilterChip`.
public enum AppFilterChipMetrics {
  /// Visual height of the capsule. Below Apple's 44pt minimum on purpose — a
  /// row of 44pt capsules reads as a toolbar, not a filter — so the hit area
  /// is grown back to ``minimumHitHeight`` without changing what is drawn.
  public static let height: CGFloat = 36
  public static let subtleHeight: CGFloat = 32
  public static let minimumHitHeight: CGFloat = 44

  public static let horizontalPadding: CGFloat = 14
  public static let subtleHorizontalPadding: CGFloat = 12
  public static let iconSpacing: CGFloat = 6
  public static let borderWidth: CGFloat = 1

  /// Gap between chips in a row.
  public static let spacing: CGFloat = 8
  public static let subtleSpacing: CGFloat = 2
}

// MARK: - Chip

/// One capsule in a left-aligned row of filters or shortcuts.
///
/// Replaces the 50/50 segmented track Home used to have. A track divides the
/// full width between its options whatever they are, so with one option still
/// empty it read as a broken control and could not take a third option without
/// every label shrinking. Chips size to their labels, sit at the leading edge,
/// and a row of them can grow to the right without the others moving.
///
/// The chip is a plain `Button`: selection state lives with the caller, so the
/// same view serves a mutually exclusive filter (pass `isSelected`) and a row
/// of one-shot shortcuts (leave it `false`).
public struct AppFilterChip: View {
  private let title: String
  private let systemImage: String?
  private let isSelected: Bool
  private let style: AppFilterChipStyle
  private let action: () -> Void

  /// - Parameters:
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///   - systemImage: Optional SF Symbol, shown before the title.
  public init(
    _ title: String,
    systemImage: String? = nil,
    isSelected: Bool = false,
    style: AppFilterChipStyle = .prominent,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.isSelected = isSelected
    self.style = style
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: AppFilterChipMetrics.iconSpacing) {
        if let systemImage {
          Image(systemName: systemImage)
            .imageScale(.small)
        }
        Text(title)
          .lineLimit(1)
      }
      .font(style == .prominent ? AppFont.button : AppFont.subheadline)
      .foregroundStyle(foreground)
      .padding(.horizontal, horizontalPadding)
      .frame(height: height)
      .background(background, in: Capsule())
      .overlay {
        if style == .prominent {
          Capsule().strokeBorder(border, lineWidth: AppFilterChipMetrics.borderWidth)
        }
      }
      // Grow the tappable area to 44pt without drawing a taller capsule.
      .frame(minHeight: AppFilterChipMetrics.minimumHitHeight)
      .contentShape(Rectangle())
      .animation(.easeOut(duration: 0.18), value: isSelected)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  // MARK: Appearance

  private var height: CGFloat {
    style == .prominent ? AppFilterChipMetrics.height : AppFilterChipMetrics.subtleHeight
  }

  private var horizontalPadding: CGFloat {
    style == .prominent
      ? AppFilterChipMetrics.horizontalPadding
      : AppFilterChipMetrics.subtleHorizontalPadding
  }

  /// Selected prominent chips invert to the page's own text colour: the
  /// strongest contrast available in both schemes without introducing a brand
  /// tint that would then compete with the primary buttons below it.
  private var foreground: Color {
    switch (style, isSelected) {
    case (.prominent, true): return AppColor.textInverse
    case (.prominent, false): return AppColor.textPrimary
    case (.subtle, true): return AppColor.textPrimary
    case (.subtle, false): return AppColor.textSecondary
    }
  }

  private var background: Color {
    switch (style, isSelected) {
    case (.prominent, true): return AppColor.textPrimary
    case (.prominent, false): return AppColor.surface
    case (.subtle, true): return AppColor.surface
    case (.subtle, false): return .clear
    }
  }

  private var border: Color {
    isSelected ? AppColor.textPrimary : AppColor.border
  }
}

// MARK: - Previews

#Preview("Styles") {
  AppFilterChipPreview()
}

private struct AppFilterChipPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: AppFilterChipMetrics.spacing) {
        AppFilterChip("All", isSelected: true) {}
        AppFilterChip("Prayers", systemImage: "book") {}
        AppFilterChip("Audio", systemImage: "headphones") {}
      }
      HStack(spacing: AppFilterChipMetrics.subtleSpacing) {
        AppFilterChip("Precepts", style: .subtle) {}
        AppFilterChip("Virtues", isSelected: true, style: .subtle) {}
        AppFilterChip("Parittas", style: .subtle) {}
      }
    }
    .appHorizontalInset()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .appTabBackground()
  }
}
