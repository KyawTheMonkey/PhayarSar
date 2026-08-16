import SwiftUI

/// A short sheet for choosing one of a handful of options.
///
/// ```swift
/// .sheet(isPresented: $isPickingTheme) {
///   AppOptionPickerSheet(
///     title: L10n.appearance,
///     options: Theme.allCases,
///     selection: $theme,
///     label: { $0.displayName },
///     systemImage: { $0.symbolName }
///   )
///   .presentationDetents([.height(AppOptionPickerMetrics.height(for: Theme.allCases.count))])
/// }
/// ```
///
/// A sheet rather than a `Menu` for settings rows: a menu opens over the row it
/// belongs to, sized to its own contents and dismissed by the next tap
/// anywhere. For a choice the user came to this screen to make, a sheet gives
/// the options room, a title saying what is being chosen, and a deliberate way
/// out. It also puts the options within thumb reach at the bottom of the screen
/// rather than wherever the row happened to be.
///
/// Selecting dismisses. There is no confirm button, because there is nothing to
/// confirm — the change has already happened behind the sheet, and every option
/// here is reversible by opening it again.
public struct AppOptionPickerSheet<Option: Hashable>: View {
  private let title: String
  private let options: [Option]
  private let label: (Option) -> String
  private let systemImage: (Option) -> String?

  @Binding private var selection: Option
  @Environment(\.dismiss) private var dismiss

  /// - Parameters:
  ///   - title: What is being chosen. Already localised.
  ///   - options: In the order they should appear. Keep it short — this is
  ///     sized for a handful, not a catalogue.
  ///   - selection: Written the moment a row is tapped.
  ///   - label: The localised name for an option.
  ///   - systemImage: Optional SF Symbol per option. Return `nil` throughout to
  ///     leave the icon column out entirely.
  public init(
    title: String,
    options: [Option],
    selection: Binding<Option>,
    label: @escaping (Option) -> String,
    systemImage: @escaping (Option) -> String? = { _ in nil }
  ) {
    self.title = title
    self.options = options
    self._selection = selection
    self.label = label
    self.systemImage = systemImage
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(title)
        .font(AppFont.title)
        .foregroundStyle(AppColor.textPrimary)
        .padding(.bottom, 8)
        .accessibilityAddTraits(.isHeader)

      ForEach(options, id: \.self) { option in
        row(for: option)
      }

      Spacer(minLength: 0)
    }
    .appHorizontalInset()
    .padding(.top, Metrics.topPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppColor.background.ignoresSafeArea())
  }

  private func row(for option: Option) -> some View {
    Button {
      selection = option
      dismiss()
    } label: {
      HStack(spacing: AppSettingsRowMetrics.iconSpacing) {
        if let systemImage = systemImage(option) {
          Image(systemName: systemImage)
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(isSelected(option) ? AppColor.primary : AppColor.textSecondary)
            .frame(width: AppSettingsRowMetrics.iconColumn)
        }

        Text(label(option))
          .font(AppFont.listItemTitle)
          .foregroundStyle(AppColor.textPrimary)

        Spacer(minLength: 8)

        // Kept in the layout when unselected so rows don't shift as the
        // selection moves between them.
        Image(systemName: "checkmark")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AppColor.primary)
          .opacity(isSelected(option) ? 1 : 0)
      }
      .padding(.vertical, AppSettingsRowMetrics.verticalPadding)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressableButtonStyle())
    .accessibilityAddTraits(isSelected(option) ? [.isButton, .isSelected] : .isButton)
  }

  private func isSelected(_ option: Option) -> Bool {
    option == selection
  }

  private typealias Metrics = AppOptionPickerMetrics
}

// MARK: - Sizing

/// How tall an ``AppOptionPickerSheet`` needs to be.
///
/// Separate from the sheet, and not generic, so a caller can size a detent
/// without naming the option type twice.
public enum AppOptionPickerMetrics {
  static let topPadding: CGFloat = 24
  /// Title line plus the gap under it.
  static let header: CGFloat = 36
  /// One row: a 17pt title between two lots of `verticalPadding`.
  static let row: CGFloat = 22 + AppSettingsRowMetrics.verticalPadding * 2
  /// Clears the home indicator without leaving a gap that reads as a mistake.
  static let bottom: CGFloat = 28

  /// The detent height that fits `count` options exactly.
  ///
  /// Computed rather than `.medium` so the sheet is as short as its contents —
  /// a half-screen sheet holding three rows looks like something failed to
  /// load. Pass it to `presentationDetents(_:)`.
  public static func height(for count: Int) -> CGFloat {
    topPadding + header + CGFloat(count) * row + bottom
  }
}

// MARK: - Previews

#Preview("Three options") {
  AppOptionPickerSheetPreview()
}

private struct AppOptionPickerSheetPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  @State private var theme: Theme = .system

  var body: some View {
    Color.clear
      .sheet(isPresented: .constant(true)) {
        AppOptionPickerSheet(
          title: "Appearance",
          options: Theme.allCases,
          selection: $theme,
          label: { String(describing: $0).capitalized },
          systemImage: { theme in
            switch theme {
            case .system: return "iphone"
            case .light: return "sun.max"
            case .dark: return "moon"
            }
          }
        )
        #if os(iOS)
        .presentationDetents([.height(AppOptionPickerMetrics.height(for: Theme.allCases.count))])
        .presentationDragIndicator(.visible)
        #endif
      }
  }
}
