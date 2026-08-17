import SwiftUI
import UtilKit

/// Colours that carry identity in a chart — one hue per category.
///
/// Separate from ``AppColor`` because these answer a different question. The
/// palette there is about hierarchy: brand, surface, text, and the four status
/// colours. These are about telling one *thing* from another, and the only
/// property that matters is that no two are confusable — including for a reader
/// with colour-vision deficiency, on either appearance.
///
/// ## Rules
///
/// - **Fixed order, never cycled.** ``at(_:)`` hands out slot 0, then 1, then 2,
///   then 3, and everything past that gets ``other``. A ninth hue invented on the
///   fly would collide with one already in use, and a palette that wraps means
///   two categories share a colour in the one chart wide enough to show both.
/// - **Colour follows the thing, not its rank.** Assign a slot from something
///   stable about the category — its entity name, not its position in a sorted
///   list — or a filter that reorders the chart will repaint everything.
/// - **Never the status colours.** ``AppColor/success`` and friends mean
///   good/warning/bad. Reusing that green as "category 3" is how a chart ends up
///   implying one of its categories is the healthy one.
/// - **Text keeps text colours.** A label next to a coloured swatch is
///   ``AppColor/textPrimary``, not the series hue — coloured text at caption size
///   fails contrast, and the swatch already carries the identity.
///
/// ## Provenance
///
/// Both sets were checked rather than chosen by eye, against the surfaces they
/// actually sit on — white cards in light, and the ~`#2E2526` a translucent card
/// resolves to over the dark canvas. Every slot clears the lightness band, the
/// chroma floor (nothing that reads as grey), and 3:1 against its surface; every
/// *pair* clears the normal-vision and colour-blind separation floors, with one
/// exception: on dark, cyan against maroon comes in at ΔE 7.4 under protanopia,
/// inside the band that is permissible only alongside a second cue. That is why
/// ``AppProportionBar`` is always accompanied by a legend naming each segment
/// with its value, and why the segments are separated by visible gaps — the
/// colour is never the only thing distinguishing them.
public enum AppChartColor {
  /// The categorical hues, in the order they are handed out.
  ///
  /// Four rather than more on purpose: past four, the pairs stop clearing the
  /// separation floors on a dark surface, and a fifth hue that a colour-blind
  /// reader cannot separate from the third is worse than an honest "Other".
  public static let categorical: [Color] = [
    Color.dynamic(light: ChartPalette.maroonLight, dark: ChartPalette.maroonDark),
    Color.dynamic(light: ChartPalette.ochreLight, dark: ChartPalette.ochreDark),
    Color.dynamic(light: ChartPalette.cyanLight, dark: ChartPalette.cyanDark),
    Color.dynamic(light: ChartPalette.violetLight, dark: ChartPalette.violetDark),
  ]

  /// Everything past the fourth category, and anything deliberately grouped as a
  /// remainder. Neutral so that "Other" does not read as a category of its own.
  public static let other = Color.dynamic(
    light: ChartPalette.otherLight,
    dark: ChartPalette.otherDark
  )

  /// The hue for slot `index`, or ``other`` once the slots run out.
  public static func at(_ index: Int) -> Color {
    guard index >= 0, index < categorical.count else { return other }
    return categorical[index]
  }
}

/// Raw values. Do not reach for these directly — go through ``AppChartColor``,
/// which is where the ordering rule lives.
private enum ChartPalette {
  // Light steps, validated against a white card.
  static let maroonLight = Color(hex: "#8A2D3B")
  static let ochreLight = Color(hex: "#B07A22")
  static let cyanLight = Color(hex: "#0286A6")
  static let violetLight = Color(hex: "#6C3FA0")

  // Dark steps. Chosen for the dark surface rather than lightened from the
  // light ones — a flipped palette lands outside the lightness band and
  // collapses the cyan/violet pair under deuteranopia.
  static let maroonDark = Color(hex: "#D2727E")
  static let ochreDark = Color(hex: "#AE8C24")
  static let cyanDark = Color(hex: "#0A7C9C")
  static let violetDark = Color(hex: "#9C83D8")

  static let otherLight = Color(hex: "#9C948C")
  static let otherDark = Color(hex: "#7C736A")
}
