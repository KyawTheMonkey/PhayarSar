import SwiftUI

extension View {
  /// Applies the same size-class-aware horizontal inset that `AppListSection`
  /// uses — 16pt in compact width, 20pt in regular.
  ///
  /// Use it on bare controls that share a screen with `AppListSection` so their
  /// edges line up. A plain `.padding(.horizontal)` matches only in compact
  /// width, and drifts 4pt wider on iPad and Mac.
  public func appHorizontalInset() -> some View {
    modifier(AppHorizontalInset())
  }
}

private struct AppHorizontalInset: ViewModifier {
  // `horizontalSizeClass` is UIKit-only; macOS is always regular width here.
  #if os(macOS)
  private var inset: CGFloat {
    AppListSectionMetrics.regularHorizontalInset
  }
  #else
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var inset: CGFloat {
    horizontalSizeClass == .regular
      ? AppListSectionMetrics.regularHorizontalInset
      : AppListSectionMetrics.compactHorizontalInset
  }
  #endif

  func body(content: Content) -> some View {
    content.padding(.horizontal, inset)
  }
}
