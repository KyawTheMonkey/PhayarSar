#if os(watchOS)
import Combine
import Foundation
import RemoteKit
import SwiftUI
import WatchKit

/// The watch's whole model.
///
/// Deliberately thin: it holds no picture of the prayer, only the last
/// ``PrayerRemoteState`` the phone sent. Everything on screen is drawn from
/// that, and every control sends a command and waits to be told what happened.
/// A watch that predicted the outcome of its own button — advancing its verse
/// counter locally and reconciling later — would be showing a different page
/// from the phone every time a command was dropped, which over a twenty minute
/// prayer is a certainty rather than a risk.
///
/// What it does own is the parts of the interaction that are the watch's alone:
/// turning crown rotation into scroll commands at a rate the wire can carry,
/// and the haptics that go with them.
@MainActor
public final class WristRemote: ObservableObject {

  public static let shared = WristRemote()

  // MARK: - Mirrored from the link

  @Published public private(set) var state = PrayerRemoteState.unknown
  @Published public private(set) var isReachable = false
  @Published public private(set) var isActivated = false

  /// The watch's own strings, in whichever language the phone is set to — see
  /// ``WristStrings`` for why the watch cannot work that out for itself.
  var strings: WristStrings { WristStrings(state: state) }

  private let link = RemoteLink.shared
  private var subscriptions: Set<AnyCancellable> = []

  // MARK: - Crown

  /// Crown movement seen but not yet sent, in pages.
  private var pendingScroll: Double = 0

  /// When the last scroll went out, so the wire carries a steady ~15 a second
  /// rather than one per frame of a spin.
  private var lastScrollSent = Date.distantPast

  /// The trailing send, so the last sliver of a turn is not left behind when
  /// the crown stops between two flushes.
  private var scrollFlush: Task<Void, Never>?

  /// How much crown has gone by since the last haptic tick.
  private var hapticDebt: Double = 0

  private init() {
    link.$state
      .receive(on: RunLoop.main)
      .assign(to: &$state)

    link.$isReachable
      .receive(on: RunLoop.main)
      .assign(to: &$isReachable)

    link.$isActivated
      .receive(on: RunLoop.main)
      .assign(to: &$isActivated)
  }

  // MARK: - Lifecycle

  /// Brings the session up and asks the phone where it is.
  public func start() {
    link.activate()
    link.send(.requestState)
  }

  // MARK: - Discrete commands

  public func stepVerse(_ delta: Int) {
    guard isReachable else { return }
    play(.click)
    link.send(.stepVerse(delta))
  }

  public func stepPrayer(_ delta: Int) {
    guard isReachable else { return }
    play(.directionUp)
    link.send(.stepPrayer(delta))
  }

  public func scrollPage(_ fraction: Double) {
    guard isReachable else { return }
    play(.click)
    link.send(.scroll(fraction: fraction))
  }

  public func open(prayerID: String) {
    guard isReachable else { return }
    play(.start)
    link.send(.openPrayer(id: prayerID))
  }

  public func closeReader() {
    guard isReachable else { return }
    play(.stop)
    link.send(.closeReader)
  }

  public func setTextSize(_ size: Int) {
    guard isReachable else { return }
    play(.click)
    link.send(.setTextSize(size))
  }

  public func refresh() {
    link.send(.requestState)
  }

  // MARK: - The crown

  /// Takes a raw change in the crown's value and turns it into page scrolling.
  ///
  /// Accumulated rather than sent as it arrives: the crown reports at frame
  /// rate, and a `WCSession` message per frame would be both far more than the
  /// link can carry and far finer than the page can show. What goes out instead
  /// is the sum of everything seen since the last send, at
  /// ``WristMetrics/scrollInterval``.
  public func crownDidRotate(by delta: Double) {
    guard isReachable, delta != 0 else { return }

    pendingScroll += delta * WristMetrics.crownPagesPerUnit
    tickHaptics(by: abs(delta) * WristMetrics.crownPagesPerUnit)

    let elapsed = Date().timeIntervalSince(lastScrollSent)
    if elapsed >= WristMetrics.scrollInterval {
      flushScroll()
    } else {
      scheduleScrollFlush(after: WristMetrics.scrollInterval - elapsed)
    }
  }

  private func flushScroll() {
    scrollFlush?.cancel()
    scrollFlush = nil

    let fraction = pendingScroll
    pendingScroll = 0
    lastScrollSent = Date()

    guard abs(fraction) > .ulpOfOne else { return }
    link.send(.scroll(fraction: fraction))
  }

  private func scheduleScrollFlush(after delay: TimeInterval) {
    guard scrollFlush == nil else { return }

    scrollFlush = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      guard !Task.isCancelled else { return }
      self?.flushScroll()
    }
  }

  /// A tick per notch of page crossed, so the crown feels like it is driving
  /// something even though what it drives is out of sight in the reader's other
  /// hand.
  private func tickHaptics(by pages: Double) {
    hapticDebt += pages
    guard hapticDebt >= WristMetrics.hapticPageInterval else { return }

    hapticDebt = 0
    play(.click)
  }

  private func play(_ haptic: WKHapticType) {
    WKInterfaceDevice.current().play(haptic)
  }
}
#endif
