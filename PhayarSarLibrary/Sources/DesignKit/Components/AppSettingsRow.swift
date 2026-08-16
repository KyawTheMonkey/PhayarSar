import SwiftUI

// MARK: - Metrics

public enum AppSettingsRowMetrics {
  /// The icon column. Fixed, so every title in a group starts on the same
  /// vertical line no matter how wide its glyph is.
  public static let iconColumn: CGFloat = 28
  public static let iconSpacing: CGFloat = 14

  /// Padding above and below a row's content. With a 17pt title this lands the
  /// row at roughly 52pt, comfortably past the 44pt minimum target.
  public static let verticalPadding: CGFloat = 14

  /// Gap between one group and the next, including the next group's label.
  public static let groupSpacing: CGFloat = 28
}

// MARK: - Row parts

/// What sits at the trailing edge of a settings row, and what it promises.
///
/// The distinction between ``disclosure`` and ``externalLink`` is worth keeping:
/// one says "this opens inside the app and you can come back", the other says
/// "this hands you to Safari or the App Store". A user who has learned the
/// difference should not have to re-learn it per screen.
public enum AppSettingsRowAccessory: Equatable, Sendable {
  case disclosure
  case externalLink
  /// For a row that only reports something, or one whose whole control is in
  /// the `detail` slot.
  case none
}

/// How much the row wants to be noticed.
public enum AppSettingsRowEmphasis: Equatable, Sendable {
  case standard
  /// Sign out, delete, reset. Colours the icon and the title.
  case destructive

  var titleColor: Color {
    self == .destructive ? AppColor.error : AppColor.textPrimary
  }

  var iconColor: Color {
    self == .destructive ? AppColor.error : AppColor.textSecondary
  }
}

/// The contents of a settings row, without any tap handling.
///
/// Public because a row's control is not always a button — the language row is
/// a `Menu`, and it needs this as its label. Reach for ``AppSettingsRow``
/// first; this is the escape hatch.
public struct AppSettingsRowLabel: View {
  private let title: String
  private let systemImage: String?
  private let detail: String?
  private let detailColor: Color?
  private let accessory: AppSettingsRowAccessory
  private let emphasis: AppSettingsRowEmphasis

  public init(
    _ title: String,
    systemImage: String? = nil,
    detail: String? = nil,
    detailColor: Color? = nil,
    accessory: AppSettingsRowAccessory = .disclosure,
    emphasis: AppSettingsRowEmphasis = .standard
  ) {
    self.title = title
    self.systemImage = systemImage
    self.detail = detail
    self.detailColor = detailColor
    self.accessory = accessory
    self.emphasis = emphasis
  }

  public var body: some View {
    HStack(spacing: AppSettingsRowMetrics.iconSpacing) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(.system(size: 20, weight: .regular))
          .foregroundStyle(emphasis.iconColor)
          .frame(width: AppSettingsRowMetrics.iconColumn, alignment: .center)
      }

      Text(title)
        .font(AppFont.listItemTitle)
        .foregroundStyle(emphasis.titleColor)
        // Burmese titles run longer than their English counterparts and would
        // otherwise push the detail and chevron off the row.
        .lineLimit(2)

      Spacer(minLength: 8)

      if let detail {
        Text(detail)
          .font(AppFont.body)
          .foregroundStyle(detailColor ?? AppColor.textSecondary)
          .lineLimit(1)
      }

      accessoryIcon
    }
    .padding(.vertical, AppSettingsRowMetrics.verticalPadding)
    // Without this the row is only tappable where there is ink.
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private var accessoryIcon: some View {
    switch accessory {
    case .disclosure:
      icon("chevron.right")
    case .externalLink:
      icon("arrow.up.right")
    case .none:
      EmptyView()
    }
  }

  private func icon(_ name: String) -> some View {
    Image(systemName: name)
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(AppColor.textTertiary)
  }
}

// MARK: - Row

