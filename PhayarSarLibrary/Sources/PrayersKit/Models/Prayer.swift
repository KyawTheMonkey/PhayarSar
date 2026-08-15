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

  /// Roughly how long this prayer takes to recite, in whole minutes.
  ///
  /// Derived from the body text rather than read from the JSON: no source
  /// records a timing, and a hand-kept number across thirty-odd files would
  /// drift the first time a verse is corrected. See
  /// ``estimatedMinutes(for:)`` for how the figure is arrived at.
  ///
  /// Stored rather than computed on demand. Counting graphemes walks the whole
  /// body with Unicode segmentation — 0.36ms for ပဋ္ဌာန်းအကျယ် on a Mac, more on
  /// a phone — which is far too much to pay from inside a SwiftUI `body`, where
  /// the home list would repeat it for every visible row on every scroll frame.
  /// Prayers are decoded once and cached by ``PrayerCatalog``, so paying here
  /// means paying once.
  public let estimatedMinutes: Int

  /// Omits ``estimatedMinutes``, which is derived from `body` rather than
  /// decoded — without this the synthesised conformance would look for it in
  /// the JSON and every file would fail to load.
  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case about
    case body
  }

  public init(id: String, title: String, about: String, body: [Verse]) {
    self.id = id
    self.title = title
    self.about = about
    self.body = body
    self.estimatedMinutes = Self.estimatedMinutes(for: body)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.title = try container.decode(String.self, forKey: .title)
    self.about = try container.decode(String.self, forKey: .about)
    self.body = try container.decode([Verse].self, forKey: .body)
    self.estimatedMinutes = Self.estimatedMinutes(for: self.body)
  }
}

// MARK: - Estimated duration

extension Prayer {
  /// Graphemes of recited text one minute of steady chanting covers.
  ///
  /// Calibrated against prayers whose chanting length is well known: at this
  /// rate သရဏဂုံ lands at 1 minute, ရတနသုတ် at 12 and ဓမ္မစကြာသုတ် at 22, which
  /// is where each actually sits.
  private static let chantedGraphemesPerMinute = 180.0

  /// Only ``Verse/content`` counts — `pronunciation` and `meaning` are reading
  /// aids, not recited. Never returns 0, so the shortest prayers read as
  /// "1 min" rather than as taking no time at all.
  private static func estimatedMinutes(for body: [Verse]) -> Int {
    let graphemes = body.reduce(0) { $0 + $1.content.count }
    let minutes = Double(graphemes) / chantedGraphemesPerMinute
    return max(1, Int(minutes.rounded()))
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
