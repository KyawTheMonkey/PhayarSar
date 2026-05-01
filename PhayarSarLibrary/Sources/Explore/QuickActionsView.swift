import DesignKit
import Inject
import SwiftUI

struct QuickActionsView: View {
  @ObserveInjection private var injectionObserver

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("Quick Actions".uppercased())
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.leading)
      
      VStack(alignment: .leading) {
        Row(title: "Bookmark", systemImage: "bookmark.fill", hasDivier: true)
        Row(title: "Statistics", systemImage: "chart.bar.fill", hasDivier: true)
        Row(title: "Downloads", systemImage: "square.and.arrow.down.fill", hasDivier: false)
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: 18)
          .fill(AppColor.card)
          .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 0)
      }
    }
    .padding(.top)

    .enableInjection()
  }
  
  @ViewBuilder
  private func Row(title: String, systemImage: String, hasDivier: Bool) -> some View {
    HStack {
      Label {
        Text(title)
      } icon: {
        Image(systemName: systemImage)
          .foregroundStyle(Color.accentColor)
      }
      
      Spacer()
      
      Image(systemName: "chevron.right")
        .foregroundStyle(.secondary)
    }
    .padding(.bottom, hasDivier ? 10 : 0)
    .overlay(alignment: .bottom) {
      if hasDivier {
        Divider()
          .padding(.leading, 25)
      }
    }
  }
}
