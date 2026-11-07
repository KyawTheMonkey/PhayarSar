import DesignKit
import LocalisationKit
import SwiftUI

/// The kinds of sitting the app offers.
///
/// An enum rather than a bundled catalog like `PrayersKit`'s prayers, and the
/// difference is what each one *is*. A prayer is data — text the app renders
/// through one reader — so a new prayer is a new JSON file. A meditation style
/// is a screen: the incense stick burns down, the candle gutters, and whatever
/// comes next will want its own artwork, its own timing and its own controls.
/// None of that can be described in JSON, so a case that has to be handled is
/// worth more here than a row that can be added without one — adding a style
/// should fail to build until its screen exists.
///
/// `CaseIterable` in declaration order, which is the order the collection view
/// pages through. Reordering the cases reorders the sheet.
public enum MeditationStyle: String, CaseIterable, Identifiable, Hashable, Sendable {
  case incenseStick
  case candleStick

  public var id: String { rawValue }

  /// Already localised.
  public var title: String {
    switch self {
    case .incenseStick:
      return L10n.meditationStyleIncenseStick
    case .candleStick:
      return L10n.meditationStyleCandleStick
    }
  }

  /// One line on what sitting with this object is like. Already localised.
  public var summary: String {
    switch self {
    case .incenseStick:
      return L10n.meditationStyleIncenseStickSummary
    case .candleStick:
      return L10n.meditationStyleCandleStickSummary
    }
  }

  /// Stands in until each style has its own artwork. SF Symbols has no incense
  /// stick, so the two are told apart by their smoke and their flame rather
  /// than by their body — which is the honest way round for placeholders, since
  /// the artwork is what will actually distinguish them.
  public var systemImage: String {
    switch self {
    case .incenseStick:
      return "smoke"
    case .candleStick:
      return "flame"
    }
  }

  /// The field colour behind the whole screen.
  public var tint: Color {
    switch self {
    case .incenseStick:
      return AppColor.Meditation.incense
    case .candleStick:
      return AppColor.Meditation.candle
    }
  }
}
