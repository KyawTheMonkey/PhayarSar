//
//  RouteView.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 15/08/2026.
//

import AuthKit
import BeadsKit
import EnvironmentKit
import HomeKit
import MeditationKit
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
    case .profile:
      ProfileScreen()
    case let .prayerDetail(prayerID):
      PrayerDetailScreen(prayerID: prayerID)
    case let .prayer(prayerID):
      PrayerScreen(prayerID: prayerID)
    case let .nissaya(prayerID):
      NissayaScreen(prayerID: prayerID)
    case .beadsPrayerBrowser:
      BeadsPrayerBrowserScreen()
    case let .beadsPrayerSelection(prayerID, location):
      BeadsPrayerSelectionScreen(prayerID: prayerID, initialPassage: location)
    }
  }
}

/// The modal counterpart to `RouteView`.
struct SheetView: View {
  @EnvironmentObject private var navigator: AppNavigatorModel
  let destination: SheetDestination

  var body: some View {
    switch destination {
    case .profile:
      // Wrapped so the screen keeps its title bar — `navigationTitle` draws
      // nothing in a bare sheet. The drag indicator is the visible half of the
      // promise the sheet is already making: this closes with a flick.
      NavigationStack(path: $navigator.sheetPath) {
        ProfileScreen()
          .navigationDestination(for: RouterDestination.self) { RouteView(destination: $0) }
      }
      .presentationDragIndicator(.visible)

    case .meditationSessionCreator:
      // Bare, unlike the profile sheet. No `NavigationStack` — this screen has
      // no title and no bar, so a stack would contribute nothing but an empty
      // one — and no presentation modifiers, because the creator sets its own
      // from inside. See `creatorSheetPresentation()`.
      MeditationSessionCreatorScreen()

    case .beadsCreator:
      BeadsCreatorContext {
        NavigationStack(path: $navigator.sheetPath) {
          BeadsCreatorScreen()
            .navigationDestination(for: RouterDestination.self) { RouteView(destination: $0) }
        }
      }
      .presentationDragIndicator(.visible)

    case let .beadsRecitationEditor(beadsID):
      BeadsCreatorContext(beadsID: beadsID) {
        NavigationStack(path: $navigator.sheetPath) {
          BeadsPrayerBrowserScreen()
            .navigationDestination(for: RouterDestination.self) { RouteView(destination: $0) }
        }
      }
      .presentationDragIndicator(.visible)
    }
  }
}
