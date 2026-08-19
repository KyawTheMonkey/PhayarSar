import Combine
import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// The wire between the phone and the watch, and the only thing in the app that
/// touches `WCSession`.
///
/// One type serves both sides rather than one per platform: the session, its
/// activation, its reachability and its two delivery modes are identical on
/// each, and only *what* is sent differs — the watch sends
/// ``PrayerRemoteCommand``, the phone sends ``PrayerRemoteState``. Splitting it
/// would duplicate the delegate and the two would drift.
///
/// ## Why two delivery modes
///
/// `sendMessage` is the live path: it is delivered immediately or not at all,
/// which is what a remote control wants — a tap that arrives forty seconds late
/// is worse than a tap that was dropped. `updateApplicationContext` is the
/// durable one: it holds only the latest value, survives the far app being
/// killed, and is what a watch app opening cold reads to find out where the
/// phone is without having to ask.
///
/// So state goes out both ways: live over `sendMessage` for the moment-to-moment
/// verse changes, and folded into the application context every so often so a
/// cold start has something to draw. Commands only ever go the live way.
@MainActor
public final class RemoteLink: NSObject, ObservableObject {

  public static let shared = RemoteLink()

  // MARK: - Published

  /// Whether the counterpart app is up and can be reached *right now*. The
  /// watch UI hangs off this: a remote that quietly does nothing is worse than
  /// one that says it is not connected.
  @Published public private(set) var isReachable = false

  /// Whether the session finished activating. Distinct from ``isReachable`` —
  /// an activated session with the phone app closed is not reachable, and the
  /// two states want different words on screen.
  @Published public private(set) var isActivated = false

  /// Where the phone is. Meaningful on the watch; on the phone this is simply
  /// the last thing it published.
  @Published public private(set) var state = PrayerRemoteState.unknown

  // MARK: - Callbacks

  /// Called on the phone for each command the watch sends. Set by
  /// `PrayerRemoteHost`.
  public var onCommand: ((PrayerRemoteCommand) -> Void)?

  /// Called on the phone when the watch asks for a fresh state, so the host can
  /// build one from whatever screen is up.
  public var onStateRequest: (() -> Void)?

  // MARK: - Session

#if canImport(WatchConnectivity)
  private var session: WCSession? {
    WCSession.isSupported() ? .default : nil
  }
#endif

  private let coder = RemoteCoder()

  /// The delegate, held here because `WCSession.delegate` is `weak`.
  ///
  /// Without this the forwarder is deallocated the instant ``activate()``
  /// returns, `session.delegate` goes back to `nil`, and the link silently
  /// receives nothing at all for the rest of the process — no error, no
  /// callback, just a remote whose buttons do nothing.
  private var forwarder: AnyObject?

  /// When the application context was last written.
  ///
  /// The system throttles context updates, and the reader can cross a verse
  /// several times a second under a spun crown. The live path carries those;
  /// this one only has to be recent enough that a cold watch opens on roughly
  /// the right page.
  private var lastContextUpdate = Date.distantPast
  private static let contextInterval: TimeInterval = 2

  private override init() {
    super.init()
  }

  // MARK: - Lifecycle

  /// Activates the session.
  ///
  /// Safe to call more than once, and it is called more than once — the watch
  /// app calls it every time it comes to the foreground. The forwarder is built
  /// once and kept; only `activate()` is repeated, which `WCSession` itself
  /// treats as a no-op once it has activated.
  public func activate() {
#if canImport(WatchConnectivity)
    guard let session else { return }

    if forwarder == nil {
      let forwarder = SessionForwarder(link: self)
      self.forwarder = forwarder
      session.delegate = forwarder
    }

    session.activate()
#endif
  }

  // MARK: - Watch → phone

  /// Sends a command to the phone, if the phone is there to hear it.
  ///
  /// Silently dropped when unreachable rather than queued: see the note above
  /// on why a remote does not want `transferUserInfo`'s guarantees.
  public func send(_ command: PrayerRemoteCommand) {
#if canImport(WatchConnectivity)
    guard let session, session.activationState == .activated, session.isReachable else { return }
    guard let payload = coder.encode(command) else { return }

    session.sendMessage(
      [RemoteCoder.commandKey: payload],
      replyHandler: nil,
      // Reachability can lapse between the check above and the send. Nothing to
      // do about it and nothing worth telling the reader, who has already moved
      // on to pressing the button again.
      errorHandler: nil
    )
#endif
  }

  // MARK: - Phone → watch

