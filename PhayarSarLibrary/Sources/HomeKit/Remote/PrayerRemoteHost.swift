import Combine
import EnvironmentKit
import Foundation
import LocalisationKit
import PrayersKit
import RemoteKit
#if canImport(UIKit)
import UIKit
#endif

/// The phone's half of the watch remote: takes ``PrayerRemoteCommand``s off the
/// wire and turns them into the things the app already knows how to do.
///
/// Nothing here reaches into a view. Commands land on one of three collaborators
/// and the app behaves exactly as it would have under a finger:
///
/// - `AppNavigatorModel` for the ones that change *which screen* is up, so a
///   prayer opened from the wrist pushes onto the same stack, in the same tab,
///   as one opened from the home list — and Back still works.
/// - ``PrayerRemoteScreenHandle`` for the ones that change *which prayer*, which
///   is `PrayerScreen`'s state to own.
/// - ``PrayerRemoteReader`` for the ones that move the *page*, which is
///   `PrayerViewController`'s.
///
/// ## Why the host tracks the screen's position itself
///
/// `PrayerScreen` is a `struct` with `@State`; there is nothing here for this to
/// hold a reference to. So the screen *pushes* where it is on every change
/// (``screenDidChange(prayerID:textSize:)``) and this keeps the last value,
/// while the handle it registers only ever *writes* — through a `Binding`, which
/// is a location and stays valid. Reading through a captured `@State` would give
/// whatever value was current when the closure was made, which is the bug this
/// arrangement exists to avoid.
@MainActor
public final class PrayerRemoteHost {

  public static let shared = PrayerRemoteHost()

  // MARK: - Collaborators

  private weak var navigator: AppNavigatorModel?

  /// The reader currently on screen, if any. Weak: the view controller's
  /// lifetime belongs to SwiftUI, and a host that kept it alive would go on
  /// scrolling a page nobody is looking at.
  private weak var reader: (any PrayerRemoteReader)?

  private var screen: PrayerRemoteScreenHandle?

  // MARK: - Last known position

  private var currentPrayerID: String?
  private var currentTextSize = PrayerSettings.standard.textSize

  /// Whether the reading screen is up, which is the difference between
  /// "step to the next prayer" and "open one".
  private var isReaderOpen: Bool { reader != nil }

  private let link = RemoteLink.shared

  private var reachability: AnyCancellable?

  private init() {}

  // MARK: - Start

  /// Wires the host to the app and brings the session up.
  ///
  /// Called once, from the app's `init`. Activating this early rather than when
  /// the reader opens is deliberate: the watch can ask for a prayer while the
  /// phone is sitting on the home screen, and a session that only existed
  /// inside the reader could not answer.
  public func start(navigator: AppNavigatorModel) {
    self.navigator = navigator

    link.onCommand = { [weak self] command in
      self?.handle(command)
    }
    link.onStateRequest = { [weak self] in
      self?.publish(force: true)
    }

    // The idle timer follows the watch coming and going, not just the reader
    // opening and closing — a phone whose watch has wandered out of range
    // should be allowed to sleep again.
    reachability = link.$isReachable
      .removeDuplicates()
      .sink { [weak self] _ in
        self?.updateIdleTimer()
      }

    link.activate()
  }

  // MARK: - Registration

  /// Called by `PrayerScreen` when it appears, and again with `nil` when it goes.
  func attach(screen handle: PrayerRemoteScreenHandle?) {
    screen = handle
    if handle == nil {
      currentPrayerID = nil
    }
    publish(force: true)
  }

  /// Called by `PrayerViewController` when it appears.
  func attach(reader newReader: any PrayerRemoteReader) {
    reader = newReader
    updateIdleTimer()
    publish(force: true)
  }

  /// Called by `PrayerViewController` when it goes.
  ///
  /// Takes the departing reader and checks it is still the registered one,
  /// rather than clearing unconditionally: SwiftUI builds the incoming
  /// controller before the outgoing one disappears, so an unconditional clear
  /// would have the old reader's departure wipe out the new reader's arrival
  /// and leave the host driving nothing.
  func detach(reader old: any PrayerRemoteReader) {
    guard reader === old else { return }
    reader = nil
    updateIdleTimer()
    publish(force: true)
  }

  /// Called by `PrayerScreen` whenever the prayer or its size changes.
  func screenDidChange(prayerID: String, textSize: Int) {
    let turned = prayerID != currentPrayerID
    currentPrayerID = prayerID
    currentTextSize = textSize
    publish(force: turned)
  }

  /// Called by the reader when the verse under the middle of the page changes —
  /// whether the watch moved it or a finger did.
  func readerDidMove() {
    publish()
  }

  // MARK: - Commands

  private func handle(_ command: PrayerRemoteCommand) {
    switch command {
    case let .scroll(fraction):
      reader?.remoteScroll(fraction: fraction)

    case let .stepVerse(delta):
      reader?.remoteStepVerse(delta)

    case let .stepPrayer(delta):
      stepPrayer(by: delta)

    case let .openPrayer(id):
      open(prayerID: id)

    case .closeReader:
      guard isReaderOpen else { return }
      navigator?.pop()

    case let .setTextSize(size):
      screen?.setTextSize(size)

    case .requestState:
      // Answered by `onStateRequest` before it reaches here.
      break
    }
  }

