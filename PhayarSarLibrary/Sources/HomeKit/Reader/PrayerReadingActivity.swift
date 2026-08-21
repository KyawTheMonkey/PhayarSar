import ActivitiesKit
import Foundation
import PrayersKit

#if canImport(ActivityKit)
// Pre-concurrency, because `Activity` is a plain class that the framework has
// never declared `Sendable` — so handing one to its own `async` methods from the
// main actor is a data race as far as Swift 6 is concerned. It is not one: this
// type is the only thing that ever holds the handle, it holds it on the main
// actor, and ActivityKit's own documentation asks to be driven from there.
@preconcurrency import ActivityKit
#endif

/// Posts, updates and retires the Live Activity that stands in for a reading
/// while the app is not the one on screen.
///
/// One activity at a time and one owner of it, because there is one reader. The
/// handle is held here rather than on ``PrayerScreen`` so that a screen rebuilt
/// mid-recitation — a language change, an injection reload — does not lose track
/// of a card it has already posted and leave it on the Lock Screen for the eight
/// hours the system would otherwise give it.
///
/// Every entry point is a no-op where Live Activities are not available: the
/// simulator without them, a build running on iOS 16.0, a reader who has turned
/// them off in Settings. The reader loses the card and nothing else — the page,
/// the bar and the island all work exactly as they did.
///
/// See ``PrayerReadingAttributes`` for what the card is and, more importantly,
/// what it deliberately is not.
@MainActor
enum PrayerReadingActivity {

  #if canImport(ActivityKit)
  /// The card currently up, if there is one.
  ///
  /// Typed against the availability guard rather than stored as `Any`, which is
  /// what the nested `if #available` is buying — the property itself cannot be
  /// annotated, so the storage is a box that only the guarded code opens.
  private static var handle: Any?

  @available(iOS 17.0, *)
  private static var activity: Activity<PrayerReadingAttributes>? {
    get { handle as? Activity<PrayerReadingAttributes> }
    set { handle = newValue }
  }
  #endif

  // MARK: - Posting

  /// Puts a card up for a reading that has just begun, or moves the one that is
  /// already up.
  ///
  /// Both jobs, rather than a `start` and an `update` the caller has to choose
  /// between. The caller is a SwiftUI screen reacting to state it did not
  /// necessarily see change — a prayer swapped under a reading arrives as one
  /// pass with a new title and a new position — and asking it to work out which
  /// verb it means would be asking it to keep a copy of what this already knows.
  ///
  /// - Parameters:
  ///   - prayer: What is being read. A change of prayer ends the old card and
  ///     posts a new one: the title is fixed for the life of an activity.
  ///   - progress: Where the reading has got to, or `nil` if it has not started.
  ///   - isPlaying: Whether the page is set to be reading.
  ///   - speed: The chosen pace.
  static func show(
    prayer: Prayer,
    progress: PrayerPlaybackProgress?,
    isPlaying: Bool,
    speed: PrayerPlaybackSpeed
  ) {
    #if canImport(ActivityKit)
    // iOS 17 rather than the 16.1 that Live Activities themselves began at. The
    // whole of this card is its buttons, and buttons are iOS 17 — a card posted
    // to iOS 16 would be a transport control that quietly does nothing. Below
    // this the reader keeps the controls in the app and loses only the card.
    guard #available(iOS 17.0, *) else { return }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

    let state = PrayerReadingAttributes.ContentState(
      verse: progress?.verse ?? 1,
      verses: progress?.verses ?? max(prayer.body.count, 1),
      isPlaying: isPlaying,
      speed: speed.rawValue
    )

    if let activity, activity.attributes.prayerID == prayer.id {
      Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
      return
    }

    // Either nothing is up, or what is up is about the prayer the reader has
    // just left. Ended rather than reused, because a card's title is part of its
    // attributes and attributes do not change.
    end()

    let attributes = PrayerReadingAttributes(
      prayerID: prayer.id,
      title: prayer.title,
      // Sent rather than left for the widget to know, so the card's row of paces
      // cannot fall out of step with the one the app offers.
      speeds: PrayerPlaybackSpeed.allCases.map(\.rawValue)
    )

    // Failure here is ordinary rather than exceptional — the reader may simply
    // have Live Activities switched off, or already have as many running as the
    // system allows. The reading carries on regardless, which is why nothing
    // above this waits on it or is told about it.
    activity = try? Activity.request(
      attributes: attributes,
      content: ActivityContent(state: state, staleDate: nil),
      pushType: nil
    )
    #endif
  }

  // MARK: - Retiring

  /// Takes the card down.
  ///
  /// Immediately, rather than letting it linger the way a finished workout does.
  /// There is nothing to look back at: the reading is over, the page has rewound
  /// itself, and a card still offering to resume would be offering something
  /// that no longer exists.
  static func end() {
    #if canImport(ActivityKit)
    guard #available(iOS 17.0, *), let activity else { return }

    self.activity = nil
    Task {
      await activity.end(
        ActivityContent(state: activity.content.state, staleDate: nil),
        dismissalPolicy: .immediate
      )
    }
    #endif
  }
}
