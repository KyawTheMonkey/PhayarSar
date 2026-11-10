import DesignKit
import Inject
import LocalisationKit
import SwiftUI

enum BeadsMaterialPickerMetrics {
  static let target: CGFloat = 44
  static let beadDiameter: CGFloat = 30
  static let selectionDiameter: CGFloat = 39
  static let selectionWidth: CGFloat = 1.5
  static let spacing: CGFloat = 6
}

/// The previews share the same finish as the strand above them. The name
/// stays readable even when two finishes look similar at thumbnail size.
struct BeadsMaterialPicker: View {
  @ObserveInjection private var injectionObserver
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Binding var material: BeadsMaterial

  var body: some View {
    VStack(alignment: .leading, spacing: AppListSectionMetrics.labelGap) {
      ViewThatFits(in: .horizontal) {
        HStack {
          title.fixedSize(horizontal: true, vertical: false)
          Spacer(minLength: BeadsMaterialPickerMetrics.spacing)
          selection.fixedSize(horizontal: true, vertical: false)
        }
        VStack(alignment: .leading, spacing: BeadsMaterialPickerMetrics.spacing) {
          title
          selection
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)

      if dynamicTypeSize.isAccessibilitySize {
        swatches(columns: 3)
      } else {
        ViewThatFits(in: .horizontal) {
          swatches(columns: BeadsMaterial.allCases.count)
          swatches(columns: 3)
        }
      }
    }
    .enableInjection()
  }

  private var title: some View {
    Text(L10n.beadsMaterial)
      .font(AppFont.headline)
  }

  private var selection: some View {
    Text(material.title)
      .font(AppFont.subheadline)
      .foregroundStyle(AppColor.textSecondary)
  }

  private func swatches(columns: Int) -> some View {
    let spacing = BeadsMaterialPickerMetrics.spacing
    let target = BeadsMaterialPickerMetrics.target
    let minimumWidth = target * CGFloat(columns) + spacing * CGFloat(columns - 1)
    return LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(minimum: target), spacing: spacing), count: columns),
      spacing: spacing
    ) {
      ForEach(BeadsMaterial.allCases) { option in
        swatch(option)
      }
    }
    .frame(minWidth: minimumWidth)
  }

  private func swatch(_ option: BeadsMaterial) -> some View {
    let isSelected = material == option
    return Button { material = option } label: {
      BeadsMaterialBead(
        material: option, diameter: BeadsMaterialPickerMetrics.beadDiameter,
        image: BeadsMaterialArtwork.image(for: option)
      )
      .frame(width: BeadsMaterialPickerMetrics.selectionDiameter, height: BeadsMaterialPickerMetrics.selectionDiameter)
      .overlay {
        if isSelected {
          Circle().strokeBorder(AppColor.primary, lineWidth: BeadsMaterialPickerMetrics.selectionWidth)
        }
      }
      .overlay(alignment: .bottomTrailing) {
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(AppColor.buttonPrimaryText, AppColor.primary)
            .font(AppFont.captionBold)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(minHeight: BeadsMaterialPickerMetrics.target)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(option.title)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
