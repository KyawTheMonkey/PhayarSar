import SwiftUI

/// The single source of truth for where the user is in the app.
///
/// Every push, pop and sheet goes through here — no `NavigationLink(value:)`,
/// no local `@State` push flags. A view that mutated a `NavigationStack`
/// directly would leave this model out of step with what is on screen, and
/// nothing else (deep links, notification taps, "back to root" on re-tapping a
/// tab) could then reason about the current location.
///
/// ```swift
/// @EnvironmentObject private var navigator: AppNavigatorModel
/// ...
/// navigator.navigate(to: .prayerDetail(prayerID: prayer.id))
/// ```
@MainActor
public final class AppNavigatorModel: ObservableObject {
  /// Tab selection lives here rather than in the view because a cross-tab
  /// route has to move the selection and a path together — split across two
  /// owners, the two would land in separate render passes.
  @Published public var selectedTab: AppTab = .home

  /// One stack per tab. `TabView` keeps all five stacks alive at once and the
  /// split view's detail column swaps between them, so a single shared path
  /// cannot serve either layout. Keeping them here rather than in the view
  /// also means a stack survives the size-class switch between the two.
  ///
  /// Tabs the user has never pushed from are simply absent — see
  /// ``path(for:)``.
  @Published public var paths: [AppTab: [RouterDestination]] = [:]

  /// Presented above the tab bar, not inside a tab, so it is app-wide rather
  /// than per-tab state.
  @Published public var presentedSheet: SheetDestination?

  public init() {}

  // MARK: - Stack binding

  /// The stack for `tab`, ready to hand to `NavigationStack(path:)`.
  ///
  /// Reads a missing tab as an empty stack, so tabs do not need pre-seeding
  /// and a tab the user never leaves costs nothing.
  public func path(for tab: AppTab) -> Binding<[RouterDestination]> {
    Binding(
      get: { self.paths[tab] ?? [] },
      set: { self.paths[tab] = $0 }
    )
  }

  // MARK: - Push

  /// Pushes onto the tab the user is already in.
  ///
  /// The default for cross-module routes too: the destination changes, the tab
  /// does not. A tap should not move the ground under the user, even when the
  /// screen it opens belongs to another module.
  public func navigate(to destination: RouterDestination) {
    navigate(to: destination, in: selectedTab)
  }

  /// Selects `tab`, then pushes onto its stack.
  ///
  /// For entry points that name their own tab — deep links, notification taps
  /// — rather than for ordinary in-app taps, which should use
  /// ``navigate(to:)``.
  public func navigate(to destination: RouterDestination, in tab: AppTab) {
    if selectedTab != tab {
      selectedTab = tab
    }
    paths[tab, default: []].append(destination)
  }

  // MARK: - Pop

  /// Drops the top screen of the current tab. No-op at the root.
  public func pop() {
    guard var path = paths[selectedTab], !path.isEmpty else { return }
    path.removeLast()
    paths[selectedTab] = path
  }

  /// Unwinds a tab back to its root.
  ///
  /// - Parameter tab: Defaults to the current tab.
  public func popToRoot(_ tab: AppTab? = nil) {
    paths[tab ?? selectedTab] = []
  }

  // MARK: - Sheets

  public func present(_ sheet: SheetDestination) {
    presentedSheet = sheet
  }

  public func dismissSheet() {
    presentedSheet = nil
  }
}

/// Every pushable screen in the app.
///
/// Cases live here, in `EnvironmentKit`, rather than in the feature module that
/// owns the screen — that is what lets any module route anywhere without
/// depending on the module it is routing into. Only the app target, which links
/// everything, knows how to turn a case back into a view (see `RouteView`).
///
/// Payloads are ids, never model values. That keeps `EnvironmentKit` free of
/// domain types, and keeps this `Codable` so a route can survive a deep link,
/// a notification payload or state restoration. The destination screen resolves
/// its own id and decides what to show if the lookup fails.
///
/// Name new cases `<subject><Screen>(<id>:)` — e.g. `planDetail(planID:)`.
public enum RouterDestination: Hashable, Codable {
  /// Who the signed-in user is. Carries no id — it is always *this* device's
  /// user, and `AuthManager` is the one place that knows who that is.
  case profile
  case prayerDetail(prayerID: String)
  /// The reading screen itself, pushed from the detail screen's "Start".
  case prayer(prayerID: String)
  /// The study screen — each verse against its translation, pushed from the
  /// detail screen's "Nissaya" quick action.
  case nissaya(prayerID: String)
}

/// Every modally presented screen. Same rules as ``RouterDestination``.
public enum SheetDestination: Identifiable, Hashable, Codable {
  /// Who the signed-in user is, raised from the home nav bar.
  ///
  /// The same screen as ``RouterDestination/profile``, and deliberately
  /// reachable both ways: from settings the profile is a level down and gets
  /// pushed, while from home it is a detour off a screen the user is in the
  /// middle of reading, and a sheet lets them flick it away rather than aim for
  /// a back button.
  case profile

  public var id: String {
    switch self {
    case .profile:
      return "profile"
    }
  }
}
