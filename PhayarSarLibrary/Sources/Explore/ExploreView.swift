import DesignKit
import EnvironmentKit
import Inject
import SwiftUI

public struct ExploreView: View {
  @EnvironmentObject var navigator: AppNavigatorModel
  @ObserveInjection var inject

  public init() {}

  public var body: some View {
    NavigationStack(path: self.$navigator.path) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {
          if #unavailable(iOS 26) {
            ExploreNavView()
            
            QuickActionsView()
          }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollContentBackground(.hidden)
      .background(AppColor.background)
      .navTitle_iOS26()
      .toolbar {
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
}

private extension View {
  @ViewBuilder func navTitle_iOS26() -> some View {
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
