import DesignKit
import Inject
import LocalisationKit
import SwiftUI

enum BeadsCountPickerMetrics {
  static let controlSize: CGFloat = 52
  static let numberWidth: CGFloat = 128
  static let numberSize: CGFloat = 40
  static let presets = [9, 27, 108]
  static let spacing: CGFloat = 20
}

struct BeadsCountPicker: View {
  @ObserveInjection private var injectionObserver
  @Binding var count: Int
  @Binding var isValid: Bool
  @State private var enteredCount: String
  @FocusState private var isEditingCount: Bool

  init(count: Binding<Int>, isValid: Binding<Bool>) {
    _count = count
    _isValid = isValid
    _enteredCount = State(initialValue: String(count.wrappedValue))
  }

  private var countLabel: String {
    Beads.countLabel(for: count)
  }

  var body: some View {
    VStack(spacing: BeadsCountPickerMetrics.spacing) {
      VStack(spacing: AppCardMetrics.contentSpacing) {
        HStack(spacing: AppCardMetrics.spacing) {
          adjustmentButton(systemImage: "minus", title: L10n.beadsRemoveOne, delta: -1)

          TextField(L10n.beadsCount, text: $enteredCount)
            .font(AppFont.lora(size: BeadsCountPickerMetrics.numberSize))
            .foregroundStyle(AppColor.textPrimary)
            .multilineTextAlignment(.center)
            .frame(width: BeadsCountPickerMetrics.numberWidth)
            .focused($isEditingCount)
            .countKeyboard()
            .accessibilityLabel(L10n.beadsCount)
            .accessibilityIdentifier("beads.count")
            .accessibilityAdjustableAction { direction in
              switch direction {
              case .increment: adjust(by: 1)
              case .decrement: adjust(by: -1)
              @unknown default: break
              }
            }

          adjustmentButton(systemImage: "plus", title: L10n.beadsAddOne, delta: 1)
        }

        Text(L10n.beadsCount)
          .font(AppFont.subheadline)
          .foregroundStyle(AppColor.textSecondary)
      }

      AppSegmentedPicker(
        selection: Binding(
          get: { count },
          set: { value in
            setCount(value)
          }
        ),
        items: BeadsCountPickerMetrics.presets
      ) { preset in
        Text(preset.formatted())
          .accessibilityLabel(Beads.countLabel(for: preset))
          .accessibilityIdentifier("beads.preset.\(preset)")
      }

      if !isValid {
        Text(L10n.beadsCountHint)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.error)
          .multilineTextAlignment(.center)
      }

      if isValid, count > BeadsStrandMetrics.maximumVisibleBeads {
        Text(L10n.beadsPreviewCount(
          .init(stringLiteral: BeadsStrandMetrics.maximumVisibleBeads.formatted()),
          .init(stringLiteral: count.formatted())
        ))
        .font(AppFont.caption)
        .foregroundStyle(AppColor.textSecondary)
        .multilineTextAlignment(.center)
      }
    }
    .onChange(of: enteredCount) { value in
      let parsed = parsedCount(value)
      isValid = parsed != nil
      if let parsed { count = parsed }
    }
    .enableInjection()
  }

  private func adjustmentButton(systemImage: String, title: String, delta: Int) -> some View {
    let isDisabled = delta < 0 ? count <= Beads.countRange.lowerBound : count >= Beads.countRange.upperBound
    return Button {
      adjust(by: delta)
    } label: {
      Image(systemName: systemImage)
        .font(AppFont.title)
        .foregroundStyle(AppColor.primary)
        .frame(width: BeadsCountPickerMetrics.controlSize, height: BeadsCountPickerMetrics.controlSize)
        .background(AppColor.primarySoft, in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(PressableButtonStyle())
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.4 : 1)
    .accessibilityLabel(title)
    .accessibilityValue(countLabel)
    .accessibilityIdentifier(delta > 0 ? "beads.increment" : "beads.decrement")
  }

  private func adjust(by delta: Int) {
    setCount(count + delta)
  }

  private func setCount(_ value: Int) {
    isEditingCount = false
    count = min(max(value, Beads.countRange.lowerBound), Beads.countRange.upperBound)
    enteredCount = String(count)
    isValid = true
  }

  /// Preserve invalid draft text so it can be corrected, while the illustration
  /// keeps the last valid strand and Save stays unavailable. Burmese digits
  /// follow the same path as Latin digits, including pasted counts.
  private func parsedCount(_ input: String) -> Int? {
    let digits = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !digits.isEmpty, digits.allSatisfy({ $0.wholeNumberValue != nil }) else { return nil }
    let normalized = digits.compactMap(\.wholeNumberValue).map(String.init).joined()
    guard let value = Int(normalized), Beads.countRange.contains(value) else { return nil }
    return value
  }
}

private extension View {
  @ViewBuilder
  func countKeyboard() -> some View {
    #if os(iOS)
    keyboardType(.numberPad)
      .submitLabel(.done)
    #else
    self
    #endif
  }
}
