//
//  RouteView.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 15/08/2026.
//

import EnvironmentKit
import HomeKit
import SwiftUI

/// Turns a `RouterDestination` into the screen it names.
///
/// Resolution lives in the app target because it is the only place that links
/// every feature module, and because SwiftUI allows just one
/// `navigationDestination` per type per stack — so there can only be one of
/// these, not one per module.
///
/// The switch is exhaustive on purpose: a new route then fails to build until
/// it has a screen, rather than pushing a blank view at runtime.
struct RouteView: View {
  let destination: RouterDestination

  var body: some View {
    switch destination {
    case let .prayerDetail(prayerID):
      PrayerDetailScreen(prayerID: prayerID)
    case let .prayer(prayerID):
      PrayerScreen(prayerID: prayerID)
    case let .nissaya(prayerID):
      NissayaScreen(prayerID: prayerID)
    }
  }
}

/// The modal counterpart to `RouteView`.
struct SheetView: View {
  let destination: SheetDestination

  var body: some View {
    switch destination {
    case .dummy:
      // Placeholder — `SheetDestination` has no real case yet.
      EmptyView()
    }
  }
}
