import SwiftUI

// MARK: - Metrics

public enum AppCardMetrics {
  /// Rounder than ``AppListSectionMetrics/cornerRadius``, and deliberately so:
  /// a list section is a container for rows, while a card is a single object the
  /// eye takes in whole, and the softer corner is what makes it read as one.
  public static let cornerRadius: CGFloat = 20

  /// Gutter between cards, across and down. Tighter than the gap between a card
  /// and the next *group* of them, so a grid reads as one field of tiles.
  public static let spacing: CGFloat = 12

  /// The width a card wants. Column counts are chosen by rounding to whatever
  /// lands nearest this — see ``AppCardGrid`` — rather than by fitting as many
  /// as clear some floor, which lets the last column that fits stretch to nearly
  /// twice the ideal before another one earns its place.
  public static let idealWidth: CGFloat = 300

  /// A phone gets one card per row whatever the arithmetic says; two tiles side
  /// by side at that width leave no room for a value and its label.
  public static let minColumns = 1

  /// Past three, cards stop reading as a considered layout and start reading as
  /// a wall of boxes — and on a wide Mac window the rows would run further than
  /// the eye tracks comfortably.
  public static let maxColumns = 3

  /// Padding around a card's content. Slightly wider than it is tall, because a
  /// hero value's own line height already supplies vertical air.
  public static var contentInsets: EdgeInsets {
    EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
  }

  /// Gap between the parts of a card — label, value, caption.
  public static let contentSpacing: CGFloat = 6
}

// MARK: - Card

/// One self-contained tile: a labelled value, a chart, a small control.
///
/// ```swift
/// AppCard {
///   Text(L10n.storage).font(AppFont.sectionLabel)
///   Text("148 KB").font(AppFont.largeTitle)
/// }
/// ```
///
/// Unlike ``AppListSection`` it applies no horizontal inset of its own and takes
/// no header, because a card is meant to be placed — in a grid, in a stack, next
/// to another card — and something outside it owns that arrangement.
///
/// It expands to fill whatever it is given in both directions, so cards sharing a
/// row in an ``AppCardGrid`` come out the same height instead of each shrinking
/// to its own content.
public struct AppCard<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: AppCardMetrics.cornerRadius, style: .continuous)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: AppCardMetrics.contentSpacing) {
      content
    }
    .padding(AppCardMetrics.contentInsets)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(AppColor.surface, in: shape)
    .overlay(shape.strokeBorder(AppColor.border, lineWidth: 0.5))
  }
}

// MARK: - Grid

/// Width available to an ``AppCardGrid``, for deciding how many columns fit.
private struct AppCardGridWidthKey: PreferenceKey {
  static var defaultValue: CGFloat { 0 }

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// Lays cards out in as many columns as the space is actually wide enough for.
///
/// ```swift
/// AppCardGrid {
///   AppCard { … }
///   AppCard { … }
/// }
/// ```
///
/// The width is **measured, not inferred from `horizontalSizeClass`**. On iPad a
/// screen may sit in a split view's detail column, so the window being regular
/// width says nothing about the room this grid was given; on macOS the size class
/// is regular at every window size, including tiny ones.
public struct AppCardGrid<Content: View>: View {
  private let content: Content

  /// `0` until the first layout pass. Reads as "not measured yet", which resolves
  /// to the single-column floor rather than to a guess that would visibly reflow.
  @State private var width: CGFloat = 0

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  private var columnCount: Int {
    guard width > 0 else { return AppCardMetrics.minColumns }

    // n columns occupy n * ideal + (n - 1) * spacing, so this is that solved for
    // n and rounded to the nearest whole column rather than floored.
    let spacing = AppCardMetrics.spacing
    let ideal = (width + spacing) / (AppCardMetrics.idealWidth + spacing)

    return min(
      max(Int(ideal.rounded()), AppCardMetrics.minColumns),
      AppCardMetrics.maxColumns
    )
  }

  private var columns: [GridItem] {
    Array(
      repeating: GridItem(
        .flexible(),
        spacing: AppCardMetrics.spacing,
        alignment: .top
      ),
      count: columnCount
    )
  }

  public var body: some View {
    LazyVGrid(columns: columns, spacing: AppCardMetrics.spacing) {
      content
    }
    // A preference rather than `onChange(of:)`, which has a different signature
    // either side of iOS 17 — and this package still builds for 16.
    .background {
      GeometryReader { proxy in
        Color.clear.preference(key: AppCardGridWidthKey.self, value: proxy.size.width)
      }
    }
    .onPreferenceChange(AppCardGridWidthKey.self) { width = $0 }
  }
}

// MARK: - Previews

#Preview("Cards") {
  AppCardGridPreview()
}

private struct AppCardGridPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    ScrollView {
      AppCardGrid {
        ForEach(["148 KB", "Aug 2026", "12 days"], id: \.self) { value in
          AppCard {
            Text("Label")
              .font(AppFont.sectionLabel)
              .textCase(.uppercase)
              .foregroundStyle(AppColor.textSecondary)

            Text(value)
              .font(AppFont.largeTitle)
              .foregroundStyle(AppColor.textPrimary)
          }
        }
      }
      .padding()
    }
    .background(AppColor.background)
  }
}
