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
  @NSManaged public var createdAt: Date?

  public static var storageLabel: String { L10n.beadsTab }
  public var storageTitle: String { name ?? Self.storageLabel }

  public static func makeEntity() -> NSEntityDescription {
    let entity = NSEntityDescription()
    entity.properties = [
      KloudAttribute.make("id", .UUIDAttributeType),
      KloudAttribute.make("name", .stringAttributeType),
      KloudAttribute.make("count", .integer32AttributeType),
      KloudAttribute.make("createdAt", .dateAttributeType),
    ]
    return entity
  }
}
