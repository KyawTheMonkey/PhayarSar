import DesignKit
import Inject
import LocalisationKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

private enum HomeContinueMetrics {
  static let phoneCardWidthFraction: CGFloat = 4.0 / 5.0
  static let maximumCardWidth: CGFloat = 480
  static let nextCardPeek: CGFloat = 24
  static let labelKerning: CGFloat = 0.6
}

/// Measure at the final width so wrapped summaries and Dynamic Type can grow
/// the whole row together. AppCard fills the resulting height for each item.
private struct HomeContinueRow: Layout {
  let cardWidth: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let cardProposal = ProposedViewSize(width: cardWidth, height: nil)
    let height = subviews.map { $0.sizeThatFits(cardProposal).height }.max() ?? 0
    let gaps = max(subviews.count - 1, 0)
    return CGSize(
      width: CGFloat(subviews.count) * cardWidth + CGFloat(gaps) * AppCardMetrics.spacing,
      height: height
    )
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let cardProposal = ProposedViewSize(width: cardWidth, height: bounds.height)
    var x = bounds.minX
    for subview in subviews {
      subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: cardProposal)
      x += cardWidth + AppCardMetrics.spacing
    }
  }
}

/// Each item is one resumable activity, with its own card and action. Keeping
/// the carousel independent of prayer state lets meditation and beads join the
/// same collection when their sessions exist, without adding placeholder cards
/// or nesting several activities inside one shared card.
struct HomeContinueCarousel<Item: Identifiable, Card: View>: View {
  @ObserveInjection private var injectionObserver
  let items: [Item]
  @ViewBuilder let card: (Item) -> Card
  @State private var width: CGFloat = 0

  #if os(macOS)
  private var horizontalInset: CGFloat { AppListSectionMetrics.regularHorizontalInset }
  #else
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private var horizontalInset: CGFloat {
    horizontalSizeClass == .regular
      ? AppListSectionMetrics.regularHorizontalInset
      : AppListSectionMetrics.compactHorizontalInset
  }
  #endif

  private var cardWidth: CGFloat {
    guard width > 0 else { return AppCardMetrics.idealWidth }
    #if os(iOS)
    if UIDevice.current.userInterfaceIdiom == .phone {
      return width * HomeContinueMetrics.phoneCardWidthFraction
    }
    #endif
    let available = width - horizontalInset * 2
    let peek = items.count > 1 ? HomeContinueMetrics.nextCardPeek + AppCardMetrics.spacing : 0
    return min(max(available - peek, 0), HomeContinueMetrics.maximumCardWidth)
  }

  var body: some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: AppListSectionMetrics.labelGap) {
        Text(L10n.continueSection)
          .font(AppFont.sectionLabel)
          .textCase(.uppercase)
          .kerning(HomeContinueMetrics.labelKerning)
          .foregroundStyle(AppColor.textSecondary)
          .padding(.horizontal, horizontalInset + AppListSectionMetrics.contentInsets.leading)

        ScrollView(.horizontal, showsIndicators: false) {
          HomeContinueRow(cardWidth: cardWidth) {
            ForEach(items) { item in
              AppCard { card(item) }
            }
          }
          .continuationScrollTargets()
          .padding(.horizontal, horizontalInset)
        }
        .continuationScrollBehavior()
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
      }
      .enableInjection()
    }
  }
}

private extension View {
  @ViewBuilder
  func continuationScrollTargets() -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      scrollTargetLayout()
    } else {
      self
    }
  }

  @ViewBuilder
  func continuationScrollBehavior() -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      scrollTargetBehavior(.viewAligned)
    } else {
      self
    }
  }
}
