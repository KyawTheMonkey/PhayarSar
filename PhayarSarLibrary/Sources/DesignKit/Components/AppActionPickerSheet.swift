import SwiftUI

/// A short sheet offering a handful of one-shot actions.
///
/// ```swift
/// .sheet(isPresented: $isFollowing) {
///   AppActionPickerSheet(
///     title: L10n.followDeveloper,
///     options: DeveloperLink.allCases,
///     label: \.displayName,
///     systemImage: \.symbolName,
///     action: { openURL($0.url) }
///   )
///   .presentationDetents([.height(AppOptionPickerMetrics.height(for: DeveloperLink.allCases.count))])
/// }
/// ```
///
/// The sibling of ``AppOptionPickerSheet``, and deliberately the same shape: a
/// title, a run of rows, one tap to finish. The difference is that nothing here
/// is a setting — there is no current value, so no row is ticked, and each row
/// carries the accessory of whatever it is about to do instead.
///
/// Tapping runs the action and dismisses. Nothing is remembered, so there is
/// nothing to confirm.
public struct AppActionPickerSheet<Option: Hashable>: View {
  private let title: String
  private let options: [Option]
  private let label: (Option) -> String
  private let systemImage: (Option) -> String?
  private let accessory: AppSettingsRowAccessory
  private let action: (Option) -> Void

  @Environment(\.dismiss) private var dismiss

  /// - Parameters:
  ///   - title: What the list is for. Already localised.
  ///   - options: In the order they should appear. Keep it short — this is
  ///     sized for a handful, not a catalogue.
  ///   - label: The localised name for an option.
  ///   - systemImage: Optional SF Symbol per option. Return `nil` throughout to
  ///     leave the icon column out entirely.
  ///   - accessory: What every row promises. Defaults to
  ///     ``AppSettingsRowAccessory/externalLink``, since a list of actions
  ///     small enough for this sheet is usually a list of places to go.
  ///   - action: Run on tap, just before the sheet dismisses.
  public init(
    title: String,
    options: [Option],
    label: @escaping (Option) -> String,
    systemImage: @escaping (Option) -> String? = { _ in nil },
    accessory: AppSettingsRowAccessory = .externalLink,
    action: @escaping (Option) -> Void
  ) {
    self.title = title
    self.options = options
    self.label = label
    self.systemImage = systemImage
    self.accessory = accessory
    self.action = action
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
    .padding(.top, AppOptionPickerMetrics.topPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppColor.background.ignoresSafeArea())
  }

  private func row(for option: Option) -> some View {
    Button {
      action(option)
      dismiss()
    } label: {
      AppSettingsRowLabel(
        label(option),
        systemImage: systemImage(option),
        accessory: accessory
      )
    }
    .buttonStyle(PressableButtonStyle())
  }
}

// MARK: - Previews

#Preview("Three actions") {
  AppActionPickerSheetPreview()
}

private struct AppActionPickerSheetPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  private let options = ["Website", "LinkedIn", "X (Twitter)"]

  var body: some View {
    Color.clear
      .sheet(isPresented: .constant(true)) {
        AppActionPickerSheet(
          title: "Follow Developer",
          options: options,
          label: { $0 },
          systemImage: { _ in "link" },
          action: { _ in }
        )
        #if os(iOS)
        .presentationDetents([.height(AppOptionPickerMetrics.height(for: 3))])
        .presentationDragIndicator(.visible)
        #endif
      }
  }
}
