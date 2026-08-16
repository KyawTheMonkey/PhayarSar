//
//  PhayarSarApp.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 03/12/2023.
//

import AuthKit
import DesignKit
import EnvironmentKit
import FirebaseCore
import FirebaseMessaging
import KloudKit
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

  /// Who is signed in. Owned here because the gate below and every screen that
  /// asks for an account read the same instance.
  @StateObject private var auth = AuthManager.shared

  /// The light/dark override. Owned here because `preferredColorScheme` has to
  /// be applied to the whole window for it to mean anything.
  @StateObject private var theme = ThemeSwitcher.shared

  init() {
    Typography.registerFonts()
    customiseTopNavFont()
    startPersistence()
  }

  var body: some Scene {
    WindowGroup {
      AppTabView()
        .environmentObject(navigator)
        // Blunt but reliable: rebuilds the tree on a language change so every
        // `L10n` lookup re-runs. `navigator` and `auth` are owned above this
        // view, so tab selection, navigation paths and the sign-in state all
        // survive the rebuild.
        //
        // Deliberately *inside* `.authGate()`. The sign-in screen carries the
        // language switcher, and it observes `LocalisationManager` itself, so
        // it relocalises without this — while sitting outside the rebuild that
        // would otherwise dismiss it the moment the user used that switcher.
        .id(localisation.currentLanguage)
        // Wraps the tabs, so they are not built at all until the user has
        // chosen. The gate itself is a pass-through on every launch after that,
        // and hosts the sign-in cover that any feature can raise.
        .authGate()
        .environmentObject(auth)
        .environmentObject(localisation)
        .environment(\.language, localisation.currentLanguage)
        // Outermost, and applied to the window rather than to a screen: it has
        // to cover the sign-in gate and every sheet the app presents, none of
        // which inherit a color scheme set further in. `nil` for `.system`,
        // which hands the decision back to the device.
        .preferredColorScheme(theme.currentTheme.colorScheme)
    }
  }

  /// Opens the store, in the mode the stored credential calls for.
  ///
  /// Order matters: `AuthManager` has to be configured first, because
  /// `preferredSyncMode` cannot name an iCloud container it has not been given.
  /// Both are synchronous, so by the time the first view is built the store is
  /// open and no screen needs a "loading" branch.
  ///
  /// The app target's own legacy `CoreDataStack` and `PhayarSar.xcdatamodeld`
  /// are untouched by this and remain unreferenced.
  private func startPersistence() {
    AuthManager.shared.configure(
      AuthConfiguration(cloudContainerIdentifier: Self.cloudContainerIdentifier)
    )

    KloudStack.shared.start(
      // Every entity in the app goes in this list. Only AuthKit has one so far;
      // a feature module that adds one has to be named here too, because this is
      // the only place that links them all.
      schema: KloudSchema([AuthProfileRecord.self]),
      mode: AuthManager.shared.preferredSyncMode
    )
  }

  private static let cloudContainerIdentifier = "iCloud.com.kyaw.PhayarSar"

  private func customiseTopNavFont() {
    let appearance = UINavigationBarAppearance()
    appearance.titleTextAttributes = [.font: AppUIFont.listItemTitle]
    appearance.largeTitleTextAttributes = [.font: AppUIFont.largeTitle]
    UINavigationBar.appearance().standardAppearance = appearance
    UINavigationBar.appearance().compactAppearance = appearance
    UINavigationBar.appearance().scrollEdgeAppearance = appearance
  }
}
