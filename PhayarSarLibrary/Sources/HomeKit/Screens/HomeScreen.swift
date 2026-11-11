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
  /// The Audio empty state sits this far below the chips, so it reads as the
  /// body of the screen rather than as a caption under the filter.
  static let emptyStateTopPadding: CGFloat = 48
}

public struct HomeScreen: View {

  /// What Home is showing. A filter on one screen rather than separate tabs:
  /// All, Prayers and Audio are three views of the same catalog, and the tab
  /// bar is already full.
  enum Filter: Hashable, CaseIterable {
    case all
    case prayers
    case audio

    var title: String {
      switch self {
      case .all: return L10n.homeFilterAll
      case .prayers: return L10n.homeFilterPrayers
      case .audio: return L10n.homeFilterAudio
      }
    }

    var systemImage: String? {
      switch self {
      case .all: return nil
      case .prayers: return "book"
      case .audio: return "headphones"
      }
    }
  }

  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var navigator: AppNavigatorModel
  @StateObject private var viewModel = HomeViewModel()
  @ObservedObject private var continuation = PrayerContinuationStore.shared
  @ObservedObject private var beads = BeadsStore.shared

  public init() {}

  public var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        // Eager, not lazy: "See all" and the category jump bar scroll to a
        // section by id, and in a `LazyVStack` the position of a section that
        // has not been built yet is only an estimate — a jump to Virtues
        // landed on Parittas. The whole catalog is 35 rows of small vector
        // covers, so building it all costs less than a jump that misses.
        VStack(alignment: .leading, spacing: AppListSectionMetrics.recommendedSectionSpacing) {
          filterBar

          // Not animated: swapping a screenful of content cross-fades badly,
          // and the chip's own highlight already shows what changed.
          switch viewModel.filter {
          case .all:
            AllContent()
          case .prayers:
            PrayersContent(proxy: proxy)
          case .audio:
            AudioContent()
          }
        }
        .padding(.top, HomeScreenMetrics.contentTopPadding)
        .padding(.bottom, HomeScreenMetrics.contentBottomPadding)
      }
    }
    .onAppear {
      viewModel.onAppear()
      beads.reload()
    }
    .appTabBackground()
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

  // MARK: - Filter

  /// Scrolls with the content rather than pinning. The old segmented control
  /// was pinned, which needed an opaque material band behind it so rows would
  /// not show through — and that band was the grey strip that broke the tab's
  /// gradient. Every filter starts at the top of the page, so the chips are
  /// always in reach when they matter.
  private var filterBar: some View {
    HStack(spacing: AppFilterChipMetrics.spacing) {
      ForEach(Filter.allCases, id: \.self) { filter in
        AppFilterChip(
          filter.title,
          systemImage: filter.systemImage,
          isSelected: viewModel.filter == filter
        ) {
          viewModel.filter = filter
        }
      }
    }
    .appHorizontalInset()
  }

  private func open(_ collection: PrayerCollection.Kind) {
    navigator.navigate(to: .prayerCollection(collectionID: PrayerCollection.id(for: collection)))
  }

  // MARK: - All

  /// The exploration view. Nothing here changes the filter: every "See all",
  /// moment and scripture row *pushes* a collection, so back returns to this
  /// page where the user left it. An earlier version sent "See all" to the
  /// Prayers filter instead, which replaced the page under the user's finger
  /// and left them somewhere they had not asked to go.
  @ViewBuilder
  private func AllContent() -> some View {
    HomeHeroPager(pages: heroPages)

    HomeMomentGrid(moments: viewModel.moments) { open($0.kind) }

    if !viewModel.shortPrayers.isEmpty {
      HomePrayerRail(
        title: L10n.twoMinutesOrLess,
        prayers: viewModel.shortPrayers,
        onSeeAll: { open(.short) },
        onOpen: { navigator.navigate(to: .prayerDetail(prayerID: $0)) }
      )
    }

    VStack(alignment: .leading, spacing: AppListSectionMetrics.labelGap) {
      HomeSectionHeader(title: L10n.byScripture)
      AppSettingsGroup {
        ForEach(viewModel.sections) { section in
          AppSettingsRow(
            section.category.displayText,
            detail: section.prayers.count.formatted()
          ) {
            open(.category(section.category))
          }
        }
      }
    }
  }

  /// Resumable things first, because unfinished work outranks a suggestion;
  /// then the pick for this time of day; then bead sessions. The pick is left
  /// out when it is the very prayer already being resumed — two pages for one
  /// prayer would read as a bug.
  private var heroPages: [HomeHeroPage] {
    var pages: [HomeHeroPage] = []
    var resumingID: Prayer.ID?

    if let reading = continuation.reading,
       let prayer = PrayerCatalog.shared.prayer(id: reading.prayerID) {
      resumingID = prayer.id
      pages.append(HomeHeroPage(
        id: "reading",
        eyebrow: L10n.continueSection,
        title: prayer.title,
        summary: L10n.continuePrayerProgress(
          .init(stringLiteral: reading.verse.formatted()),
          .init(stringLiteral: reading.verses.formatted())
        ),
        actionTitle: L10n.heroResume,
        tint: .rose,
        artwork: .prayer(prayer.id),
        action: { navigator.navigate(to: .prayer(prayerID: prayer.id)) }
      ))
    }

    if let feature = viewModel.feature, feature.pick.id != resumingID {
      let prayer = feature.pick
      pages.append(HomeHeroPage(
        id: "pick",
        eyebrow: feature.title,
        title: prayer.title,
        summary: "\(prayer.estimatedMinutes) \(L10n.minutesUnit) • \(prayer.body.count) \(L10n.verses)",
        actionTitle: L10n.startReading,
        tint: feature.tint,
        artwork: .prayer(prayer.id),
        action: { navigator.navigate(to: .prayerDetail(prayerID: prayer.id)) }
      ))
    }

    for session in beads.ongoingSessions {
      pages.append(HomeHeroPage(
        id: "beads.\(session.id.uuidString)",
        eyebrow: L10n.beads,
        title: session.name,
        summary: L10n.continueBeadsProgress(
          .init(stringLiteral: session.completed.formatted()),
          .init(stringLiteral: session.total.formatted())
        ),
        actionTitle: L10n.heroResume,
        tint: .plum,
        artwork: .symbol("circle.hexagonpath"),
        action: { navigator.navigate(to: .beadsSession(beadsID: session.id)) }
      ))
    }
    return pages
  }

  // MARK: - Prayers

  /// The browse view: the whole catalog, grouped, as plain rows. The jump bar
  /// is a set of one-shot shortcuts rather than a second filter, so none of
  /// its chips stays selected — a highlight that did not follow the scroll
  /// position would soon point at the wrong category.
  @ViewBuilder
  private func PrayersContent(proxy: ScrollViewProxy) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: AppFilterChipMetrics.subtleSpacing) {
        ForEach(viewModel.sections) { section in
          AppFilterChip(section.category.displayText, style: .subtle) {
            withAnimation { proxy.scrollTo(section.category, anchor: .top) }
          }
        }
      }
      // Pulls the first label's text, not its invisible capsule, onto the
      // screen's leading inset.
      .padding(.horizontal, -AppFilterChipMetrics.subtleHorizontalPadding)
      .appHorizontalInset()
    }

    ForEach(viewModel.sections) { section in
      // Zero vertical insets: `HomePrayerCardView` pads its own rows, so the
      // section adding more would double the gap at the first and last row.
      AppListSection(
        contentInsets: EdgeInsets(
          top: 0,
          leading: AppListSectionMetrics.contentInsets.leading,
          bottom: 0,
          trailing: AppListSectionMetrics.contentInsets.trailing
        )
      ) {
        HStack {
          Text(section.category.displayText)
          Spacer()
          Text(L10n.prayerCount(.init(stringLiteral: section.prayers.count.formatted())))
        }
      } content: {
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
      } footer: {
        EmptyView()
      }
      .id(section.category)
    }
  }

  // MARK: - Audio

  /// Kept as a real filter while empty so the chip row does not change shape
  /// the day recordings ship.
  private func AudioContent() -> some View {
    AppEmptyStateView(
      systemImage: "headphones",
      title: L10n.audioEmptyTitle,
      message: L10n.audioEmptyMessage,
      actionTitle: L10n.browsePrayers
    ) {
      viewModel.filter = .prayers
    }
    .padding(.top, HomeScreenMetrics.emptyStateTopPadding)
    .appHorizontalInset()
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
