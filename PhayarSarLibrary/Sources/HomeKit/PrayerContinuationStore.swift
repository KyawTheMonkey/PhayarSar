import Combine
import Foundation

/// A reading position belongs to this device, rather than to the prayer's
/// synced appearance settings. Keep only the last opened reading: Home should
/// offer what the reader just left, not a backlog of every prayer ever opened.
@MainActor
final class PrayerContinuationStore: ObservableObject {
  struct Reading: Codable, Equatable, Identifiable {
    var id: String { prayerID }
    let prayerID: String
    let verseID: Int
    let line: Int
    let verse: Int
    let verses: Int
    let fraction: Double
  }

  static let shared = PrayerContinuationStore()
  private static let key = "prayer.lastUnfinishedReading"

  @Published private(set) var reading: Reading?

  private init() {
    if let data = UserDefaults.standard.data(forKey: Self.key) {
      reading = try? JSONDecoder().decode(Reading.self, from: data)
    }
  }

  func save(_ reading: Reading) {
    guard reading != self.reading else { return }
    self.reading = reading
    if let data = try? JSONEncoder().encode(reading) {
      UserDefaults.standard.set(data, forKey: Self.key)
    }
  }

  func finish(prayerID: String) {
    guard reading?.prayerID == prayerID else { return }
    reading = nil
    UserDefaults.standard.removeObject(forKey: Self.key)
  }
}
