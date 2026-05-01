import DesignKit
import EnvironmentKit
import Inject
import SwiftUI

public struct ExploreView: View {
  @EnvironmentObject var navigator: AppNavigatorModel
  @ObserveInjection var inject
  @Environment(\.colorScheme) var colorScheme
  
  public init() {}

  public var body: some View {
    NavigationStack(path: $navigator.path) {
      List {
        Section("Quick actions") {
          NavigationLink(value: "prayers") {
            Label("All Prayers", systemImage: "books.vertical")
              .font(AppFont.bodySemibold)
          }
          
          NavigationLink(value: "audios") {
            Label("Chantings", systemImage: "music.note.list")
              .font(AppFont.bodySemibold)
          }
        }
        .listRowBackground(AppColor.card)
      }
      .scrollContentBackground(.hidden)
      .background(AppColor.background)
      .safeAreaInset(edge: .top) {
        headerView()
      }
      .enableInjection()
    }
  }
  
  @ViewBuilder
  private func headerView() -> some View {
    HStack {
      VStack(alignment: .leading) {
        Text("PhayarSar")
          .font(AppFont.largeTitle)
        Text("Buddhist Prayers App")
          .font(.caption.weight(.semibold))
          .foregroundStyle(AppColor.textSecondary)
      }
      
      Spacer()
      
      if #available(iOS 26, *) {
        
      } else {
        searchBar()
      }
    }
    .foregroundStyle(AppColor.textPrimary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background {
      AppColor.background.ignoresSafeArea()
    }
  }
  
  @ViewBuilder
  private func searchBar() -> some View {
    Capsule()
      .fill(AppColor.searchBarBackground)
      .overlay {
        Capsule()
          .strokeBorder(
            colorScheme == .light ? AppColor.border : Color.secondary.opacity(0.7),
            lineWidth: 0.7
          )
      }
      .shadow(
        color: colorScheme == .light ? .black.opacity(0.05) : .secondary.opacity(0.2),
        radius: 10, x: 1, y: 0
      )
      .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
      .frame(
        width: Constants.SearchBar.size.width,
        height: Constants.SearchBar.size.height
      )
      .overlay {
        HStack(spacing: 12) {
          Text("Search")
            .font(AppFont.body.weight(.medium))
          Image(systemName: "magnifyingglass")
        }
        .font(AppFont.headline)
        .foregroundStyle(.secondary)
      }
  }
}

// MARK: - Private Helper

private extension ExploreView {
  enum Constants {
    enum SearchBar {
      static let size: CGSize = .init(width: 126, height: 56)
    }
  }
}