/// One line of a settings screen: icon, title, optional value, accessory.
///
/// ```swift
/// AppSettingsRow(L10n.notifications, systemImage: "bell") {
///   navigator.navigate(to: .notificationSettings)
/// }
/// ```
///
/// Flat rather than in a card, unlike ``AppListSection`` — a settings screen is
/// a long list of single actions, and boxing each group of them adds a border
/// per idea without adding a distinction the labels do not already make.
public struct AppSettingsRow: View {
  private let title: String
  private let systemImage: String?
  private let detail: String?
  private let detailColor: Color?
  private let accessory: AppSettingsRowAccessory
  private let emphasis: AppSettingsRowEmphasis
  private let action: (() -> Void)?

  /// - Parameters:
  ///   - title: Already localised — pass `L10n.something`.
  ///   - systemImage: SF Symbol for the icon column. Omitting it leaves the
  ///     column empty rather than shifting the title left, so rows in a group
  ///     stay aligned.
  ///   - detail: Trailing value, e.g. the language a picker currently holds.
  ///   - detailColor: For a value that is also a status. Defaults to the same
  ///     secondary grey every other row's value uses.
  ///   - accessory: Defaults to a chevron. Pass ``AppSettingsRowAccessory/none``
  ///     for a row that only reports.
  ///   - action: Omit for a row that is not tappable — it then renders as plain
  ///     content rather than a button, so VoiceOver does not offer to activate
  ///     something that does nothing.
  public init(
    _ title: String,
    systemImage: String? = nil,
    detail: String? = nil,
    detailColor: Color? = nil,
    accessory: AppSettingsRowAccessory = .disclosure,
    emphasis: AppSettingsRowEmphasis = .standard,
    action: (() -> Void)? = nil
  ) {
    self.title = title
    self.systemImage = systemImage
    self.detail = detail
    self.detailColor = detailColor
    self.accessory = accessory
    self.emphasis = emphasis
    self.action = action
  }

  public var body: some View {
    if let action {
      Button(action: action) { label }
        .buttonStyle(PressableButtonStyle())
    } else {
      label.accessibilityElement(children: .combine)
    }
  }

  private var label: AppSettingsRowLabel {
    AppSettingsRowLabel(
      title,
      systemImage: systemImage,
      detail: detail,
      detailColor: detailColor,
      accessory: accessory,
      emphasis: emphasis
    )
  }
}

// MARK: - Group

/// A labelled run of settings rows.
///
/// ```swift
/// AppSettingsGroup(L10n.preferences) {
///   AppSettingsRow(L10n.language, systemImage: "globe", detail: current) { ... }
/// }
/// ```
///
/// The label is sentence case and quiet, not the uppercase header
/// ``AppListSection`` uses — with no card edge to sit against, an uppercase
/// label reads as a heading for the whole screen rather than for the four rows
/// beneath it.
public struct AppSettingsGroup<Content: View>: View {
  private let title: String?
  private let content: Content

  public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let title {
        Text(title)
          .font(AppFont.subheadline)
          .foregroundStyle(AppColor.textTertiary)
          .padding(.bottom, 2)
          .accessibilityAddTraits(.isHeader)
      }

      content
    }
    .appHorizontalInset()
  }
}

// MARK: - Previews

#Preview("Rows") {
  AppSettingsPreview()
}

private struct AppSettingsPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppSettingsRowMetrics.groupSpacing) {
        AppSettingsGroup {
          AppSettingsRow("Account", systemImage: "person.crop.circle") {}
          AppSettingsRow("iCloud Sync", systemImage: "icloud", detail: "Up to date", accessory: .none)
        }

        AppSettingsGroup("Preferences") {
          AppSettingsRow("Language", systemImage: "globe", detail: "English") {}
          AppSettingsRow("Notifications", systemImage: "bell") {}
        }

        AppSettingsGroup("Resources") {
          AppSettingsRow("Rate in App Store", systemImage: "star", accessory: .externalLink) {}
          AppSettingsRow("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", accessory: .none, emphasis: .destructive) {}
        }
      }
      .padding(.vertical, 16)
    }
    .background(AppColor.background)
  }
}
