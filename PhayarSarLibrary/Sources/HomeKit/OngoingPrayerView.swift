import DesignKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI

private enum OngoingPrayerMetrics {
  static let spacing: CGFloat = 12
  static let coverSize: CGFloat = 48
  static let coverCornerRadius: CGFloat = 16
  static let textSpacing: CGFloat = 2
  static let progressTopPadding: CGFloat = 4
  static let progressHeight: CGFloat = 5
}

struct OngoingPrayerView: View {
  @ObserveInjection private var injectionObserver
  let prayer: Prayer
  let category: PrayerCategory?
  let reading: PrayerContinuationStore.Reading
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: OngoingPrayerMetrics.spacing) {
        PrayerCoverImage(prayerID: prayer.id)
          .frame(width: OngoingPrayerMetrics.coverSize, height: OngoingPrayerMetrics.coverSize)
          .clipShape(RoundedRectangle(cornerRadius: OngoingPrayerMetrics.coverCornerRadius))

        VStack(alignment: .leading, spacing: OngoingPrayerMetrics.textSpacing) {
          Text(prayer.title)
            .font(AppFont.listItemTitle)
            .foregroundStyle(AppColor.textPrimary)

          Text(summary)
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

          GeometryReader { proxy in
            Capsule()
              .fill(AppColor.grey300)
              .overlay(alignment: .leading) {
                Capsule()
                  .fill(AppColor.primary)
                  .frame(width: proxy.size.width * min(max(reading.fraction, 0), 1))
              }
          }
          .frame(height: OngoingPrayerMetrics.progressHeight)
          .padding(.top, OngoingPrayerMetrics.progressTopPadding)
          .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .foregroundStyle(AppColor.primary)
          .accessibilityHidden(true)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .enableInjection()
  }

  private var summary: String {
    let progress = L10n.continuePrayerProgress(
      .init(stringLiteral: reading.verse.formatted()),
      .init(stringLiteral: reading.verses.formatted())
    )
    return category.map { "\($0.displayText) • \(progress)" } ?? progress
  }
}
