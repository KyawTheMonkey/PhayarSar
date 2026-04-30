import DesignKit
import LocalisationKit
import SwiftUI

@main
struct PhayarSarAppV2: App {
  @StateObject private var l10n = LocalisationManager.shared
  @StateObject private var theme = ThemeSwitcher.shared
  @StateObject private var navigator = AppNavigatorModel()

  init() {
    Typography.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      AppContentView()
        .environmentObject(l10n)
        .environment(\.language, l10n.currentLanguage)
        .environmentObject(theme)
        .environmentObject(navigator)
        .preferredColorScheme(theme.currentTheme.colorScheme)
    }
  }
}

// MARK: - Preview
extension View {
  func withPreviewsEnv() -> some View {
    modifier(PreviewEnvModifier())
  }
}

fileprivate struct PreviewEnvModifier: ViewModifier {
  @StateObject private var l10n = LocalisationManager.shared
  @StateObject private var theme = ThemeSwitcher.shared

  func body(content: Content) -> some View {
    content
      .environmentObject(l10n)
      .environment(\.language, l10n.currentLanguage)
      .environmentObject(theme)
      .environmentObject(AppNavigatorModel())
  }
}
