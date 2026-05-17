import DesignKit
import EnvironmentKit
import Explore
import SwiftUI
import SwiftUIX

struct AppMainTabView: View {
  @Environment(\.userInterfaceIdiom) var uii
  @EnvironmentObject var navigator: AppNavigatorModel
  @State private var searchQuery = ""

  var body: some View {
    if uii == .phone {
      if #available(iOS 26.0, *) {
        TabView_iOS26()
          .tint(Color.accent)

      } else if #available(iOS 18.0, *) {
        TabView_iOS18()
          .tint(Color.accent)
      } else {
        TabView_Old()
          .accentColor(Color.accent)
      }
    } else {
      iPadTabView()
    }
  }

  @available(iOS 18.0, *)
  @ViewBuilder
  private func TabView_iOS26() -> some View {
    TabView(
      selection: .init(
        get: { navigator.selectedTab },
        set: { navigator.changeTabSelection(to: $0) }
      )
    ) {
      Tab(value: AppTab.explore) {
        ExploreView()
      } label: {
        AppTab.explore.label(isSelected: navigator.selectedTab == AppTab.explore)
      }

      Tab(value: AppTab.plan) {} label: {
        AppTab.plan.label(isSelected: navigator.selectedTab == AppTab.plan)
      }

      Tab(value: AppTab.settings) {} label: {
        AppTab.settings.label(isSelected: navigator.selectedTab == AppTab.settings)
      }

      Tab(value: AppTab.search, role: .search) {
        NavigationStack {
          List {}
            .navigationTitle("Search")
        }
        .searchable(text: $searchQuery)
      }
    }
  }

  @available(iOS 18.0, *)
  @ViewBuilder
  private func TabView_iOS18() -> some View {
    TabView(
      selection: .init(
        get: { navigator.selectedTab },
        set: { navigator.changeTabSelection(to: $0) }
      )
    ) {
      Tab(value: AppTab.explore) {
        ExploreView()
      } label: {
        AppTab.explore.label(isSelected: navigator.selectedTab == AppTab.explore)
      }

      Tab(value: AppTab.plan) {} label: {
        AppTab.plan.label(isSelected: navigator.selectedTab == AppTab.plan)
      }

      Tab(value: AppTab.settings) {} label: {
        AppTab.settings.label(isSelected: navigator.selectedTab == AppTab.settings)
      }
    }
  }

  @ViewBuilder
  private func TabView_Old() -> some View {
    TabView(
      selection: .init(
        get: { navigator.selectedTab },
        set: { navigator.changeTabSelection(to: $0) }
      )
    ) {
      ExploreView()
        .tabItem {
          AppTab.explore.label(isSelected: navigator.selectedTab == AppTab.explore)
        }
        .tag(AppTab.explore)

      Text("Plan")
        .tabItem {
          AppTab.plan.label(isSelected: navigator.selectedTab == AppTab.plan)
        }
        .tag(AppTab.plan)

      Text("Settings")
        .tabItem {
          AppTab.settings.label(isSelected: navigator.selectedTab == AppTab.settings)
        }
        .tag(AppTab.settings)
    }
  }
}

#Preview {
  AppMainTabView()
    .withPreviewsEnv()
}

struct iPadTabView: View {
  @Environment(\.userInterfaceIdiom) var uii
  @EnvironmentObject var navigator: AppNavigatorModel

  var body: some View {
    if uii != .phone {
      NavigationSplitView {
        List(
          selection: .init(
            get: { navigator.selectedTab },
            set: { navigator.changeTabSelection(to: $0) }
          )
        ) {
          NavigationLink(value: AppTab.explore) {
            AppTab.explore.label(isSelected: navigator.selectedTab == AppTab.explore)
          }
          
          NavigationLink(value: AppTab.plan) {
            AppTab.plan.label(isSelected: navigator.selectedTab == AppTab.plan)
          }
          
          NavigationLink(value: AppTab.bookmark) {
            AppTab.bookmark.label(isSelected: navigator.selectedTab == AppTab.bookmark)
          }
          
          NavigationLink(value: AppTab.statistics) {
            AppTab.statistics.label(isSelected: navigator.selectedTab == AppTab.statistics)
          }
          
          NavigationLink(value: AppTab.downloads) {
            AppTab.downloads.label(isSelected: navigator.selectedTab == AppTab.downloads)
          }
          
          NavigationLink(value: AppTab.settings) {
            AppTab.settings.label(isSelected: navigator.selectedTab == AppTab.settings)
          }
        }
      } detail: {
        ExploreView()
      }
      .tint(.accent)
      .accentColor(.accent)
      .navigationSplitViewStyle(.balanced)
    }
  }
}
