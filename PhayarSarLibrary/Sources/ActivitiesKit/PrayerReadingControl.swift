import Foundation

/// Where a tap on the Live Activity's controls arrives in the app.
///
/// The card's buttons are `LiveActivityIntent`s, which iOS runs **in the app's
/// own process** rather than in the widget extension — launching or resuming the
/// app in the background to do it if it has to. That is the whole reason this
/// feature needs no App Group and no shared container: by the time an intent
/// runs, it is standing inside the app, next to the screen it wants to talk to.
///
/// What it still needs is a way to *find* that screen, and this is it: the
/// reading screen leaves a handle here while it is up, and the intents call
/// through it. Deliberately the same shape as `PrayerRemoteHost`, which does the
/// identical job for the watch — a feature outside the app reaching one screen
/// inside it, through writes only, along the same paths a finger would take.
///
/// Empty when no reading screen is up, which is not an error: an intent can
/// arrive a moment after the reader has left the page, and the right answer then
/// is to do nothing.
@MainActor
public final class PrayerReadingControl {
  public static let shared = PrayerReadingControl()

  /// What the card is allowed to change.
  ///
  /// Writes only, and every one of them through the same path the equivalent
  /// gesture takes — the Lock Screen has no privileges the finger does not,
  /// which is what keeps the two from producing different states.
  public struct Handle {
    /// Play when paused, pause when playing.
    public let toggle: () -> Void

    /// Ends the reading and gives the page back.
    public let stop: () -> Void

    /// Changes the pace, as a multiple of the ordinary one. Ignored if it is not
    /// one of the paces the app offers — see `PrayerPlaybackSpeed`.
    public let setSpeed: (Double) -> Void

    public init(
      toggle: @escaping () -> Void,
      stop: @escaping () -> Void,
      setSpeed: @escaping (Double) -> Void
    ) {
      self.toggle = toggle
      self.stop = stop
      self.setSpeed = setSpeed
    }
  }

  private var handle: Handle?

  private init() {}

  /// Called by the reading screen as it arrives and again as it leaves.
  ///
  /// Last one wins, and `nil` clears it. A screen that pushed another on top of
  /// itself has not left, which is why detaching is by assignment rather than by
  /// a count.
  public func attach(_ handle: Handle?) {
    self.handle = handle
  }

  // MARK: - What the card asks for

  public func toggle() {
    handle?.toggle()
  }

  public func stop() {
    handle?.stop()
  }

  public func setSpeed(_ speed: Double) {
    handle?.setSpeed(speed)
  }
}
