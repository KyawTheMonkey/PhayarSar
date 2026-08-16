import CoreData
import Foundation

/// What CloudKit mirroring is doing, in the terms a UI would want to say it in.
///
/// The message on ``failed(_:)`` is a `String` rather than the `Error` so the
/// state stays `Equatable` and `Sendable` — a view that redraws on every change
/// needs to be able to tell one failure from the same failure repeated.
public enum KloudSyncState: Equatable, Sendable {
  /// Nothing in flight. Also the resting state of a `.local` store, which has
  /// nothing to sync in the first place.
  case idle

  /// A setup, import or export is running.
  case syncing

  /// The last operation failed. Usually transient — no network, or iCloud
  /// throttling — so this is worth surfacing quietly rather than as an alert.
  case failed(String)

  /// Mirroring cannot run at all: no iCloud account on the device, or the
  /// container is unreachable. See ``KloudAccount``.
  case unavailable
}

/// Translates `NSPersistentCloudKitContainer`'s event stream into
/// ``KloudSyncState``.
///
/// The container posts one event when an operation starts and another when it
/// ends, for each of three activity types running independently. Rather than
/// track all three, this counts how many are in flight: anything outstanding
/// reads as ``KloudSyncState/syncing``, and the count returning to zero settles
/// back to ``KloudSyncState/idle`` or reports whatever failed on the way.
@MainActor
final class KloudSyncMonitor {
  /// `nonisolated(unsafe)` so `deinit`, which cannot be main-actor isolated, can
  /// read it back to unregister. Safe because the monitor is only ever created
  /// and released on the main actor by `KloudStack`, so the property is never
  /// touched from two places at once.
  private nonisolated(unsafe) var observer: NSObjectProtocol?
  private var inFlight = 0
  private let onChange: (KloudSyncState) -> Void

  init(
    container: NSPersistentCloudKitContainer,
    onChange: @escaping (KloudSyncState) -> Void
  ) {
    self.onChange = onChange

    observer = NotificationCenter.default.addObserver(
      forName: NSPersistentCloudKitContainer.eventChangedNotification,
      object: container,
      queue: .main
    ) { [weak self] notification in
      // The event is unpacked here, in the notification's own context, so that
      // only `Bool` and `String?` cross into the actor below — `Notification`
      // itself is not `Sendable` and cannot make the trip.
      let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
      guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event else {
        return
      }

      let hasEnded = event.endDate != nil
      let failure = event.error?.localizedDescription

      // `assumeIsolated` rather than a `Task`: `queue: .main` means this block is
      // already on the main queue, and hopping would let two events land out of
      // order and leave `inFlight` wrong.
      MainActor.assumeIsolated {
        self?.handle(hasEnded: hasEnded, failure: failure)
      }
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  private func handle(hasEnded: Bool, failure: String?) {
    guard hasEnded else {
      inFlight += 1
      onChange(.syncing)
      return
    }

    inFlight = max(0, inFlight - 1)

    if let failure {
      onChange(.failed(failure))
    } else if inFlight == 0 {
      onChange(.idle)
    }
  }
}
