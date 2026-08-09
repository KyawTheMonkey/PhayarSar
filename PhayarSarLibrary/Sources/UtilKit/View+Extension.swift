import SwiftUI

extension View {
  public func hideNavBar() -> some View {
    modifier(HideNavBar())
  }
}

private struct HideNavBar: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 18.0, *) {
      content.toolbarVisibility(.hidden, for: .navigationBar)
    } else {
      // Fallback on earlier versions
      content.navigationBarHidden(true)
    }
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
    if #available(iOS 26.0, *) {
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
