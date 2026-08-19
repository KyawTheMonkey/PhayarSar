import CoreData
import Foundation

/// Where the store's data lives.
public enum KloudSyncMode: Equatable, Sendable {
  /// On this device only. What a guest gets, and what everyone falls back to
  /// when there is no iCloud account signed in.
  case local

  /// Mirrored to the user's CloudKit private database.
  case cloud(containerIdentifier: String)

  var isCloud: Bool {
    if case .cloud = self { return true }
    return false
  }

  /// The container being mirrored to, or `nil` in ``local`` mode.
  ///
  /// Public because ``KloudAccount/status(containerIdentifier:)`` needs it, and
  /// the store is the one place that knows which container is actually loaded —
  /// a UI asking "is iCloud working?" should not have to be told the identifier
  /// a second time.
  public var containerIdentifier: String? {
    if case let .cloud(identifier) = self { return identifier }
    return nil
  }
}

/// How a manual ``KloudStack/syncNow()`` ended.
///
/// Distinct from ``KloudSyncState``, which describes what the mirror is doing at
/// any moment. This is the answer to one question the user actually asked, and
/// it is worth being able to say "your iCloud is full" rather than redrawing a
/// status line and hoping they notice.
public enum KloudSyncOutcome: Equatable, Sendable {
  /// The mirror ran and settled with nothing outstanding.
  case completed

  /// The store is local, so there is nothing to sync. Not a failure — a guest
  /// gets this every time, and the UI should say so rather than apologise.
  case notSyncing

  /// The device cannot reach the private database. Carries the reason, because
  /// "no iCloud account" and "your account needs attention in Settings" send the
  /// user to two different places.
  case accountUnavailable(KloudAccountStatus)

  /// The account is out of space. Retrying will not clear it — see
  /// ``KloudSyncState/quotaExceeded``.
  case quotaExceeded

  /// Something else went wrong, usually transient.
  case failed(String)

  /// Still going when we stopped watching. Mirroring carries on in the
  /// background; only the waiting gave up, so this is not an error to report as
  /// one.
  case stillRunning
}

/// The app's one persistent store, and the only thing in the codebase that
/// knows Core Data is what backs it.
///
/// ```swift
/// // Once, at launch:
/// KloudStack.shared.start(schema: KloudSchema([...]), mode: .local)
///
/// // Anywhere after that:
/// let store = KloudStack.shared.store(for: BookmarkRecord.self)
/// try store.insert { $0.prayerID = prayer.id }
/// ```
///
/// The two modes are two separate store files, not one file with mirroring
/// switched on and off. Keeping them apart is what makes ``signIn(to:)`` able to
/// merge a guest's work into an account that may already hold data from another
/// device — a single file could only be uploaded wholesale, overwriting whatever
/// was there. It also means signing out leaves the account's data untouched in
/// iCloud rather than stranded in a file the next user would inherit.
@MainActor
public final class KloudStack: ObservableObject {
  public static let shared = KloudStack()

  /// Where the loaded store is writing to. `.local` until ``start(schema:mode:)``
  /// says otherwise.
  @Published public private(set) var mode: KloudSyncMode = .local

  /// What CloudKit mirroring is currently doing. Always ``KloudSyncState/idle``
  /// in `.local` mode — there is nothing to sync.
  @Published public private(set) var syncState: KloudSyncState = .idle

  /// When the last manual sync finished, or `nil` if one never has.
  ///
  /// Only ``syncNow()`` writes it. Background mirroring deliberately does not:
  /// the mirror runs constantly and a timestamp that changed on its own would be
  /// reporting something the user did not ask for and cannot rely on.
  ///
  /// Persisted, so "Last synced" still means something after a relaunch.
  // `KloudStack.` rather than `Self.` — a stored property initializer cannot
  // reference the covariant `Self`.
  @Published public private(set) var lastSyncedAt: Date? = KloudStack.storedLastSyncedAt

  /// Whether a manual sync is in flight. Guards against a second tap stacking a
  /// second store reload on top of the first.
  @Published public private(set) var isSyncing = false

