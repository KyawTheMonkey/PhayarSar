#if os(watchOS)
import DesignKit
import SwiftUI

/// The watch app.
///
/// The only thing the watch target itself contains is a `WindowGroup` around
/// this, so that everything the app is lives in the package alongside the phone
/// — including, and mainly, the wire types the two have to agree on.
public struct WristRootView: View {

  /// Observed rather than owned: it is a singleton that outlives every view,
  /// and `@StateObject` would claim a lifetime this view does not have.
  @ObservedObject private var remote = WristRemote.shared

  /// Holds the app frontmost while the reader is being driven from it.
  ///
  /// Without it the screen returns to the watch face on wrist-down, and the
  /// remote is gone in the middle of a prayer — which is exactly when it is
  /// being used, and exactly when the reader has no free hand to bring it back.
  @StateObject private var runtime = WristRuntimeSession()

  @Environment(\.scenePhase) private var scenePhase

  /// Whether there is a prayer on the phone's screen right now — and so whether
  /// there is anything for the remote to be holding the watch awake for.
  private var isReading: Bool {
    remote.isReachable && remote.state.isReaderOpen
  }

  public init() {}

  public var body: some View {
    NavigationStack {
      ZStack {
        AppColor.background
          .ignoresSafeArea()

        if remote.isReachable {
          WristReaderView(remote: remote)
        } else {
          WristUnreachableView(
            isActivated: remote.isActivated,
            strings: remote.strings
          )
        }
      }
    }
    .tint(AppColor.primary)
    .onAppear { remote.start() }
    // The session follows the *reading*, not the app.
    //
    // Holding the screen from launch would mean a watch that never sleeps
    // whenever the app was left open, for a remote with nothing to remote. It
    // begins when a prayer is on the phone's screen and ends the moment the
    // reader closes it, which is exactly the stretch the reader's hands are
    // busy and the wrist is down.
    .onChange(of: isReading, initial: true) { _, reading in
      if reading {
        runtime.begin()
      } else {
        runtime.end()
      }
    }
    .onChange(of: scenePhase) { _, phase in
      switch phase {
      case .active:
        // The phone may have moved on while the watch was away — a prayer
        // finished, another opened. Ask rather than draw what was true when the
        // wrist dropped.
        remote.refresh()
        if isReading {
          runtime.begin()
        }
      case .background:
        runtime.end()
      default:
        break
      }
    }
  }
}

/// What the remote shows when there is no phone on the other end.
///
/// Its own screen rather than a banner over dimmed controls: every control here
/// does nothing without the phone, and a screen of dead buttons invites the
/// reader to keep pressing them.
struct WristUnreachableView: View {

  let isActivated: Bool

  /// Passed in rather than read from the remote: the language came from the
  /// phone, and if the phone has never been reachable this falls back to
  /// English — which is the honest answer, since there is nothing to have
  /// learned it from yet.
  let strings: WristStrings

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "iphone.slash")
        .font(.system(size: 22))
        .foregroundStyle(AppColor.primary)

      Text(isActivated ? strings.disconnected : strings.connecting)
        .font(AppFont.bodySemibold)
        .foregroundStyle(AppColor.textPrimary)
        .multilineTextAlignment(.center)

      if isActivated {
        Text(strings.disconnectedHint)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textSecondary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 8)
  }
}
#endif
