import Foundation
import KloudKit
import LocalisationKit

/// One prayer's reading configuration, in the synced store.
///
/// Keyed by ``Prayer/id`` rather than by a relationship to a prayer, because
/// prayers are not in the store at all — they are decoded from the bundled JSON
/// by ``PrayerCatalog``. A row whose `prayerID` names a prayer this build no
/// longer ships is simply never read.
///
/// **Flat columns rather than one encoded blob**, which
/// ``KloudAttribute/codable(_:)`` would also have allowed. Three reasons:
/// `KloudStack` merges with `mergeByPropertyObjectTrump`, which resolves
/// conflicts a property at a time — two devices changing different settings
/// converge, where a blob is one property and one device's whole page would win.
/// An unknown raw value in a later build's `font` falls back to the standard face
/// and leaves every other column intact, where a blob fails to decode whole.
/// And adding a setting later is a new nullable column rather than a decode
/// break.
///
/// There is deliberately no `background` column — see ``PrayerConfiguration``.
@objc(PrayerConfigurationRecord)
public final class PrayerConfigurationRecord: NSManagedObject, KloudEntity {
  @NSManaged public var prayerID: String?

  /// The scalars are `NSNumber?`, not `Int`/`Double`/`Bool`.
  ///
  /// ``KloudAttribute`` makes every attribute optional — CloudKit's rule, with no
  /// way to opt out — and a null read back through a Swift scalar arrives as
  /// `0`/`false` rather than as nothing. That is unusable here: `0` is a legal
  /// letter spacing and a legal line spacing, and `false` is the opposite of what
  /// `showsPronunciation` defaults to. Boxing them keeps "never written" distinct
  /// from "written as zero", so the fallback to ``PrayerSettings/standard`` can
  /// live in exactly one place, ``asConfiguration``.
  @NSManaged public var textSize: NSNumber?
  @NSManaged public var font: String?
  @NSManaged public var alignment: String?
  @NSManaged public var letterSpacing: NSNumber?
  @NSManaged public var lineSpacing: NSNumber?
  @NSManaged public var verseSpacing: NSNumber?
  @NSManaged public var showsPronunciation: NSNumber?

  /// The theme, as ``PrayerThemeSlot/rawValue``. The paper is resolved from this
  /// and the current appearance, and is not stored.
  @NSManaged public var themeSlot: String?

  /// How fast the page reads itself, as ``PrayerPlaybackSpeed/rawValue`` — the
  /// multiple, not the interval. What a multiple works out to in seconds belongs
  /// to the reader and may be retuned; what the reader *chose* must not change
  /// under them because of it.
  ///
  /// Boxed like the other scalars: `0` is not a legal pace, so a null read back
  /// as one would be indistinguishable from a row this build wrote.
  @NSManaged public var playbackSpeed: NSNumber?

  /// When this row was last written. Read to break ties between two devices that
  /// both inserted before they had synced — see
  /// ``PrayerConfigurationStore/loadIfNeeded()``.
  @NSManaged public var updatedAt: Date?

  public static var storageLabel: String { L10n.prayerSettings }

  /// Clearable, unlike `AuthProfileRecord` next door: this is content the reader
  /// made, one row per prayer they have themed, and clearing it returns those
  /// prayers to the standard page rather than costing them anything they cannot
  /// produce again.
  ///
  /// (`isUserClearable` defaults to `true`, so it is not overridden — this note
  /// is here because the neighbouring entity sets it `false`.)

  /// The prayer's own title, so the per-item delete list names what it is about
  /// to clear. Without it the list would be thirty identical "Reading settings"
  /// rows.
  public var storageTitle: String {
    guard let prayerID else { return Self.storageLabel }
    return PrayerCatalog.shared.prayer(id: prayerID)?.title ?? prayerID
  }

