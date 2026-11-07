import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI

public enum BeadsCreatorMetrics {
  public static let verticalPadding: CGFloat = 24
  public static let maxWidth: CGFloat = 520
}

/// Draft fields stay local; only a successful save dismisses the sheet. Cancel
/// and swipe-to-dismiss leave the saved collection alone.
public struct BeadsCreatorScreen: View {
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var navigator: AppNavigatorModel
  @State private var draftID = UUID()
  @State private var name = ""
  @State private var count = Beads.defaultCount
  @State private var isValidCount = true
  @State private var didFailToSave = false

  public init() {}

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
        VStack(spacing: 0) {
          BeadsStrandView(count: count)
          BeadsCountPicker(count: $count, isValid: $isValidCount)
        }
        .appHorizontalInset()

        AppListSection(L10n.beadsName) {
          TextField(L10n.beadsNamePlaceholder, text: $name)
            .accessibilityLabel(L10n.beadsName)
        }
        if didFailToSave {
          Text(L10n.beadsSaveError)
            .font(AppFont.subheadline)
            .foregroundStyle(AppColor.error)
            .appHorizontalInset()
        }
        AppButton(L10n.beadsAdd, systemImage: "plus", action: save)
          .disabled(trimmedName.isEmpty || !isValidCount)
          .opacity(trimmedName.isEmpty || !isValidCount ? 0.5 : 1)
          .appHorizontalInset()
      }
      .font(AppFont.body)
      .foregroundStyle(AppColor.textPrimary)
      .padding(.vertical, BeadsCreatorMetrics.verticalPadding)
      .frame(maxWidth: BeadsCreatorMetrics.maxWidth)
      .frame(maxWidth: .infinity)
    }
    .appBackground()
    .navigationTitle(L10n.beadsAdd)
    .creatorNavigationTitle()
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(L10n.cancel) { navigator.dismissSheet() }
          .font(AppFont.body)
      }
    }
    .enableInjection()
  }

  private func save() {
    guard !trimmedName.isEmpty, isValidCount, Beads.countRange.contains(count) else { return }
    do {
      try BeadsStore.shared.add(id: draftID, name: trimmedName, count: count)
      navigator.dismissSheet()
    } catch {
      didFailToSave = true
    }
  }
}

private extension View {
  @ViewBuilder
  func creatorNavigationTitle() -> some View {
    #if os(iOS)
    navigationBarTitleDisplayMode(.inline)
    #else
    self
    #endif
  }
}

// MARK: - Previews

#Preview {
  BeadsCreatorPreview()
}

private struct BeadsCreatorPreview: View {
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    NavigationStack {
      BeadsCreatorScreen()
    }
    .environmentObject(AppNavigatorModel())
  }
}
