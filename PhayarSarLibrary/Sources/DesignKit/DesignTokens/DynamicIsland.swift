#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

/// Whether the reader can offer controls below the phone's Dynamic Island.
///
/// UIKit exposes the safe area, not the hardware cutout's frame. The two must
/// not be confused: phones can reserve similar safe areas around different
/// pills. Chrome should use its scene's safe area for placement and disappear
/// at its animation origin, rather than draw a guessed outline over the camera.
public enum AppDynamicIsland {

  // MARK: - Presence

  /// Whether this device has a Dynamic Island at all.
  ///
  /// Decided from the safe area rather than from the model identifier, which
  /// would be a list to maintain forever and would answer `false` for every
  /// iPhone Apple has not shipped yet.
  ///
  /// The threshold is the gap between two clusters that do not overlap and have
  /// not moved in four years: the notch reserves 44 to 50 points, and the island
  /// reserves 59 or 62. Anything at 51 or above has an island.
  ///
  /// The *largest* inset rather than the top one, because the reserved edge
  /// moves to the side in landscape and the top inset there is zero — this
  /// answers a question about the device, not about how it is being held. Where
  /// the chrome is allowed to dock is a separate question; see
  /// ``docks(verticalSizeClass:)``.
  @MainActor
  public static var isPresent: Bool {
    #if canImport(UIKit) && !os(watchOS)
    guard UIDevice.current.userInterfaceIdiom == .phone else { return false }

    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }

    guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else {
      return false
    }

    let insets = window.safeAreaInsets
    return max(insets.top, max(insets.left, insets.right)) >= presenceThreshold
    #else
    return false
    #endif
  }

  /// Between the deepest notch and the shallowest island. See ``isPresent``.
  private static let presenceThreshold: CGFloat = 51

  /// Whether chrome should dock to the cutout right now.
  ///
  /// Presence is about the device; this is about the moment. The island is only
  /// at the top of the screen while the phone is upright — held on its side the
  /// cutout becomes a bar down one edge, and a control drawn at the top of the
  /// screen would be floating in the middle of nothing.
  ///
  /// The size class is the whole test, and on a phone it is exact: every iPhone
  /// reports a compact height in landscape and a regular one in portrait,
  /// whatever its size. Measuring the layout instead would say the same thing
  /// less reliably and would need a `GeometryReader` around chrome that does not
  /// otherwise want one.
  ///
  /// iOS only, because `UserInterfaceSizeClass` is — and because the only
  /// hardware this question can be asked about is an iPhone.
  #if canImport(UIKit) && !os(watchOS)
  @MainActor
  public static func docks(verticalSizeClass: UserInterfaceSizeClass?) -> Bool {
    isPresent && verticalSizeClass != .compact
  }
  #endif
}
