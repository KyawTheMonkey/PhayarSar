import Inject
import LocalisationKit
import PrayersKit
import SwiftUI

public struct PrayerDetailScreen: View {
  @ObserveInjection private var injectionObserver

  /// Resolved from the id the route carried rather than passed in whole — see
  /// `RouterDestination`, whose payloads are ids so that routes stay `Codable`.
  private let prayer: Prayer?

  public init(prayerID: String) {
    self.prayer = PrayerCatalog.shared.prayer(id: prayerID)
  }

  public var body: some View {
    Group {
      if let prayer {
        Text(prayer.title)
      } else {
        PrayerNotFoundView()
      }
    }
    // Deliberately no `.hideNavBar()` here — unlike `HomeScreen`, which draws
    // its own collapsing bar, this screen needs the system bar for its back
    // button.
    .navigationTitle(prayer?.title ?? L10n.prayerNotFound)
    // No navigation bar on macOS, so no display mode to set either.
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .enableInjection()
  }
}

/// Shown when the route's id matches no bundled prayer.
///
/// Reachable state rather than a programmer error: with id-carrying routes, a
/// notification payload or a restored stack can name a prayer that a later
/// build no longer ships.
private struct PrayerNotFoundView: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "questionmark.circle")
        .font(.largeTitle)
      Text(L10n.prayerNotFound)
        .multilineTextAlignment(.center)
    }
    .foregroundStyle(.secondary)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  NavigationStack {
    PrayerDetailScreen(prayerID: "Khandha")
  }
}

#Preview("Not found") {
  NavigationStack {
    PrayerDetailScreen(prayerID: "no-such-prayer")
  }
}
