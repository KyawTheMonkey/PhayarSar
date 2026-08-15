//
//  AppTabView.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 08/08/2026.
//

import DesignKit
import EnvironmentKit
import HomeKit
import SettingsKit
import SwiftUI

struct AppTabView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @EnvironmentObject private var navigator: AppNavigatorModel

  /// Mac always gets the split view. On iOS/iPadOS we key off the
  /// horizontal size class so it adapts live to iPad multitasking,
  /// rotation, etc. — regular resolves to a split view, compact (iPhone,
  /// or a slid-over/compact iPad) resolves to a tab-bar + nav stack.
  private var useSplitView: Bool {
    #if os(macOS)
    true
    #else
    horizontalSizeClass == .regular
    #endif
  }

  var body: some View {
    Group {
      if useSplitView {
        splitView
      } else {
        tabStackView
      }
    }
    .tint(DesignKit.AppColor.primary)
    // On the outermost view rather than inside a stack, so a sheet presents
    // above the tab bar instead of within whichever tab happened to open it.
    .sheet(item: $navigator.presentedSheet) { destination in
      SheetView(destination: destination)
    }
  }

  private var splitView: some View {
    NavigationSplitView {
      // `NavigationSplitView` insists on an optional selection, but the rest
      // of the app relies on a tab always being selected — so the optionality
      // is adapted here and nowhere else.
      List(
        AppTab.allCases,
        selection: Binding(
          get: { navigator.selectedTab },
          set: { navigator.selectedTab = $0 ?? navigator.selectedTab }
        )
      ) { tab in
        tab.label(isSelected: navigator.selectedTab == tab)
          .tag(tab)
      }
      .navigationTitle("PhayarSar")
    } detail: {
      NavigationStack(path: navigator.path(for: navigator.selectedTab)) {
        content(for: navigator.selectedTab)
          .navigationTitle(navigator.selectedTab.title)
          .navigationDestination(for: RouterDestination.self) { destination in
            RouteView(destination: destination)
          }
      }
    }
  }

  private var tabStackView: some View {
    TabView(selection: $navigator.selectedTab) {
      ForEach(AppTab.allCases) { tab in
        NavigationStack(path: navigator.path(for: tab)) {
          content(for: tab)
            .navigationTitle(tab.title)
            .navigationDestination(for: RouterDestination.self) { destination in
              RouteView(destination: destination)
            }
        }
        .tabItem {
          tab.label(isSelected: navigator.selectedTab == tab)
        }
        .tag(tab)
      }
    }
    .tint(DesignKit.AppColor.primary)
  }

  @ViewBuilder
  private func content(for tab: AppTab) -> some View {
    switch tab {
    case .home:
      HomeScreen()
    case .settings:
      SettingsScreen()
    default:
      Text(tab.title)
    }
  }
}

#Preview {
  AppTabView()
    .environmentObject(AppNavigatorModel())
}
