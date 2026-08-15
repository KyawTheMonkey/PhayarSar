import PrayersKit
import SwiftUI

final class HomeViewModel: ObservableObject {
  @Published var activeSegment: HomeScreen.Segment = .prayers
  @Published var sections: [PrayerSection] = []
  private let catalog: PrayerCatalog = PrayerCatalog.shared

  /// The catalog caches after first read, but `onAppear` fires on every return
  /// to the tab — so skip the work once it is populated.
  func onAppear() {
    guard sections.isEmpty else { return }
    sections = catalog.sections()
  }
}
