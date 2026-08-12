import PrayersKit
import SwiftUI

final class HomeViewModel: ObservableObject {
  @Published var activeSegment: HomeScreen.Segment = .prayers
  @Published var prayers: [(category: PrayerCategory, prayers: [Prayer])] = []
  private let prayerLoader: PrayerLoader = PrayerLoader.shared

  func onAppear() {
    loadPrayers()
  }
  
  private func loadPrayers(){
    do {
      prayers = [
        (
          category: PrayerCategory.precepts,
          prayers: [
            try prayerLoader.prayer(named: "သြကာသ.json"),
            try prayerLoader.prayer(named: "သရဏဂုံ"),
            try prayerLoader.prayer(named: "သီလတောင်း"),
            try prayerLoader.prayer(named: "ငါးပါးသီလ"),
            try prayerLoader.prayer(named: "ရှစ်ပါးသီလ"),
            try prayerLoader.prayer(named: "ဆယ်ပါးသီလ"),
            try prayerLoader.prayer(named: "အမျှဝေ")
          ]
        )
      ]
    } catch {
      print(error)
    }
  }
}
