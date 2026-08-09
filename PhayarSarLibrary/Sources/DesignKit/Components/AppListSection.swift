import SwiftUI

// MARK: - Metrics

/// Layout constants for `AppListSection`. Public because default arguments on
/// a `public init` can't reference `fileprivate` declarations.
public enum AppListSectionMetrics {
  public static let cornerRadius: CGFloat = 16

  /// Matches `.padding(.horizontal)`'s 16pt default, so sections line up with
  /// nav headers and other bare controls on the same screen.
  public static let compactHorizontalInset: CGFloat = 16
  public static let regularHorizontalInset: CGFloat = 20

  /// Gap between the header and the card, and between the card and the footer.
  public static let labelGap: CGFloat = 8

  /// Suggested spacing for the `VStack` that stacks sections inside a `ScrollView`.
  public static let recommendedSectionSpacing: CGFloat = 24

  /// Padding applied around the section's content, mirroring a `List` row's insets.
  ///
  /// Computed rather than stored to sidestep any Swift 6 global-Sendable
  /// question around `EdgeInsets`.
  public static var contentInsets: EdgeInsets {
    EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
  }
}

// MARK: - Section

/// A grouped section that mimics SwiftUI's inset-grouped `List` section, for
/// use inside a plain `ScrollView`.
///
/// The content is wrapped in a rounded, translucent card (`AppColor.surface`,
/// designed to layer over `AppBackgroundGradient`), with an optional uppercase
/// header label above it and an optional caption footer below.
///
/// ```swift
/// ScrollView {
///   VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
///     AppListSection("Continue", footer: "Pick up where you left off.") {
///       OngoingPrayerView()
///     }
///   }
/// }
/// ```
///
/// The content is treated as opaque — separators between rows are not inserted
/// automatically, so add your own `Divider()` where you want them.
public struct AppListSection<Header: View, Content: View, Footer: View>: View {
  private let header: Header
  private let content: Content
  private let footer: Footer
  private let contentInsets: EdgeInsets

  public init(
    contentInsets: EdgeInsets = AppListSectionMetrics.contentInsets,
    @ViewBuilder header: () -> Header,
    @ViewBuilder content: () -> Content,
    @ViewBuilder footer: () -> Footer
  ) {
    self.header = header()
    self.content = content()
    self.footer = footer()
    self.contentInsets = contentInsets
  }

  #if os(macOS)
  private var horizontalInset: CGFloat {
    AppListSectionMetrics.regularHorizontalInset
  }
  #else
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var horizontalInset: CGFloat {
    horizontalSizeClass == .regular
      ? AppListSectionMetrics.regularHorizontalInset
      : AppListSectionMetrics.compactHorizontalInset
  }
  #endif

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: AppListSectionMetrics.cornerRadius, style: .continuous)
  }

  /// Aligns the header and footer text with the content inside the card,
  /// the way a `List` section does.
  private var labelInset: CGFloat {
    horizontalInset + contentInsets.leading
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: AppListSectionMetrics.labelGap) {
      // `EmptyView` doesn't collapse once it's been padded, so the empty cases
      // have to be branched away entirely or they leave a phantom gap.
      if Header.self != EmptyView.self {
        header
          .font(AppFont.sectionLabel)
          .textCase(.uppercase)
          .kerning(0.6)
          .foregroundStyle(AppColor.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, labelInset)
      }

      VStack(alignment: .leading, spacing: 0) {
        content
      }
      .padding(contentInsets)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppColor.surface, in: shape)
      .overlay(shape.strokeBorder(AppColor.border, lineWidth: 0.5))
      .padding(.horizontal, horizontalInset)

      if Footer.self != EmptyView.self {
        footer
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, labelInset)
      }
    }
  }
}

// MARK: - Text convenience initializers

// Strings rather than `LocalizedStringKey`: this project localises through
// `LocalisationKit`'s generated `L10n`, which vends plain `String`.

extension AppListSection where Header == Text, Footer == Text {
  public init(
    _ header: String,
    footer: String,
    contentInsets: EdgeInsets = AppListSectionMetrics.contentInsets,
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      contentInsets: contentInsets,
      header: { Text(header) },
      content: content,
      footer: { Text(footer) }
    )
  }
}

extension AppListSection where Header == Text, Footer == EmptyView {
  public init(
    _ header: String,
    contentInsets: EdgeInsets = AppListSectionMetrics.contentInsets,
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      contentInsets: contentInsets,
      header: { Text(header) },
      content: content,
      footer: { EmptyView() }
    )
  }
}

extension AppListSection where Header == EmptyView, Footer == Text {
  public init(
    footer: String,
    contentInsets: EdgeInsets = AppListSectionMetrics.contentInsets,
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      contentInsets: contentInsets,
      header: { EmptyView() },
      content: content,
      footer: { Text(footer) }
    )
  }
}

extension AppListSection where Header == EmptyView, Footer == EmptyView {
  public init(
    contentInsets: EdgeInsets = AppListSectionMetrics.contentInsets,
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      contentInsets: contentInsets,
      header: { EmptyView() },
      content: content,
      footer: { EmptyView() }
    )
  }
}

// MARK: - Previews

#Preview("Variants") {
  AppListSectionPreview()
}

private struct AppListSectionPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    ScrollView {
      VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
        AppListSection("Header & footer", footer: "A footer explains what the rows above do.") {
          PreviewRow(title: "Morning prayer", subtitle: "Resumed 2 days ago")
        }

        AppListSection("Header only") {
          PreviewRow(title: "Evening chant", subtitle: "Not started")
        }

        AppListSection(footer: "Footer only — no header label above the card.") {
          PreviewRow(title: "Metta Sutta", subtitle: "Completed")
        }

        AppListSection {
          PreviewRow(title: "Bare section", subtitle: "No header, no footer")
        }

        AppListSection("Multiple rows", footer: "Separators are yours to place.") {
          PreviewRow(title: "First", subtitle: "Row one")
          Divider()
            .padding(.vertical, 8)
          PreviewRow(title: "Second", subtitle: "Row two")
          Divider()
            .padding(.vertical, 8)
          PreviewRow(title: "Third", subtitle: "Row three")
        }

        AppListSection {
          HStack {
            Text("Custom header view")
            Spacer()
            Button("Edit") {}
              .font(AppFont.button)
              .textCase(nil)
          }
        } content: {
          PreviewRow(title: "Pinned", subtitle: "Tap Edit to reorder")
        } footer: {
          Text("A custom header inherits the label styling unless it overrides it.")
        }

        AppListSection("Edge-to-edge content", contentInsets: EdgeInsets()) {
          Rectangle()
            .fill(AppColor.primarySoft)
            .frame(height: 80)
            .overlay {
              Text("contentInsets: .init()")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
            }
        }
      }
      .padding(.vertical)
    }
    .appBackground()
  }
}

private struct PreviewRow: View {
  let title: String
  let subtitle: String

  var body: some View {
    HStack(spacing: 12) {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(AppColor.primarySoft)
        .frame(width: 44, height: 44)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(AppFont.listItemTitle)
          .foregroundStyle(AppColor.textPrimary)

        Text(subtitle)
          .font(AppFont.subheadline)
          .foregroundStyle(AppColor.textSecondary)
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(AppFont.caption)
        .foregroundStyle(AppColor.textTertiary)
    }
  }
}
