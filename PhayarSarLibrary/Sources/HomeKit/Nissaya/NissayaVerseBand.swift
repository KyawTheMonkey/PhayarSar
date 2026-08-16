import DesignKit
import PrayersKit
import SwiftUI

/// The tinted strip across the top of a verse card, carrying its number and —
/// where the source gives one — its name.
///
/// Full-bleed rather than inset. It is the only part of a card that shows in the
/// sliver behind the front one, which is what makes the deck read as a stack of
/// *cards* rather than as one card with lines behind it.
///
/// A view of its own rather than a method on ``NissayaCard`` because it is the
/// card's most recognisable feature at a glance, and anything else that comes to
/// show a verse should show the same band rather than approximate it.
struct NissayaVerseBand: View {
  let verse: Prayer.Verse
  /// 1-based position in the prayer.
  let position: Int
  /// Point size for the verse name. The band tracks whichever card it is in.
  let nameSize: CGFloat
  let horizontalPadding: CGFloat
  let verticalPadding: CGFloat

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text("\(position)")
        .font(AppFont.captionBold)
        // Otherwise the number shifts the name sideways as the deck steps
        // between differently-wide digits.
        .monospacedDigit()
        .foregroundStyle(AppColor.primary)

      // Set in the Myanmar face rather than the app's section-label style: the
      // names that exist are Burmese (the 24 paccayas in ပဋ္ဌာန်းအကျယ်), and
      // Inter has no glyphs for them.
      if let name = verse.name, !name.isEmpty {
        Text("·")
          .font(AppFont.captionBold)
          .foregroundStyle(AppColor.primary.opacity(0.5))

        Text(name)
          .font(AppFont.jasmine(size: nameSize, relativeTo: .footnote))
          .foregroundStyle(AppColor.textSecondary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.vertical, verticalPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppColor.primarySoft)
    // Separates the band from the card's face, where the tint alone is too
    // close to it to show an edge.
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(AppColor.border)
        .frame(height: 0.5)
    }
  }
}
