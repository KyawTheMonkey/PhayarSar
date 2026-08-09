import SwiftUI

public enum Typography {
  public static func registerFonts() {
    for item in AppFonts.allCases {
      registerFont(bundle: .module, fontName: item.rawValue, fontExtension: "ttf")
    }
  }
  
  fileprivate static func registerFont(bundle: Bundle, fontName: String, fontExtension: String) {
    guard let fontURL = bundle.url(forResource: fontName, withExtension: fontExtension) else {
      return
    }
    guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
          CGFont(fontDataProvider) != nil
    else {
      return
    }

    let success = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    if !success {
      debugPrint("Failed to register font: \(fontName).ttf")
    }
  }
}

// MARK: - Type scale, matches Design Tokens page (Lora display / Inter UI+body)

public enum AppFont {
  // MARK: - Display (Lora) — screen titles, prayer/section headers
  
  /// Lora 700 · 34pt — app name, large screen titles
  public static let largeTitle = Font.custom(
    AppFonts.loraBold.rawValue,
    size: 34,
    relativeTo: .largeTitle
  )
  
  /// Lora 600 · 22pt — section/card titles
  public static let title = Font.custom(
    AppFonts.loraSemiBold.rawValue,
    size: 22,
    relativeTo: .title
  )
  
  /// Lora 600 · 17pt — prayer/audio list item titles
  public static let listItemTitle = Font.custom(
    AppFonts.loraSemiBold.rawValue,
    size: 17,
    relativeTo: .headline
  )
  
  // MARK: - Body & UI (Inter)
  
  /// Inter 400 · 17pt — reading/body copy
  public static let body = Font.custom(
    AppFonts.interRegular.rawValue,
    size: 17,
    relativeTo: .body
  )
  
  public static let bodySemibold = Font.custom(
    AppFonts.interSemiBold.rawValue,
    size: 17,
    relativeTo: .body
  )
  
  public static let headline = Font.custom(
    AppFonts.interSemiBold.rawValue,
    size: 17,
    relativeTo: .headline
  )
  
  public static let subheadline = Font.custom(
    AppFonts.interRegular.rawValue,
    size: 15,
    relativeTo: .subheadline
  )
  
  /// Inter 600 · 15pt — button/control labels
  public static let button = Font.custom(
    AppFonts.interSemiBold.rawValue,
    size: 15,
    relativeTo: .subheadline
  )
  
  public static let caption = Font.custom(
    AppFonts.interRegular.rawValue,
    size: 13,
    relativeTo: .caption
  )
  
  public static let captionBold = Font.custom(
    AppFonts.interBold.rawValue,
    size: 13,
    relativeTo: .caption
  )
  
  /// Inter 600 · 12pt, uppercase — section labels/captions
  public static let sectionLabel = Font.custom(
    AppFonts.interSemiBold.rawValue,
    size: 12,
    relativeTo: .caption
  )
  
  // MARK: - Special (Myanmar)
  
  public static func jasmine(relativeTo style: Font.TextStyle = .body) -> Font {
    Font.custom(AppFonts.jasmineUnicode.rawValue, size: 17, relativeTo: style)
  }
  
  public static func panlong(relativeTo style: Font.TextStyle = .body) -> Font {
    Font.custom(AppFonts.pangLong.rawValue, size: 17, relativeTo: style)
  }
  
  public static func mSquare(relativeTo style: Font.TextStyle = .body) -> Font {
    Font.custom(AppFonts.myanmarSquare.rawValue, size: 17, relativeTo: style)
  }
  
  public static func yoeYar(relativeTo style: Font.TextStyle = .body) -> Font {
    Font.custom(AppFonts.yoeYarOne.rawValue, size: 17, relativeTo: style)
  }
}

