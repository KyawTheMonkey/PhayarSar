import DesignKit
import LocalisationKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// How one prayer is laid out on the reading screen.
///
/// A value type, and per-prayer rather than global: someone reading ပဋ္ဌာန်းအကျယ်
/// at a large size on a black page may still want ငါးပါးသီလ small and classic.
///
/// Nothing persists these yet — every prayer reads back ``standard`` until a
/// store is wired up behind ``settings(for:)``.
public struct PrayerSettings: Hashable, Sendable {
  /// Point size of the recited text.
  public var textSize: Int
  /// The Burmese face the recited text is set in.
  public var font: Face
  public var alignment: Alignment
  public var background: Background
  /// Extra tracking between characters.
  public var letterSpacing: Double
  /// Extra leading between the lines within one verse.
  public var lineSpacing: Double
  /// Gap between one verse and the next. Separate from ``lineSpacing`` so the
  /// break between verses can be read at a glance without loosening the verse
  /// itself.
  public var verseSpacing: Double
  /// Whether the Burmese phonetic respelling shows under each verse. Several
  /// prayers ship an empty `pronunciation`, so this being `true` does not mean
  /// there is anything to show — see ``Prayer/Verse/pronunciation``.
  public var showsPronunciation: Bool

  public init(
    textSize: Int = 28,
    font: Face = .jasmine,
    alignment: Alignment = .left,
    background: Background = .classic,
    letterSpacing: Double = 2,
    lineSpacing: Double = 15,
    verseSpacing: Double = 10,
    showsPronunciation: Bool = true
  ) {
    self.textSize = textSize
    self.font = font
    self.alignment = alignment
    self.background = background
    self.letterSpacing = letterSpacing
    self.lineSpacing = lineSpacing
    self.verseSpacing = verseSpacing
    self.showsPronunciation = showsPronunciation
  }

  /// What a prayer opens with before the reader has changed anything.
  public static let standard = PrayerSettings()
}

// MARK: - Face

extension PrayerSettings {
  /// The Burmese face a prayer is set in.
  ///
  /// All four ship with the app and are registered at launch by
  /// `Typography.registerFonts()`, so any of them can be asked for at any time
  /// without a load. The Latin faces in `AppFont` are deliberately absent: this
  /// is the setting for the *recited* text, which is always Burmese, and none of
  /// Lora or Inter can draw it.
  public enum Face: String, CaseIterable, Hashable, Sendable, Codable {
    case jasmine
    case panglong
    case square
    case yoeYar

    public var displayText: String {
      switch self {
      case .jasmine:
        return L10n.fontJasmine
      case .panglong:
        return L10n.fontPanglong
      case .square:
        return L10n.fontSquare
      case .yoeYar:
        return L10n.fontYoeYar
      }
    }

    /// The face at a given point size, tracking Dynamic Type from there.
    ///
    /// Takes a size rather than reading ``PrayerSettings/textSize`` itself, so
    /// the same face can be drawn small for a picker row and large for the page.
    public func font(size: CGFloat) -> Font {
      switch self {
      case .jasmine:
        return AppFont.jasmine(size: size)
      case .panglong:
        return AppFont.panlong(size: size)
      case .square:
        return AppFont.mSquare(size: size)
      case .yoeYar:
        return AppFont.yoeYar(size: size)
      }
    }

    #if canImport(UIKit)
    /// The UIKit counterpart of ``font(size:)``, for the reader — which draws
    /// its page with `NSAttributedString` and cannot take a SwiftUI `Font`.
    public func uiFont(size: CGFloat) -> UIFont {
      switch self {
      case .jasmine:
        return AppUIFont.jasmine(size: size)
      case .panglong:
        return AppUIFont.panlong(size: size)
      case .square:
        return AppUIFont.mSquare(size: size)
      case .yoeYar:
        return AppUIFont.yoeYar(size: size)
      }
    }
    #endif
  }
}

// MARK: - Alignment

extension PrayerSettings {
  public enum Alignment: String, CaseIterable, Hashable, Sendable, Codable {
    case left
    case center
    case right

    public var displayText: String {
      switch self {
      case .left:
        return L10n.alignLeft
      case .center:
        return L10n.alignCenter
      case .right:
        return L10n.alignRight
      }
    }

    /// Shows the setting rather than just naming it, so the row reads at a
    /// glance.
    public var systemImage: String {
      switch self {
      case .left:
        return "text.alignleft"
      case .center:
        return "text.aligncenter"
      case .right:
        return "text.alignright"
      }
    }

    public var textAlignment: TextAlignment {
      switch self {
      case .left:
        return .leading
      case .center:
        return .center
      case .right:
        return .trailing
      }
    }
  }
}

// MARK: - Background

extension PrayerSettings {
  /// The paper a prayer is read on.
  ///
  /// Six of them, three light and three dark, paired into themes by
  /// `PrayerTheme`. Nothing here knows about that pairing — a paper is just a
  /// colour and the ink that goes on it.
  public enum Background: String, CaseIterable, Hashable, Sendable, Codable {
    case classic
    case parchment
    case paper

    case midnight
    case charcoal
    case ink

    public var displayText: String {
      switch self {
      case .classic:
        return L10n.pageClassic
      case .parchment:
        return L10n.pageParchment
      case .paper:
        return L10n.pagePaper
      case .midnight:
        return L10n.pageMidnight
      case .charcoal:
        return L10n.pageCharcoal
      case .ink:
        return L10n.pageInk
      }
    }

    public var color: Color {
      switch self {
      case .classic:
        return AppColor.Page.classic
      case .parchment:
        return AppColor.Page.parchment
      case .paper:
        return AppColor.Page.paper
      case .midnight:
        return AppColor.Page.midnight
      case .charcoal:
        return AppColor.Page.charcoal
      case .ink:
        return AppColor.Page.ink
      }
    }

    /// Text colour that stays legible on ``color``.
    ///
    /// One ink per paper rather than one shared by all the light pages and one
    /// by all the dark: pure black on cream is harsher than the paper deserves,
    /// and pure white on true black blooms.
    public var foreground: Color {
      switch self {
      case .classic:
        return AppColor.Page.Ink.classic
      case .parchment:
        return AppColor.Page.Ink.parchment
      case .paper:
        return AppColor.Page.Ink.paper
      case .midnight:
        return AppColor.Page.Ink.midnight
      case .charcoal:
        return AppColor.Page.Ink.charcoal
      case .ink:
        return AppColor.Page.Ink.ink
      }
    }
  }
}

// MARK: - Lookup

extension PrayerSettings {
  /// The settings a prayer is currently read with.
  ///
  /// A stub: it returns ``standard`` for every prayer. It exists so the screens
  /// that show or edit these settings can be built against their real call
  /// site, and so wiring up a store later is a change in one place rather than
  /// in every view that reads a setting.
  ///
  /// - Parameter prayerID: ``Prayer/id``, the same key the rest of the app
  ///   stores per-prayer state against.
  public static func settings(for prayerID: Prayer.ID) -> PrayerSettings {
    _ = prayerID
    return .standard
  }
}
