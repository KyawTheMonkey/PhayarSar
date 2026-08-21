#if canImport(UIKit)
import PrayersKit
import SwiftUI
import UIKit

// MARK: - Window

/// The window the docked island chrome lives in.
///
/// A window of its own rather than a view in the reader's hierarchy, and the
/// first attempt at this feature is the argument for it. Chrome that has to sit
/// in the cutout has to sit *above* the navigation bar — and inside a
/// `NavigationStack` that is not possible, because `UINavigationBar` is a
/// sibling view above the SwiftUI content in `UINavigationController`. Anything
/// the content drew up there was behind the bar, and every touch aimed at it
/// went to the bar instead. The controls looked right and did nothing.
///
/// Above the status bar too, at `.statusBar + 1`, which is what lets the open
/// sheet cover the clock the way the system's own expanded island does.
///
/// Full-screen and mostly not there: see ``hitTest(_:with:)``.
final class PrayerIslandWindow: UIWindow {

  /// The only part of the screen this window will take a touch in.
  ///
  /// Everything outside it belongs to whatever is underneath — the page, the
  /// Back button, the system's own pull-down from the top corners. A window at
  /// this level that swallowed touches indiscriminately would take the whole app
  /// away from the reader.
  ///
  /// A rectangle rather than the chrome's real outline. It is a hair generous at
  /// the pill's rounded corners, and that is the right way to be wrong: the cost
  /// is a few square points of page that do nothing when tapped, against a
  /// control whose corners would otherwise be dead.
  var interactiveRect: CGRect = .zero

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard interactiveRect.contains(point) else { return nil }

    return super.hitTest(point, with: event)
  }
}

// MARK: - Presenter

/// Puts ``PrayerIslandBar`` in that window, and takes it away again.
///
/// A `UIViewControllerRepresentable` that never shows a view controller. It is
/// here purely for the lifetime: SwiftUI creates it when the reader reaches a
/// page that wants the island, updates it as the reading moves, and dismantles
/// it on the way out — which is exactly the three moments a window like this has
/// to be raised, refreshed and lowered.
///
/// The alternative was a singleton the screen pokes at from `onAppear` and
/// `onDisappear`. This way a screen that goes away without either being called —
/// a hosting controller torn down under a rebuild — still takes its window with
/// it.
struct PrayerIslandPresenter: UIViewControllerRepresentable {
  let state: PrayerPlaybackState
  let speed: PrayerPlaybackSpeed
  let progress: PrayerPlaybackProgress?
  let title: String

  /// Whether the sheet is down. Owned by the screen rather than by the bar
  /// because the window needs it too — it decides whether a touch anywhere on
  /// screen belongs to this chrome or to the page under it.
  @Binding var isOpen: Bool

  let onToggle: () -> Void
  let onStop: () -> Void
  let onSpeed: (PrayerPlaybackSpeed) -> Void

  func makeUIViewController(context: Context) -> UIViewController {
    // Nothing is ever drawn in it. The controller exists so that SwiftUI has
    // something whose lifetime it understands to hang the window off.
    let controller = UIViewController()
    controller.view.isUserInteractionEnabled = false
    controller.view.backgroundColor = .clear
    return controller
  }

  func updateUIViewController(_ controller: UIViewController, context: Context) {
    context.coordinator.show(
      PrayerIslandBar(
        state: state,
        speed: speed,
        progress: progress,
        title: title,
        isOpen: $isOpen,
        onToggle: onToggle,
        onStop: onStop,
        onSpeed: onSpeed
      ),
      isOpen: isOpen,
      isActive: state != .stopped
    )
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  static func dismantleUIViewController(_ controller: UIViewController, coordinator: Coordinator) {
    coordinator.hide()
  }

  // MARK: Coordinator

  @MainActor
  final class Coordinator {
    private var window: PrayerIslandWindow?
    private var host: UIHostingController<PrayerIslandBar>?

    /// Raises the window if it is not up, and re-roots it on every pass.
    ///
    /// Re-rooted rather than left alone, because the bar's closures capture the
    /// current `body`'s state — the same reason ``PrayerReader`` re-sets the
    /// reader's callbacks every time through.
    func show(_ bar: PrayerIslandBar, isOpen: Bool, isActive: Bool) {
      guard let scene = Self.scene else { return }

      let window = self.window ?? make(in: scene)

      if let host {
        host.rootView = bar
      } else {
        let host = UIHostingController(rootView: bar)
        host.view.backgroundColor = .clear
        // Both of these say the same thing twice, and after the first attempt
        // at this feature that is deliberate. A hosting controller inherits the
        // scene's safe area, which would lay the bar out below the status bar —
        // the whole of what this window exists to get above. The bar asks for
        // the full screen itself with `ignoresSafeArea`; this makes sure there
        // is no safe area left for it to have to ask about.
        host.view.insetsLayoutMarginsFromSafeArea = false
        if #available(iOS 16.4, *) {
          host.safeAreaRegions = []
        }
        window.rootViewController = host
        self.host = host
      }

      // Shut, only the pill takes touches. Open, everything does — the scrim is
      // how a tap outside the sheet shuts it, and it has to be able to hear one.
      // Nothing at all while the page is not reading itself.
      window.interactiveRect = {
        guard isActive else { return .zero }
        guard !isOpen else { return window.bounds }

        return PrayerIslandMetrics.shutRect(in: window.bounds)
      }()

      window.isHidden = false
    }

    /// Takes the window down for good.
    func hide() {
      window?.isHidden = true
      window?.rootViewController = nil
      window = nil
      host = nil
    }

    private func make(in scene: UIWindowScene) -> PrayerIslandWindow {
      let window = PrayerIslandWindow(windowScene: scene)
      window.backgroundColor = .clear
      // Above the status bar, so the open sheet may cover the clock exactly as
      // the system's own expanded island does.
      window.windowLevel = .statusBar + 1
      // Never made key. This window holds chrome, not the app — the reader's
      // keyboard, their text selection and their focus all belong to the window
      // underneath, and taking key status would quietly move all three.
      self.window = window
      return window
    }

    private static var scene: UIWindowScene? {
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
  }
}
#endif