  private var container: NSPersistentCloudKitContainer?
  private var schema: KloudSchema?
  private var model: NSManagedObjectModel?
  private var monitor: KloudSyncMonitor?

  private init() {}

  // MARK: - Lifecycle

  /// Builds the model and loads the store. Call once, from the app's `init`.
  ///
  /// Synchronous on purpose: every screen that reads persisted state would
  /// otherwise need a "not ready yet" branch, and the load is a local sqlite
  /// open — CloudKit's first sync happens afterwards, in the background, and is
  /// reported through ``syncState`` rather than waited on here.
  ///
  /// Calling it a second time is ignored. Use ``signIn(to:)`` / ``signOut()`` to
  /// change modes after launch.
  public func start(schema: KloudSchema, mode: KloudSyncMode) {
    guard container == nil else { return }

    self.schema = schema
    self.model = schema.makeModel()
    load(mode: mode)
  }

  /// Moves to the account's store and brings the guest's data with it.
  ///
  /// The order matters and is the whole reason this is one method rather than
  /// two: the cloud store has to be open before anything can be written into it,
  /// and the local file has to survive until that write has been committed. A
  /// failure anywhere leaves the local store in place, so a retry loses nothing.
  ///
  /// - Parameter containerIdentifier: The iCloud container, e.g.
  ///   `iCloud.com.kyaw.PhayarSar`.
  public func signIn(to containerIdentifier: String) throws {
    guard !mode.isCloud else { return }

    let localURL = Self.storeURL(for: .local)
    load(mode: .cloud(containerIdentifier: containerIdentifier))

    if FileManager.default.fileExists(atPath: localURL.path) {
      try migrate(from: localURL)
      try destroyStore(at: localURL)
    }
  }

  /// Drops back to the local store, leaving the account's data in iCloud.
  ///
  /// Nothing is copied down. The signed-in store file stays on disk, so signing
  /// back in on this device picks it up again without a full re-sync.
  public func signOut() {
    guard mode.isCloud else { return }
    load(mode: .local)
    syncState = .idle

    // The next account's "last synced" is not this one's.
    lastSyncedAt = nil
    Self.storedLastSyncedAt = nil
  }

  // MARK: - Manual sync

  /// Runs a sync now, and waits for it to settle.
  ///
  /// **`NSPersistentCloudKitContainer` has no "sync now" API.** Mirroring is
  /// scheduled by the system, and nothing in the framework will make an import
  /// or an export happen on demand. What can be done — and what this does — is:
  ///
  /// 1. Check the iCloud account, which catches the single most common reason
  ///    nothing is syncing before anything else is attempted.
  /// 2. Flush pending edits out of ``viewContext``, so the export has all of
  ///    them rather than whatever happened to be saved.
  /// 3. Reload the store, which tears down the mirroring engine and builds a new
  ///    one. That forces a fresh setup → import → export cycle, and is the only
  ///    supported way to get the *import* half on demand.
  /// 4. Watch ``syncState`` until it settles, so the caller can report an
  ///    outcome rather than leaving a spinner up forever.
  ///
  /// Step 3 is the same operation ``signIn(to:)`` and ``signOut()`` already
  /// perform, so nothing here is a path the app does not already take. It is
  /// still the heaviest thing in this type: it replaces the container, which
  /// invalidates every managed object handed out before it. Nothing in the app
  /// holds one across a call — reads go through a store each time — and
  /// `PrayerConfigurationStore` already drops its cache when ``mode`` is
  /// republished, which a reload does.
  ///
  /// Safe to call when signed out; it answers ``KloudSyncOutcome/notSyncing``
  /// without touching anything.
  @discardableResult
  public func syncNow() async -> KloudSyncOutcome {
    guard case let .cloud(containerIdentifier) = mode else { return .notSyncing }
    guard !isSyncing else { return .stillRunning }

    isSyncing = true
    defer { isSyncing = false }

    let status = await KloudAccount.status(containerIdentifier: containerIdentifier)
    guard status == .available else {
      syncState = .unavailable
      return .accountUnavailable(status)
    }

    // Anything sitting unsaved in the view context is not the mirror's yet.
    if let container, container.viewContext.hasChanges {
      try? container.viewContext.save()
    }

    // Set before the reload rather than waiting for the first event, so a status
    // row reads "Syncing…" from the moment the user taps rather than a beat
    // later.
    syncState = .syncing
    load(mode: mode)

    let outcome = await settled()

    if outcome == .completed {
      let now = Date.now
      lastSyncedAt = now
      Self.storedLastSyncedAt = now
    }

    return outcome
  }

