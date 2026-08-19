import Combine
import Foundation
import KloudKit

/// A plan's identifier.
///
/// A `typealias` rather than a type, because there are no plans yet. It exists so
/// that the signatures which will one day take one are already written, and can
/// be pointed at a real plan id without a change at any call site.
public typealias PrayerPlanID = String

/// Holds every prayer's reading configuration, and is the only thing that reads
/// or writes them.
///
/// ```swift
/// let configuration = PrayerConfigurationStore.shared.configuration(for: prayer.id)
/// PrayerConfigurationStore.shared.save(configuration, for: prayer.id)
/// ```
///
/// One shared instance, so that a theme chosen on the detail screen is the theme
/// the reader opens with — the two screens used to seed themselves independently
/// and could not agree.
///
/// Reads are synchronous and come from an in-memory cache filled by a single
/// fetch. That is what lets a screen seed its `@State` in `init`, where an async
/// API would force a "not loaded yet" branch into every screen that shows a
/// prayer — the same argument `KloudStack.start(schema:mode:)` makes for loading
/// the store synchronously.
@MainActor
public final class PrayerConfigurationStore: ObservableObject {
  public static let shared = PrayerConfigurationStore()

  /// Bumped whenever the cache was dropped because the store changed underneath
  /// it — an import from another device, or a deletion from the storage screen.
  ///
  /// Published so that a screen which wants to follow the store can. The reading
  /// screens deliberately do not: a paper pulled out from under someone
  /// mid-prayer is worse than a page that is one session stale. They pick the new
  /// value up the next time they load.
  @Published public private(set) var revision: Int = 0

  private var cache: [Prayer.ID: PrayerConfiguration] = [:]
  private var hasLoaded = false
  private var changeObserver: NSObjectProtocol?
  private var modeObserver: AnyCancellable?

  private init() {
    observeStore()
  }

  // MARK: - Reading

  /// The configuration a prayer is read with.
  ///
  /// - Parameters:
  ///   - prayerID: ``Prayer/id``.
  ///   - planID: The plan the prayer is being read inside, when it is being read
  ///     inside one.
  ///
  ///     **This is the seam for plans, and nothing more yet.** A plan is a
  ///     collection of prayers that carries one configuration of its own, and
  ///     that configuration overrides the prayer's — a plan set at one size, on
  ///     one paper, is read at that size on that paper throughout, whatever each
  ///     prayer in it is set to on its own. So the plan's configuration is
  ///     returned *instead of* the prayer's rather than merged into it: a merge
  ///     could not express "this size, for everything in me".
  ///
  ///     There are no plans yet, so every id falls through to the prayer's own
  ///     configuration. Filling in ``planConfiguration(for:)`` is what turns this
  ///     on, with no call site to chase.
  public func configuration(
    for prayerID: Prayer.ID,
    in planID: PrayerPlanID? = nil
  ) -> PrayerConfiguration {
    loadIfNeeded()

    if let planID, let planConfiguration = planConfiguration(for: planID) {
      return planConfiguration
    }

    return cache[prayerID] ?? .standard
  }

  /// Reserved for plans. Always `nil` until a plan can carry a configuration.
  private func planConfiguration(for planID: PrayerPlanID) -> PrayerConfiguration? {
    _ = planID
    return nil
  }

  // MARK: - Writing

  /// Keeps a prayer's configuration.
  ///
  /// The cache is written first, so the next read is right even if the store
  /// throws. A failure is swallowed for the same reason `AuthManager` swallows a
  /// failed profile write: losing this costs the reader a page that does not look
  /// the way they left it, which is not worth taking the prayer down for.
  ///
  /// No plan parameter. A plan's configuration is one row for the plan, not one
  /// row per prayer in it, so it gets a call of its own when there is something
  /// to write it to.
  public func save(_ configuration: PrayerConfiguration, for prayerID: Prayer.ID) {
    cache[prayerID] = configuration

    guard isSchemaAvailable else { return }

    let store = KloudStack.shared.store(for: PrayerConfigurationRecord.self)
    try? store.upsert(matching: PrayerConfigurationRecord.matching(prayerID)) { record in
      record.apply(configuration, for: prayerID)
    }
  }

  /// Drops a prayer's row, so it reads back ``PrayerConfiguration/standard``.
  public func reset(_ prayerID: Prayer.ID) {
    cache[prayerID] = nil

    guard isSchemaAvailable else { return }

    let store = KloudStack.shared.store(for: PrayerConfigurationRecord.self)
    try? store.delete(where: PrayerConfigurationRecord.matching(prayerID))
  }

