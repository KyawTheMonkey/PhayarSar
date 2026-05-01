import Foundation
import SwiftUI
import UtilKit

public enum AppColor {
  // MARK: - Brand

  public static let primary = Color.dynamic(
    light: Palette.Green.primary,
    dark: Palette.Green.primaryDark
  )
  
  public static let secondary = Color.dynamic(
    light: Palette.Green.secondary,
    dark: Palette.Green.secondaryDark
  )
  
  public static let accent = Color.dynamic(
    light: Palette.Green.tertiary,
    dark: Palette.Green.tertiaryDark
  )
  
  // MARK: - Backgrounds

  public static let background = Color.dynamic(
    light: Palette.Neutral.lighter,
    dark: Palette.Base.whiteDark
  )
  
  public static let surface = Color.dynamic(
    light: Palette.Green.lighterAlt,
    dark: Palette.Green.lighterAltDark
  )
  
  public static let card = Color.dynamic(
    light: Palette.Base.white,
    dark: Palette.Neutral.darkDark
  )
  
  // MARK: - Text

  public static let textPrimary = Color.dynamic(
    light: Palette.Neutral.primary,
    dark: Palette.Neutral.primaryDark
  )
  
  public static let textSecondary = Color.dynamic(
    light: Palette.Neutral.secondary,
    dark: Palette.Neutral.secondaryDark
  )
  
  public static let textInverse = Color.dynamic(
    light: Color.white,
    dark: Palette.Neutral.primary
  )
  
  // MARK: - Borders

  public static let border = Color.dynamic(
    light: Palette.Neutral.quaternary,
    dark: Palette.Neutral.quaternaryDark
  )
  
  public static let divider = Color.dynamic(
    light: Palette.Neutral.light,
    dark: Palette.Neutral.lightDark
  )
  
  // MARK: - States

  public static let success = primary
  
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
  
  public static let buttonSecondaryBackground = Color.dynamic(
    light: Palette.Green.lighter,
    dark: Palette.Green.lightDark
  )
  
  public static let buttonSecondaryText = primary
  
  public static let searchBarBackground = Color.dynamic(
    light: Palette.Neutral.primaryAltDark,
    dark: Color(white: 0.25)
  )
}

fileprivate enum Palette {
  enum Green {
    // Light
    static let primary = Color(hex: "#31663e")
    static let lighterAlt = Color(hex: "#f4f9f5")
    static let lighter = Color(hex: "#d3e7d8")
    static let light = Color(hex: "#b0d1b9")
    static let tertiary = Color(hex: "#70a37d")
    static let secondary = Color(hex: "#41784f")
    static let darkAlt = Color(hex: "#2c5c38")
    static let dark = Color(hex: "#254e2f")
    static let darker = Color(hex: "#1b3923")
    
    // Dark (REAL TOKENS)
    static let primaryDark = Color(hex: "#469158")
    static let lighterAltDark = Color(hex: "#030603")
    static let lighterDark = Color(hex: "#0b170e")
    static let lightDark = Color(hex: "#152c1a")
    static let tertiaryDark = Color(hex: "#6FCF97")
    static let secondaryDark = Color(hex: "#3d804d")
    static let darkAltDark = Color(hex: "#539c64")
    static let darkDark = Color(hex: "#68ac78")
    static let darkerDark = Color(hex: "#89c296")
  }
  
  enum Neutral {
    // Light
    static let lighterAlt = Color(hex: "#f8f2ec")
    static let lighter = Color(hex: "#f4eee8")
    static let light = Color(hex: "#eae4de")
    static let quaternaryAlt = Color(hex: "#dad5cf")
    static let quaternary = Color(hex: "#d0cbc6")
    static let tertiaryAlt = Color(hex: "#c8c3be")
    static let tertiary = Color(hex: "#bab2aa")
    static let secondary = Color(hex: "#a39a91")
    static let primaryAlt = Color(hex: "#8d8379")
    static let primary = Color(hex: "#332d26")
    static let dark = Color(hex: "#60574d")
    
    // Dark
    static let lighterAltDark = Color(hex: "#0f0f0f")
    static let lighterDark = Color(hex: "#0f0f0f")
    static let lightDark = Color(hex: "#0e0e0e")
    static let quaternaryAltDark = Color(hex: "#0d0d0d")
    static let quaternaryDark = Color(hex: "#0c0c0c")
    static let tertiaryAltDark = Color(hex: "#0c0c0c")
    static let tertiaryDark = Color(hex: "#fdfffa")
    static let secondaryDark = Color(hex: "#c9c9c9")
    static let primaryAltDark = Color(hex: "#fdfffc")
    static let primaryDark = Color(hex: "#fcfff7")
    static let darkDark = Color(hex: "#1a1918")
  }
  
  enum Base {
    static let black = Color(hex: "#494139")
    static let white = Color(hex: "#fff9f2")
    
    static let blackDark = Color(hex: "#fffffe")
    static let whiteDark = Color(hex: "#0f0f0f")
  }
}
