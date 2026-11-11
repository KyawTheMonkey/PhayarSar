import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI

// MARK: - Metrics

private enum PrayerCollectionMetrics {
  static let centreCover: CGFloat = 96
  static let sideCover: CGFloat = 72
  static let coverCornerRadius: CGFloat = 16
  /// How far each side cover tucks behind the centre one.
  static let coverOverlap: CGFloat = -18
  static let sideTilt: Double = 8
  static let headerSpacing: CGFloat = 14
  static let headerTextSpacing: CGFloat = 4
  static let contentTopPadding: CGFloat = 8
  static let contentBottomPadding: CGFloat = 16
}

// MARK: - Screen

/// A collection's prayers as a list: where every "See all", moment card and
/// scripture row on Home's All filter lands.
///
/// Pushed, so the system back button returns to All at the scroll position the
/// user left — which is the whole reason this screen exists rather than a jump
/// to the Prayers filter. It resolves its own id, per the navigation rule, and
/// shows the not-found state when a restored stack names a collection that no
/// longer resolves.
public struct PrayerCollectionScreen: View {
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var navigator: AppNavigatorModel
  private let collection: PrayerCollection?
  /// How far the list is pulled down past its top; drives the close button.
  @State private var pull: CGFloat = 0

  public init(collectionID: String) {
    collection = PrayerCollection(id: collectionID)
  }

  /// Only moments zoom. Their grid cards are the one place a collection is
  /// opened from something card-shaped; a "See all" link or a scripture row
  /// has no shape for the screen to grow out of, and a zoom from nothing is
  /// just a slower push.
  private var zoomID: String? {
    guard let collection, case .moment = collection.kind else { return nil }
    return collection.id
  }

  public var body: some View {
    Group {
      if let collection {
        content(collection)
      } else {
        AppEmptyStateView(systemImage: "questionmark.circle", title: L10n.collectionNotFound)
          .frame(maxHeight: .infinity)
      }
    }
    .appBackground()
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .appZoomDestination(id: zoomID, pull: pull)
    .enableInjection()
  }

  private func content(_ collection: PrayerCollection) -> some View {
    ScrollView {
      VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
        header(collection)

        // Zero vertical insets: `HomePrayerCardView` pads its own rows.
        AppListSection(
          contentInsets: EdgeInsets(
            top: 0,
            leading: AppListSectionMetrics.contentInsets.leading,
            bottom: 0,
            trailing: AppListSectionMetrics.contentInsets.trailing
          )
        ) {
          ForEach(collection.prayers) { prayer in
            HomePrayerCardView(
              prayer: prayer,
              shouldShowDivider: prayer.id != collection.prayers.last?.id,
              onTap: { navigator.navigate(to: .prayerDetail(prayerID: prayer.id)) }
            )
          }
        }
      }
      .padding(.top, PrayerCollectionMetrics.contentTopPadding)
      .padding(.bottom, PrayerCollectionMetrics.contentBottomPadding)
    }
    .appZoomPullTracking($pull)
  }

  // MARK: Header

  private func header(_ collection: PrayerCollection) -> some View {
    VStack(spacing: PrayerCollectionMetrics.headerSpacing) {
      covers(collection.prayers)

      VStack(spacing: PrayerCollectionMetrics.headerTextSpacing) {
        Text(collection.title)
          .font(AppFont.largeTitle)
          .foregroundStyle(AppColor.textPrimary)
          .accessibilityAddTraits(.isHeader)
        Text(collection.summary)
          .font(AppFont.subheadline)
          .foregroundStyle(AppColor.textSecondary)
      }
      .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .appHorizontalInset()
  }

  /// Up to three covers fanned out: the first prayer in front, the next two
  /// tipped away behind it. With fewer prayers the fan simply has fewer blades.
  private func covers(_ prayers: [Prayer]) -> some View {
    let front = prayers.first
    let left = prayers.count > 1 ? prayers[1] : nil
    let right = prayers.count > 2 ? prayers[2] : nil

    return HStack(alignment: .bottom, spacing: PrayerCollectionMetrics.coverOverlap) {
      if let left {
        cover(left, size: PrayerCollectionMetrics.sideCover)
          .rotationEffect(.degrees(-PrayerCollectionMetrics.sideTilt))
      }
      if let front {
        cover(front, size: PrayerCollectionMetrics.centreCover)
          .zIndex(1)
      }
      if let right {
        cover(right, size: PrayerCollectionMetrics.sideCover)
          .rotationEffect(.degrees(PrayerCollectionMetrics.sideTilt))
      }
    }
    .accessibilityHidden(true)
  }

  private func cover(_ prayer: Prayer, size: CGFloat) -> some View {
    PrayerCoverImage(prayerID: prayer.id)
      .frame(width: size, height: size)
      .clipShape(
        RoundedRectangle(cornerRadius: PrayerCollectionMetrics.coverCornerRadius, style: .continuous)
      )
      .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
  }
}
