import CoreData

/// A managed object a feature module contributes to the shared store.
///
/// There is no `.xcdatamodeld` anywhere in KloudKit. Each module describes its
/// own entities in code and hands them to ``KloudSchema``, which assembles one
/// `NSManagedObjectModel` at launch. That is what keeps a feature's schema in
/// the feature's own package: adding a table to PrayersKit is a change to
/// PrayersKit, not an edit to a binary file that every module shares and no
/// merge tool can read.
///
/// ```swift
/// @objc(BookmarkRecord)
/// final class BookmarkRecord: NSManagedObject, KloudEntity {
///   @NSManaged var prayerID: String?
///   @NSManaged var createdAt: Date?
///
///   static func makeEntity() -> NSEntityDescription {
///     let entity = NSEntityDescription()
///     entity.properties = [
///       KloudAttribute.make("prayerID", .stringAttributeType),
///       KloudAttribute.make("createdAt", .dateAttributeType),
///     ]
///     return entity
///   }
/// }
/// ```
///
/// Leave `name` and `managedObjectClassName` alone — ``KloudSchema`` fills both
/// in from the conforming type, so they cannot drift out of step with it.
///
/// The `@objc(...)` attribute is not optional. Core Data resolves the class by
/// its Objective-C name, and without it a Swift class in a package is mangled to
/// something the runtime lookup will not find.
public protocol KloudEntity: NSManagedObject {
  /// The entity's name in the model, and the string `KloudStore` builds fetch
  /// requests with.
  static var entityName: String { get }

  /// Everything but the name: attributes, relationships, indexes.
  static func makeEntity() -> NSEntityDescription

  /// What to call these records on a storage screen — "Plans", "Bookmarks".
  ///
  /// Required, with no default, because the only default available would be the
  /// class name: a user reading "WorshipPlanRecord" in a list of things they can
  /// delete is worse than a build error reminding someone to name it. Return a
  /// localised string — the entity's own module can import LocalisationKit,
  /// which is why this lives on the entity rather than in a table KloudKit would
  /// have to hold.
  static var storageLabel: String { get }

  /// Whether a user may delete these records themselves.
  ///
  /// `false` for anything that is identity or bookkeeping rather than content —
  /// a profile record is a name the user cannot be asked for a second time, and
  /// it has no business appearing in a list of things to clear out. Such an
  /// entity is left out of ``KloudStorageFootprint`` entirely, so "nothing to
  /// clear" can be an honest answer while the store is not literally empty.
  static var isUserClearable: Bool { get }

  /// What to call *one* of these records — a plan's name, a prayer's title.
  ///
  /// Read by the per-item list that lets a user delete a single record rather
  /// than a whole category, so make it the thing they would recognise. Defaults
  /// to ``storageLabel``, which is right for an entity that only ever holds one
  /// row.
  var storageTitle: String { get }
}

extension KloudEntity {
  /// Defaults to the Swift type name, which is what almost every entity wants.
  public static var entityName: String {
    String(describing: Self.self)
  }

  /// Content unless an entity says otherwise. Most entities are the user's own
  /// data, and the exceptions are rare enough to be worth spelling out at the
  /// one place they apply.
  public static var isUserClearable: Bool { true }

  public var storageTitle: String { Self.storageLabel }
}

// MARK: - Attributes

/// Builders for CloudKit-legal attributes.
///
/// CloudKit mirroring rejects a model outright if it contains an attribute that
/// is neither optional nor defaulted — the record may arrive from another device
/// before that field exists there. Rather than document that rule and hope, the
/// builder makes it the only thing you can express: there is no parameter for
/// turning optionality off.
public enum KloudAttribute {
  /// - Parameters:
  ///   - name: The property name. Must match the `@NSManaged` property exactly.
  ///   - type: The Core Data storage type.
  ///   - defaultValue: Optional. Supplying one does not make the attribute
  ///     non-optional — it only decides what a freshly inserted object reads
  ///     back before anything has been assigned.
  public static func make(
    _ name: String,
    _ type: NSAttributeType,
    defaultValue: Any? = nil
  ) -> NSAttributeDescription {
    let attribute = NSAttributeDescription()
    attribute.name = name
    attribute.attributeType = type
    attribute.isOptional = true
    attribute.defaultValue = defaultValue
    return attribute
  }

  /// A `Codable` value stored as JSON in a binary attribute.
  ///
  /// For the shape of thing that has no business being its own table — a small
  /// struct of display preferences, say. CloudKit sees an opaque blob, so it
  /// syncs fine but cannot be queried against; if you need a predicate on one of
  /// its fields, it wants to be a real attribute instead.
  ///
  /// Encode and decode with ``KloudCodableValue``.
  public static func codable(_ name: String) -> NSAttributeDescription {
    make(name, .binaryDataAttributeType)
  }
}

/// JSON coding for attributes declared with ``KloudAttribute/codable(_:)``.
public enum KloudCodableValue {
  public static func encode<Value: Encodable>(_ value: Value) -> Data? {
    try? JSONEncoder().encode(value)
  }

  public static func decode<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
    guard let data else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }
}

// MARK: - Relationships

/// Builders for CloudKit-legal relationships.
///
/// Same idea as ``KloudAttribute``: CloudKit requires every relationship to be
/// optional and to have an inverse, so `inverse` is a required argument and
/// optionality is not offered as a choice. The inverse is resolved by name in
/// ``KloudSchema`` rather than here, because the entity on the other end does
/// not exist yet at the point `makeEntity()` runs.
public enum KloudRelationship {
  /// Keys the resolver in ``KloudSchema`` reads back out of `userInfo`. Stashed
  /// there because `NSRelationshipDescription` has nowhere else to carry a
  /// forward reference to an entity that has not been built yet.
  static let destinationKey = "kloud.destinationEntity"
  static let inverseKey = "kloud.inverseName"

  /// - Parameters:
  ///   - name: The property name on this entity.
  ///   - destinationEntityName: ``KloudEntity/entityName`` of the entity at the
  ///     far end.
  ///   - inverseName: The property name on *that* entity pointing back here.
  ///   - isToMany: `true` for a set-valued relationship.
  public static func make(
    _ name: String,
    to destinationEntityName: String,
    inverse inverseName: String,
    isToMany: Bool = false
  ) -> NSRelationshipDescription {
    let relationship = NSRelationshipDescription()
    relationship.name = name
    relationship.isOptional = true
    relationship.minCount = 0
    relationship.maxCount = isToMany ? 0 : 1
    // Nullify rather than cascade: a cascade that fires on one device has to be
    // replayed as a set of individual deletions on every other, and CloudKit
    // gives no ordering guarantee between them. Delete the children yourself if
    // you mean to.
    relationship.deleteRule = .nullifyDeleteRule
    relationship.userInfo = [
      destinationKey: destinationEntityName,
      inverseKey: inverseName,
    ]
    return relationship
  }
}
