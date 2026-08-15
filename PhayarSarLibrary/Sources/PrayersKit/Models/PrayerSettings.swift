import DesignKit
import LocalisationKit
import SwiftUI

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
    alignment: Alignment = .left,
    background: Background = .classic,
    letterSpacing: Double = 2,
    lineSpacing: Double = 15,
    verseSpacing: Double = 10,
    showsPronunciation: Bool = true
  ) {
    self.textSize = textSize
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
  public enum Background: String, CaseIterable, Hashable, Sendable, Codable {
    case classic
    case yellow
    case grey
    case black

    public var displayText: String {
      switch self {
      case .classic:
        return L10n.pageClassic
      case .yellow:
        return L10n.pageYellow
      case .grey:
        return L10n.pageGrey
      case .black:
        return L10n.pageBlack
      }
    }

    public var color: Color {
      switch self {
      case .classic:
        return AppColor.Page.classic
      case .yellow:
        return AppColor.Page.yellow
      case .grey:
        return AppColor.Page.grey
      case .black:
        return AppColor.Page.black
      }
    }

    /// Text colour that stays legible on ``color``.
    public var foreground: Color {
      switch self {
      case .classic, .yellow:
        return AppColor.Page.black
      case .grey, .black:
        return AppColor.Page.classic
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