  /// Publishes where the phone is.
  ///
  /// - Parameter force: writes the application context even if the interval
  ///   since the last one has not elapsed. Used for the changes a cold watch
  ///   must not miss — opening or closing the reader, turning to another
  ///   prayer — as against the steady drip of verse changes.
  public func publish(_ newState: PrayerRemoteState, force: Bool = false) {
    state = newState

#if canImport(WatchConnectivity)
    guard let session, session.activationState == .activated else { return }

    // The live path. Without the catalog, which does not change between two
    // verses and is the bulk of the payload.
    if session.isReachable, let payload = coder.encode(newState.withoutCatalog) {
      session.sendMessage(
        [RemoteCoder.stateKey: payload],
        replyHandler: nil,
        errorHandler: nil
      )
    }

    // The durable path, throttled.
    let due = force || Date().timeIntervalSince(lastContextUpdate) >= Self.contextInterval
    guard due, let context = coder.encodeContext(newState) else { return }

    do {
      try session.updateApplicationContext(context)
      lastContextUpdate = Date()
    } catch {
      // An unactivated or unpaired session. The live path above is unaffected,
      // and the next publish tries again.
    }
#endif
  }

  // MARK: - Delegate hand-offs
  //
  // Called by `SessionForwarder` from whatever queue `WCSession` chose, already
  // hopped onto the main actor.

  fileprivate func linkDidActivate(reachable: Bool) {
    isActivated = true
    isReachable = reachable
  }

  fileprivate func reachabilityDidChange(_ reachable: Bool) {
    isReachable = reachable

    // Coming back after a gap, the watch's picture of the phone is however old
    // the gap was. Ask rather than assume.
#if os(watchOS)
    if reachable {
      send(.requestState)
    }
#endif
  }

  fileprivate func didReceive(_ message: [String: Any]) {
    if let data = message[RemoteCoder.commandKey] as? Data,
       let command = coder.decode(PrayerRemoteCommand.self, from: data) {
      if case .requestState = command {
        onStateRequest?()
      } else {
        onCommand?(command)
      }
    }

    if let data = message[RemoteCoder.stateKey] as? Data,
       let update = coder.decode(PrayerRemoteState.self, from: data) {
      state = state.merging(update)
    }
  }

  fileprivate func didReceiveContext(_ context: [String: Any]) {
    guard
      let data = context[RemoteCoder.stateKey] as? Data,
      let update = coder.decode(PrayerRemoteState.self, from: data)
    else {
      return
    }
    state = state.merging(update)
  }
}

// MARK: - Delegate

#if canImport(WatchConnectivity)
/// Holds the `WCSessionDelegate` conformance away from ``RemoteLink``.
///
/// `WCSession` calls its delegate on a background queue, while everything the
/// link touches — its `@Published` properties, the reader it ends up driving —
/// belongs to the main actor. A separate `nonisolated` object is what lets the
/// hop be explicit and in one place, rather than scattering
/// `MainActor.assumeIsolated` through a delegate that genuinely is called off
/// the main thread.
private final class SessionForwarder: NSObject, WCSessionDelegate {

  /// Weak, because ownership runs the other way: the link holds the forwarder
  /// (see `RemoteLink.forwarder`), precisely because `WCSession.delegate` will
  /// not. Holding the link back strongly would close a cycle for no gain.
  private weak var link: RemoteLink?

  init(link: RemoteLink) {
    self.link = link
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    let activated = activationState == .activated
    let reachable = session.isReachable
    guard activated else { return }

    Task { @MainActor [weak link] in
      link?.linkDidActivate(reachable: reachable)
    }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    let reachable = session.isReachable
    Task { @MainActor [weak link] in
      link?.reachabilityDidChange(reachable)
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    // Only `Data` crosses the wire — see `RemoteCoder` — so the dictionary is
    // narrowed to something `Sendable` before the hop.
    let payload = message.compactMapValues { $0 as? Data }
    Task { @MainActor [weak link] in
      link?.didReceive(payload)
    }
  }

  func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
    let payload = context.compactMapValues { $0 as? Data }
    Task { @MainActor [weak link] in
      link?.didReceiveContext(payload)
    }
  }

#if os(iOS)
  // Required on iOS, where one phone can be re-paired to a different watch. The
  // session has to be reactivated for the new one, and there is nothing of ours
  // to tear down in between — the link holds no per-watch state.
  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
#endif
}
#endif

// MARK: - Coding

/// Turns the two wire types into `Data` and back.
///
/// `WCSession` payloads must be property-list types, so everything travels as a
/// JSON `Data` under a fixed key rather than as a hand-built dictionary — which
/// keeps the wire format in step with the types automatically, including as
/// cases are added to ``PrayerRemoteCommand``.
private struct RemoteCoder {
  static let commandKey = "command"
  static let stateKey = "state"

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  func encode<T: Encodable>(_ value: T) -> Data? {
    try? encoder.encode(value)
  }

  func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
    try? decoder.decode(type, from: data)
  }

  func encodeContext(_ state: PrayerRemoteState) -> [String: Any]? {
    guard let data = encode(state) else { return nil }
    return [Self.stateKey: data]
  }
}
