import CoreData
import Foundation

/// The set of entities the app persists, gathered from every module that has
/// one.
///
/// Built once, in the app target, because that is the only place that links
/// every feature module and can therefore name them all:
///
/// ```swift
/// KloudStack.shared.start(
///   schema: KloudSchema([AuthProfileRecord.self, BookmarkRecord.self]),
///   mode: .local
/// )
/// ```
///
/// An entity left out of this list is not in the model, so the first fetch
/// against it traps. That is deliberate — a silently absent table would look
/// like an empty one, and "the user's bookmarks vanished" is a much worse
/// failure than a crash on the first launch after someone forgot a line here.
public struct KloudSchema {
  public let entityTypes: [any KloudEntity.Type]

  public init(_ entityTypes: [any KloudEntity.Type]) {
    self.entityTypes = entityTypes
  }

  /// The names of every entity in the schema, in declaration order.
  public var entityNames: [String] {
    entityTypes.map { $0.entityName }
  }

  /// Assembles the model: builds each entity, names it, binds it to its class,
  /// then resolves relationships across the whole set.
  ///
  /// Relationship resolution has to happen here rather than in `makeEntity()`
  /// because an entity cannot reference one that has not been built yet. By the
  /// time this runs, every entity exists and both ends can be joined up.
  func makeModel() -> NSManagedObjectModel {
    let entities = entityTypes.map { type -> NSEntityDescription in
      let entity = type.makeEntity()
      entity.name = type.entityName
      entity.managedObjectClassName = NSStringFromClass(type as AnyClass)
      return entity
    }

    let byName = Dictionary(
      entities.compactMap { entity in entity.name.map { ($0, entity) } },
      uniquingKeysWith: { first, _ in first }
    )

    resolveRelationships(in: entities, byName: byName)
    validate(entities)

    let model = NSManagedObjectModel()
    model.entities = entities
    return model
  }

  /// Walks every relationship, points it at its destination entity, and joins it
  /// to its inverse.
  private func resolveRelationships(
    in entities: [NSEntityDescription],
    byName: [String: NSEntityDescription]
  ) {
    for entity in entities {
      for relationship in entity.properties.compactMap({ $0 as? NSRelationshipDescription }) {
        guard
          let destinationName = relationship.userInfo?[KloudRelationship.destinationKey] as? String,
          let destination = byName[destinationName]
        else {
          assertionFailure(
            """
            KloudKit: relationship '\(entity.name ?? "?").\(relationship.name)' names a \
            destination entity that is not in the schema. Add it to the KloudSchema(...) list.
            """
          )
          continue
        }

        relationship.destinationEntity = destination
      }
    }

    // A second pass, because `inverseRelationship` can only be set once both
    // sides have a destination — which the loop above has just finished giving
    // them.
    for entity in entities {
      for relationship in entity.properties.compactMap({ $0 as? NSRelationshipDescription }) {
        guard
          let inverseName = relationship.userInfo?[KloudRelationship.inverseKey] as? String,
          let destination = relationship.destinationEntity,
          let inverse = destination.relationshipsByName[inverseName]
        else {
          assertionFailure(
            """
            KloudKit: relationship '\(entity.name ?? "?").\(relationship.name)' names an \
            inverse that its destination entity does not declare.
            """
          )
          continue
        }

        relationship.inverseRelationship = inverse
      }
    }
  }

  /// Checks the rules CloudKit mirroring enforces, in debug builds only.
  ///
  /// `NSPersistentCloudKitContainer` validates the model itself and refuses to
  /// load the store if it fails — but it does so at launch, with a message that
  /// names the constraint and not the entity that broke it. These assertions
  /// fire first, and say which property is at fault.
  private func validate(_ entities: [NSEntityDescription]) {
    #if DEBUG
    for entity in entities {
      let name = entity.name ?? "?"

      assert(
        entity.uniquenessConstraints.isEmpty,
        "KloudKit: entity '\(name)' declares a uniqueness constraint, which CloudKit does not support. Deduplicate on read instead."
      )

      for attribute in entity.properties.compactMap({ $0 as? NSAttributeDescription }) {
        assert(
          attribute.isOptional || attribute.defaultValue != nil,
          "KloudKit: attribute '\(name).\(attribute.name)' is neither optional nor defaulted. Build it with KloudAttribute.make(_:_:)."
        )
      }

      for relationship in entity.properties.compactMap({ $0 as? NSRelationshipDescription }) {
        assert(
          relationship.isOptional,
          "KloudKit: relationship '\(name).\(relationship.name)' is not optional, which CloudKit requires."
        )
        assert(
          relationship.inverseRelationship != nil,
          "KloudKit: relationship '\(name).\(relationship.name)' has no inverse, which CloudKit requires."
        )
      }
    }
    #endif
  }
}
