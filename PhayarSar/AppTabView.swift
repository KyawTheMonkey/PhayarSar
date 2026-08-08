//
//  AppTabView.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 08/08/2026.
//

import EnvironmentKit
import SwiftUI

struct AppTabView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var selectedTab: EnvironmentKit.AppTab? = .home

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
    if useSplitView {
      splitView
    } else {
      tabStackView
    }
  }

  private var splitView: some View {
    NavigationSplitView {
      List(AppTab.allCases, selection: $selectedTab) { tab in
        tab.label(isSelected: selectedTab == tab)
          .tag(tab)
      }
      .navigationTitle("PhayarSar")
    } detail: {
      if let selectedTab {
        NavigationStack {
          Text(selectedTab.title)
            .navigationTitle(selectedTab.title)
        }
      } else {
        Text("Select a tab")
          .foregroundStyle(.secondary)
      }
    }
  }

  private var tabStackView: some View {
    TabView(
      selection: Binding(
        get: { selectedTab ?? .home },
        set: { selectedTab = $0 }
      )
    ) {
      ForEach(AppTab.allCases) { tab in
        NavigationStack {
          Text(tab.title)
            .navigationTitle(tab.title)
        }
        .tabItem {
          tab.label(isSelected: selectedTab == tab)
        }
        .tag(tab)
      }
    }
  }
}

#Preview {
  AppTabView()
}
