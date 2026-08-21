#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

/// What the hardware cutout at the top of the screen is, and where it is.
///
/// The Dynamic Island is not something UIKit will tell you about. There is no
/// trait for it, no property on `UIScreen`, and no supported way to ask for the
/// cutout's frame — so this is measurement and arithmetic rather than a query,
/// and it is kept in one place so that every guess the app makes about the
/// island is the same guess.
///
/// Chrome that docks to the cutout lives in `HomeKit`; this only says whether
/// there is a cutout to dock to and what shape it is.
public enum AppDynamicIsland {

  // MARK: - Geometry

  /// The cutout itself, in points, and the same on every iPhone that has one —
  /// the 14 Pro pair, every 15 and 16 but the 16e, and the 17s after them. Apple
  /// has changed the safe area around it between generations and has not once
  /// changed the pill.
  ///
  /// Measured rather than read: see the type's own note. A control drawn to
  /// these numbers meets the hardware exactly, and a control drawn a point
  /// short of them shows a seam of screen between itself and the black.
  public static let cutoutSize = CGSize(width: 126, height: 37.33)

  /// How far the cutout's top edge sits below the top of the screen.
  public static let cutoutTop: CGFloat = 11

  /// The corner the cutout is drawn with, which is simply half its height — the
  /// island is a capsule. Chrome that continues it has to use the same radius or
  /// the join reads as two objects.
  public static var cutoutRadius: CGFloat { cutoutSize.height / 2 }

  /// The bottom edge of the cutout, which is where anything hanging below it
  /// starts.
  public static var cutoutBottom: CGFloat { cutoutTop + cutoutSize.height }

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
  /// cutout becomes a bar down one edge, and a control drawn to ``cutoutTop``
  /// and ``cutoutSize`` would be floating in the middle of nothing.
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
