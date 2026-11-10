import DesignKit
import Inject
import SwiftUI

private enum HomeContinueCardMetrics {
  static let spacing: CGFloat = 12
  static let coverSize: CGFloat = 48
  static let coverCornerRadius: CGFloat = 16
  static let textSpacing: CGFloat = 2
  static let progressTopPadding: CGFloat = 4
  static let progressHeight: CGFloat = 5
}

struct HomeContinueCard<Artwork: View>: View {
  @ObserveInjection private var injectionObserver
  let title: String
  let summary: String
  let fraction: Double
  let onTap: () -> Void
  @ViewBuilder let artwork: () -> Artwork

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: HomeContinueCardMetrics.spacing) {
        artwork()
          .frame(width: HomeContinueCardMetrics.coverSize, height: HomeContinueCardMetrics.coverSize)
          .clipShape(RoundedRectangle(cornerRadius: HomeContinueCardMetrics.coverCornerRadius))
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: HomeContinueCardMetrics.textSpacing) {
          Text(title)
            .font(AppFont.listItemTitle)
            .foregroundStyle(AppColor.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)

          Text(summary)
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

          GeometryReader { proxy in
            Capsule()
              .fill(AppColor.grey300)
              .overlay(alignment: .leading) {
                Capsule()
                  .fill(AppColor.primary)
                  .frame(width: proxy.size.width * min(max(fraction, 0), 1))
              }
          }
          .frame(height: HomeContinueCardMetrics.progressHeight)
          .padding(.top, HomeContinueCardMetrics.progressTopPadding)
          .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .foregroundStyle(AppColor.primary)
          .accessibilityHidden(true)
      }
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .enableInjection()
  }
}
