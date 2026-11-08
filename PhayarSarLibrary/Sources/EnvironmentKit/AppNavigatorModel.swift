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
  @Published public var presentedSheet: SheetDestination? {
    didSet {
      if presentedSheet == nil { sheetPath = [] }
    }
  }

  /// Modal detours have their own stack. Putting their pushes in the tab's
  /// path would change the screen *behind* the sheet and lose the creator's
  /// draft when a source breadcrumb is followed.
  @Published public var sheetPath: [RouterDestination] = []

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

  /// Pushes inside the presented sheet, or onto the current tab otherwise.
  ///
  /// The default for cross-module routes too: the destination changes, the tab
  /// does not. A tap should not move the ground under the user, even when the
  /// screen it opens belongs to another module.
  public func navigate(to destination: RouterDestination) {
    navigate(to: [destination])
  }

  /// Install a deep link's complete ancestry in one update. Sequential pushes
  /// animate through the browser before reaching the picker; one path lands
  /// directly on the selection while keeping the browser behind Back.
  public func navigate(to destinations: [RouterDestination]) {
    if presentedSheet != nil {
      sheetPath.append(contentsOf: destinations)
    } else {
      paths[selectedTab, default: []].append(contentsOf: destinations)
    }
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

  /// Drops the top screen of the active modal or tab stack. No-op at its root.
  public func pop() {
    if presentedSheet != nil {
      if !sheetPath.isEmpty { sheetPath.removeLast() }
      return
    }
    guard var path = paths[selectedTab], !path.isEmpty else { return }
    path.removeLast()
    paths[selectedTab] = path
  }

  /// Returns from a picker to the form that opened it without discarding
  /// that form's draft or assuming it sits at the stack's root.
  public func pop(to destination: RouterDestination) {
    if presentedSheet != nil {
      guard let index = sheetPath.lastIndex(of: destination) else { return }
      sheetPath = Array(sheetPath.prefix(through: index))
    } else {
      guard let path = paths[selectedTab],
            let index = path.lastIndex(of: destination) else { return }
      paths[selectedTab] = Array(path.prefix(through: index))
    }
  }

  /// Unwinds a tab back to its root.
  ///
  /// - Parameter tab: Defaults to the current tab.
  public func popToRoot(_ tab: AppTab? = nil) {
    paths[tab ?? selectedTab] = []
  }

  // MARK: - Sheets

  public func present(_ sheet: SheetDestination, path: [RouterDestination] = []) {
    sheetPath = path
    presentedSheet = sheet
  }

  public func popSheetToRoot() {
    sheetPath = []
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
  /// The saved set is edited in place within the Beads navigation stack.
  case beadsEditor(beadsID: UUID)
  case beadsPrayerBrowser
  case beadsPrayerSelection(prayerID: String, location: PrayerPassageLocation? = nil)
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

  /// The meditation session creator — one style per screen, swiped through.
  ///
  /// A sheet rather than a push because starting a session is a detour off the
  /// meditation tab that ends in either a session or nothing, and a sheet is
  /// the shape of a decision the user can back out of. It carries no id: the
  /// styles it offers are `MeditationStyle`'s cases, not stored records.
  case meditationSessionCreator

  /// Creating a bead set is a cancellable detour. The reader supplies source
  /// ids so the draft can resolve a whole verse without coupling navigation
  /// to prayer models or the reader's reshaped display text.
  case beadsCreator(prayerID: String? = nil, verseID: Int? = nil)

  /// Re-selecting a saved bead set's passage uses the same browser and picker,
  /// but Done updates that record rather than creating a second bead set.
  case beadsRecitationEditor(beadsID: UUID)

  public var id: String {
    switch self {
    case .profile:
      return "profile"
    case .meditationSessionCreator:
      return "meditationSessionCreator"
    case let .beadsCreator(prayerID, verseID):
      if let prayerID, let verseID {
        return "beadsCreator-\(prayerID)-\(verseID)"
      }
      return "beadsCreator"
    case let .beadsRecitationEditor(beadsID):
      return "beadsRecitationEditor-\(beadsID.uuidString)"
    }
  }
}
