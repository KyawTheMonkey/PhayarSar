import Combine
import Foundation
import KloudKit
import LocalisationKit

struct Beads: Identifiable, Sendable {
  let id: UUID
  let name: String
  let count: Int

  static let defaultCount = 108
  static let countRange = 1...10_000

  static func countLabel(for count: Int) -> String {
    count == 1 ? L10n.beadsCountOne : L10n.beadsCountSummary(.init(stringLiteral: count.formatted()))
  }
}

/// Publishes values rather than managed objects: a sign-in replaces the store,
/// and a screen must not keep references into the context that just closed.
@MainActor
final class BeadsStore: ObservableObject {
  static let shared = BeadsStore()

  @Published private(set) var beads: [Beads] = []
  @Published private(set) var didFailToLoad = false

  private var changeObserver: NSObjectProtocol?
  private var modeObserver: AnyCancellable?

  private init() {
    // Includes imports and deletion through the profile's storage screen.
    changeObserver = NotificationCenter.default.addObserver(
      forName: .NSManagedObjectContextObjectsDidChange,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard Self.touchesBeads(notification) else { return }
      Task { @MainActor in self?.reload() }
    }
    modeObserver = KloudStack.shared.$mode.dropFirst().sink { [weak self] _ in
      Task { @MainActor in self?.reload() }
    }
  }

  func reload() {
    guard isSchemaAvailable else { return }
    do {
      let records = try KloudStack.shared.store(for: BeadsRecord.self).fetch(
        sortedBy: [NSSortDescriptor(key: "createdAt", ascending: false)]
      )
      var seen: Set<UUID> = []
      beads = records.compactMap { record in
        guard let id = record.id, let name = record.name,
              let count = record.count?.intValue,
              Beads.countRange.contains(count), seen.insert(id).inserted
        else { return nil }
        return Beads(id: id, name: name, count: count)
      }
      didFailToLoad = false
    } catch {
      didFailToLoad = true
    }
  }

  func add(id: UUID, name: String, count: Int) throws {
    guard isSchemaAvailable else { throw KloudError.entityNotInSchema(BeadsRecord.entityName) }
    let store = KloudStack.shared.store(for: BeadsRecord.self)
    // KloudStore.insert removes a failed insertion from the context, so Cancel
    // after a save error cannot leak the draft into a later unrelated save.
    try store.insert { record in
      record.id = id
      record.name = name
      record.count = NSNumber(value: count)
      record.createdAt = .now
    }
    reload()
  }

  private var isSchemaAvailable: Bool {
    let model = KloudStack.shared.viewContext.persistentStoreCoordinator?.managedObjectModel
    let isAvailable = model?.entitiesByName[BeadsRecord.entityName] != nil
    assert(
      isAvailable || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1",
      "Add BeadsRecord to the app's KloudSchema."
    )
    return isAvailable
  }

  private nonisolated static func touchesBeads(_ notification: Notification) -> Bool {
    if notification.userInfo?[NSInvalidatedAllObjectsKey] != nil { return true }
    return [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSRefreshedObjectsKey, NSDeletedObjectsKey].contains { key in
      guard let objects = notification.userInfo?[key] as? Set<NSManagedObject> else { return false }
      return objects.contains { $0 is BeadsRecord }
    }
  }
}