  public static func makeEntity() -> NSEntityDescription {
    let entity = NSEntityDescription()
    // No `defaultValue:` anywhere: every write goes through `apply(_:for:)`,
    // which sets all of them, so a default would only ever be read on a row that
    // is missing a column — and `asConfiguration` already answers that case, in
    // one place, with the value `PrayerSettings.standard` actually carries.
    entity.properties = [
      KloudAttribute.make("prayerID", .stringAttributeType),
      KloudAttribute.make("textSize", .integer16AttributeType),
      KloudAttribute.make("font", .stringAttributeType),
      KloudAttribute.make("alignment", .stringAttributeType),
      KloudAttribute.make("letterSpacing", .doubleAttributeType),
      KloudAttribute.make("lineSpacing", .doubleAttributeType),
      KloudAttribute.make("verseSpacing", .doubleAttributeType),
      KloudAttribute.make("showsPronunciation", .booleanAttributeType),
      KloudAttribute.make("themeSlot", .stringAttributeType),
      KloudAttribute.make("playbackSpeed", .doubleAttributeType),
      KloudAttribute.make("updatedAt", .dateAttributeType),
    ]
    return entity
  }
}

// MARK: - Mapping

extension PrayerConfigurationRecord {
  /// The row for one prayer.
  ///
  /// A predicate rather than a uniqueness constraint, which CloudKit does not
  /// support — see ``KloudSchema``. Two devices can both insert before they have
  /// synced; the pair converges on the next write, and until then the newer row
  /// wins on read.
  static func matching(_ prayerID: Prayer.ID) -> NSPredicate {
    NSPredicate(format: "prayerID == %@", prayerID)
  }

  /// Every column falls back to what ``PrayerSettings/standard`` carries, so a
  /// row written by an older build — or one carrying a face a later build
  /// introduced — still reads back as a whole, usable configuration.
  var asConfiguration: PrayerConfiguration {
    let standard = PrayerSettings.standard

    let settings = PrayerSettings(
      textSize: textSize.map { $0.intValue } ?? standard.textSize,
      font: font.flatMap(PrayerSettings.Face.init(rawValue:)) ?? standard.font,
      alignment: alignment.flatMap(PrayerSettings.Alignment.init(rawValue:)) ?? standard.alignment,
      // Left at the standard paper on purpose. It is derived from the theme and
      // the appearance, and HomeKit overwrites it before anything draws.
      background: standard.background,
      letterSpacing: letterSpacing.map { $0.doubleValue } ?? standard.letterSpacing,
      lineSpacing: lineSpacing.map { $0.doubleValue } ?? standard.lineSpacing,
      verseSpacing: verseSpacing.map { $0.doubleValue } ?? standard.verseSpacing,
      showsPronunciation: showsPronunciation.map { $0.boolValue } ?? standard.showsPronunciation
    )

    return PrayerConfiguration(
      settings: settings,
      themeSlot: themeSlot.flatMap(PrayerThemeSlot.init(rawValue:))
        ?? PrayerConfiguration.standard.themeSlot,
      // A pace this build does not have — one dropped from the list, or one a
      // later build added — reads back as the ordinary one rather than as
      // nothing, which is the same rule every other column here follows.
      playbackSpeed: playbackSpeed.flatMap { PrayerPlaybackSpeed(rawValue: $0.doubleValue) }
        ?? PrayerConfiguration.standard.playbackSpeed
    )
  }

  /// Writes every column, which is what lets ``asConfiguration`` treat a null as
  /// "this build did not know about the column" rather than as a real value.
  func apply(_ configuration: PrayerConfiguration, for prayerID: Prayer.ID) {
    let settings = configuration.settings

    self.prayerID = prayerID
    textSize = NSNumber(value: settings.textSize)
    font = settings.font.rawValue
    alignment = settings.alignment.rawValue
    letterSpacing = NSNumber(value: settings.letterSpacing)
    lineSpacing = NSNumber(value: settings.lineSpacing)
    verseSpacing = NSNumber(value: settings.verseSpacing)
    showsPronunciation = NSNumber(value: settings.showsPronunciation)
    themeSlot = configuration.themeSlot.rawValue
    playbackSpeed = NSNumber(value: configuration.playbackSpeed.rawValue)
    updatedAt = .now
  }
}
