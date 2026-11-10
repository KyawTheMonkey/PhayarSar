import DesignKit
import Foundation
import LocalisationKit

/// What the mala is made of. Every material is rendered by the same shader
/// from a handful of numbers, so adding one is a palette and a case here, not
/// new drawing code. The choice belongs to the person, not to a bead set: a
/// mala is a thing you own and keep using.
enum BeadsMaterial: String, CaseIterable, Identifiable, Sendable {
  case titanium, gold, sandalwood, bodhi, jade, amber

  /// How light meets the bead: mirrored, scattered across a grain, let
  /// through, or caught in the furrows of a dried seed. The raw value is what the shader branches on.
  enum Surface: Float { case metal = 0, wood = 1, stone = 2, seed = 3 }

  var id: String { rawValue }

  var title: String {
    switch self {
    case .titanium: L10n.beadsMaterialTitanium
    case .gold: L10n.beadsMaterialGold
    case .sandalwood: L10n.beadsMaterialSandalwood
    case .bodhi: L10n.beadsMaterialBodhi
    case .jade: L10n.beadsMaterialJade
    case .amber: L10n.beadsMaterialAmber
    }
  }

  var surface: Surface {
    switch self {
    case .titanium, .gold: .metal
    case .sandalwood: .wood
    case .bodhi: .seed
    case .jade, .amber: .stone
    }
  }

  var palette: AppColor.BeadsSession.MaterialPalette {
    switch self {
    case .titanium: AppColor.BeadsSession.titanium
    case .gold: AppColor.BeadsSession.gold
    case .sandalwood: AppColor.BeadsSession.sandalwood
    case .bodhi: AppColor.BeadsSession.bodhi
    case .jade: AppColor.BeadsSession.jade
    case .amber: AppColor.BeadsSession.amber
    }
  }

  /// How soft the room's reflection is in a metal.
  var roughness: Float {
    switch self {
    case .titanium: 0.20
    case .gold: 0.16
    default: 0
    }
  }

  /// How much light a stone lets through to its far side.
  var translucency: Float {
    switch self {
    case .jade: 0.5
    case .amber: 0.8
    default: 0
    }
  }

  /// How strongly the bead picks up the warmth of the finger it rests on.
  /// Polished metal mirrors skin; wood and stone only take a little of it.
  var warmth: Float {
    switch self {
    case .titanium: 0.5
    case .gold: 0.42
    case .sandalwood: 0.26
    case .bodhi: 0.18
    case .jade: 0.3
    case .amber: 0.34
    }
  }

  /// Grain and mottling differ from bead to bead; a mirror finish does not.
  var patterns: Int { surface == .metal ? 1 : 5 }
}
