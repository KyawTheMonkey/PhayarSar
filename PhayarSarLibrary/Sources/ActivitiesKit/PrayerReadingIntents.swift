#if canImport(AppIntents) && canImport(ActivityKit)
import AppIntents

/// The buttons on the card, as things the system can run.
///
/// `LiveActivityIntent` rather than plain `AppIntent`, and the distinction is
/// the load-bearing one: a `LiveActivityIntent` is run **in the app's process**.
/// The app is woken in the background if it is not already there, the intent
/// finds the reading screen through ``PrayerReadingControl``, and the screen
/// updates the activity as it would for any other change. Nothing is written to
/// a shared container and nothing has to be reconciled later.
///
/// iOS 17 for all of it, which is where interactive Live Activities begin. Below
/// that the app shows no card at all and the reader's controls are the ones in
/// the app — see `PrayerIslandBar`.
///
/// None of these open the app. `openAppWhenRun` is left at its default of
/// `false` so that pausing a prayer from the Lock Screen pauses the prayer,
/// rather than pausing the prayer and then throwing the reader into the app they
/// had just put down.

// MARK: - Transport

@available(iOS 17.0, *)
public struct PrayerReadingToggleIntent: LiveActivityIntent {
  public static let title: LocalizedStringResource = "Play or pause the prayer"

  public init() {}

  @MainActor
  public func perform() async throws -> some IntentResult {
    PrayerReadingControl.shared.toggle()
    return .result()
  }
}

@available(iOS 17.0, *)
public struct PrayerReadingStopIntent: LiveActivityIntent {
  public static let title: LocalizedStringResource = "Stop the prayer"

  public init() {}

  @MainActor
  public func perform() async throws -> some IntentResult {
    PrayerReadingControl.shared.stop()
    return .result()
  }
}

// MARK: - Pace

@available(iOS 17.0, *)
public struct PrayerReadingSpeedIntent: LiveActivityIntent {
  public static let title: LocalizedStringResource = "Set the reading pace"

  /// The pace, as its multiple of the ordinary one.
  ///
  /// A `Double` rather than an `AppEnum`, so that this module stays free of
  /// `PrayersKit` — see ``PrayerReadingAttributes``. The app is what decides
  /// whether the number names a pace it offers; a value it does not recognise is
  /// dropped rather than clamped, because there is no sensible nearest pace to a
  /// number nobody sent.
  @Parameter(title: "Speed")
  public var speed: Double

  public init() {}

  public init(speed: Double) {
    self.speed = speed
  }

  @MainActor
  public func perform() async throws -> some IntentResult {
    PrayerReadingControl.shared.setSpeed(speed)
    return .result()
  }
}
#endif
