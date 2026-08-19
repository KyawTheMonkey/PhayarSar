import DesignKit
import EnvironmentKit
import Inject
import SwiftUI

/// Tells the user this build will not do, and points them at the App Store.
///
/// ```swift
/// .fullScreenCover(isPresented: $mustUpdate) {
///   ForceUpdateScreen(
///     title: L10n.updateRequiredTitle,
///     message: L10n.updateRequiredMessage,
///     version: "Version 2.4.0",
///     updateTitle: L10n.updateNow
///   ) {
///     openAppStore()
///   }
///   .interactiveDismissDisabled()
/// }
/// ```
///
/// The screen decides nothing. It does not know the running version, does not
/// call remote config, and does not open the App Store — it renders the demand
/// and calls back. Everything that could be wrong about *whether* an update is
/// required stays in the app target, where it can be changed without touching a
/// view.
///
/// Whether it can be escaped is the caller's choice too: give `onLater` and the
/// screen offers a way past, omit it and there is none. Pair the strict form
/// with `.interactiveDismissDisabled()` at the presentation site — a view cannot
/// stop the sheet that contains it from being swiped away.
public struct ForceUpdateScreen: View {
  @ObserveInjection private var injectionObserver

  private let title: String
  private let message: String
  private let version: String?
  private let highlights: [String]
  private let updateTitle: String
  private let onUpdate: () -> Void
  private let laterTitle: String?
  private let onLater: (() -> Void)?

  /// - Parameters:
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///   - message: Why the old build has stopped working. Worth writing
  ///     specifically; "please update" tells the user nothing they cannot see.
  ///   - version: Shown as a caption under the message. Pass the already
  ///     formatted string — this screen does no number formatting.
  ///   - highlights: What the user gets for updating. A short list makes a
  ///     forced update feel less like a toll. Omit it entirely rather than
  ///     padding it out.
  ///   - onUpdate: Open the App Store from here.
  ///   - laterTitle: Required alongside `onLater`; the escape is only rendered
  ///     when both are given, so a title without a handler cannot ship as a
  ///     button that does nothing.
  ///   - onLater: Omit for a genuinely blocking update. Given, it becomes a
  ///     plain button under the primary one.
  public init(
    title: String,
    message: String,
    version: String? = nil,
    highlights: [String] = [],
    updateTitle: String,
    onUpdate: @escaping () -> Void,
    laterTitle: String? = nil,
    onLater: (() -> Void)? = nil
  ) {
    self.title = title
    self.message = message
    self.version = version
    self.highlights = highlights
    self.updateTitle = updateTitle
    self.onUpdate = onUpdate
    self.laterTitle = laterTitle
    self.onLater = onLater
  }

  public var body: some View {
    MiscStatusLayout(
      systemImage: "arrow.down.circle.fill",
      title: title,
      message: message
    ) {
      detail
    } actions: {
      AppButton(updateTitle, systemImage: "arrow.up.forward.app", action: onUpdate)

      if let laterTitle, let onLater {
        AppButton(laterTitle, kind: .plain, action: onLater)
      }
    }
    .enableInjection()
  }

  // MARK: - Detail

  @ViewBuilder
  private var detail: some View {
    VStack(spacing: Metrics.detailSpacing) {
      if let version {
        Text(version)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textTertiary)
      }

      if !highlights.isEmpty {
        highlightList
      }
    }
  }

  /// Left-aligned inside a centred column: a bulleted list that is itself
  /// centred has no common left edge for the eye to run down.
  private var highlightList: some View {
    VStack(alignment: .leading, spacing: Metrics.highlightSpacing) {
      ForEach(highlights, id: \.self) { highlight in
        Label {
          Text(highlight)
            .font(AppFont.subheadline)
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.leading)
        } icon: {
          Image(systemName: "checkmark")
            .font(AppFont.captionBold)
            .foregroundStyle(AppColor.primary)
        }
      }
    }
    .padding(Metrics.highlightPadding)
    .frame(maxWidth: Metrics.highlightWidth)
    .background(
      AppColor.surface,
      in: RoundedRectangle(cornerRadius: AppListSectionMetrics.cornerRadius, style: .continuous)
    )
  }

  // MARK: - Metrics

  private enum Metrics {
    static let detailSpacing: CGFloat = 20
    static let highlightSpacing: CGFloat = 12
    static let highlightPadding: CGFloat = 16

    /// Narrower than the message above it, so the card reads as an aside to the
    /// message rather than as a second, competing block.
    static let highlightWidth: CGFloat = 320
  }
}

// MARK: - Previews

#Preview("Blocking") {
  ForceUpdateScreen(
    title: "Time to update",
    message: "This version of PhayarSar can no longer sync your prayers. Update to carry on where you left off.",
    version: "Version 2.4.0",
    updateTitle: "Update now"
  ) {}
}

#Preview("With highlights") {
  ForceUpdateScreen(
    title: "Time to update",
    message: "This version of PhayarSar can no longer sync your prayers.",
    version: "Version 2.4.0",
    highlights: [
      "Your prayers sync across every device",
      "Nissaya translations line up with the Pali",
      "Reading themes you can save"
    ],
    updateTitle: "Update now"
  ) {}
}

#Preview("Escapable") {
  ForceUpdateScreen(
    title: "A new version is ready",
    message: "You can keep reading on this version for now, but syncing is turned off until you update.",
    version: "Version 2.4.0",
    updateTitle: "Update now",
    onUpdate: {},
    laterTitle: "Not now",
    onLater: {}
  )
}
