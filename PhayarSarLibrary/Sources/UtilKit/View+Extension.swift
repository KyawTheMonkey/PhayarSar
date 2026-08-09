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
