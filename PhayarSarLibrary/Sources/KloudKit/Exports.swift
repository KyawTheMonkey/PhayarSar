// Consumers describe their entities with `NSAttributeDescription` and query
// with `NSPredicate`/`NSSortDescriptor`, so they would all have to import
// CoreData alongside KloudKit anyway. Re-exporting keeps `import KloudKit` the
// only line a feature module needs — the same trick `EnvironmentKit/Exports.swift`
// plays with LocalisationKit and UtilKit.
@_exported import CoreData
