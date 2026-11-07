import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI

public enum BeadsScreenMetrics {
  public static let verticalPadding: CGFloat = 24
}

/// Uses the shared empty state inside a scrollable viewport so large Burmese
/// type can grow without pushing the action offscreen.
public struct BeadsScreen: View {
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var navigator: AppNavigatorModel
  @ObservedObject private var store = BeadsStore.shared

  public init() {}

  public var body: some View {
    Group {
      if store.didFailToLoad {
        AppEmptyStateView(
          systemImage: "exclamationmark.circle",
          title: L10n.beadsLoadError,
          actionTitle: L10n.beadsTryAgain,
          action: store.reload
        )
        .appHorizontalInset()
      } else if store.beads.isEmpty {
        GeometryReader { proxy in
          ScrollView {
            AppEmptyStateView(
              systemImage: "circle.hexagonpath",
              title: L10n.beadsEmptyTitle,
              message: L10n.beadsEmptyMessage,
              actionTitle: L10n.beadsAdd,
              action: addBeads
            )
            .appHorizontalInset()
            .frame(minHeight: proxy.size.height)
          }
        }
      } else {
        ScrollView {
          VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
            AppListSection {
              ForEach(store.beads) { beads in
                VStack(alignment: .leading, spacing: AppCardMetrics.contentSpacing) {
                  Text(beads.name)
                    .font(AppFont.listItemTitle)
                    .foregroundStyle(AppColor.textPrimary)
                  Text(Beads.countLabel(for: beads.count))
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                }
                .padding(.vertical, AppListSectionMetrics.labelGap)
                .accessibilityElement(children: .combine)

                if beads.id != store.beads.last?.id {
                  AppDivider()
                }
              }
            }
            AppButton(L10n.beadsAdd, systemImage: "plus", action: addBeads)
              .appHorizontalInset()
          }
          .padding(.vertical, BeadsScreenMetrics.verticalPadding)
        }
      }
    }
    .appBackground()
    .onAppear { store.reload() }
    .enableInjection()
  }

  private func addBeads() {
    navigator.present(.beadsCreator)
  }
}

// MARK: - Previews

#Preview("Empty") {
  BeadsScreenPreview()
}

private struct BeadsScreenPreview: View {
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    NavigationStack {
      BeadsScreen()
        .navigationTitle(AppTab.beads.title)
    }
    .environmentObject(AppNavigatorModel())
  }
}
