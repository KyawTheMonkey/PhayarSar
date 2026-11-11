import PrayersKit
import SwiftUI

final class HomeViewModel: ObservableObject {
  @Published var filter: HomeScreen.Filter = .all
  @Published var sections: [PrayerSection] = []
  @Published var feature: HomeFeature?
  @Published var moments: [PrayerCollection] = []
  /// A handful for the rail; "See all" pushes the full collection.
  @Published var shortPrayers: [Prayer] = []
  private static let railLimit = 8
  private let catalog: PrayerCatalog = PrayerCatalog.shared

  /// The catalog caches after first read, but `onAppear` fires on every return
  /// to the tab — so skip that work once it is populated. The feature is
  /// recomputed every time: it depends on the clock, and coming back to Home in
  /// the evening should not still show the morning pick.
  func onAppear() {
    if sections.isEmpty {
      sections = catalog.sections()
      moments = PrayerCollection.moments(catalog: catalog)
      shortPrayers = Array(
        (PrayerCollection(kind: .short, catalog: catalog)?.prayers ?? []).prefix(Self.railLimit)
      )
    }
    let current = HomeFeature.current(catalog: catalog)
    if current != feature {
      feature = current
    }
  }
}
