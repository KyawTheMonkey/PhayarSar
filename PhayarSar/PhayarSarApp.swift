//
//  PhayarSarApp.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 03/12/2023.
//

import DesignKit
import EnvironmentKit
import FirebaseCore
import FirebaseMessaging
import LocalisationKit
import SwiftUI
import UserNotifications

var langDict: [String: [String: String]] = [:]

@main
struct PhayarSarApp: App {
  /// Owned at the root so every tab's stack outlives the views that push onto
  /// it — including across the size-class switch between the split view and
  /// the tab view.
  @StateObject private var navigator = AppNavigatorModel()

  /// The language selection lives here so a change in Settings re-renders the
  /// whole app — `L10n` resolves through `LocalisationManager.shared` at read
  /// time, so views only pick up a new language when they rebuild.
  @StateObject private var localisation = LocalisationManager.shared

  init() {
    Typography.registerFonts()
    customiseTopNavFont()
  }

  var body: some Scene {
    WindowGroup {
      AppTabView()
        .environmentObject(navigator)
        .environmentObject(localisation)
        .environment(\.language, localisation.currentLanguage)
        // Blunt but reliable: rebuilds the tree on a language change so every
        // `L10n` lookup re-runs. `navigator` is owned above this view, so tab
        // selection and navigation paths survive the rebuild.
        .id(localisation.currentLanguage)
    }
  }

  private func customiseTopNavFont() {
    let appearance = UINavigationBarAppearance()
    appearance.titleTextAttributes = [.font: AppUIFont.listItemTitle]
    appearance.largeTitleTextAttributes = [.font: AppUIFont.largeTitle]
    UINavigationBar.appearance().standardAppearance = appearance
    UINavigationBar.appearance().compactAppearance = appearance
    UINavigationBar.appearance().scrollEdgeAppearance = appearance
  }
}
