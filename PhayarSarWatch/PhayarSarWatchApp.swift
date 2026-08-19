//
//  PhayarSarWatchApp.swift
//  PhayarSarWatch
//

import DesignKit
import SwiftUI
import WristKit

/// The watch app, which is a window around `WristRootView` and nothing else.
///
/// Everything it does lives in `WristKit`, alongside the phone's own modules and
/// alongside `RemoteKit` — the wire types the two apps have to agree on. Keeping
/// the target this thin is what stops the agreement drifting: there is no second
/// copy of a command enum here to fall behind the one on the phone.
@main
struct PhayarSarWatchApp: App {

  init() {
    // The same call the phone app makes. The Burmese faces are what the prayer
    // titles and the verse glance are set in, and a watch that skipped this
    // would fall back to the system font for both.
    Typography.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      WristRootView()
    }
  }
}