private enum AppFonts: String, CaseIterable {
  case loraSemiBold = "Lora-SemiBold"
  case loraBold = "Lora-Bold"
  case interRegular = "Inter-Regular"
  case interSemiBold = "Inter-SemiBold"
  case interBold = "Inter-Bold"
  case jasmineUnicode = "Jasmine_Unicode"
  case pangLong = "PangLong"
  case myanmarSquare = "MyanmarSquare"
  case yoeYarOne = "YoeYar-One"
}

// MARK: - UIKit bridge, same type scale as `AppFont` for call sites that
// can't use SwiftUI's `Font` (UIKit view controllers, UIAppearance proxies,
// attributed strings, etc).

#if canImport(UIKit)
import UIKit

public enum AppUIFont {
  // MARK: - Display (Lora) — screen titles, prayer/section headers

  /// Lora 700 · 34pt — app name, large screen titles
  public static var largeTitle: UIFont {
    scaledFont(AppFonts.loraBold.rawValue, size: 34, relativeTo: .largeTitle)
  }

  /// Lora 600 · 22pt — section/card titles
  public static var title: UIFont {
    scaledFont(AppFonts.loraSemiBold.rawValue, size: 22, relativeTo: .title1)
  }

  /// Lora 600 · 17pt — prayer/audio list item titles
  public static var listItemTitle: UIFont {
    scaledFont(AppFonts.loraSemiBold.rawValue, size: 17, relativeTo: .headline)
  }

  // MARK: - Body & UI (Inter)

  /// Inter 400 · 17pt — reading/body copy
  public static var body: UIFont {
    scaledFont(AppFonts.interRegular.rawValue, size: 17, relativeTo: .body)
  }

  public static var bodySemibold: UIFont {
    scaledFont(AppFonts.interSemiBold.rawValue, size: 17, relativeTo: .body)
  }

  public static var headline: UIFont {
    scaledFont(AppFonts.interSemiBold.rawValue, size: 17, relativeTo: .headline)
  }

  public static var subheadline: UIFont {
    scaledFont(AppFonts.interRegular.rawValue, size: 15, relativeTo: .subheadline)
  }

  /// Inter 600 · 15pt — button/control labels
  public static var button: UIFont {
    scaledFont(AppFonts.interSemiBold.rawValue, size: 15, relativeTo: .subheadline)
  }

  public static var caption: UIFont {
    scaledFont(AppFonts.interRegular.rawValue, size: 13, relativeTo: .caption1)
  }

  public static var captionBold: UIFont {
    scaledFont(AppFonts.interBold.rawValue, size: 13, relativeTo: .caption1)
  }

  /// Inter 600 · 12pt, uppercase — section labels/captions
  public static var sectionLabel: UIFont {
    scaledFont(AppFonts.interSemiBold.rawValue, size: 12, relativeTo: .caption1)
  }

  // MARK: - Special (Myanmar)

  public static func jasmine(relativeTo style: UIFont.TextStyle = .body) -> UIFont {
    scaledFont(AppFonts.jasmineUnicode.rawValue, size: 17, relativeTo: style)
  }

  public static func panlong(relativeTo style: UIFont.TextStyle = .body) -> UIFont {
    scaledFont(AppFonts.pangLong.rawValue, size: 17, relativeTo: style)
  }

  public static func mSquare(relativeTo style: UIFont.TextStyle = .body) -> UIFont {
    scaledFont(AppFonts.myanmarSquare.rawValue, size: 17, relativeTo: style)
  }

  public static func yoeYar(relativeTo style: UIFont.TextStyle = .body) -> UIFont {
    scaledFont(AppFonts.yoeYarOne.rawValue, size: 17, relativeTo: style)
  }

  /// Falls back to the system font at the same size if the custom font
  /// isn't registered (see `Typography.registerFonts()`), then scales it
  /// for Dynamic Type against `style` — mirrors `Font.custom(_:size:relativeTo:)`.
  private static func scaledFont(_ name: String, size: CGFloat, relativeTo style: UIFont.TextStyle) -> UIFont {
    let baseFont = UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
    return UIFontMetrics(forTextStyle: style).scaledFont(for: baseFont)
  }
}
#endif
