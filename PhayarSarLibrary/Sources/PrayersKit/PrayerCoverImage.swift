import DesignKit
import SwiftUI

/// Keeps the resource bundle private to PrayersKit: feature screens should not
/// need to know where SwiftPM puts the compiled asset catalog. Each image set
/// contains an individual SVG with vector preservation enabled, so the same
/// artwork serves a list thumbnail and a larger detail cover.
///
/// Layout and corner treatment belong to the caller. The picture is decorative
/// because its neighbouring title already identifies the prayer to VoiceOver.
public struct PrayerCoverImage: View {
  private let assetName: String?

  public init(prayerID: Prayer.ID?, catalog: PrayerCatalog = .shared) {
    assetName = prayerID.flatMap { catalog.coverAssetName(for: $0) }
  }

  public var body: some View {
    Group {
      if let assetName {
        Image(assetName, bundle: .module)
          .resizable()
          .scaledToFit()
      } else {
        Rectangle()
          .fill(AppColor.grey300)
          .aspectRatio(1, contentMode: .fit)
      }
    }
    .accessibilityHidden(true)
  }
}
