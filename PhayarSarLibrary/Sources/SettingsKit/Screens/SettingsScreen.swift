import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI

public struct SettingsScreen: View {
  @ObserveInjection private var injectionObserver

  /// The shared manager is observed directly rather than taken from the
  /// environment: it is a singleton either way, and this screen is the one
  /// place that writes to it.
  @ObservedObject private var localisation = LocalisationManager.shared

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
        languageSection
        aboutSection
      }
      .padding(.vertical)
    }
    .appBackground()
    .enableInjection()
  }

  // MARK: - Sections

  private var languageSection: some View {
    AppListSection(L10n.language, footer: L10n.languageFooter) {
      ForEach(Array(Language.allCases.enumerated()), id: \.element) { index, language in
        if index > 0 {
          Divider()
            .padding(.vertical, 8)
        }

        LanguageRow(
          language: language,
          isSelected: localisation.currentLanguage == language
        ) {
          localisation.setLanguage(language)
        }
      }
    }
  }

  private var aboutSection: some View {
    AppListSection(L10n.about) {
      InfoRow(title: L10n.appName, value: AppInfo.name)

      Divider()
        .padding(.vertical, 8)

      InfoRow(title: L10n.version, value: AppInfo.displayVersion)
    }
  }
}

// MARK: - Rows

/// One selectable language, with a checkmark on the active one.
private struct LanguageRow: View {
  let language: Language
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack {
        Text(language.displayName)
          .font(AppFont.listItemTitle)
          .foregroundStyle(AppColor.textPrimary)

        Spacer()

        // Kept in the layout when unselected so rows don't shift width as the
        // selection moves between them.
        Image(systemName: "checkmark")
          .font(AppFont.button)
          .foregroundStyle(AppColor.primary)
          .opacity(isSelected ? 1 : 0)
      }
      // The label only covers the text without this, leaving the row's empty
      // space untappable.
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}

/// A read-only title/value pair.
private struct InfoRow: View {
  let title: String
  let value: String

  var body: some View {
    HStack {
      Text(title)
        .font(AppFont.body)
        .foregroundStyle(AppColor.textPrimary)

      Spacer()

      Text(value)
        .font(AppFont.body)
        .foregroundStyle(AppColor.textSecondary)
    }
  }
}

// MARK: - Previews

#Preview {
  NavigationStack {
    SettingsScreen()
      .navigationTitle(L10n.settingsTab)
  }
}
