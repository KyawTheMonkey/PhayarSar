#if os(iOS)
import UIKit
#endif

/// Whether the reader can offer controls below a top Dynamic Island.
///
/// An unfolded phone can have regular height while the system puts its status
/// area down one side. Neither a phone idiom nor a large safe-area inset means
/// there is a cutout at the top. Ask the attached window about its current
/// traits; a process-wide answer cannot follow folding or a different scene.
public enum AppDynamicIsland {
  #if os(iOS)
  @MainActor
  public static func docks(in window: UIWindow) -> Bool {
    let traits = window.traitCollection
    guard traits.userInterfaceIdiom == .phone,
      traits.horizontalSizeClass == .compact,
      traits.verticalSizeClass == .regular
    else { return false }

    if #available(iOS 27.1, *), traits.verticalBarEdge != .unspecified {
      return false
    }

    // UIKit still has no top-camera capability query. Retain this narrow
    // compatibility heuristic for existing island phones (59/62pt versus the
    // notch's 44–50pt). Only the top edge participates: a side system bar is
    // reserved space, never evidence of a Dynamic Island. Actual layout uses
    // the overlay's live safe area, independently of this capability fallback.
    return window.safeAreaInsets.top >= presenceThreshold
  }

  private static let presenceThreshold: CGFloat = 51
  #endif
}