  /// Turns to the prayer `delta` along from the one showing.
  ///
  /// Falls back to opening the reader when it is closed, so the prayer steps on
  /// the watch mean something from the home screen too — there, "next" is the
  /// next one after whatever was last read.
  private func stepPrayer(by delta: Int) {
    guard !catalogEntries.isEmpty else { return }

    let current = currentPrayerID.flatMap { id in
      catalogEntries.firstIndex { $0.id == id }
    }

    // From nowhere, a forward step opens the first prayer rather than doing
    // nothing — a wrist that has never opened one still has somewhere to go.
    let target = current.map { $0 + delta } ?? (delta > 0 ? 0 : catalogEntries.count - 1)
    guard catalogEntries.indices.contains(target) else { return }

    open(prayerID: catalogEntries[target].id)
  }

  private func open(prayerID: String) {
    guard PrayerCatalog.shared.prayer(id: prayerID) != nil else { return }

    // Already reading: swap the prayer in place rather than stacking a second
    // reader on the first, which is what `PrayerScreen`'s own switcher does and
    // for the same reason — Back should still lead where the reader came in
    // from, however far the wrist has wandered since.
    //
    // The `isReaderOpen` test comes first and stands alone. Pushing whenever
    // the *handle* happens to be missing would stack a second reader on the
    // first during the moment between the screen detaching and the reader
    // doing so — and a stack two readers deep takes two taps of Back to leave.
    guard !isReaderOpen else {
      screen?.show(prayerID)
      return
    }

    navigator?.navigate(to: .prayer(prayerID: prayerID), in: .home)
  }

  // MARK: - State

  /// The catalog as the watch wants it, built once.
  ///
  /// This runs on every verse the page crosses, which under a spun crown is
  /// several a second. The catalog is decoded from bundled JSON and cannot
  /// change while the app is running, so rebuilding thirty-five entries each
  /// time was work with no possible result.
  private lazy var catalogEntries: [PrayerRemoteState.Entry] = PrayerCatalog.shared
    .orderedPrayers()
    .map { .init(id: $0.id, title: $0.title) }

  /// Sends the watch where the phone is.
  private func publish(force: Bool = false) {
    let prayer = currentPrayerID.flatMap { PrayerCatalog.shared.prayer(id: $0) }
    let verse = reader?.remoteVerse

    let state = PrayerRemoteState(
      isReaderOpen: isReaderOpen,
      prayerID: prayer?.id,
      prayerTitle: prayer?.title,
      prayerIndex: currentPrayerID.flatMap { id in catalogEntries.firstIndex { $0.id == id } },
      verseIndex: verse?.index,
      verseCount: verse?.count ?? prayer?.body.count ?? 0,
      verseText: verse?.text,
      verseName: verse?.name,
      textSize: currentTextSize,
      // The watch cannot read this for itself — its `UserDefaults` are its own,
      // and the language switcher in Settings never writes to them.
      language: LocalisationManager.shared.currentLanguage.rawValue,
      catalog: catalogEntries
    )

    link.publish(state, force: force)
  }

  // MARK: - Keeping the screen up

  /// Holds the phone awake while it is being read from the wrist.
  ///
  /// Only while a watch is actually on the other end. A remote that cannot stop
  /// the phone locking four minutes into a prayer is not a remote — but a phone
  /// that never sleeps in the reader would be a battery bug for the far larger
  /// number of readers who have no watch at all.
  private func updateIdleTimer() {
#if os(iOS)
    UIApplication.shared.isIdleTimerDisabled = isReaderOpen && link.isReachable
#endif
  }
}

// MARK: - Collaborator interfaces

/// What the host can ask `PrayerScreen` to do.
///
/// Writes only, and through bindings — see the note on ``PrayerRemoteHost``
/// about why nothing here reads.
@MainActor
struct PrayerRemoteScreenHandle {
  /// Put the reader on this prayer, in place.
  let show: (String) -> Void

  /// Set the recited text's point size.
  let setTextSize: (Int) -> Void
}

/// What the host can ask the reader to do.
///
/// A protocol rather than a direct reference to `PrayerViewController` because
/// the host has no business knowing the page is a `UITableView` — and because
/// the reader does not exist at all on the Mac build.
@MainActor
protocol PrayerRemoteReader: AnyObject {
  /// Move the page by a fraction of its own height.
  func remoteScroll(fraction: Double)

  /// Centre the verse `delta` along from the one at the middle of the page.
  func remoteStepVerse(_ delta: Int)

  /// The verse at the middle of the page, for the watch's glance.
  var remoteVerse: PrayerRemoteVerse? { get }
}

/// The centred verse, as the watch wants to see it.
struct PrayerRemoteVerse {
  /// 0-based position in the prayer.
  let index: Int
  let count: Int
  let name: String?
  let text: String
}
