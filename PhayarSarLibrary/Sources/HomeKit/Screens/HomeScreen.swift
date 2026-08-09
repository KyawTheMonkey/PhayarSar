import DesignKit
import Inject
import LocalisationKit
import SwiftUI
import UtilKit

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
  @State private var activeSegment: Segment = .prayers

  public init() {}

  public var body: some View {
    ScrollView {
      LazyVStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
        AppListSection("Continue") {
          OngoingPrayerView()
        }

        HomeSegmentView(activeSegment: $activeSegment)
          .appHorizontalInset()
      }
      .padding(.vertical)
    }
    .background(AppBackgroundGradient())
    .safeAreaInset(edge: .top, content: {
      HomeNavView()
    })
    .hideNavBar()
    .enableInjection()
  }
}

struct HomeNavView: View {
  var body: some View {
    HStack {
      Text(L10n.homeTab)
        .font(AppFont.largeTitle)
      
      Spacer()
      
      HStack(spacing: 9) {
        Button {} label: {
          Circle()
            .strokeBorder(AppColor.border, lineWidth: 3)
            .frame(width: 38, height: 38)
            .overlay {
              Circle()
                .trim(from: 0, to: 0.64)
                .stroke(
                  AppColor.primary,
                  style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 36, height: 36)
            }
            .overlay {
              Text("12")
                .font(AppFont.listItemTitle)
                .foregroundStyle(AppColor.primary)
                .scaleEffect(0.65)
            }
        }
        
        Button {} label: {
          Image(systemName: "magnifyingglass")
            .font(.title2)
            .fontWeight(.medium)
            .foregroundStyle(AppColor.textPrimary)
            .padding(8)
            .toolBarButtonCircularGlass()
        }
        
        Button {} label: {
          Image(systemName: "person.crop.circle")
            .font(.title2)
            .fontWeight(.medium)
            .foregroundStyle(AppColor.textPrimary)
            .padding(8)
            .toolBarButtonCircularGlass()
        }
      }
    }
    .padding(.horizontal)
  }
}

#Preview {
  NavigationStack {
    HomeScreen()
  }
}
