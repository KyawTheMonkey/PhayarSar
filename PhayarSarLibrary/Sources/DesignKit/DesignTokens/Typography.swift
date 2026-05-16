import SwiftUI

public enum Typography {
  public static func registerFonts() {
    AppFonts.allCases.forEach {
      registerFont(bundle: .module, fontName: $0.rawValue, fontExtension: "ttf")
    }
  }
  
  fileprivate static func registerFont(bundle: Bundle, fontName: String, fontExtension: String) {
    guard let fontURL = bundle.url(forResource: fontName, withExtension: fontExtension),
          let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
          let _ = CGFont(fontDataProvider)
    else {
      fatalError("Couldn't create font from data")
    }
    
    let success = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    if !success {
      debugPrint("Failed to register font: \(fontName).ttf")
    }
  }
}

public enum AppFont {
  
  // MARK: - Display (Serif)
  public static let largeTitle = Font.custom(
    AppFonts.dmSerifDisplayRegular.rawValue,
    size: 34,
    relativeTo: .largeTitle
  )
  
  public static let title = Font.custom(
    AppFonts.dmSerifDisplayRegular.rawValue,
    size: 28,
    relativeTo: .title
  )
  
  public static let title2 = Font.custom(
    AppFonts.dmSerifDisplayRegular.rawValue,
    size: 24,
    relativeTo: .title
  )
  
  public static let title3 = Font.custom(
    AppFonts.dmSerifDisplayRegular.rawValue,
    size: 20,
    relativeTo: .title
  )
  
  // MARK: - Body (Quicksand)
  public static let body = Font.custom(
    AppFonts.quicksandRegular.rawValue,
    size: 17,
    relativeTo: .body
  )
  
  public static let bodySemibold = Font.custom(
    AppFonts.quicksandSemiBold.rawValue,
    size: 17,
    relativeTo: .body
  )
  
  public static let headline = Font.custom(
    AppFonts.quicksandSemiBold.rawValue,
    size: 17,
    relativeTo: .headline
  )
  
  public static let subheadline = Font.custom(
    AppFonts.quicksandRegular.rawValue,
    size: 15,
    relativeTo: .subheadline
  )
  
  public static let caption = Font.custom(
    AppFonts.quicksandRegular.rawValue,
    size: 13,
    relativeTo: .caption
  )
  
  public static let captionBold = Font.custom(
    AppFonts.quicksandBold.rawValue,
    size: 13,
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

fileprivate enum AppFonts: String, CaseIterable {
  case dmSerifDisplayRegular = "DMSerifDisplay-Regular"
  case quicksandRegular = "Quicksand-Regular"
  case quicksandSemiBold = "Quicksand-SemiBold"
  case quicksandBold = "Quicksand-Bold"
  case jasmineUnicode = "Jasmine_Unicode"
  case pangLong = "PangLong"
  case myanmarSquare = "MyanmarSquare"
  case yoeYarOne = "YoeYar-One"
}