  /// Waits for the mirror to stop moving.
  ///
  /// Polled rather than driven off the event stream, because what is being
  /// waited for is not an event: the container runs three activity types
  /// independently and "finished" is the *absence* of anything outstanding — a
  /// quiet period, which `KloudSyncMonitor` already collapses into
  /// ``KloudSyncState/idle``. Watching that settle is a read of one value, and a
  /// poll expresses it without a second layer of bookkeeping to keep in step.
  ///
  /// Only ``syncNow()`` calls this, and only after setting ``syncState`` to
  /// ``KloudSyncState/syncing`` — so an `idle` seen here is always the mirror
  /// having finished, never a mirror that has not started yet.
  private func settled() async -> KloudSyncOutcome {
    let deadline = Date.now.addingTimeInterval(Self.syncTimeout)

    while Date.now < deadline {
      switch syncState {
      case .quotaExceeded:
        return .quotaExceeded

      case let .failed(message):
        return .failed(message)

      case .unavailable:
        // The account was available when it was checked a moment ago, so this is
        // the container having become unreachable since — which is what
        // `unknown` means: worth retrying, not worth explaining.
        return .accountUnavailable(.unknown)

      case .idle:
        return .completed

      case .syncing:
        break
      }

      try? await Task.sleep(nanoseconds: Self.pollInterval)
    }

    return .stillRunning
  }

  /// Long enough for a first sync on a slow connection, short enough that a
  /// stuck mirror does not hold a spinner up indefinitely. Passing it is
  /// reported as ``KloudSyncOutcome/stillRunning``, not as a failure.
  private static let syncTimeout: TimeInterval = 30

  private static let pollInterval: UInt64 = 300_000_000

  private static let lastSyncedAtKey = "KloudKit.lastSyncedAt"

  private static var storedLastSyncedAt: Date? {
    get { UserDefaults.standard.object(forKey: lastSyncedAtKey) as? Date }
    set { UserDefaults.standard.set(newValue, forKey: lastSyncedAtKey) }
  }

  // MARK: - Contexts

  /// The context for anything that feeds a view.
  public var viewContext: NSManagedObjectContext {
    resolvedContainer.viewContext
  }

  /// A private-queue context for work that should not block a frame. Save it
  /// yourself; changes merge into ``viewContext`` automatically.
  public func newBackgroundContext() -> NSManagedObjectContext {
    let context = resolvedContainer.newBackgroundContext()
    context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    return context
  }

  /// A typed store for one entity, bound to ``viewContext``.
  public func store<Entity: KloudEntity>(for type: Entity.Type) -> KloudStore<Entity> {
    KloudStore(context: viewContext)
  }

  /// Every entity in the loaded model, or `nil` before ``start(schema:mode:)``.
  ///
  /// The types rather than their names, because `KloudStorage` needs what each
  /// one says about itself — its label, and whether a user may clear it.
  /// Internal rather than private so it can read them without being handed the
  /// schema a second time.
  var schemaEntityTypes: [any KloudEntity.Type]? {
    schema?.entityTypes
  }

  /// A typed store bound to a context you own — pair it with
  /// ``newBackgroundContext()`` for bulk work.
  public nonisolated func store<Entity: KloudEntity>(
    for type: Entity.Type,
    in context: NSManagedObjectContext
  ) -> KloudStore<Entity> {
    KloudStore(context: context)
  }

  // MARK: - Loading

