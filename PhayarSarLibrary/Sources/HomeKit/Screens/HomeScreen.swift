import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI
import UtilKit

/// Top edge of the pinned segment picker, in global coordinates.
private struct SegmentTopKey: PreferenceKey {
  static var defaultValue: CGFloat { .greatestFiniteMagnitude }

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = min(value, nextValue())
  }
}

/// Global frame of the scroll content's top edge, full width.
///
/// Carries two things the nav needs. Its `minY` gives the bar's bottom edge —
/// measuring the bar directly would be the obvious move, but preferences set
/// inside `.safeAreaInset` content do not reliably propagate out to the modified
/// view (see `HomeScreen.navBottom`). Its `midX` gives the centre line for the
/// collapsed title: on iPad this screen lives in a `NavigationSplitView` detail
/// column, so the screen's centre and the content's centre are not the same
/// point.
private struct ContentFrameKey: PreferenceKey {
  static var defaultValue: CGRect { .zero }

  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    let next = nextValue()
    if next != .zero { value = next }
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
  
  /// Names the scroll view's coordinate space so `ScrollOffsetReader` can
  /// measure against it.
  private static let scrollSpace = "HomeScreen.scroll"

  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var navigator: AppNavigatorModel
  @StateObject private var viewModel = HomeViewModel()
  @State private var scrollOffset: CGFloat = 0
  @State private var segmentTop: CGFloat = .greatestFiniteMagnitude
  @State private var contentFrame: CGRect = .zero
  /// How far the list must scroll before the picker reaches the nav bar and
  /// pins. Measured from the layout while the list is at rest, so it adapts to
  /// whatever height the "Continue" section above it happens to be.
  @State private var pinScrollDistance: CGFloat = .greatestFiniteMagnitude
  @State private var titleAnchor: CGRect = .zero

  public init() {}

  /// `0` at rest, `1` once the nav bar is fully collapsed.
  private var progress: CGFloat {
    min(max(-scrollOffset / HomeNavMetrics.collapseDistance, 0), 1)
  }

  /// How far past the top the user is pulling, `0` otherwise.
  private var stretch: CGFloat {
    max(scrollOffset, 0)
  }

  /// Global Y of the nav bar's bottom edge, which is where the scroll content
  /// begins.
  ///
  /// At rest the content's top edge sits exactly there, and scrolling moves the
  /// two apart by precisely `scrollOffset` — so subtracting it recovers the
  /// bar's edge at any scroll position, without measuring the bar itself.
  private var navBottom: CGFloat {
    contentFrame.minY - scrollOffset
  }

  /// `1` once the pinned picker has come to rest against the nav bar, which is
  /// when the two backgrounds must join into one continuous pane.
  ///
  /// Derived from how far the list has scrolled rather than from the live gap
  /// between the two: a pinned header settles a few points below the safe-area
  /// inset, not flush against it, so the gap alone never reaches a value that
  /// could be tested against zero.
  private var docked: CGFloat {
    guard pinScrollDistance < .greatestFiniteMagnitude else { return 0 }

    return smoothstep(
      (pinScrollDistance - HomeNavMetrics.dockDistance)...pinScrollDistance,
      -scrollOffset
    )
  }

  /// Measures the picker's distance from the nav bar.
  ///
  /// Only meaningful while the list is at rest — once scrolling starts the
  /// picker is in motion, and after it pins the distance stops changing
  /// altogether. Re-running at every return to rest keeps it correct across
  /// rotation and Dynamic Type changes.
  private func calibratePinDistance() {
    guard abs(scrollOffset) < 0.5,
          contentFrame != .zero,
          segmentTop < .greatestFiniteMagnitude
    else { return }

    pinScrollDistance = max(segmentTop - navBottom, 0)
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        // Outside the padded stack below, so its resting position is 0 rather
        // than the padding amount.
        ScrollOffsetReader(space: Self.scrollSpace)
          .background {
            GeometryReader { proxy in
              Color.clear.preference(
                key: ContentFrameKey.self,
                value: proxy.frame(in: .global)
              )
            }
          }

        LazyVStack(
          spacing: AppListSectionMetrics.recommendedSectionSpacing,
          pinnedViews: [.sectionHeaders]
        ) {
          HomeTitleAnchor()

          AppListSection("Continue") {
            OngoingPrayerView()
          }

          // The picker is a section header so it pins under the nav bar once it
          // reaches it, staying reachable through a long list. `safeAreaInset`
          // already insets the scroll view, so it pins to the right place.
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
              .padding(
                .top,
                lerp(
                  HomeNavMetrics.segmentTopPadding,
                  HomeNavMetrics.segmentDockedTopPadding,
                  docked
                )
              )
              .padding(.bottom, HomeNavMetrics.segmentTopPadding)
              .background {
                // Only once docked, so the picker carries no band while it is
                // still scrolling along with the content.
                //
                // Extended upward past its own top edge to close the few points
                // a pinned header rests below the bar. The overhang ends up
                // behind the nav bar, which draws over it, so it is invisible —
                // it exists only to remove the seam.
                // High solid stop: the overhang above adds to this pane's
                // height, so a lower one would put the picker itself inside the
                // fade. Full strength through the control, fading only past it.
                AppFadeBlurBackground(
                  intensity: docked,
                  solidStop: HomeNavMetrics.dockedSolidStop
                )
                .padding(.top, -HomeNavMetrics.dockOverlap * docked)
              }
              .background {
                GeometryReader { proxy in
                  Color.clear.preference(
                    key: SegmentTopKey.self,
                    value: proxy.frame(in: .global).minY
                  )
                }
              }
          }
        }
        // Asymmetric: the large title sits tight under the bar, but the list
        // still needs clearance at the bottom.
        .padding(.top, HomeNavMetrics.largeTitleTopPadding)
        .padding(.bottom, 16)
      }
    }
    .coordinateSpace(name: Self.scrollSpace)
    .onScrollOffsetChange {
      scrollOffset = $0
      calibratePinDistance()
    }
    .onPreferenceChange(SegmentTopKey.self) {
      segmentTop = $0
      calibratePinDistance()
    }
    .onPreferenceChange(ContentFrameKey.self) {
      contentFrame = $0
      calibratePinDistance()
    }
    .onPreferenceChange(HomeTitleAnchorKey.self) { titleAnchor = $0 }
    .onAppear {
      viewModel.onAppear()
    }
    .background(AppBackgroundGradient())
    .safeAreaInset(edge: .top, content: {
      HomeNavView(progress: progress, stretch: stretch, docked: docked)
    })
    // Above the bar, so the title stays legible once it lands on it. Applied
    // after `safeAreaInset` so it draws over the bar rather than under it.
    .overlay {
      HomeCollapsingTitle(
        progress: progress,
        stretch: stretch,
        anchor: titleAnchor,
        navBottom: navBottom,
        centreX: contentFrame.midX
      )
      .ignoresSafeArea()
    }
    .hideNavBar()
    .enableInjection()
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
  NavigationStack {
    HomeScreen()
  }
  .environmentObject(AppNavigatorModel())
}
