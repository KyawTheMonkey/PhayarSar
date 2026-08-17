import CloudKit
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

  /// The user's iCloud account is out of space, so nothing more can be exported.
  ///
  /// Split out from ``failed(_:)`` because it is the one sync failure the user
  /// can do something about, and the only one worth naming: it is not transient,
  /// retrying will not clear it, and "Last sync failed" would send someone
  /// looking for a network problem they do not have.
  case quotaExceeded

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
      let isOutOfSpace = Self.isQuotaExceeded(event.error)

      // `assumeIsolated` rather than a `Task`: `queue: .main` means this block is
      // already on the main queue, and hopping would let two events land out of
      // order and leave `inFlight` wrong.
      MainActor.assumeIsolated {
        self?.handle(hasEnded: hasEnded, failure: failure, isOutOfSpace: isOutOfSpace)
      }
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  private func handle(hasEnded: Bool, failure: String?, isOutOfSpace: Bool) {
    guard hasEnded else {
      inFlight += 1
      onChange(.syncing)
      return
    }

    inFlight = max(0, inFlight - 1)

    if isOutOfSpace {
      onChange(.quotaExceeded)
    } else if let failure {
      onChange(.failed(failure))
    } else if inFlight == 0 {
      onChange(.idle)
    }
  }

  /// Whether this error is CloudKit saying the account is full.
  ///
  /// Checked two ways because an export rarely fails as a single clean error: a
  /// batch that could not be saved comes back as `.partialFailure` carrying one
  /// error per record, and the quota code is inside those rather than on the
  /// error the notification hands over.
  ///
  /// `nonisolated` and `static` so it can run in the notification's own context,
  /// where the event is unpacked — see `init`.
  private nonisolated static func isQuotaExceeded(_ error: Error?) -> Bool {
    guard let error = error as? CKError else { return false }

    if error.code == .quotaExceeded { return true }

    guard
      error.code == .partialFailure,
      let partial = error.partialErrorsByItemID
    else {
      return false
    }

    return partial.values.contains { ($0 as? CKError)?.code == .quotaExceeded }
  }
}
