import DesignKit
import Inject
import SwiftUI

struct QuickActionsView: View {
  @ObserveInjection private var injectionObserver
  @State private var isQuickActionsShowing = true
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      quickActionHeaderView()
      
      if isQuickActionsShowing {
        VStack(alignment: .leading, spacing: 12) {
          Row(title: "Bookmark", systemImage: "bookmark.fill", hasDivier: true)
          Row(title: "Statistics", systemImage: "chart.bar.fill", hasDivier: true)
          Row(title: "Downloads", systemImage: "square.and.arrow.down.fill", hasDivier: false)
        }
        .padding([.horizontal, .bottom])
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .clipShape(RoundedRectangle(cornerRadius: 18))
    .background {
      RoundedRectangle(cornerRadius: 18)
        .fill(AppColor.card)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 0)
    }
    .padding(.top)
    .enableInjection()
  }
  
  @ViewBuilder fileprivate func quickActionHeaderView() -> some View {
    HStack {
      Text("Quick Actions")
        .font(AppFont.caption)
        .fontWeight(.semibold)
      Spacer()
      Image(systemName: isQuickActionsShowing ? "xmark" : "line.3.horizontal")
        .contentTransition_iOS17()
    }
    .font(.caption)
    .padding([.horizontal])
    .padding([.vertical], 12)
    .background(AppColor.searchBarBackground)
    .overlay(alignment: .bottom) {
      if isQuickActionsShowing {
        Divider()
      }
    }
    .contentShape(.rect)
    .onTapGesture {
      withAnimation(.smooth) {
        isQuickActionsShowing.toggle()
      }
    }
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
          .padding(.leading, 28)
          .padding(.trailing, -18)
      }
    }
  }
}

extension View {
  @ViewBuilder fileprivate func contentTransition_iOS17() -> some View{
    if #available(iOS 17, *) {
      contentTransition(.symbolEffect(.replace))
    } else {
      self
    }
  }
}
