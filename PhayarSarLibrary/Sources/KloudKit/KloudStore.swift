import CoreData
import Foundation

/// Typed reads and writes for one entity.
///
/// The point of this type is that no feature module ever holds an
/// `NSManagedObjectContext`. Every call here saves before it returns, so there
/// is no window in which a module is holding unsaved changes that another
/// module's save would flush at an unpredictable moment.
///
/// ```swift
/// let store = KloudStack.shared.store(for: BookmarkRecord.self)
/// try store.upsert(matching: NSPredicate(format: "prayerID == %@", id)) {
///   $0.prayerID = id
///   $0.createdAt = .now
/// }
/// let all = try store.fetch(sortedBy: [NSSortDescriptor(key: "createdAt", ascending: false)])
/// ```
///
/// Not `Sendable`, and deliberately so — it wraps a context, which is bound to
/// the queue it was made on. Get one from `KloudStack.store(for:)` for the main
/// queue, or `store(for:in:)` with a background context for bulk work.
public struct KloudStore<Entity: KloudEntity> {
  private let context: NSManagedObjectContext

  public init(context: NSManagedObjectContext) {
    self.context = context
  }

  // MARK: - Reading

  /// - Parameters:
  ///   - predicate: `nil` fetches everything.
  ///   - sortedBy: Unsorted fetches come back in no defined order — sqlite's,
  ///     which is not insertion order and is not stable across syncs.
  ///   - limit: `nil` for no limit.
  public func fetch(
    where predicate: NSPredicate? = nil,
    sortedBy sortDescriptors: [NSSortDescriptor] = [],
    limit: Int? = nil
  ) throws -> [Entity] {
    let request = NSFetchRequest<Entity>(entityName: Entity.entityName)
    request.predicate = predicate
    request.sortDescriptors = sortDescriptors
    if let limit { request.fetchLimit = limit }
    return try context.fetch(request)
  }

  /// The first match, or `nil`.
  ///
  /// Fetches with a limit of 1, so it stays cheap on a large table.
  public func first(
    where predicate: NSPredicate? = nil,
    sortedBy sortDescriptors: [NSSortDescriptor] = []
  ) throws -> Entity? {
    try fetch(where: predicate, sortedBy: sortDescriptors, limit: 1).first
  }

  public func count(where predicate: NSPredicate? = nil) throws -> Int {
    let request = NSFetchRequest<Entity>(entityName: Entity.entityName)
    request.predicate = predicate
    return try context.count(for: request)
  }

  // MARK: - Writing

  /// Inserts a new object and saves it.
  @discardableResult
  public func insert(_ configure: (Entity) -> Void) throws -> Entity {
    let object = try make()
    configure(object)
    try save()
    return object
  }

  /// Updates the first match, or inserts one if there is none.
  ///
  /// The read-then-write that CloudKit's lack of uniqueness constraints forces
  /// on every "one row per key" case — see ``KloudSchema``. Two devices racing
  /// can still both insert; deduplicate on read when that matters.
  @discardableResult
  public func upsert(
    matching predicate: NSPredicate,
    _ configure: (Entity) -> Void
  ) throws -> Entity {
    let object = try first(where: predicate) ?? make()
    configure(object)
    try save()
    return object
  }

  /// Deletes every match. Passing `nil` empties the table.
  public func delete(where predicate: NSPredicate? = nil) throws {
    // Object-by-object rather than `NSBatchDeleteRequest`: a batch delete goes
    // straight to the store file, so the deletions are invisible to CloudKit
    // and would come straight back on the next sync.
    for object in try fetch(where: predicate) {
      context.delete(object)
    }
    try save()
  }

  /// Commits pending changes. Only needed if you have mutated an object handed
  /// back by ``fetch(where:sortedBy:limit:)`` — the methods above all save.
  public func save() throws {
    guard context.hasChanges else { return }
    try context.save()
  }

  private func make() throws -> Entity {
    guard
      let description = NSEntityDescription.entity(forEntityName: Entity.entityName, in: context),
      let object = NSManagedObject(entity: description, insertInto: context) as? Entity
    else {
      throw KloudError.entityNotInSchema(Entity.entityName)
    }

    return object
  }
}

// MARK: - Errors

public enum KloudError: LocalizedError, Equatable {
  /// The entity was queried but never handed to ``KloudSchema``.
  case entityNotInSchema(String)

  public var errorDescription: String? {
    switch self {
    case let .entityNotInSchema(name):
      return "'\(name)' is not in the KloudSchema the store was started with."
    }
  }
}
