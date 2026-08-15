import SwiftUI

extension View {
  public func hideNavBar() -> some View {
    modifier(HideNavBar())
  }
}

private struct HideNavBar: ViewModifier {
  func body(content: Content) -> some View {
    // `ToolbarPlacement.navigationBar` doesn't exist on macOS — there's no
    // navigation bar to hide there, so this is a no-op.
    #if os(macOS)
    content
    #else
    if #available(iOS 18.0, *) {
      content.toolbarVisibility(.hidden, for: .navigationBar)
    } else {
      // Fallback on earlier versions
      content.navigationBarHidden(true)
    }
    #endif
  }
}

extension View {
  /// Hides the tab bar for as long as this screen is on screen.
  ///
  /// Apply it to a *pushed* screen, not to a tab's root: the visibility belongs
  /// to the view, so the bar comes back on its own when the screen pops. Toggling
  /// a flag on the tab container instead would leave the bar hidden if the user
  /// swiped back mid-gesture and the pop never completed.
  ///
  /// ```swift
  /// var body: some View {
  ///   Content()
  ///     .hideTabBar()
  /// }
  /// ```
  ///
  /// Inert wherever there is no tab bar — macOS, and the iPad/Mac split view
  /// layout, which puts pushed screens in the detail column.
  ///
  /// - Parameter hidden: Pass `false` to keep the bar, for a screen that hides
  ///   it only in some states.
  public func hideTabBar(_ hidden: Bool = true) -> some View {
    modifier(HideTabBar(hidden: hidden))
  }
}

private struct HideTabBar: ViewModifier {
  let hidden: Bool

  func body(content: Content) -> some View {
    // `ToolbarPlacement.tabBar` is unavailable on macOS, where the sidebar
    // stands in for the tab bar and is not the pushed screen's business.
    #if os(macOS)
    content
    #else
    if #available(iOS 18.0, *) {
      content.toolbarVisibility(hidden ? .hidden : .visible, for: .tabBar)
    } else {
      content.toolbar(hidden ? .hidden : .visible, for: .tabBar)
    }
    #endif
  }
}

// MARK: - Glass Effect
extension View {
  public func toolBarButtonCircularGlass() -> some View {
    modifier(ToolBarButtonCircularGlass())
  }
}


private struct ToolBarButtonCircularGlass: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, macOS 26.0, *) {
      content.glassEffect(.clear.interactive(), in: .circle)
    } else {
      content
        .background {
          Circle()
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.1), radius: 0.1, x: 0, y: 0)
        }
    }
  }
}

extension View {
  /// Liquid Glass on iOS/macOS 26+, `.regularMaterial` below, clipped to a capsule.
  ///
  /// - Parameter interactive: Whether the glass reacts to touch on 26+. Has no
  ///   effect on the material fallback, which can't animate under the finger.
  public func capsuleGlass(interactive: Bool = true) -> some View {
    modifier(CapsuleGlass(interactive: interactive))
  }
}

private struct CapsuleGlass: ViewModifier {
  let interactive: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26.0, macOS 26.0, *) {
      content.glassEffect(interactive ? .regular.interactive() : .regular, in: .capsule)
    } else {
      content
        .background {
          Capsule(style: .continuous)
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
        }
    }
  }
}
