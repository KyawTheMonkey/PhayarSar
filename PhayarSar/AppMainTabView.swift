import EnvironmentKit
import Explore
import SwiftUI

struct AppMainTabView: View {
  @EnvironmentObject var navigator: AppNavigatorModel
  @State private var searchQuery = ""

  var body: some View {
    if #available(iOS 26.0, *) {
      TabView_iOS26()
    } else if #available(iOS 18.0, *) {
      TabView_iOS18()
    } else {
      TabView_Old()
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
        AppTab.explore.label
      }

      Tab(value: AppTab.plan) {} label: {
        AppTab.plan.label
      }

      Tab(value: AppTab.settings) {} label: {
        AppTab.settings.label
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
      Tab(value: AppTab.explore) {} label: {
        AppTab.explore.label
      }

      Tab(value: AppTab.plan) {} label: {
        AppTab.plan.label
      }

      Tab(value: AppTab.settings) {} label: {
        AppTab.settings.label
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
      Text("Explore")
        .tabItem {
          AppTab.explore.label
        }
        .tag(AppTab.explore)

      Text("Plan")
        .tabItem {
          AppTab.plan.label
        }
        .tag(AppTab.plan)

      Text("Settings")
        .tabItem {
          AppTab.settings.label
        }
        .tag(AppTab.settings)
    }
  }
}

#Preview {
  AppMainTabView()
    .withPreviewsEnv()
}
