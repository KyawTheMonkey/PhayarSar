#if os(watchOS)
import Foundation
import SwiftUI
import WatchKit

/// Keeps the remote on screen for the length of a prayer.
///
/// A watch app is frontmost for about seventy seconds after the wrist drops,
/// and then the watch goes back to its face. For most apps that is right; for
/// this one it means the remote disappears part-way through every reading, and
/// the reader has to raise their wrist and find the app again with hands that
/// are often holding beads.
///
/// `WKExtendedRuntimeSession` is the sanctioned way out of that, and
/// ``WKExtendedRuntimeSessionType/mindfulness`` is the session this app is
/// actually running — a period of quiet attention the user started deliberately
/// and will end deliberately. It holds the app frontmost for up to an hour, and
/// the screen stays legible through Always On rather than blanking.
///
/// Deliberately *not* a `HKWorkoutSession`, which is the other way to get long
/// runtime and the wrong one twice over: it would claim the reader is
/// exercising, and it keeps the heart-rate sensor running for a screen that has
/// no use for it.
///
/// The plist has to agree: the watch target declares `WKBackgroundModes` of
/// `mindfulness`, without which `start()` fails immediately with
/// `.mustBeActiveToStartOrSchedule`.
@MainActor
final class WristRuntimeSession: NSObject, ObservableObject {

  /// Whether a session is currently holding the app up. Not shown anywhere —
  /// the reader should never have to think about this — but it is what keeps
  /// ``begin()`` from stacking sessions on each other.
  @Published private(set) var isRunning = false

  private var session: WKExtendedRuntimeSession?

  func begin() {
    guard !isRunning else { return }

    let session = WKExtendedRuntimeSession()
    session.delegate = self
    session.start()

    self.session = session
    isRunning = true
  }

  func end() {
    session?.invalidate()
    session = nil
    isRunning = false
  }
}

extension WristRuntimeSession: WKExtendedRuntimeSessionDelegate {

  nonisolated func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {}

  /// The system's warning that it is about to end the session — an hour has
  /// gone by, or the battery is low.
  ///
  /// Nothing to save and nothing to warn about: the phone holds the reading
  /// position, so the worst that happens is the watch returns to its face and
  /// the reader raises their wrist to find the remote exactly where they left
  /// it.
  nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {}

  nonisolated func extendedRuntimeSession(
    _ session: WKExtendedRuntimeSession,
    didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
    error: Error?
  ) {
    Task { @MainActor [weak self] in
      // Cleared rather than restarted. An invalidation the app did not ask for
      // means the system has decided the app should not be holding the screen —
      // starting another immediately would be arguing with it, and on the
      // battery-low reason it would be arguing badly.
      self?.session = nil
      self?.isRunning = false
    }
  }
}
#endif
