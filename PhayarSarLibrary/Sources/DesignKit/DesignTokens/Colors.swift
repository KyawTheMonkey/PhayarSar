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

  // MARK: - Meditation

  /// The field colour behind each meditation style's screen.
  ///
  /// One per style, and `Color.dynamic` rather than fixed — unlike
  /// ``AppColor/Page``, which is paper the reader picked and so must stay the
  /// colour they picked. A style's tint is not a choice, it is the identity of
  /// the object being sat with, and it should follow the appearance like every
  /// other surface in the app.
  ///
  /// Each pair is pale in light and deep in dark so that ``textPrimary`` and
  /// ``textSecondary`` land on it at full contrast. That is the whole reason
  /// these are not saturated brand colours: a mid-tone tint would need an ink
  /// of its own, and then every control drawn over a style screen would need to
  /// know which style it was on.
  public enum Meditation {
    /// Sandalwood smoke — greyed and warm, not orange. The stick's colour, not
    /// the flame's, which is what keeps it apart from ``candle``.
    public static let incense = Color.dynamic(
      light: Palette.MeditationTint.incenseLight,
      dark: Palette.MeditationTint.incenseDark
    )

    /// Candle gold. The warmest and lightest of the set — the one screen that
    /// should look lit.
    public static let candle = Color.dynamic(
      light: Palette.MeditationTint.candleLight,
      dark: Palette.MeditationTint.candleDark
    )
  }

  // MARK: - Beads

  /// A polished, dark bead keeps its material in either appearance. The lifted
  /// rim in dark mode separates the silhouette from the canvas without turning
  /// the whole strand into a light-coloured material.
  public enum Beads {
    public static let core = Color.dynamic(light: Palette.BeadMaterial.coreLight, dark: Palette.BeadMaterial.coreDark)
    public static let warmth = Color.dynamic(light: Palette.BeadMaterial.warmthLight, dark: Palette.BeadMaterial.warmthDark)
    public static let rim = Color.dynamic(light: Palette.BeadMaterial.rimLight, dark: Palette.BeadMaterial.rimDark)
    public static let reflection = Color.dynamic(light: Palette.BeadMaterial.reflectionLight, dark: Palette.BeadMaterial.reflectionDark)
    public static let thread = Color.dynamic(light: Palette.BeadMaterial.threadLight, dark: Palette.BeadMaterial.threadDark)
    public static let shadow = Color.dynamic(light: Palette.BeadMaterial.shadowLight, dark: Palette.BeadMaterial.shadowDark)
  }

  /// The beads session sits on the app's shared background gradient and
  /// follows the chosen theme like any other screen. The beads bring their own
  /// colour; these are only the text and controls around them.
  public enum BeadsSession {
    public static let text = Color.dynamic(light: Palette.BeadSession.textLight, dark: Palette.BeadSession.textDark)
    public static let recitationSheen = Color.dynamic(light: Palette.BeadSession.sheenLight, dark: Palette.BeadSession.sheenDark)
    public static let secondaryText = Color.dynamic(light: Palette.BeadSession.secondaryTextLight, dark: Palette.BeadSession.secondaryTextDark)
    public static let actionSurface = Color.dynamic(light: Palette.BeadSession.actionSurfaceLight, dark: Palette.BeadSession.actionSurfaceDark)
    public static let actionText = Color.dynamic(light: Palette.BeadSession.actionTextLight, dark: Palette.BeadSession.actionTextDark)
    public static let accent = text

    /// SpriteKit keeps shader uniforms alive across theme changes. Supply
    /// concrete colours once per appearance instead of asking dynamic
    /// UIKit/AppKit providers to resolve inside the rendering loop.
    public struct RenderingPalette {
      /// The numeral beside the bead in hand.
      public let numeral: Color
      /// What the beads pick up from the finger they rest on.
      public let skin: Color
    }

    public static func renderingPalette(for scheme: ColorScheme) -> RenderingPalette {
      RenderingPalette(
        numeral: scheme == .dark ? Palette.BeadSession.numeralDark : Palette.BeadSession.numeralLight,
        skin: Palette.BeadSession.skin
      )
    }

    /// One mala's worth of colour. These are what the bead shader works from,
    /// not swatches: a metal's `body` is what it tints a reflection with, a
    /// wood's is its heartwood, and a stone runs from `deep` to `pale` across
    /// its mottling and glows `glow` where light passes through it. A material
    /// is the same object under either theme, so there is one value of each.
    public struct MaterialPalette: Sendable {
      public let body: Color
      public let deep: Color
      public let pale: Color
      public let glow: Color
      public let cord: Color
      public let tassel: Color
      public let binding: Color
    }

    public static let titanium = MaterialPalette(
      body: Palette.BeadMaterials.titanium, deep: Palette.BeadMaterials.titanium, pale: Palette.BeadMaterials.titanium,
      glow: Palette.BeadMaterials.titanium, cord: Palette.BeadMaterials.titaniumCord,
      tassel: Palette.BeadMaterials.titaniumTassel, binding: Palette.BeadMaterials.titaniumBinding)
    public static let gold = MaterialPalette(
      body: Palette.BeadMaterials.gold, deep: Palette.BeadMaterials.gold, pale: Palette.BeadMaterials.gold,
      glow: Palette.BeadMaterials.gold, cord: Palette.BeadMaterials.goldCord,
      tassel: Palette.BeadMaterials.goldTassel, binding: Palette.BeadMaterials.goldBinding)
    public static let sandalwood = MaterialPalette(
      body: Palette.BeadMaterials.sandalwood, deep: Palette.BeadMaterials.sandalwood, pale: Palette.BeadMaterials.sandalwood,
      glow: Palette.BeadMaterials.sandalwood, cord: Palette.BeadMaterials.sandalwoodCord,
      tassel: Palette.BeadMaterials.sandalwoodTassel, binding: Palette.BeadMaterials.sandalwoodBinding)
    public static let bodhi = MaterialPalette(
      body: Palette.BeadMaterials.bodhiPale, deep: Palette.BeadMaterials.bodhiDeep, pale: Palette.BeadMaterials.bodhiPale,
      glow: Palette.BeadMaterials.bodhiPale, cord: Palette.BeadMaterials.bodhiCord,
      tassel: Palette.BeadMaterials.bodhiTassel, binding: Palette.BeadMaterials.bodhiBinding)
    public static let jade = MaterialPalette(
      body: Palette.BeadMaterials.jadePale, deep: Palette.BeadMaterials.jadeDeep, pale: Palette.BeadMaterials.jadePale,
      glow: Palette.BeadMaterials.jadeGlow, cord: Palette.BeadMaterials.jadeCord,
      tassel: Palette.BeadMaterials.jadeTassel, binding: Palette.BeadMaterials.jadeBinding)
    public static let amber = MaterialPalette(
      body: Palette.BeadMaterials.amberPale, deep: Palette.BeadMaterials.amberDeep, pale: Palette.BeadMaterials.amberPale,
      glow: Palette.BeadMaterials.amberGlow, cord: Palette.BeadMaterials.amberCord,
      tassel: Palette.BeadMaterials.amberTassel, binding: Palette.BeadMaterials.amberBinding)
  }

  // MARK: - Particle reveal

  /// The light palette carries colour as ink on a pale card; the dark palette
  /// carries it as light on a dark card. These are transient effect colours,
  /// separate from chart identities and from the final readable text colour.
  public enum ParticleReveal {
    public static let rose = Color.dynamic(
      light: Palette.Reveal.roseLight, dark: Palette.Reveal.roseDark
    )
    public static let violet = Color.dynamic(
      light: Palette.Reveal.violetLight, dark: Palette.Reveal.violetDark
    )
    public static let blue = Color.dynamic(
      light: Palette.Reveal.blueLight, dark: Palette.Reveal.blueDark
    )
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
  enum BeadSession {
    static let textLight = Color(hex: "#242528")
    static let textDark = Color(hex: "#F7F2EC")
    static let sheenLight = Color(hex: "#767577")
    static let sheenDark = Color(hex: "#FFFFFF")
    static let secondaryTextLight = Color(hex: "#686A6E")
    static let secondaryTextDark = Color(hex: "#9E979C")
    static let actionSurfaceLight = Color(hex: "#11161B")
    static let actionSurfaceDark = Color(hex: "#1C1920")
    static let actionTextLight = Color(hex: "#FFFFFF")
    static let actionTextDark = Color(hex: "#FFFFFF")
    static let numeralLight = Color(hex: "#6E4E2C")
    static let numeralDark = Color(hex: "#E6CBA3")
    static let skin = Color(hex: "#E8A484")
  }

  enum BeadMaterials {
    // These feed the bead shader's lighting, which brightens and gamma-encodes
    // them. They are deliberately darker and more saturated than the colour
    // they end up as on screen; do not correct them by eye against a swatch.
    static let titanium = Color(hex: "#A3A6B3")
    static let titaniumCord = Color(hex: "#968C7E")
    static let titaniumTassel = Color(hex: "#BAAE9C")
    static let titaniumBinding = Color(hex: "#D9A65C")
    static let gold = Color(hex: "#FFC257")
    static let goldCord = Color(hex: "#7A2220")
    static let goldTassel = Color(hex: "#9C2624")
    static let goldBinding = Color(hex: "#F6D080")
    static let sandalwood = Color(hex: "#854D29")
    static let sandalwoodCord = Color(hex: "#8C321C")
    static let sandalwoodTassel = Color(hex: "#C8782C")
    static let sandalwoodBinding = Color(hex: "#E4B870")
    static let bodhiDeep = Color(hex: "#0B0201")
    static let bodhiPale = Color(hex: "#660E06")
    static let bodhiCord = Color(hex: "#A01C24")
    static let bodhiTassel = Color(hex: "#B5222B")
    static let bodhiBinding = Color(hex: "#E4B870")
    static let jadeDeep = Color(hex: "#002B17")
    static let jadePale = Color(hex: "#3DA866")
    static let jadeGlow = Color(hex: "#4DF28C")
    static let jadeCord = Color(hex: "#C8A462")
    static let jadeTassel = Color(hex: "#D6B470")
    static let jadeBinding = Color(hex: "#F4D690")
    static let amberDeep = Color(hex: "#4D1200")
    static let amberPale = Color(hex: "#CC660F")
    static let amberGlow = Color(hex: "#FFA829")
    static let amberCord = Color(hex: "#6C201E")
    static let amberTassel = Color(hex: "#8E2824")
    static let amberBinding = Color(hex: "#F4CC7C")
  }

  enum Reveal {
    static let roseLight = Color(hex: "#B13D72")
    static let violetLight = Color(hex: "#7750B7")
    static let blueLight = Color(hex: "#386DB6")
    static let roseDark = Color(hex: "#F19BC5")
    static let violetDark = Color(hex: "#BBACFA")
    static let blueDark = Color(hex: "#92CBFA")
  }

  enum BeadMaterial {
    static let coreLight = Color(hex: "#160F15")
    static let coreDark = Color(hex: "#241923")
    static let warmthLight = Color(hex: "#542C38")
    static let warmthDark = Color(hex: "#744452")
    static let rimLight = Color(hex: "#987583")
    static let rimDark = Color(hex: "#C3A1B1")
    static let reflectionLight = Color(hex: "#FFF3EA")
    static let reflectionDark = Color(hex: "#FFF7F0")
    static let threadLight = Color(hex: "#A28772")
    static let threadDark = Color(hex: "#C7AD94")
    static let shadowLight = Color(hex: "#21151D", alpha: 0.24)
    static let shadowDark = Color(hex: "#080509", alpha: 0.52)
  }

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

  /// The tint behind each meditation style. Separated by hue rather than by
  /// lightness, for the same reason the papers are — two warm creams a shade
  /// apart are one colour on a phone in daylight.
  enum MeditationTint {
    static let incenseLight = Color(hex: "#EFE2D8")
    static let candleLight = Color(hex: "#F8EBC8")

    static let incenseDark = Color(hex: "#2A1F1A")
    static let candleDark = Color(hex: "#2E2614")
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
