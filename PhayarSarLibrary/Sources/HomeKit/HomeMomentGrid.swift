import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI

// MARK: - Metrics

private enum HomeMomentMetrics {
  static let columns = 2
  static let spacing: CGFloat = 12
  static let cardHeight: CGFloat = 112
  static let cornerRadius: CGFloat = 18
  static let padding: CGFloat = 14
  static let sectionSpacing: CGFloat = 12

  /// Same idea as the hero's artwork at a smaller scale: a cover tipped into
  /// the trailing corner, mostly on the card and partly off it.
  static let coverSize: CGFloat = 76
  static let coverCornerRadius: CGFloat = 14
  static let coverOverhang: CGFloat = 14
  static let coverTilt: Double = 10
}

// MARK: - Grid

/// "Find a prayer for": a grid of the moments a prayer is recited at.
///
/// The catalog is organised by scripture type, which is how someone who
/// already knows the texts looks for one. This is the other way in — by when
/// or why — for someone who knows they want something for the evening and not
/// that it is filed under Parittas. Each card pushes its collection.
struct HomeMomentGrid: View {
  @ObserveInjection private var injectionObserver
  let moments: [PrayerCollection]
  let onOpen: (PrayerCollection) -> Void

  private var columns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: HomeMomentMetrics.spacing),
      count: HomeMomentMetrics.columns
    )
  }

  var body: some View {
    if !moments.isEmpty {
      VStack(alignment: .leading, spacing: HomeMomentMetrics.sectionSpacing) {
        HomeSectionHeader(title: L10n.findAPrayerFor)

        LazyVGrid(columns: columns, spacing: HomeMomentMetrics.spacing) {
          ForEach(moments) { moment in
            card(moment)
          }
        }
        .appHorizontalInset()
      }
      .enableInjection()
    }
  }

  private func card(_ collection: PrayerCollection) -> some View {
    let tint = tint(for: collection)
    let shape = RoundedRectangle(cornerRadius: HomeMomentMetrics.cornerRadius, style: .continuous)

    return Button {
      onOpen(collection)
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        Text(collection.title)
          .font(AppFont.listItemTitle)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        Spacer(minLength: 0)
        Text(L10n.prayerCount(.init(stringLiteral: collection.prayers.count.formatted())))
          .font(AppFont.caption)
          .opacity(0.8)
      }
      .foregroundStyle(tint.ink)
      .padding(HomeMomentMetrics.padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(height: HomeMomentMetrics.cardHeight)
      .background(alignment: .bottomTrailing) {
        PrayerCoverImage(prayerID: collection.coverPrayerID)
          .frame(width: HomeMomentMetrics.coverSize, height: HomeMomentMetrics.coverSize)
          .clipShape(
            RoundedRectangle(cornerRadius: HomeMomentMetrics.coverCornerRadius, style: .continuous)
          )
          .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
          .rotationEffect(.degrees(HomeMomentMetrics.coverTilt))
          .offset(x: HomeMomentMetrics.coverOverhang, y: HomeMomentMetrics.coverOverhang)
      }
      .background(tint.background)
      .clipShape(shape)
      .contentShape(shape)
      // On the label, not the button: the source has to be the card's own
      // drawn shape, without the press style's scaling applied around it.
      .appZoomSource(id: collection.id, cornerRadius: HomeMomentMetrics.cornerRadius)
    }
    .buttonStyle(PressableButtonStyle())
    .accessibilityElement(children: .combine)
  }

  private func tint(for collection: PrayerCollection) -> AppColor.Tint {
    if case let .moment(moment) = collection.kind { return moment.tint }
    return .rose
  }
}
