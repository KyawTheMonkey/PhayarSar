import LocalisationKit
import SwiftUI

/// Shown when a route's id matches no bundled prayer.
///
/// Reachable state rather than a programmer error: with id-carrying routes, a
/// notification payload or a restored stack can name a prayer that a later
/// build no longer ships. Shared by every screen a prayer id can open.
struct PrayerNotFoundView: View {
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
