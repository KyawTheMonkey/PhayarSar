import AuthKit
import DesignKit
import EnvironmentKit
import LocalisationKit
import SwiftUI

private enum HomeToolbarMetrics {
  static let ringSize: CGFloat = 24
  static let ringLineWidth: CGFloat = 2
  static let ringProgress: CGFloat = 0.64
  static let ringValue = 12
}

/// Separate toolbar items let the system own spacing, hit targets and glass.
/// The profile remains a sheet so returning to Home preserves its scroll.
struct HomeToolbar: ToolbarContent {
  @EnvironmentObject private var navigator: AppNavigatorModel

  var body: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Button {} label: {
        Circle()
          .strokeBorder(AppColor.border, lineWidth: HomeToolbarMetrics.ringLineWidth)
          .overlay {
            Circle()
              .trim(from: 0, to: HomeToolbarMetrics.ringProgress)
              .stroke(
                AppColor.primary,
                style: StrokeStyle(lineWidth: HomeToolbarMetrics.ringLineWidth, lineCap: .round)
              )
              .rotationEffect(.degrees(-90))
          }
          .overlay {
            Text(HomeToolbarMetrics.ringValue, format: .number)
              .font(AppFont.caption)
              .foregroundStyle(AppColor.primary)
          }
          .frame(width: HomeToolbarMetrics.ringSize, height: HomeToolbarMetrics.ringSize)
      }

      Button {} label: {
        Image(systemName: "magnifyingglass")
      }
      .accessibilityLabel(L10n.homeSearch)

      Button {
        navigator.present(.profile)
      } label: {
        ProfileAvatarView()
      }
      .accessibilityLabel(L10n.profile)
    }
  }
}
