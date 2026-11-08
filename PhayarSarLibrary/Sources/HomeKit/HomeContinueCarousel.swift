import DesignKit
import Inject
import LocalisationKit
import SwiftUI

private enum HomeContinueMetrics {
  static let maximumCardWidth: CGFloat = 480
  static let nextCardPeek: CGFloat = 24
  static let labelKerning: CGFloat = 0.6
}

private struct HomeContinueWidthKey: PreferenceKey {
  static var defaultValue: CGFloat { 0 }

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
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
    // Before the width preference arrives, a zero-width card wraps every
    // character onto its own line and gives the carousel an enormous height.
    let available = width > 0
      ? max(width - horizontalInset * 2, 0)
      : AppCardMetrics.idealWidth
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
          HStack(spacing: AppCardMetrics.spacing) {
            ForEach(items) { item in
              AppCard { card(item) }
                .frame(width: cardWidth)
                // AppCard fills height for grids. This horizontal strip needs
                // its natural height at the resolved width instead, including
                // any extra room required by Burmese text and Dynamic Type.
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .continuationScrollTargets()
          .padding(.horizontal, horizontalInset)
        }
        .continuationScrollBehavior()
        .fixedSize(horizontal: false, vertical: true)
      }
      .background {
        GeometryReader { proxy in
          Color.clear.preference(key: HomeContinueWidthKey.self, value: proxy.size.width)
        }
      }
      .onPreferenceChange(HomeContinueWidthKey.self) { width = $0 }
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
