import CoreData
import Foundation

// MARK: - Footprint

/// One kind of thing the user has stored, and how much of it there is.
public struct KloudStorageCategory: Identifiable, Equatable, Sendable {
  /// The entity name, which is also what ``KloudStack/storageItems(in:)`` and
  /// friends take to name a category again later. Stable across launches, unlike
  /// an index into a list whose order could change.
  public let id: String

  /// What to call it, from ``KloudEntity/storageLabel``.
  public let label: String

  /// Total size of the records in this category, by the same estimate
  /// ``KloudStorageFootprint/bytes`` uses.
  public let bytes: Int64

  /// How many records. Worth showing beside the size: "12 items · 4 KB" tells a
  /// user which of the two numbers to be surprised by.
  public let count: Int

  public init(id: String, label: String, bytes: Int64, count: Int) {
    self.id = id
    self.label = label
    self.bytes = bytes
    self.count = count
  }
}

/// One record, as a row a user can look at and delete.
public struct KloudStorageItem: Identifiable, Equatable, Sendable {
  /// The object's URI, which is a stable handle that can cross out of Core Data
  /// and come back — unlike `NSManagedObjectID` itself, which is a reference type
  /// and has no business being held by a view.
  public let id: String

  /// What to call it, from ``KloudEntity/storageTitle``.
  public let title: String

  public let bytes: Int64

  public init(id: String, title: String, bytes: Int64) {
    self.id = id
    self.title = title
    self.bytes = bytes
  }
}

/// How much the store holds, broken down by what kind of thing it is.
public struct KloudStorageFootprint: Equatable, Sendable {
  /// What the user has stored, largest first, and **only what they may clear**.
  ///
  /// Entities marked `isUserClearable == false` are absent — see
  /// ``KloudEntity/isUserClearable``. That is what lets an app with a profile
  /// record it will never delete still answer "nothing to clear here" honestly.
  public let categories: [KloudStorageCategory]

  /// Whether these bytes are mirrored to the user's private database. `false`
  /// for a guest, whose data never leaves the device.
  public let isMirrored: Bool

  /// The size of the stored data itself.
  ///
  /// **An estimate, and deliberately not the sqlite file's size on disk.** Two
  /// reasons, both of which would make the file the wrong number to show a user:
  ///
  /// - The file is inflated by things that are not the user's data and never
  ///   reach iCloud — `NSPersistentCloudKitContainer`'s local mirroring metadata,
  ///   persistent history, and SQLite's own page overhead.
  /// - SQLite does not hand freed pages back when rows are deleted. A user who
  ///   tapped "Delete" would watch the number refuse to move, which reads as a
  ///   broken button rather than as a database implementation detail.
  ///
  /// This adds up the records instead, so it responds to a deletion immediately
  /// and tracks what CloudKit is actually holding. It still excludes CloudKit's
  /// own per-record bookkeeping, so treat it as a lower bound rather than a
  /// billing figure.
  public var bytes: Int64 {
    categories.reduce(0) { $0 + $1.bytes }
  }

  /// Nothing stored that the user could clear. The screen's cue to say so and
  /// offer no controls, rather than to draw an empty chart.
  public var isEmpty: Bool { categories.isEmpty }

  public init(categories: [KloudStorageCategory], isMirrored: Bool) {
    self.categories = categories
    self.isMirrored = isMirrored
  }
}

// MARK: - Measuring

public extension KloudStack {
  /// Adds up everything the store is holding, per kind of thing.
  ///
  /// Walks every record in the schema, so the cost is proportional to what the
  /// user has saved. That is fine for text — plans, settings, a profile — and is
  /// the reason downloaded media belongs in a file cache measured separately
  /// rather than as bytes inside this store.
  ///
  /// Categories come back largest first, which is the order a storage screen
  /// wants: the thing worth deleting is at the top.
  func storageFootprint() throws -> KloudStorageFootprint {
    guard let types = schemaEntityTypes else {
      return KloudStorageFootprint(categories: [], isMirrored: mode.isCloud)
    }

    var categories: [KloudStorageCategory] = []

    for type in types where type.isUserClearable {
      let objects = try fetchAll(entityName: type.entityName)
      // An entity with no rows is not a category with nothing in it — it is not
      // a category. A legend listing "Plans · 0 items" invites a user to go
      // looking for something that is not there.
      guard !objects.isEmpty else { continue }

      categories.append(
        KloudStorageCategory(
          id: type.entityName,
          label: type.storageLabel,
          bytes: objects.reduce(0) { $0 + Self.size(of: $1) },
          count: objects.count
        )
      )
    }

    return KloudStorageFootprint(
      categories: categories.sorted { $0.bytes > $1.bytes },
      isMirrored: mode.isCloud
    )
  }

