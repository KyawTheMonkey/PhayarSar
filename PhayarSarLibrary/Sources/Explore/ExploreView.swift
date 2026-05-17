import DesignKit
import EnvironmentKit
import Inject
import SwiftUI
import SwiftUIX

public struct ExploreView: View {
  @Environment(\.userInterfaceIdiom) var uii
  @EnvironmentObject var navigator: AppNavigatorModel
  @ObserveInjection var inject

  public init() {}

  public var body: some View {
    NavigationStack(path: self.$navigator.path) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {
          customNavAndQuickActionsForPhone()
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollContentBackground(.hidden)
      .background(AppColor.background)
      .customNavTitle(isIpad: uii == .pad)
      .toolbar {
        if uii == .phone {
          if #available(iOS 26, *) {
            ToolbarItem(placement: .topBarLeading) {
              Menu {
                Button {} label: {
                  Label("Bookmark", systemImage: "bookmark.fill")
                }
                
                Button {} label: {
                  Label("Statistics", systemImage: "chart.bar.fill")
                }
                
                Button {} label: {
                  Label("Downloads", systemImage: "square.and.arrow.down.fill")
                }
                
                Divider()
                
                Section {
                  Button {} label: {
                    Label("Scroll to top", systemImage: "arrow.up.circle.fill")
                  }
                } header: {
                  Text("Quick actions")
                }
              } label: {
                Image(systemName: "line.3.horizontal")
                  .fontWeight(.bold)
              }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
              Button {} label: {
                Text("Sign in")
              }
            }
          }
        } else {
          ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Search", systemImage: "magnifyingglass") {
              
            }
            .fontWeight(.semibold)
          }
        }
      }
      .tint(AppColor.accent)
      .enableInjection()
    }
    .overlay(alignment: .top) {
      if #unavailable(iOS 26) {
        Rectangle()
          .fill(
            LinearGradient(
              colors: [AppColor.background, AppColor.background.opacity(0.9), AppColor.background.opacity(0.1)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(maxWidth: .infinity)
          .frame(height: 90)
          .ignoresSafeArea()
      }
    }
  }
  
  @ViewBuilder
  private func customNavAndQuickActionsForPhone() -> some View {
    if #unavailable(iOS 26) {
      if uii == .phone {
        ExploreNavView()
        
        QuickActionsView()
      }
    }
  }
}

private extension View {
  @ViewBuilder func customNavTitle(isIpad: Bool) -> some View {
    if isIpad {
      self.navigationTitle("PhayarSar")
    } else {
      if #available(iOS 26, *) {
        self.navigationTitle("PhayarSar")
      } else if #available(iOS 18, *) {
        self
          .toolbarVisibility(.hidden, for: .navigationBar)
      } else {
        self.navigationBarHidden(true)
      }
    }
  }
}
