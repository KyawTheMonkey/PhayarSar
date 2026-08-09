import Foundation
import SwiftUI
import UtilKit

public enum AppColor {
  // MARK: - Brand

  public static let primary = Color.dynamic(
    light: Palette.Accent.light,
    dark: Palette.Accent.dark
  )

  /// Soft, low-emphasis tint of `primary` — for tinted backgrounds behind
  /// brand-colored content (e.g. secondary buttons, badges, highlights).
  public static let primarySoft = Color.dynamic(
    light: Palette.AccentSoft.light,
    dark: Palette.AccentSoft.dark
  )

  // MARK: - Backgrounds

  public static let background = Color.dynamic(
    light: Palette.Canvas.light,
    dark: Palette.Canvas.dark
  )

  /// Translucent panel color, meant to be layered on top of `background`.
  public static let surface = Color.dynamic(
    light: Palette.Surface.light,
    dark: Palette.Surface.dark
  )

  public static let card = surface

  // MARK: - Text

  public static let textPrimary = Color.dynamic(
    light: Palette.TextColor.primaryLight,
    dark: Palette.TextColor.primaryDark
  )

  public static let textSecondary = Color.dynamic(
    light: Palette.TextColor.secondaryLight,
    dark: Palette.TextColor.secondaryDark
  )

  public static let textTertiary = Color.dynamic(
    light: Palette.TextColor.tertiaryLight,
    dark: Palette.TextColor.tertiaryDark
  )

  public static let textInverse = Color.dynamic(
    light: Color.white,
    dark: Palette.TextColor.primaryLight
  )

  // MARK: - Borders

  public static let border = Color.dynamic(
    light: Palette.Separator.light,
    dark: Palette.Separator.dark
  )

  public static let divider = border

  // MARK: - States

  public static let success = Color.dynamic(
    light: Color.green,
    dark: Color.green.opacity(0.85)
  )

  public static let warning = Color.dynamic(
    light: Color.orange,
    dark: Color.orange.opacity(0.85)
  )

  public static let error = Color.dynamic(
    light: Color.red,
    dark: Color.red.opacity(0.85)
  )

  // MARK: - Buttons

  public static let buttonPrimaryBackground = primary

  public static let buttonPrimaryText = Color.dynamic(
    light: Color.white,
    dark: Color.white
  )

  public static let buttonSecondaryBackground = primarySoft

  public static let buttonSecondaryText = primary

  public static let searchBarBackground = surface
}

/// Primitive values mirror the color sets in `Assets.xcassets`
/// (AccentColor, AccentSoft, Canvas, Separator, Surface, TextPrimary,
/// TextSecondary, TextTertiary) — do not use these directly, go through
/// `AppColor`.
fileprivate enum Palette {
  enum Accent {
    static let light = Color(hex: "#8A2D3B")
    static let dark = Color(hex: "#C4636F")
  }

  enum AccentSoft {
    static let light = Color(hex: "#F1DEE1")
    static let dark = Color(hex: "#3B1E22")
  }

  enum Canvas {
    static let light = Color(hex: "#F8F1EF")
    static let dark = Color(hex: "#1E1516")
  }

  enum Surface {
    static let light = Color.white.opacity(0.55)
    static let dark = Color.white.opacity(0.07)
  }

  enum Separator {
    static let light = Color(hex: "#2A2420", alpha: 0.12)
    static let dark = Color(hex: "#F2EEE8", alpha: 0.14)
  }

  enum TextColor {
    static let primaryLight = Color(hex: "#2A2420")
    static let primaryDark = Color(hex: "#F2EEE8")

    static let secondaryLight = Color(hex: "#6F6660")
    static let secondaryDark = Color(hex: "#B5ACA3")

    static let tertiaryLight = Color(hex: "#9C948C")
    static let tertiaryDark = Color(hex: "#7C736A")
  }
}
