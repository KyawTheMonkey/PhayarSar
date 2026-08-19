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
  
  /// The rule drawn *between* rows inside a card, as opposed to `border`,
  /// which draws the card's own edge.
  ///
  /// Carries more ink than `border` on purpose: an edge is read against the
  /// canvas behind the card, while a divider has to survive on top of
  /// `surface` — at `border`'s weight it all but disappears there, in both
  /// appearances. This lands about where a `List` row separator does.
  public static let divider = Color.dynamic(
    light: Palette.Divider.light,
    dark: Palette.Divider.dark
  )
  
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
  
  // MARK: - Reading page

  /// The paper colours a prayer can be read on — three light, three dark.
  ///
  /// Deliberately *not* `Color.dynamic`: an individual paper is a fixed colour,
  /// and one that changed with the system appearance would be meaningless.
  /// Which of the six is in use follows the appearance, but that is a decision
  /// made a level up, by the theme — see `PrayerTheme`.
  ///
  /// The three in each set are separated by **hue**, not just by lightness.
  /// Three warm off-whites at slightly different brightnesses are three papers
  /// nobody can tell apart on a phone in daylight, which is what the earlier
  /// four-colour set amounted to once two themes had to share.
  public enum Page {
    /// Warm near-white. The default, and the brightest of the three.
    public static let classic = Palette.PageColor.classic

    /// Amber cream — the sepia page. Clearly deeper and more saturated than
    /// ``classic`` rather than a shade off it.
    public static let parchment = Palette.PageColor.parchment

    /// Cool grey-green — a soft sage. The only light paper with no warmth in it,
    /// and the darkest of the three. Both are needed: at a lighter tint it read
    /// as another off-white beside ``classic`` rather than as its own stock.
    public static let paper = Palette.PageColor.paper

    /// Deep blue-black. Reads as night rather than as a dimmed page.
    public static let midnight = Palette.PageColor.midnight

    /// Warm near-black, the darkest end of the app's own grey ramp.
    public static let charcoal = Palette.PageColor.charcoal

    /// True black, for OLED and for anyone who wants the page to disappear.
    public static let ink = Palette.PageColor.ink

    /// The ink each paper carries.
    ///
    /// Paired rather than shared: pure black on cream is harsher than the paper
    /// deserves, and pure white on true black blooms. Each of these is pulled a
    /// little way toward its own paper, and each clears 10:1 against it.
    public enum Ink {
      public static let classic = Palette.PageInk.classic
      public static let parchment = Palette.PageInk.parchment
      public static let paper = Palette.PageInk.paper
      public static let midnight = Palette.PageInk.midnight
      public static let charcoal = Palette.PageInk.charcoal
      public static let ink = Palette.PageInk.ink
    }
  }

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
  /// Fixed paper colours — see `AppColor.Page` for why these have no light/dark
  /// pair, and for why the three in each set differ in hue rather than only in
  /// brightness.
  enum PageColor {
    static let classic = Color(hex: "#FFFAF3")
    static let parchment = Color(hex: "#F0E1BE")
    static let paper = Color(hex: "#F5F5F5")

    static let midnight = Color(hex: "#141922")
    static let charcoal = Color(hex: "#2B2725")
    static let ink = Color(hex: "#000000")
  }

  /// The ink for each paper above, in the same order.
  enum PageInk {
    static let classic = Color(hex: "#22201D")
    static let parchment = Color(hex: "#2E2517")
    static let paper = Color(hex: "#1E2320")

    static let midnight = Color(hex: "#E4EAF4")
    static let charcoal = Color(hex: "#F0EAE2")
    static let ink = Color(hex: "#E6E6E6")
  }

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

  enum Divider {
    static let light = Color(hex: "#2A2420", alpha: 0.22)
    static let dark = Color(hex: "#F2EEE8", alpha: 0.20)
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