  private func load(mode: KloudSyncMode) {
    guard let model else {
      preconditionFailure("KloudKit: load(mode:) before a model was built. Call start(schema:mode:) first.")
    }

    // A fresh container rather than a reconfigured one: the store URL and the
    // CloudKit options are both read at load time, and there is no supported way
    // to change either on a container that has already loaded.
    let container = NSPersistentCloudKitContainer(name: Self.containerName, managedObjectModel: model)
    container.persistentStoreDescriptions = [Self.description(for: mode)]

    var loadError: Error?
    container.loadPersistentStores { _, error in
      loadError = error
    }

    if let loadError {
      // Not a `fatalError`: a corrupt or unreadable store should not brick the
      // app for someone who only wanted to read a prayer. The store is dropped
      // and rebuilt empty, and CloudKit re-populates it on the next sync if the
      // user is signed in.
      assertionFailure("KloudKit: failed to load the \(mode.isCloud ? "cloud" : "local") store — \(loadError)")
      try? destroyStore(at: Self.storeURL(for: mode))
      container.loadPersistentStores { _, _ in }
    }

    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

    self.container = container
    self.mode = mode
    self.monitor = mode.isCloud
      ? KloudSyncMonitor(container: container) { [weak self] state in
          self?.syncState = state
        }
      : nil
  }

  private var resolvedContainer: NSPersistentCloudKitContainer {
    guard let container else {
      // SwiftUI previews render a view without ever running the app's `init`, so
      // any screen that touches the store would trap. An empty in-memory store
      // lets those previews draw; anywhere else, a missing `start` is a wiring
      // bug worth failing loudly for.
      if Self.isRunningForPreviews {
        start(schema: KloudSchema([]), mode: .local)
        return self.container!
      }

      preconditionFailure("KloudKit: the store was used before start(schema:mode:) was called.")
    }

    return container
  }

  // MARK: - Store description

  private static let containerName = "Kloud"

  private static func description(for mode: KloudSyncMode) -> NSPersistentStoreDescription {
    let description = NSPersistentStoreDescription(url: storeURL(for: mode))

    // Both are prerequisites for CloudKit mirroring, and both are set even in
    // `.local` mode so that the two store files stay format-compatible — the
    // guest store is copied into the cloud one on sign-in, and a store without
    // history tracking cannot be read by a container that has it on.
    description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

    switch mode {
    case .local:
      description.cloudKitContainerOptions = nil
    case let .cloud(containerIdentifier):
      description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
        containerIdentifier: containerIdentifier
      )
    }

    return description
  }

  private static func storeURL(for mode: KloudSyncMode) -> URL {
    let fileName = mode.isCloud ? "Kloud-cloud.sqlite" : "Kloud-local.sqlite"
    return directory.appendingPathComponent(fileName)
  }

  /// Application Support rather than Documents: this is the app's own data, not
  /// the user's files, and it should not show up in a Files browser.
  private static var directory: URL {
    let fileManager = FileManager.default
    let url = (try? fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )) ?? fileManager.temporaryDirectory

    return url
  }

  private static var isRunningForPreviews: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  }

  // MARK: - Migration

  /// Opens the guest store on its own and copies everything in it into the
  /// currently loaded one.
  ///
  /// A plain `NSPersistentContainer`, not a CloudKit one: this store is being
  /// read for the last time and must not start mirroring on its way out.
  private func migrate(from localURL: URL) throws {
    guard let model, let schema else { return }

    let source = NSPersistentContainer(name: Self.containerName, managedObjectModel: model)
    let description = NSPersistentStoreDescription(url: localURL)
    description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    source.persistentStoreDescriptions = [description]

    var loadError: Error?
    source.loadPersistentStores { _, error in loadError = error }
    if let loadError { throw loadError }

    try KloudMigrator.copy(
      entityNames: schema.entityNames,
      from: source.viewContext,
      to: viewContext
    )
  }

  private func destroyStore(at url: URL) throws {
    guard let model else { return }

    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    try coordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType)

    // `destroyPersistentStore` truncates the file rather than removing it, and
    // leaves the -wal and -shm siblings behind. Sweeping them up is what makes
    // "no local store exists" a check `signIn(to:)` can trust.
    for suffix in ["", "-wal", "-shm"] {
      let sibling = URL(fileURLWithPath: url.path + suffix)
      try? FileManager.default.removeItem(at: sibling)
    }
  }
}
