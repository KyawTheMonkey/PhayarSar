import DesignKit
import Foundation
import LocalisationKit
import PrayersKit

/// The prayers Home suggests right now, and why.
///
/// Picked by the time of day rather than by history or popularity, because the
/// practice itself is organised that way: the morning sutta and the precepts
/// open the day, the virtues of the Triple Gem are recollected through it, and
/// metta and the sharing of merit close it. That makes the suggestion useful on the
/// very first launch, before there is any reading history to learn from, and
/// it never needs a network call or a stored profile.
///
/// The lists are hand-picked prayer ids, not categories, so each period can
/// mix categories where the practice does. Ids are the `id` field inside each
/// prayer's JSON, which is usually but not always its file name — the five
/// precepts are `nga-par-thila` and the Dhamma virtues `ta-ra-gon-daw`.
/// An id that is missing from the catalog is dropped rather than drawn as a
/// blank cover, so renaming a prayer shrinks the list instead of breaking
/// it.
struct HomeFeature: Equatable {
  enum Period: Equatable {
    case morning
    case day
    case evening

    /// 04:00–10:59 morning, 11:00–16:59 day, everything else evening. The
    /// evening runs through the small hours on purpose: someone reading at
    /// 2 a.m. is ending their day, not starting it.
    init(hour: Int) {
      switch hour {
      case 4..<11: self = .morning
      case 11..<17: self = .day
      default: self = .evening
      }
    }

    /// The middle one is the period's main suggestion — see ``HomeFeature/pick``.
    fileprivate var prayerIDs: [Prayer.ID] {
      switch self {
      case .morning: return ["သြကာသ", "ပုဗ္ဗဏှသုတ်", "nga-par-thila"]
      case .day: return ["ta-ra-gon-daw", "ဘုရားဂုဏ်တော်", "သံဃာဂုဏ်တော်"]
      case .evening: return ["မင်္ဂလသုတ်", "မေတ္တသုတ်", "အမျှဝေ"]
      }
    }
  }

  let period: Period
  let prayers: [Prayer]

  var title: String {
    switch period {
    case .morning: return L10n.featuredMorningTitle
    case .day: return L10n.featuredDayTitle
    case .evening: return L10n.featuredEveningTitle
    }
  }

  /// The period's main suggestion: the middle of the three.
  var pick: Prayer { prayers[prayers.count / 2] }

  var tint: AppColor.Tint {
    switch period {
    case .morning: return .amber
    case .day: return .forest
    case .evening: return .indigo
    }
  }

  /// `nil` only if none of the period's prayers exist in the catalog.
  static func current(
    at date: Date = .now,
    calendar: Calendar = .current,
    catalog: PrayerCatalog = .shared
  ) -> HomeFeature? {
    let period = Period(hour: calendar.component(.hour, from: date))
    let prayers = period.prayerIDs.compactMap { catalog.prayer(id: $0) }
    guard !prayers.isEmpty else { return nil }
    return HomeFeature(period: period, prayers: prayers)
  }
}
