import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI

public enum BeadsCreatorMetrics {
  public static let verticalPadding: CGFloat = 24
  public static let maxWidth: CGFloat = 520
}

/// Draft fields stay local until Save. Adding dismisses its sheet; editing
/// returns to the list. Back and sheet dismissal leave saved data alone.
public struct BeadsCreatorScreen: View {
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var navigator: AppNavigatorModel
  @EnvironmentObject private var recitationDraft: BeadsRecitationDraft
  @State private var draftID = UUID()
  @State private var name = ""
  @State private var count = Beads.defaultCount
  @State private var material: BeadsMaterial = .defaultMaterial
  @State private var isValidCount = true
  @State private var rounds = Beads.defaultRounds
  @State private var isValidRounds = true
  @State private var didFailToSave = false
  @State private var didFailToDelete = false
  private let beadsID: UUID?

  public init(beadsID: UUID? = nil) {
    self.beadsID = beadsID
    if let beadsID, let beads = BeadsStore.shared.beads.first(where: { $0.id == beadsID }) {
      _name = State(initialValue: beads.name)
      _count = State(initialValue: beads.count)
      _rounds = State(initialValue: beads.rounds)
      _material = State(initialValue: beads.material)
    }
  }

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSave: Bool {
    !trimmedName.isEmpty && isValidCount && isValidRounds && recitationDraft.recitation != nil
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
        VStack(spacing: 0) {
          BeadsStrandView(count: count, material: material)
          BeadsMaterialPicker(material: $material)
            .padding(.bottom, AppListSectionMetrics.recommendedSectionSpacing)
          BeadsCountPicker(count: $count, isValid: $isValidCount)
        }
        .appHorizontalInset()

        AppListSection(L10n.beadsName) {
          TextField(L10n.beadsNamePlaceholder, text: $name)
            .accessibilityLabel(L10n.beadsName)
        }
        BeadsRecitationSection()
        BeadsRoundsPicker(rounds: $rounds, isValid: $isValidRounds)
        if didFailToSave {
          Text(L10n.beadsSaveError)
            .font(AppFont.subheadline)
            .foregroundStyle(AppColor.error)
            .appHorizontalInset()
        }
        AppButton(
          beadsID == nil ? L10n.beadsAdd : L10n.beadsSaveChanges,
          systemImage: beadsID == nil ? "plus" : "checkmark", action: save
        )
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.5)
        .appHorizontalInset()
        if beadsID != nil {
          AppButton(L10n.beadsDelete, systemImage: "trash", kind: .destructive, action: delete)
            .appHorizontalInset()
        }
      }
      .font(AppFont.body)
      .foregroundStyle(AppColor.textPrimary)
      .padding(.vertical, BeadsCreatorMetrics.verticalPadding)
      .frame(maxWidth: BeadsCreatorMetrics.maxWidth)
      .frame(maxWidth: .infinity)
    }
    .appKeyboardDismissal()
    .appBackground()
    .navigationTitle(beadsID == nil ? L10n.beadsAdd : L10n.beadsEdit)
    .creatorNavigationTitle()
    .toolbar {
      if beadsID == nil {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.cancel) { navigator.dismissSheet() }
            .font(AppFont.body)
        }
      }
    }
    .onAppear {
      if let beadsID { recitationDraft.prepareToEdit(beadsID: beadsID) }
    }
    .alert(L10n.deleteFailed, isPresented: $didFailToDelete) {
      Button(L10n.done, role: .cancel) {}
    }
    .enableInjection()
  }

  private func save() {
    guard !trimmedName.isEmpty, isValidCount, isValidRounds,
          Beads.countRange.contains(count), Beads.roundsRange.contains(rounds),
          let recitation = recitationDraft.recitation
    else { return }
    do {
      if let beadsID {
        try BeadsStore.shared.update(
          id: beadsID, name: trimmedName, count: count, rounds: rounds, material: material, recitation: recitation
        )
      } else {
        try BeadsStore.shared.add(
          id: draftID, name: trimmedName, count: count, rounds: rounds, material: material, recitation: recitation
        )
      }
      finish()
    } catch {
      didFailToSave = true
    }
  }

  private func finish() {
    if beadsID != nil {
      navigator.pop()
    } else {
      navigator.dismissSheet()
    }
  }

  private func delete() {
    guard let beadsID else { return }
    do {
      try BeadsStore.shared.delete(id: beadsID)
      finish()
    } catch {
      didFailToDelete = true
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
    BeadsCreatorContext {
      NavigationStack {
        BeadsCreatorScreen()
      }
    }
    .environmentObject(AppNavigatorModel())
  }
}
