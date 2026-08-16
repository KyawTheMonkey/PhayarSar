import SwiftUI

public enum AppButtonMetrics {
  /// Matches `AppListSectionMetrics.cornerRadius`, so a button sitting under a
  /// card reads as part of the same family rather than as a foreign control.
  public static let cornerRadius: CGFloat = 16

  /// Generous on purpose: these are full-width primary actions, and the height
  /// this produces clears the 44pt minimum with room for a Burmese line, whose
  /// stacked diacritics need more vertical space than Latin text.
  public static let verticalPadding: CGFloat = 16

  /// Gap between a button's icon and its title.
  public static let iconSpacing: CGFloat = 8
}

/// How much weight a button carries.
public enum AppButtonKind: Sendable {
  /// Filled with the brand colour. One per screen — it is the thing the screen
  /// exists to get done.
  case primary

  /// Tinted, not filled. For the alternative that is a real choice rather than
  /// a lesser version of the primary one.
  case secondary

  /// Text only. For the way out of a screen, or an action that undoes something.
  case plain

  var foreground: Color {
    switch self {
    case .primary:
      return AppColor.buttonPrimaryText
    case .secondary:
      return AppColor.buttonSecondaryText
    case .plain:
      return AppColor.textSecondary
    }
  }

  var background: Color {
    switch self {
    case .primary:
      return AppColor.buttonPrimaryBackground
    case .secondary:
      return AppColor.buttonSecondaryBackground
    case .plain:
      return .clear
    }
  }
}

/// The app's full-width button.
///
/// ```swift
/// AppButton(L10n.startReading, systemImage: "play.fill") {
///   navigator.navigate(to: .prayer(prayerID: prayer.id))
/// }
/// ```
///
/// Full-width by default because every call site so far is a bottom bar or a
/// stacked column of choices. Give it a `.frame` if you need otherwise — the
/// `maxWidth: .infinity` is on the label, so an outer frame wins.
public struct AppButton: View {
  private let title: String
  private let systemImage: String?
  private let kind: AppButtonKind
  private let isLoading: Bool
  private let action: () -> Void

  /// - Parameters:
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///   - systemImage: Optional SF Symbol, shown before the title.
  ///   - isLoading: Swaps the label for a spinner and stops the button
  ///     responding. The frame does not change, so a row of buttons does not
  ///     resize as one of them starts working.
  public init(
    _ title: String,
    systemImage: String? = nil,
    kind: AppButtonKind = .primary,
    isLoading: Bool = false,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.kind = kind
    self.isLoading = isLoading
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      ZStack {
        // Kept in the layout, only hidden, so the button holds its width while
        // the spinner is up.
        HStack(spacing: AppButtonMetrics.iconSpacing) {
          if let systemImage {
            Image(systemName: systemImage)
          }

          Text(title)
        }
        .opacity(isLoading ? 0 : 1)

        if isLoading {
          ProgressView()
            .tint(kind.foreground)
        }
      }
      .font(AppFont.headline)
      .foregroundStyle(kind.foreground)
      .frame(maxWidth: .infinity)
      .padding(.vertical, AppButtonMetrics.verticalPadding)
      .background(
        kind.background,
        in: RoundedRectangle(
          cornerRadius: AppButtonMetrics.cornerRadius,
          style: .continuous
        )
      )
      // A `.plain` button has no fill to catch the tap, so without this only
      // the glyphs themselves are tappable.
      .contentShape(Rectangle())
    }
    .buttonStyle(PressableButtonStyle())
    .disabled(isLoading)
  }
}

// MARK: - Press feedback

/// `.plain` with the press feedback put back — plain leaves a filled control
/// looking dead under the finger.
public struct PressableButtonStyle: ButtonStyle {
  /// `1` for full-width rows, where only the dimming should show. A row that
  /// scaled would drag its neighbours' alignment around with it.
  public var pressedScale: CGFloat

  public init(pressedScale: CGFloat = 0.97) {
    self.pressedScale = pressedScale
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.7 : 1)
      .scaleEffect(configuration.isPressed ? pressedScale : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

// MARK: - Previews

#Preview("Kinds") {
  AppButtonPreview()
}

private struct AppButtonPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    VStack(spacing: 12) {
      AppButton("Start reading", systemImage: "play.fill") {}
      AppButton("Continue as Guest", kind: .secondary) {}
      AppButton("Not now", kind: .plain) {}
      AppButton("Signing in", isLoading: true) {}
    }
    .padding()
    .frame(maxHeight: .infinity)
    .appBackground()
  }
}
