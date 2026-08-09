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
  
  // MARK: - Grey
  public static let grey50 = Color.dynamic(
    light: Palette.Grey.grey50Light,
    dark: Palette.Grey.grey50Dark
  )
  
  public static let grey100 = Color.dynamic(
    light: Palette.Grey.grey100Light,
    dark: Palette.Grey.grey100Dark
  )
  
  public static let grey200 = Color.dynamic(
    light: Palette.Grey.grey200Light,
    dark: Palette.Grey.grey200Dark
  )
  
  public static let grey300 = Color.dynamic(
    light: Palette.Grey.grey300Light,
    dark: Palette.Grey.grey300Dark
  )
  
  public static let grey400 = Color.dynamic(
    light: Palette.Grey.grey400Light,
    dark: Palette.Grey.grey400Dark
  )
  
  public static let grey500 = Color.dynamic(
    light: Palette.Grey.grey500Light,
    dark: Palette.Grey.grey500Dark
  )
  
  public static let grey600 = Color.dynamic(
    light: Palette.Grey.grey600Light,
    dark: Palette.Grey.grey600Dark
  )
  
  public static let grey700 = Color.dynamic(
    light: Palette.Grey.grey700Light,
    dark: Palette.Grey.grey700Dark
  )
}

/// Primitive values mirror the color sets in `Assets.xcassets`
/// (AccentColor, AccentSoft, Canvas, Separator, Surface, TextPrimary,
/// TextSecondary, TextTertiary) — do not use these directly, go through
/// `AppColor`.
fileprivate enum Palette {
  enum Grey {
    static let grey50Light = Color(hex: "#FAFAF9")
    static let grey100Light = Color(hex: "#F0EEEB")
    static let grey200Light = Color(hex: "#E2DED9")
    static let grey300Light = Color(hex: "#C7C0B8")
    static let grey400Light = Color(hex: "#9C948C")
    static let grey500Light = Color(hex: "#6F6660")
    static let grey600Light = Color(hex: "#4B443F")
    static let grey700Light = Color(hex: "#2A2420")
    
    static let grey50Dark = Color(hex: "#17110F")
    static let grey100Dark = Color(hex: "#211A17")
    static let grey200Dark = Color(hex: "#332A25")
    static let grey300Dark = Color(hex: "#4E433C")
    static let grey400Dark = Color(hex: "#7C736A")
    static let grey500Dark = Color(hex: "#B5ACA3")
    static let grey600Dark = Color(hex: "#D8D1C9")
    static let grey700Dark = Color(hex: "#F2EEE8")
  }
  
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
    static let light = Color.white
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
