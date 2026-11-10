import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI

public enum BeadsScreenMetrics {
  public static let rowSpacing: CGFloat = 4
}

/// A native list owns swipe actions and row accessibility. The empty state
/// keeps its prominent Add action; saved sets move that action into the bar.
public struct BeadsScreen: View {
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var navigator: AppNavigatorModel
  @ObservedObject private var store = BeadsStore.shared
  @State private var didFailToDelete = false

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
        beadsList
      }
    }
    .appBackground()
    .toolbar {
      if !store.beads.isEmpty {
        ToolbarItem(placement: .primaryAction) {
          Button(action: addBeads) {
            Image(systemName: "plus")
          }
          .accessibilityLabel(L10n.beadsAdd)
        }
      }
    }
    .alert(L10n.deleteFailed, isPresented: $didFailToDelete) {
      Button(L10n.done, role: .cancel) {}
    }
    .onAppear { store.reload() }
    .enableInjection()
  }

  private var beadsList: some View {
    List {
      Section {
        ForEach(store.beads) { beads in
          Button {
            navigator.navigate(to: .beadsSession(beadsID: beads.id))
          } label: {
            HStack(spacing: AppSettingsRowMetrics.iconSpacing) {
              VStack(alignment: .leading, spacing: BeadsScreenMetrics.rowSpacing) {
                Text(beads.name)
                  .font(AppFont.listItemTitle)
                  .foregroundStyle(AppColor.textPrimary)
                  .fixedSize(horizontal: false, vertical: true)
                Text(L10n.beadsListSummary(
                  .init(stringLiteral: Beads.countLabel(for: beads.count)),
                  .init(stringLiteral: Beads.roundsLabel(for: beads.rounds))
                ))
                  .font(AppFont.subheadline)
                  .foregroundStyle(AppColor.textSecondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer(minLength: 0)
              Image(systemName: "chevron.right")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textTertiary)
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .listRowInsets(AppListSectionMetrics.contentInsets)
          .listRowBackground(AppColor.surface)
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { deleteBeads(id: beads.id) } label: {
              Label(L10n.delete, systemImage: "trash")
            }
            Button {
              navigator.navigate(to: .beadsEditor(beadsID: beads.id))
            } label: {
              Label(L10n.beadsEdit, systemImage: "pencil")
            }
          }
        }
      }
    }
    #if os(iOS)
    .listStyle(.insetGrouped)
    #else
    .listStyle(.inset)
    #endif
    .scrollContentBackground(.hidden)
  }

  private func deleteBeads(id: UUID) {
    do {
      try store.delete(id: id)
    } catch {
      didFailToDelete = true
    }
  }

  private func addBeads() {
    navigator.present(.beadsCreator())
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
