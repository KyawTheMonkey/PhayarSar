import Foundation

/// Why a prayer file could not be turned into a ``Prayer``.
public enum PrayerLoadingError: Error, LocalizedError, Equatable {
  /// No `<name>.json` in the bundle. Usually a typo, or a file that was added
  /// to the folder but the target was not rebuilt.
  case fileNotFound(name: String)
  /// The file exists but could not be read off disk.
  case unreadable(name: String, underlying: String)
  /// The file is present and readable but is not a valid `Prayer`.
  case decodingFailed(name: String, underlying: String)

  public var errorDescription: String? {
    switch self {
    case let .fileNotFound(name):
      return "No prayer named '\(name)' in the PrayersKit bundle."
    case let .unreadable(name, underlying):
      return "Could not read prayer '\(name)': \(underlying)"
    case let .decodingFailed(name, underlying):
      return "Could not decode prayer '\(name)': \(underlying)"
    }
  }
}

/// Loads prayers from the bundled JSON files, caching each one after first read.
///
/// ```swift
/// let metta = try PrayerLoader.shared.prayer(named: "မေတ္တသုတ်")
/// print(metta.body[2].content)
/// ```
///
/// The prayer files are named in Burmese, which is also the value of
/// ``Prayer/id`` for most of them — but not all, so prefer listing with
/// ``availablePrayerNames()`` over hardcoding.
public final class PrayerLoader: @unchecked Sendable {
  public static let shared = PrayerLoader()

  private let bundle: Bundle
  private var cache: [String: Prayer] = [:]
  private let cacheQueue = DispatchQueue(label: "com.phayarsar.prayers.cache")

  /// Reads from the PrayersKit resource bundle.
  ///
  /// `Bundle.module` is internal to the module, so it cannot be spelled as a
  /// default argument on a public initialiser — hence the separate overload.
  public convenience init() {
    self.init(bundle: .module)
  }

  /// - Parameter bundle: Injectable so tests can point at a fixture bundle.
  public init(bundle: Bundle) {
    self.bundle = bundle
  }

  /// Decodes the prayer stored as `<name>.json`.
  ///
  /// - Parameter name: The file name, with or without the `.json` extension.
  ///   Unicode-normalised before lookup, so Burmese text typed on different
  ///   keyboards still resolves to the same file.
  /// - Throws: ``PrayerLoadingError``.
  public func prayer(named name: String) throws -> Prayer {
    let key = Self.normalise(name)

    if let cached = cacheQueue.sync(execute: { cache[key] }) {
      return cached
    }

    guard let url = bundle.url(forResource: key, withExtension: "json") else {
      throw PrayerLoadingError.fileNotFound(name: name)
    }

    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      throw PrayerLoadingError.unreadable(name: name, underlying: "\(error)")
    }

    let prayer: Prayer
    do {
      prayer = try JSONDecoder().decode(Prayer.self, from: data)
    } catch {
      throw PrayerLoadingError.decodingFailed(name: name, underlying: "\(error)")
    }

    cacheQueue.sync { cache[key] = prayer }
    return prayer
  }

  /// Every prayer file in the bundle, sorted. These are the valid arguments to
  /// ``prayer(named:)``.
  ///
  /// Excludes `manifest.json` — it sits in the same flattened resource root but
  /// describes the catalog rather than a prayer. See ``PrayerCatalog``.
  public func availablePrayerNames() -> [String] {
    let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
    return urls
      .map { $0.deletingPathExtension().lastPathComponent }
      .filter { $0 != PrayerCatalog.manifestResourceName }
      .sorted()
  }

  /// Decodes every bundled prayer. Skips — rather than throws on — any file
  /// that fails, so one bad file cannot take down a whole list screen.
  public func allPrayers() -> [Prayer] {
    availablePrayerNames().compactMap { try? prayer(named: $0) }
  }

  /// Strips a trailing `.json` and applies canonical composition, so callers
  /// can pass either form and any keyboard's byte sequence.
  private static func normalise(_ name: String) -> String {
    let trimmed = name.hasSuffix(".json") ? String(name.dropLast(5)) : name
    return trimmed.precomposedStringWithCanonicalMapping
  }
}
