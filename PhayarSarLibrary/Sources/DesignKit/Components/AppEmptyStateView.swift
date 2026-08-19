import SwiftUI

public enum AppEmptyStateMetrics {
  /// Large enough to read as illustration rather than as an icon that lost its
  /// row, small enough that it does not become the point of the screen — the
  /// message is.
  public static let iconSize: CGFloat = 44

  /// Between the icon, the text block and the action.
  public static let spacing: CGFloat = 16

  /// Gap between title and message, tighter than `spacing` so the two read as
  /// one block.
  public static let textSpacing: CGFloat = 6

  /// Stops the message running the full width of an iPad. Long measure is hard
  /// to read, and an empty state is usually one sentence sitting in a lot of
  /// space, where the eye has nothing else to anchor on.
  public static let maxTextWidth: CGFloat = 320

  /// The action is deliberately not full width — an empty state is an aside,
  /// and a full-width slab across a blank list overstates it.
  public static let actionWidth: CGFloat = 240
}

/// What a list shows when it has nothing to show.
///
/// ```swift
/// if plans.isEmpty {
///   AppEmptyStateView(
///     systemImage: "list.bullet.rectangle",
///     title: L10n.noPlansTitle,
///     message: L10n.noPlansMessage,
///     actionTitle: L10n.createPlan
///   ) {
///     navigator.present(.newPlan)
///   }
/// }
/// ```
///
/// Lives in DesignKit rather than with the full-screen status screens in MiscKit
/// because it is rendered *inside* a feature's own layout — every feature target
/// already depends on DesignKit, and none of them should have to take on a new
/// dependency to say "nothing here yet".
///
/// It sizes to its content rather than filling the screen, so the caller decides
/// whether it is centred in a `ScrollView`, sitting under a header, or occupying
/// one section of a longer page.
public struct AppEmptyStateView: View {
  private let systemImage: String
  private let title: String
  private let message: String?
  private let actionTitle: String?
  private let action: (() -> Void)?

  /// - Parameters:
  ///   - systemImage: SF Symbol standing in for whatever is missing.
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///     Name the absence ("No saved prayers"), do not apologise for it.
  ///   - message: One line on how to fill the space. Omit it when the title
  ///     already says everything.
  ///   - actionTitle: Omit — along with `action` — for an empty state the user
  ///     cannot do anything about from here. The button is only rendered when
  ///     both are given, so a title without a handler cannot ship as a control
  ///     that does nothing.
  public init(
    systemImage: String,
    title: String,
    message: String? = nil,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil
  ) {
    self.systemImage = systemImage
    self.title = title
    self.message = message
    self.actionTitle = actionTitle
    self.action = action
  }

  public var body: some View {
    VStack(spacing: AppEmptyStateMetrics.spacing) {
      Image(systemName: systemImage)
        .font(.system(size: AppEmptyStateMetrics.iconSize, weight: .light))
        .foregroundStyle(AppColor.textTertiary)
        // The title already says what is missing; the symbol repeating it is
        // noise to a screen reader.
        .accessibilityHidden(true)

      textBlock

      if let actionTitle, let action {
        AppButton(actionTitle, kind: .secondary, action: action)
          .frame(maxWidth: AppEmptyStateMetrics.actionWidth)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, AppEmptyStateMetrics.spacing * 2)
  }

  // MARK: - Text

  private var textBlock: some View {
    VStack(spacing: AppEmptyStateMetrics.textSpacing) {
      Text(title)
        .font(AppFont.headline)
        .foregroundStyle(AppColor.textPrimary)

      if let message {
        Text(message)
          .font(AppFont.subheadline)
          .foregroundStyle(AppColor.textSecondary)
      }
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: AppEmptyStateMetrics.maxTextWidth)
  }
}

// MARK: - Previews

#Preview("Variants") {
  AppEmptyStateViewPreview()
}

private struct AppEmptyStateViewPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        AppEmptyStateView(
          systemImage: "bookmark",
          title: "No saved prayers",
          message: "Prayers you bookmark will appear here.",
          actionTitle: "Browse prayers"
        ) {}

        Divider()

        AppEmptyStateView(
          systemImage: "magnifyingglass",
          title: "No results",
          message: "Try a different word, or search in Burmese."
        )

        Divider()

        AppEmptyStateView(
          systemImage: "clock",
          title: "Nothing read yet"
        )
      }
    }
    .appHorizontalInset()
    .appBackground()
  }
}
