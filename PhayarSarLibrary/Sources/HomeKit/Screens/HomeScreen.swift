import BeadsKit
import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI

private enum HomeScreenMetrics {
  static let contentTopPadding: CGFloat = 8
  static let contentBottomPadding: CGFloat = 16
  static let segmentVerticalPadding: CGFloat = 8
}

private enum HomeContinuation: Identifiable {
  case prayer(Prayer, PrayerContinuationStore.Reading)
  case beads(BeadsContinuation)

  var id: RouterDestination {
    switch self {
    case let .prayer(prayer, _): .prayer(prayerID: prayer.id)
    case let .beads(session): .beadsSession(beadsID: session.id)
    }
  }
}

public struct HomeScreen: View {

  enum Segment: Int, Hashable, CaseIterable {
    case prayers
    case audio
    
    var displayText: String {
      switch self {
      case .prayers: return "Prayers"
      case .audio: return "Audios"
      }
    }
  }
  
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var navigator: AppNavigatorModel
  @StateObject private var viewModel = HomeViewModel()
  @ObservedObject private var continuation = PrayerContinuationStore.shared
  @ObservedObject private var beads = BeadsStore.shared

  public init() {}

  private var continuations: [HomeContinuation] {
    let sessions = beads.ongoingSessions.map(HomeContinuation.beads)
    guard let reading = continuation.reading,
          let prayer = PrayerCatalog.shared.prayer(id: reading.prayerID)
    else { return sessions }
    return [.prayer(prayer, reading)] + sessions
  }

  public var body: some View {
    ScrollView {
      LazyVStack(
        spacing: AppListSectionMetrics.recommendedSectionSpacing,
        pinnedViews: [.sectionHeaders]
      ) {
        HomeContinueCarousel(items: continuations) { item in
          continuationCard(item)
        }

        Section {
          switch viewModel.activeSegment {
          case .prayers:
            PrayersContent()
          case .audio:
            Text("Empty")
          }
        } header: {
          HomeSegmentView(activeSegment: $viewModel.activeSegment)
            .appHorizontalInset()
            .padding(.vertical, HomeScreenMetrics.segmentVerticalPadding)
            .background(.regularMaterial)
        }
      }
      .padding(.top, HomeScreenMetrics.contentTopPadding)
      .padding(.bottom, HomeScreenMetrics.contentBottomPadding)
    }
    .onAppear {
      viewModel.onAppear()
      beads.reload()
    }
    .background(AppBackgroundGradient())
    // The system owns both title sizes and the scroll view's navigation inset.
    // Measuring and moving an overlay title alongside that inset creates two
    // competing layouts, especially when Continue appears or disappears.
    .navigationTitle(L10n.homeTab)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.large)
    .toolbar(.visible, for: .navigationBar)
    #endif
    .toolbar { HomeToolbar() }
    .enableInjection()
  }

  @ViewBuilder
  private func continuationCard(_ item: HomeContinuation) -> some View {
    switch item {
    case let .prayer(prayer, reading):
      let progress = L10n.continuePrayerProgress(
        .init(stringLiteral: reading.verse.formatted()),
        .init(stringLiteral: reading.verses.formatted())
      )
      let category = viewModel.sections.first { section in
        section.prayers.contains { $0.id == prayer.id }
      }?.category
      HomeContinueCard(
        title: prayer.title, summary: category.map { "\($0.displayText) • \(progress)" } ?? progress,
        fraction: reading.fraction, onTap: { navigator.navigate(to: item.id) }
      ) {
        PrayerCoverImage(prayerID: prayer.id)
      }
    case let .beads(session):
      HomeContinueCard(
        title: session.name,
        summary: L10n.continueBeadsProgress(
          .init(stringLiteral: session.completed.formatted()),
          .init(stringLiteral: session.total.formatted())
        ),
        fraction: Double(session.completed) / Double(session.total),
        onTap: { navigator.navigate(to: item.id) }
      ) {
        ZStack {
          AppColor.primarySoft
          Image(systemName: "circle.hexagonpath")
            .font(AppFont.title)
            .foregroundStyle(AppColor.primary)
        }
      }
    }
  }

  @ViewBuilder
  private func PrayersContent() -> some View {
    ForEach(viewModel.sections) { section in
      // Zero vertical insets: `HomePrayerCardView` pads its own rows, so the
      // section adding more would double the gap at the first and last row.
      AppListSection(
        section.category.displayText,
        contentInsets: EdgeInsets(
          top: 0,
          leading: AppListSectionMetrics.contentInsets.leading,
          bottom: 0,
          trailing: AppListSectionMetrics.contentInsets.trailing
        )
      ) {
        ForEach(section.prayers) { prayer in
          HomePrayerCardView(
            prayer: prayer,
            shouldShowDivider: prayer.id != section.prayers.last?.id,
            // A `Button` through the navigator rather than a
            // `NavigationLink(value:)` — a link would push straight onto the
            // stack and leave `AppNavigatorModel` unaware of where the user is.
            onTap: { navigator.navigate(to: .prayerDetail(prayerID: prayer.id)) }
          )
        }
      }
    }
  }
}

#Preview {
  HomeScreenPreview()
}

private struct HomeScreenPreview: View {
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    NavigationStack {
      HomeScreen()
    }
    .environmentObject(AppNavigatorModel())
  }
}