  // MARK: - Loading

  /// Fills the cache from the store, once.
  ///
  /// Every row in one fetch rather than one row per prayer on demand: this is
  /// called from a SwiftUI `init`, which runs more often than a screen is
  /// presented, and the catalog is some thirty prayers — a single query, after
  /// which every read is a dictionary hit.
  ///
  /// Not done in `init()`: ``shared`` can be touched before
  /// `KloudStack.start(schema:mode:)` has run, and previews never run it at all.
  /// The same lazy-cache idiom ``PrayerCatalog`` uses.
  private func loadIfNeeded() {
    guard !hasLoaded, isSchemaAvailable else { return }
    hasLoaded = true

    let store = KloudStack.shared.store(for: PrayerConfigurationRecord.self)
    // Oldest first, so that a later row overwrites an earlier one for the same
    // prayer. This is the deduplicate-on-read that `KloudStore.upsert` asks for:
    // two devices can both insert before they have synced, and the newer write is
    // the answer.
    let records = (try? store.fetch(
      sortedBy: [NSSortDescriptor(key: "updatedAt", ascending: true)]
    )) ?? []

    for record in records {
      guard let prayerID = record.prayerID else { continue }
      cache[prayerID] = record.asConfiguration
    }
  }

  /// Whether the entity is actually in the loaded model.
  ///
  /// `NSFetchRequest(entityName:)` against a model that does not contain the
  /// entity raises an Objective-C exception, which `try?` cannot catch — so this
  /// has to be asked before any fetch rather than recovered from after one.
  ///
  /// It is `false` in exactly two cases. In SwiftUI previews, where
  /// `KloudStack` starts itself with an empty schema, this degrades the store to
  /// an in-memory cache so that previews of the reading screens draw. And when
  /// someone has added the entity without naming it in `KloudSchema`, where the
  /// assertion fires — keeping KloudKit's "fail loudly if you forgot" stance
  /// rather than silently behaving like an empty table.
  private var isSchemaAvailable: Bool {
    let model = KloudStack.shared.viewContext.persistentStoreCoordinator?.managedObjectModel
    let isAvailable = model?.entitiesByName[PrayerConfigurationRecord.entityName] != nil

    assert(
      isAvailable || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1",
      "PrayerConfigurationRecord is not in the KloudSchema the store was started with. Add it in PhayarSarApp."
    )

    return isAvailable
  }

  // MARK: - Staying in step with the store

  private func observeStore() {
    // `objectsDidChange` rather than `NSPersistentStoreRemoteChange`, which only
    // reports writes made by another process. This also catches the storage
    // screen, whose `KloudStorage.deleteStorageItems` deletes straight through
    // `viewContext` — without it, clearing reading settings would appear to do
    // nothing until the next launch.
    //
    // No filter for this store's own writes: invalidating after one is merely a
    // wasted fetch, since the store it re-reads is the one that was just written.
    changeObserver = NotificationCenter.default.addObserver(
      forName: .NSManagedObjectContextObjectsDidChange,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard Self.touchesConfigurations(notification) else { return }
      Task { @MainActor in self?.invalidate() }
    }

    // The container is replaced wholesale on sign-in and sign-out — a different
    // `viewContext`, holding a different store's worth of configurations. Without
    // this a guest's themes would survive into the account they signed in to.
    modeObserver = KloudStack.shared.$mode
      .dropFirst()
      .sink { [weak self] _ in
        Task { @MainActor in self?.invalidate() }
      }
  }

  private func invalidate() {
    hasLoaded = false
    cache.removeAll()
    revision &+= 1
  }

  /// Whether a context change involved one of our rows.
  ///
  /// `nonisolated` and `static` so it can run in the notification callback
  /// without hopping actors — most changes are some other entity's, and those
  /// should cost nothing.
  private nonisolated static func touchesConfigurations(_ notification: Notification) -> Bool {
    let keys = [
      NSInsertedObjectsKey,
      NSUpdatedObjectsKey,
      NSRefreshedObjectsKey,
      NSDeletedObjectsKey,
    ]

    return keys.contains { key in
      guard let objects = notification.userInfo?[key] as? Set<NSManagedObject> else { return false }
      return objects.contains { $0 is PrayerConfigurationRecord }
    }
  }
}
