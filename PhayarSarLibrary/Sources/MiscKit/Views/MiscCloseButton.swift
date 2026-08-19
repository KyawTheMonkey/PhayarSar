import DesignKit
import EnvironmentKit
import SwiftUI

/// The circular dismiss button in the corner of a screen the user is allowed to
/// leave.
///
/// Only the screens that *can* be dismissed have one — the announcement and
/// what's-new screens. A force-update screen with no `onLater` deliberately has
/// no way out, and adding a close button "just in case" would undo that.
///
/// Matches the toolbar buttons elsewhere in the app via
/// ``SwiftUI/View/toolBarButtonCircularGlass()``, so it reads as the same
/// control the user already knows rather than as this screen's own invention.
struct MiscCloseButton: View {
  private let action: () -> Void

  init(action: @escaping () -> Void) {
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(AppFont.bodySemibold)
        .foregroundStyle(AppColor.textSecondary)
        .frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
        // The glyph is small and the glass behind it is not a hit region, so
        // without this only the strokes themselves are tappable.
        .contentShape(Circle())
    }
    .buttonStyle(PressableButtonStyle())
    .toolBarButtonCircularGlass()
    .accessibilityLabel(L10n.close)
  }

  // MARK: - Metrics

  private enum Metrics {
    /// Apple's minimum. The glyph is far smaller; the frame is what makes it
    /// hittable.
    static let tapTarget: CGFloat = 44
  }
}
