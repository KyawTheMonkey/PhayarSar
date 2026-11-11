import DesignKit
import LocalisationKit
import PrayersKit

/// A named list of prayers that Home's All filter can push as its own screen.
///
/// All used to send "See all" to the Prayers filter, which swapped the whole
/// page out from under the user and left no way back to where they were. A
/// collection is the thing that gets pushed instead: it has an id a route can
/// carry, so it sits on the navigation stack like any other screen.
///
/// Three kinds share the one type because they share the one screen:
/// - **moments** group prayers by when or why they are recited, cutting across
///   the catalog's categories;
/// - **categories** are the catalog's own sections, reached from "By scripture";
/// - **short** is every prayer at or under ``shortMinutes``.
///
/// Moments are hand-picked prayer ids (the `id` inside each prayer's JSON, not
/// its file name). A missing id is dropped, as in ``HomeFeature``, and a
/// collection that ends up empty does not exist — `init?(id:)` returns `nil`
/// and the grid leaves its card out.
struct PrayerCollection: Identifiable {
  enum Moment: String, CaseIterable {
    case waking
    case sleep
    case sabbath
    case protection
    case lovedOnes = "loved-ones"
    case unwell

    var title: String {
      switch self {
      case .waking: return L10n.momentWaking
      case .sleep: return L10n.momentSleep
      case .sabbath: return L10n.momentSabbath
      case .protection: return L10n.momentProtection
      case .lovedOnes: return L10n.momentLovedOnes
      case .unwell: return L10n.momentUnwell
      }
    }

    /// Neighbours in the two-column grid never share a tint.
    var tint: AppColor.Tint {
      switch self {
      case .waking: return .amber
      case .sleep: return .indigo
      case .sabbath: return .rose
      case .protection: return .forest
      case .lovedOnes: return .plum
      case .unwell: return .teal
      }
    }

    /// The cover a moment's card shows. Chosen by hand rather than taken from
    /// the first prayer, because several moments open with the same prayer and
    /// the grid would then show the same picture twice.
    fileprivate var coverID: Prayer.ID {
      switch self {
      case .waking: return "သြကာသ"
      case .sleep: return "မေတ္တသုတ်"
      case .sabbath: return "ရှစ်ပါးသီလ"
      case .protection: return "ရတနသုတ်"
      case .lovedOnes: return "အမျှဝေ"
      case .unwell: return "ဗောဇ္ဈင်္ဂသုတ်"
      }
    }

    /// `nil` for protection, which is two whole categories rather than a list.
    fileprivate var prayerIDs: [Prayer.ID]? {
      switch self {
      case .waking:
        return ["သြကာသ", "သရဏဂုံ", "nga-par-thila", "ပုဗ္ဗဏှသုတ်", "မင်္ဂလသုတ်"]
      case .sleep:
        return ["မေတ္တသုတ်", "မေတ္တာသုတ်လာမ္မေတ္တာပွား", "ဆယ်မျက်နှာမ္မေတ္တာပွား", "အမျှဝေ"]
      case .sabbath:
        return ["သြကာသ", "သီလတောင်း", "ရှစ်ပါးသီလ", "ဘုရားဂုဏ်တော်", "ta-ra-gon-daw", "သံဃာဂုဏ်တော်"]
      case .protection:
        return nil
      case .lovedOnes:
        return ["မေတ္တသုတ်", "ဆယ်မျက်နှာမ္မေတ္တာပွား", "အမျှဝေ"]
      case .unwell:
        // The Bojjhanga is the discourse traditionally recited for the sick;
        // the Ratana was recited against the plague at Vesali.
        return ["ဗောဇ္ဈင်္ဂသုတ်", "ရတနသုတ်"]
      }
    }
  }

  enum Kind: Hashable {
    case moment(Moment)
    case category(PrayerCategory)
    case short
  }

  /// A prayer this long or shorter counts as short.
  static let shortMinutes = 2

  let kind: Kind
  let prayers: [Prayer]

  // MARK: Identity

  /// `moment.sleep`, `category.precepts`, `short`. A string so it can ride in
  /// a `RouterDestination`, which must stay `Codable` and free of domain types.
  var id: String { Self.id(for: kind) }

  static func id(for kind: Kind) -> String {
    switch kind {
    case let .moment(moment): return "moment.\(moment.rawValue)"
    case let .category(category): return "category.\(category.rawValue)"
    case .short: return "short"
    }
  }

  var title: String {
    switch kind {
    case let .moment(moment): return moment.title
    case let .category(category): return category.displayText
    case .short: return L10n.twoMinutesOrLess
    }
  }

  /// Falls back to the first prayer when the hand-picked cover is not in the
  /// collection, so a renamed prayer costs a picture's variety, not the picture.
  var coverPrayerID: Prayer.ID? {
    if case let .moment(moment) = kind, prayers.contains(where: { $0.id == moment.coverID }) {
      return moment.coverID
    }
    return prayers.first?.id
  }

  var totalMinutes: Int { prayers.reduce(0) { $0 + $1.estimatedMinutes } }

  var summary: String {
    L10n.collectionSummary(
      .init(stringLiteral: prayers.count.formatted()),
      .init(stringLiteral: totalMinutes.formatted())
    )
  }

  // MARK: Resolution

  init?(kind: Kind, catalog: PrayerCatalog = .shared) {
    let prayers: [Prayer]
    switch kind {
    case let .moment(moment):
      if let ids = moment.prayerIDs {
        prayers = ids.compactMap { catalog.prayer(id: $0) }
      } else {
        prayers = catalog.sections()
          .filter { $0.category == .parittas || $0.category == .protection }
          .flatMap(\.prayers)
      }
    case let .category(category):
      prayers = catalog.sections().first { $0.category == category }?.prayers ?? []
    case .short:
      prayers = catalog.orderedPrayers().filter { $0.estimatedMinutes <= Self.shortMinutes }
    }
    guard !prayers.isEmpty else { return nil }
    self.kind = kind
    self.prayers = prayers
  }

  init?(id: String, catalog: PrayerCatalog = .shared) {
    let parts = id.split(separator: ".", maxSplits: 1).map(String.init)
    let kind: Kind
    switch (parts.first, parts.dropFirst().first) {
    case ("short", nil):
      kind = .short
    case let ("moment", raw?):
      guard let moment = Moment(rawValue: raw) else { return nil }
      kind = .moment(moment)
    case let ("category", raw?):
      guard let category = PrayerCategory(rawValue: raw) else { return nil }
      kind = .category(category)
    default:
      return nil
    }
    self.init(kind: kind, catalog: catalog)
  }

  static func moments(catalog: PrayerCatalog = .shared) -> [PrayerCollection] {
    Moment.allCases.compactMap { PrayerCollection(kind: .moment($0), catalog: catalog) }
  }
}
