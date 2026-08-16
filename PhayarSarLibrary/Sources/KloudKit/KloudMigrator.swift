import CoreData
import Foundation

/// Copies an object graph from one store into another.
///
/// Used once in the app's life: when a guest signs in and their local store has
/// to be folded into the account's. A file-level replacement would be a single
/// line, but it would overwrite whatever the account already holds from another
/// device — this walks the objects instead, so the two sets merge.
enum KloudMigrator {
  /// - Parameters:
  ///   - entityNames: Every entity in the schema. Taken as an argument rather
  ///     than read off the model so the caller decides what moves.
  ///   - source: A context on the store being emptied.
  ///   - destination: A context on the store being filled. Saved on success.
  static func copy(
    entityNames: [String],
    from source: NSManagedObjectContext,
    to destination: NSManagedObjectContext
  ) throws {
    // Keyed by the source object's ID, because that is the only identity a
    // freshly copied object shares with its original — the destination assigns
    // its own IDs on insert.
    var copies: [NSManagedObjectID: NSManagedObject] = [:]
    var originals: [NSManagedObject] = []

    // Pass one: attributes only. Relationships are skipped because the object at
    // the far end may not have been copied yet.
    for name in entityNames {
      let request = NSFetchRequest<NSManagedObject>(entityName: name)
      let objects = try source.fetch(request)

      for object in objects {
        guard
          let description = NSEntityDescription.entity(forEntityName: name, in: destination)
        else {
          continue
        }

        let copy = NSManagedObject(entity: description, insertInto: destination)
        for attribute in description.attributesByName.keys {
          copy.setValue(object.value(forKey: attribute), forKey: attribute)
        }

        copies[object.objectID] = copy
        originals.append(object)
      }
    }

    // Pass two: relationships, now that every object has a counterpart to point
    // at. An object whose destination was not copied is simply left unset —
    // relationships are optional throughout (see `KloudRelationship`), so a
    // partial graph is still a legal one.
    for object in originals {
      guard let copy = copies[object.objectID] else { continue }

      for (name, relationship) in object.entity.relationshipsByName {
        if relationship.isToMany {
          guard let related = object.value(forKey: name) as? Set<NSManagedObject> else { continue }
          let mapped = related.compactMap { copies[$0.objectID] }
          copy.setValue(Set(mapped), forKey: name)
        } else {
          guard
            let related = object.value(forKey: name) as? NSManagedObject,
            let mapped = copies[related.objectID]
          else {
            continue
          }
          copy.setValue(mapped, forKey: name)
        }
      }
    }

    guard destination.hasChanges else { return }
    try destination.save()
  }
}
