import Foundation

/// A single prayer, decoded from its bundled JSON file.
///
/// Every file under `Sources/PrayersKit/Prayers` shares one schema, so no
/// per-file special casing is needed. Load one with
/// ``PrayerLoader/prayer(named:)``.
public struct Prayer: Decodable, Identifiable, Hashable, Sendable {
  /// Stable key for this prayer. Also what `PrayerConfiguration.prayerId`
  /// persists against, so it must not change without a CoreData migration.
  public let id: String
  public let title: String
  /// Long-form background text. May contain `\n\n` paragraph breaks.
  public let about: String
  public let body: [Verse]

  public init(id: String, title: String, about: String, body: [Verse]) {
    self.id = id
    self.title = title
    self.about = about
    self.body = body
  }
}

extension Prayer {
  /// One recitable unit — a verse, a precept, or a paragraph.
  public struct Verse: Decodable, Identifiable, Hashable, Sendable {
    /// 1-based position within ``Prayer/body``.
    public let index: Int
    /// Set only where the source names each unit — currently just the 24
    /// paccayas in ပဋ္ဌာန်းအကျယ်.
    public let name: String?
    /// The Pali/Burmese text as recited.
    public let content: String
    /// Burmese phonetic respelling. Empty for prayers that have no
    /// transliteration yet, so check `isEmpty` before showing it.
    public let pronunciation: String
    /// Burmese translation. Empty for the same reason as `pronunciation`.
    public let meaning: String

    public var id: Int { index }

    public init(
      index: Int,
      name: String? = nil,
      content: String,
      pronunciation: String = "",
      meaning: String = ""
    ) {
      self.index = index
      self.name = name
      self.content = content
      self.pronunciation = pronunciation
      self.meaning = meaning
    }
  }
}
