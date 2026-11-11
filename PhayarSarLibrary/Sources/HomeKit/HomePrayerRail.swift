import DesignKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI

// MARK: - Metrics

private enum HomePrayerRailMetrics {
  /// Wide enough for a two-line Burmese title at the button size; narrower
  /// than this and most titles truncate inside their first word.
  static let tileWidth: CGFloat = 104
  static let coverCornerRadius: CGFloat = 14
  static let tileSpacing: CGFloat = 14
  static let tileTextSpacing: CGFloat = 4
  static let tileCoverSpacing: CGFloat = 8
  static let sectionSpacing: CGFloat = 12
}

// MARK: - Section header

/// The Lora heading Home's All filter puts over each of its sections, with an
/// optional "See all". Shared so the rail, the moments grid and the scripture
/// list line up on the same baseline and inset.
struct HomeSectionHeader: View {
  let title: String
  var onSeeAll: (() -> Void)?

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(AppFont.title)
        .foregroundStyle(AppColor.textPrimary)
        .accessibilityAddTraits(.isHeader)

      Spacer(minLength: 0)

      if let onSeeAll {
        Button(L10n.seeAll, action: onSeeAll)
          .font(AppFont.button)
          .foregroundStyle(AppColor.primary)
          .accessibilityHint(title)
      }
    }
    .appHorizontalInset()
  }
}

// MARK: - Rail

/// A heading and one horizontal strip of covers.
///
/// All uses exactly one of these. A page built from several rails is the
/// monotony the redesign set out to remove, just turned sideways; one rail
/// between two differently shaped sections gives the page a change of rhythm.
struct HomePrayerRail: View {
  @ObserveInjection private var injectionObserver
  let title: String
  let prayers: [Prayer]
  let onSeeAll: () -> Void
  let onOpen: (Prayer.ID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: HomePrayerRailMetrics.sectionSpacing) {
      HomeSectionHeader(title: title, onSeeAll: onSeeAll)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: HomePrayerRailMetrics.tileSpacing) {
          ForEach(prayers) { prayer in
            tile(prayer)
          }
        }
        .appHorizontalInset()
      }
    }
    .enableInjection()
  }

  private func tile(_ prayer: Prayer) -> some View {
    Button {
      onOpen(prayer.id)
    } label: {
      VStack(alignment: .leading, spacing: HomePrayerRailMetrics.tileCoverSpacing) {
        PrayerCoverImage(prayerID: prayer.id)
          .frame(width: HomePrayerRailMetrics.tileWidth, height: HomePrayerRailMetrics.tileWidth)
          .clipShape(
            RoundedRectangle(cornerRadius: HomePrayerRailMetrics.coverCornerRadius, style: .continuous)
          )

        VStack(alignment: .leading, spacing: HomePrayerRailMetrics.tileTextSpacing) {
          Text(prayer.title)
            .font(AppFont.button)
            .foregroundStyle(AppColor.textPrimary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

          Text("\(prayer.estimatedMinutes) \(L10n.minutesUnit) • \(prayer.body.count) \(L10n.verses)")
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textTertiary)
            .lineLimit(1)
        }
      }
      .frame(width: HomePrayerRailMetrics.tileWidth, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressableButtonStyle())
    .accessibilityElement(children: .combine)
  }
}
