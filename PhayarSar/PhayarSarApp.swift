//
//  PhayarSarApp.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 03/12/2023.
//

import DesignKit
import FirebaseCore
import FirebaseMessaging
import LocalisationKit
import SwiftUI
import UserNotifications

var langDict: [String: [String: String]] = [:]

@main
struct PhayarSarApp: App {
  init() {
    Typography.registerFonts()
    customiseTopNavFont()
  }

  var body: some Scene {
    WindowGroup {
      AppTabView()
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
