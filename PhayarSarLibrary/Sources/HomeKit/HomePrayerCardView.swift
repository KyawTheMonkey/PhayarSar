import DesignKit
import LocalisationKit
import PrayersKit
import SwiftUI

/// Layout constants for `HomePrayerCardView`.
private enum HomePrayerCardMetrics {
  /// Space above and below a row's content. Rows own their own vertical rhythm,
  /// so the enclosing section is handed zero vertical content insets — see
  /// `HomeScreen.PrayersContent()`. Between two rows this reads as 12 above and
  /// 12 below the separator; at the card edges, as a single 12.
  static let rowVerticalPadding: CGFloat = 12

  /// Cancels the section's horizontal content inset so the separator spans the
  /// full width of the card, the way a `List` row separator does.
  static var dividerBleed: CGFloat {
    -AppListSectionMetrics.contentInsets.leading
  }
}

struct HomePrayerCardView: View {
  let prayer: Prayer
  /// `false` on the last row of a section — a separator sitting directly on the
  /// card's bottom edge reads as a rendering mistake.
  let shouldShowDivider: Bool

  private var name: String {
    prayer.title
  }
  
  private var duration: String {
//    prayer.body
    return "2 min"
  }
  
  private var verses: String {
    return "\(prayer.body.count) \(L10n.verses)"
  }
  
  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.gray)
          .frame(width: 46, height: 46)
        
        VStack(alignment: .leading, spacing: 8) {
          Text(name)
            .font(AppFont.listItemTitle)
          HStack(spacing: 4) {
            Text(duration)
            Text("•")
            Text(verses)
          }
          .foregroundStyle(AppColor.grey400)
          .font(AppFont.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        Image(systemName: "chevron.right")
          .foregroundStyle(AppColor.grey400)
      }
      .padding(.vertical, HomePrayerCardMetrics.rowVerticalPadding)

      if shouldShowDivider {
        Divider()
          .padding(.horizontal, HomePrayerCardMetrics.dividerBleed)
      }
    }
  }
}