  /// The individual records in one category, largest first.
  ///
  /// - Parameter categoryID: A ``KloudStorageCategory/id``.
  func storageItems(in categoryID: String) throws -> [KloudStorageItem] {
    guard
      let type = schemaEntityTypes?.first(where: { $0.entityName == categoryID }),
      type.isUserClearable
    else {
      return []
    }

    let items = try fetchAll(entityName: type.entityName).map { object in
      KloudStorageItem(
        id: object.objectID.uriRepresentation().absoluteString,
        // Every entity in the schema conforms, so this cast holds; the fallback
        // is there because `fetchAll` is typed to `NSManagedObject` and the
        // compiler cannot know that.
        title: (object as? any KloudEntity)?.storageTitle ?? type.storageLabel,
        bytes: Self.size(of: object)
      )
    }

    return items.sorted { $0.bytes > $1.bytes }
  }

  // MARK: - Erasing

  /// Deletes the named records, and with them the copies in the user's iCloud.
  ///
  /// The single deletion primitive: clearing one plan and clearing every plan
  /// are the same call with a different list, so there is one path to get right
  /// rather than two that could diverge.
  ///
  /// The deletions go through the context one object at a time rather than as an
  /// `NSBatchDeleteRequest`. A batch delete runs in the store underneath Core
  /// Data and never surfaces as managed-object changes, so the CloudKit mirror
  /// does not learn about it — the rows would vanish here and stay in the user's
  /// account, which is the exact opposite of what someone tapping "delete" asked
  /// for. One-at-a-time is affordable because this store holds text.
  ///
  /// Returning quickly is not the same as being finished: the local rows are gone
  /// when this returns, and the mirror exports the deletions afterwards, which
  /// needs a network trip. ``KloudStack/syncState`` reports that half.
  ///
  /// Anything belonging to an entity the user may not clear is skipped rather
  /// than deleted, so the guarantee in ``KloudEntity/isUserClearable`` holds even
  /// if a caller passes an id it should not have.
  ///
  /// - Parameter itemIDs: ``KloudStorageItem/id`` values.
  func deleteStorageItems(_ itemIDs: [String]) throws {
    guard
      !itemIDs.isEmpty,
      let coordinator = viewContext.persistentStoreCoordinator
    else {
      return
    }

    // Built with explicit closures rather than key paths: a key path applied to
    // an existential metatype (`any KloudEntity.Type`) crashes SILGen on the
    // toolchain this builds with.
    var clearable: Set<String> = []
    for type in schemaEntityTypes ?? [] where type.isUserClearable {
      clearable.insert(type.entityName)
    }

    for itemID in itemIDs {
      guard
        let url = URL(string: itemID),
        let objectID = coordinator.managedObjectID(forURIRepresentation: url),
        let name = objectID.entity.name,
        clearable.contains(name),
        // `existingObject` rather than `object(with:)`: the latter returns a
        // fault that only throws when it is next read, which would be after the
        // delete has already been queued.
        let object = try? viewContext.existingObject(with: objectID)
      else {
        continue
      }

      viewContext.delete(object)
    }

    guard viewContext.hasChanges else { return }
    try viewContext.save()
  }

  // MARK: - Fetching

  private func fetchAll(entityName: String) throws -> [NSManagedObject] {
    let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
    // Fully realised objects: the attributes are about to be read, and letting
    // them fault in one row at a time would be a query per record.
    request.returnsObjectsAsFaults = false
    return try viewContext.fetch(request)
  }

  // MARK: - Attribute sizes

  private static func size(of object: NSManagedObject) -> Int64 {
    object.entity.attributesByName.reduce(into: Int64(0)) { total, entry in
      let (name, attribute) = entry
      total += size(of: object.value(forKey: name), as: attribute.attributeType)
    }
  }

  /// The bytes one attribute value occupies.
  ///
  /// Fixed-width types are counted at their storage width rather than measured,
  /// which is both cheaper and closer to the truth than encoding them would be.
  /// Anything unrecognised counts as nothing: an unknown type is far more likely
  /// to be an empty relationship placeholder than a large value, and guessing
  /// high would overstate a figure the user reads as fact.
  private static func size(of value: Any?, as type: NSAttributeType) -> Int64 {
    guard let value else { return 0 }

    switch type {
    case .stringAttributeType:
      return Int64((value as? String)?.utf8.count ?? 0)
    case .binaryDataAttributeType:
      return Int64((value as? Data)?.count ?? 0)
    case .URIAttributeType:
      return Int64((value as? URL)?.absoluteString.utf8.count ?? 0)
    case .UUIDAttributeType:
      return 16
    case .decimalAttributeType:
      return 16
    case .dateAttributeType, .doubleAttributeType, .integer64AttributeType:
      return 8
    case .integer32AttributeType, .floatAttributeType:
      return 4
    case .integer16AttributeType:
      return 2
    case .booleanAttributeType:
      return 1
    default:
      return 0
    }
  }
}
