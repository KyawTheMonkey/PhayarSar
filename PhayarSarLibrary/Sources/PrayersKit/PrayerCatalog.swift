import Foundation

/// One category's worth of prayers, ready to render as a list section.
public struct PrayerSection: Identifiable, Hashable, Sendable {
  public let category: PrayerCategory
  public let prayers: [Prayer]

  /// Categories are unique within a catalog, so the category is the identity.
  public var id: PrayerCategory { category }

  public init(category: PrayerCategory, prayers: [Prayer]) {
    self.category = category
    self.prayers = prayers
  }
}

/// The shape of `manifest.json`. Category ids stay `String` here rather than
/// `PrayerCategory` so that one unrecognised id skips its own section instead of
/// failing the whole decode.
private struct PrayerManifest: Decodable {
  struct Category: Decodable {
    let id: String
    let prayers: [String]
  }

  let categories: [Category]
}

/// Groups the bundled prayers into ordered, categorised sections.
///
/// ```swift
/// for section in PrayerCatalog.shared.sections() {
///   print(section.category.displayText, section.prayers.count)
/// }
/// ```
///
/// The taxonomy lives in `Prayers/manifest.json`, which maps each category to an
/// ordered list of prayer *file names* — the same strings
/// ``PrayerLoader/prayer(named:)`` takes. File names rather than ``Prayer/id``
/// because the ids are a mix of Burmese and romanised spellings, while the file
/// names are uniform.
///
/// Every lookup is lenient: a prayer that fails to load is skipped, and a
/// category that ends up with no prayers is dropped. A single renamed file can
/// therefore never blank the whole list.
public final class PrayerCatalog: @unchecked Sendable {
  public static let shared = PrayerCatalog()

  /// Bundle resource name of the taxonomy file. `.process("Prayers")` flattens
  /// the folder into the bundle root, so ``PrayerLoader/availablePrayerNames()``
  /// filters this out to keep it from looking like a prayer.
  static let manifestResourceName = "manifest"

  private let loader: PrayerLoader
  private let bundle: Bundle
  private var cached: [PrayerSection]?
  private var idIndex: [Prayer.ID: Prayer]?
  private let cacheQueue = DispatchQueue(label: "com.phayarsar.prayers.catalog")

  /// Reads the manifest from the PrayersKit resource bundle.
  ///
  /// Separate from the designated initialiser for the same reason as
  /// ``PrayerLoader/init()`` — `Bundle.module` cannot be a default argument on a
  /// public initialiser.
  public convenience init() {
    self.init(loader: .shared, bundle: .module)
  }

  /// - Parameters:
  ///   - loader: Resolves each file name to a ``Prayer``.
  ///   - bundle: Injectable so tests can point at a fixture manifest.
  public init(loader: PrayerLoader, bundle: Bundle) {
    self.loader = loader
    self.bundle = bundle
  }

  /// The catalog in manifest order, decoded once and cached.
  ///
  /// - Returns: Empty if the manifest is missing or malformed.
  public func sections() -> [PrayerSection] {
    if let cached = cacheQueue.sync(execute: { cached }) {
      return cached
    }

    let sections = loadSections()
    cacheQueue.sync { cached = sections }
    return sections
  }

  /// Looks a prayer up by ``Prayer/id``.
  ///
  /// This is the key that `RouterDestination` carries and that
  /// `PrayerConfiguration.prayerId` persists — deliberately not the file name
  /// ``PrayerLoader/prayer(named:)`` takes, which is a separate namespace.
  ///
  /// - Returns: `nil` if no prayer in the catalog has that id. A stale deep
  ///   link or an id from an older build both land here, so callers must
  ///   handle it rather than force-unwrap.
  public func prayer(id: Prayer.ID) -> Prayer? {
    if let index = cacheQueue.sync(execute: { idIndex }) {
      return index[id]
    }

    // Built from `sections()` rather than `loader.allPrayers()` so it reuses
    // the decode the list screen has already paid for. A prayer left out of
    // the manifest is therefore unreachable by id — which matches the fact
    // that it is also unreachable by tapping.
    let index = Dictionary(
      sections().flatMap(\.prayers).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    cacheQueue.sync { idIndex = index }
    return index[id]
  }

  private func loadSections() -> [PrayerSection] {
    guard
      let url = bundle.url(forResource: Self.manifestResourceName, withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let manifest = try? JSONDecoder().decode(PrayerManifest.self, from: data)
    else {
      return []
    }

    return manifest.categories.compactMap { entry in
      guard let category = PrayerCategory(rawValue: entry.id) else { return nil }

      let prayers = entry.prayers.compactMap { try? loader.prayer(named: $0) }
      guard !prayers.isEmpty else { return nil }

      return PrayerSection(category: category, prayers: prayers)
    }
  }
}
