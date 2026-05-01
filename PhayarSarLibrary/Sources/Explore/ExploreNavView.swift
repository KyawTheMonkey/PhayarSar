import DesignKit
import Inject
import SwiftUI

struct ExploreNavView: View {
  @Environment(\.colorScheme) private var colorScheme
  @ObserveInjection private var injectionObserver
  @State private var blurRadius: CGFloat = 0
  
  var body: some View {
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
    .padding(.top, 30)
    .background {
      AppColor.background.ignoresSafeArea()
    }
    .enableInjection()
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
      .frame(width: 126, height: 56)
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
