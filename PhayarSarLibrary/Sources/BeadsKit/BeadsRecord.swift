import Foundation
import KloudKit
import LocalisationKit

/// Saved bead sets belong to the feature's schema so they follow the same
/// guest-to-account migration and storage controls as the rest of the app.
@objc(BeadsRecord)
public final class BeadsRecord: NSManagedObject, KloudEntity {
  @NSManaged public var id: UUID?
  @NSManaged public var name: String?
  @NSManaged public var count: NSNumber?
  @NSManaged public var rounds: NSNumber?
  @NSManaged public var recitationData: Data?
  /// Finished recitations survive leaving the screen. The strand's physical
  /// position is deliberately not persisted or interpreted as a count.
  @NSManaged public var completedRecitations: NSNumber?
  @NSManaged public var createdAt: Date?

  public static var storageLabel: String { L10n.beadsTab }
  public var storageTitle: String { name ?? Self.storageLabel }

  public static func makeEntity() -> NSEntityDescription {
    let entity = NSEntityDescription()
    entity.properties = [
      KloudAttribute.make("id", .UUIDAttributeType),
      KloudAttribute.make("name", .stringAttributeType),
      KloudAttribute.make("count", .integer32AttributeType),
      KloudAttribute.make("rounds", .integer32AttributeType, defaultValue: 1),
      KloudAttribute.codable("recitationData"),
      KloudAttribute.make("completedRecitations", .integer64AttributeType, defaultValue: 0),
      KloudAttribute.make("createdAt", .dateAttributeType),
    ]
    return entity
  }
}
