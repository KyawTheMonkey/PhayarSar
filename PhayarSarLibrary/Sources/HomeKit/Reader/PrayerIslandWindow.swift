#if os(iOS)
import DesignKit
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
  @Binding var isDocked: Bool
  @Binding var resumeOnClose: Bool

  let onToggle: () -> Void
  let onStop: () -> Void
  let onSpeed: (PrayerPlaybackSpeed) -> Void

  func makeUIViewController(context: Context) -> PrayerIslandSourceController {
    let controller = PrayerIslandSourceController()
    controller.onLayout = { [weak coordinator = context.coordinator] view in
      coordinator?.layout(in: view)
    }
    controller.onDisappear = { [weak coordinator = context.coordinator] in
      coordinator?.hideWindow()
    }
    return controller
  }

  func updateUIViewController(_ controller: PrayerIslandSourceController, context: Context) {
    context.coordinator.configure(
      { topInset in
        PrayerIslandBar(
          topInset: topInset,
          state: state,
          speed: speed,
          progress: progress,
          title: title,
          isOpen: $isOpen,
          resumeOnClose: $resumeOnClose,
          onToggle: onToggle,
          onStop: onStop,
          onSpeed: onSpeed
        )
      },
      isOpen: isOpen,
      isActive: state != .stopped,
      onDockingChange: { isDocked = $0 }
    )
    controller.view.setNeedsLayout()
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  static func dismantleUIViewController(_ controller: PrayerIslandSourceController, coordinator: Coordinator) {
    controller.onLayout = nil
    controller.onDisappear = nil
    coordinator.hideWindow()
  }

  // MARK: Coordinator

  @MainActor
  final class Coordinator {
    private var window: PrayerIslandWindow?
    private var host: UIHostingController<PrayerIslandBar>?
    private var makeBar: ((CGFloat) -> PrayerIslandBar)?
    private var onDockingChange: ((Bool) -> Void)?
    private var isOpen = false
    private var isActive = false
    private var reportedDocking: Bool?

    func configure(
      _ makeBar: @escaping (CGFloat) -> PrayerIslandBar,
      isOpen: Bool,
      isActive: Bool,
      onDockingChange: @escaping (Bool) -> Void
    ) {
      self.makeBar = makeBar
      self.isOpen = isOpen
      self.isActive = isActive
      self.onDockingChange = onDockingChange
    }

    /// Read at layout time, from the scene that actually contains the reader.
    /// A fold can move the system bar without a size-class change, and another
    /// foreground scene must never acquire this reader's playback window.
    func layout(in source: UIView) {
      guard let appWindow = source.window,
        let scene = appWindow.windowScene,
        AppDynamicIsland.docks(in: appWindow),
        let makeBar
      else {
        reportDocking(false)
        hideWindow()
        return
      }

      reportDocking(true)
      if let window, window.windowScene !== scene {
        hideWindow()
      }
      let window = self.window ?? make(in: scene)
      let topInset = appWindow.safeAreaInsets.top
      let bar = makeBar(topInset)

      if let host {
        host.rootView = bar
      } else {
        let host = UIHostingController(rootView: bar)
        host.view.backgroundColor = .clear
        // Only the top edge is intentionally extended by the bar itself.
        // Keep the host's other safe-area regions intact, including a system
        // bar that may arrive during the next fold or rotation.
        host.view.insetsLayoutMarginsFromSafeArea = false
        window.rootViewController = host
        self.host = host
      }

      // Shut, only the pill takes touches. Open, everything does — the scrim is
      // how a tap outside the sheet shuts it, and it has to be able to hear one.
      // Nothing at all while the page is not reading itself.
      window.interactiveRect = {
        guard isActive else { return .zero }
        guard !isOpen else { return window.bounds }

        return PrayerIslandMetrics.shutRect(in: window.bounds, topInset: topInset)
      }()

      window.isHidden = false
    }

    /// Takes the window down for good.
    func hideWindow() {
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

    private func reportDocking(_ isDocked: Bool) {
      guard reportedDocking != isDocked else { return }
      reportedDocking = isDocked
      // UIKit can lay out during a SwiftUI update. Deliver the binding change
      // after that pass, and discard an obsolete report from an interrupted fold.
      DispatchQueue.main.async { [weak self] in
        guard let self, self.reportedDocking == isDocked else { return }
        self.onDockingChange?(isDocked)
      }
    }
  }
}

/// A local layout probe instead of a global scene observer. It stays mounted
/// when the island is unavailable so unfolding can hand the controls to the
/// bottom bar and folding back can restore them without restarting playback.
final class PrayerIslandSourceController: UIViewController {
  var onLayout: ((UIView) -> Void)?
  var onDisappear: (() -> Void)?

  override func loadView() {
    view = UIView()
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    if #available(iOS 27.1, *) {
      registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
        (self: PrayerIslandSourceController, _) in
        self.view.setNeedsLayout()
      }
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    onLayout?(view)
  }

  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    view.setNeedsLayout()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    view.setNeedsLayout()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    view.setNeedsLayout()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    onDisappear?()
  }
}
#endif
