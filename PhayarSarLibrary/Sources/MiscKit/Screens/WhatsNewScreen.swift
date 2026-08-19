import DesignKit
import EnvironmentKit
import Inject
import SwiftUI

/// One line of ``WhatsNewScreen``.
public struct WhatsNewItem: Identifiable, Equatable, Sendable {
  public let id: String
  public let systemImage: String
  public let title: String
  public let message: String

  /// - Parameters:
  ///   - id: Give a stable one when the list comes from remote config. The
  ///     generated default is fine for a list written in code.
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///     Name the feature, do not describe the work: "Reading themes", not
  ///     "Improved theming support".
  ///   - message: One line on what it does for the reader.
  public init(
    id: String = UUID().uuidString,
    systemImage: String,
    title: String,
    message: String
  ) {
    self.id = id
    self.systemImage = systemImage
    self.title = title
    self.message = message
  }
}

/// The release notes, in the shape Apple's own apps use.
///
/// ```swift
/// .sheet(isPresented: $showWhatsNew) {
///   WhatsNewScreen(
///     title: L10n.whatsNewTitle,
///     version: "Version 2.4",
///     items: releaseHighlights,
///     continueTitle: L10n.continueAction,
///     onContinue: { showWhatsNew = false }
///   )
/// }
/// ```
///
/// The sibling of ``TutorialScreen``, for the returning user rather than the new
/// one. A list rather than a carousel because someone who already knows the app
/// wants to see everything at once and decide what to look at — paging them
/// through it one item at a time is asking them to sit through what they could
/// have scanned.
///
/// Which version the user last saw, and whether this screen is due, stays in the
/// app. This renders the list it is handed.
public struct WhatsNewScreen: View {
  @ObserveInjection private var injectionObserver

  private let title: String
  private let version: String?
  private let items: [WhatsNewItem]
  private let continueTitle: String
  private let onContinue: () -> Void
  private let onClose: (() -> Void)?

  /// - Parameters:
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///   - version: Shown under the title, already formatted. This screen does no
  ///     version formatting of its own.
  ///   - items: In the order they matter to the reader, not the order they were
  ///     built. Keep it to what a user would notice.
  ///   - onContinue: The one button, pinned to the bottom.
  ///   - onClose: Omit when the button is the only way out — which is usually
  ///     right here, since the list is the whole point of showing the screen.
  public init(
    title: String,
    version: String? = nil,
    items: [WhatsNewItem],
    continueTitle: String,
    onContinue: @escaping () -> Void,
    onClose: (() -> Void)? = nil
  ) {
    self.title = title
    self.version = version
    self.items = items
    self.continueTitle = continueTitle
    self.onContinue = onContinue
    self.onClose = onClose
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: Metrics.blockSpacing) {
        header
        list
      }
      .padding(.top, Metrics.topPadding)
      .padding(.bottom, Metrics.contentBottomPadding)
      .frame(maxWidth: Metrics.maxWidth)
      .frame(maxWidth: .infinity)
      .appHorizontalInset()
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      actions
    }
    .overlay(alignment: .topTrailing) {
      if let onClose {
        MiscCloseButton(action: onClose)
          .padding(Metrics.closeInset)
      }
    }
    .appBackground()
    .enableInjection()
  }

  // MARK: - Header

  private var header: some View {
    VStack(spacing: Metrics.headerSpacing) {
      Text(title)
        .font(AppFont.largeTitle)
        .foregroundStyle(AppColor.textPrimary)

      if let version {
        Text(version)
          .font(AppFont.subheadline)
          .foregroundStyle(AppColor.primary)
      }
    }
    .multilineTextAlignment(.center)
    // Clears the close button, which is overlaid and so takes no space of its
    // own — without this a long title runs underneath it.
    .padding(.horizontal, onClose == nil ? 0 : Metrics.headerCloseClearance)
  }

  // MARK: - List

  private var list: some View {
    VStack(alignment: .leading, spacing: Metrics.itemSpacing) {
      ForEach(items) { item in
        Row(item)
      }
    }
  }

  private func Row(_ item: WhatsNewItem) -> some View {
    HStack(alignment: .top, spacing: AppSettingsRowMetrics.iconSpacing) {
      Image(systemName: item.systemImage)
        .font(AppFont.title)
        .foregroundStyle(AppColor.primary)
        // The same icon column the settings rows use, so the text edge lines up
        // with the rest of the app rather than with this screen alone.
        .frame(width: AppSettingsRowMetrics.iconColumn, alignment: .center)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: Metrics.rowTextSpacing) {
        Text(item.title)
          .font(AppFont.headline)
          .foregroundStyle(AppColor.textPrimary)

        Text(item.message)
          .font(AppFont.subheadline)
          .foregroundStyle(AppColor.textSecondary)
      }

      Spacer(minLength: 0)
    }
    // Icon and text are one thought; read separately they are a symbol name
    // followed by a fragment.
    .accessibilityElement(children: .combine)
  }

  // MARK: - Actions

  private var actions: some View {
    AppButton(continueTitle, action: onContinue)
      .appHorizontalInset()
      .padding(.top, Metrics.actionTopPadding)
      .padding(.bottom, Metrics.actionBottomPadding)
      .frame(maxWidth: Metrics.maxWidth)
      .frame(maxWidth: .infinity)
      // The list scrolls underneath this bar, so it needs to be opaque. Flat
      // rather than the gradient: `AppBackgroundGradient` finishes at 48%
      // height, so down here it is already this exact colour.
      .background(AppColor.background)
  }

  // MARK: - Metrics

  private enum Metrics {
    static let topPadding: CGFloat = 48
    static let blockSpacing: CGFloat = 36
    static let headerSpacing: CGFloat = 8
    static let itemSpacing: CGFloat = 26
    static let rowTextSpacing: CGFloat = 4
    static let contentBottomPadding: CGFloat = 24
    static let actionTopPadding: CGFloat = 12
    static let actionBottomPadding: CGFloat = 12
    static let closeInset: CGFloat = 8

    /// Room for the 44pt close button plus its inset, applied to both sides so
    /// the title stays centred.
    static let headerCloseClearance: CGFloat = 52

    /// Wider than the status screens: this one is a list, and a list reads worse
    /// squeezed into a narrow column than a two-sentence message does spread
    /// across a wide one.
    static let maxWidth: CGFloat = 440
  }
}

// MARK: - Previews

private let previewItems = [
  WhatsNewItem(
    systemImage: "text.book.closed",
    title: "Nissaya translations",
    message: "Word-by-word Burmese lined up with the Pali, on every prayer in the library."
  ),
  WhatsNewItem(
    systemImage: "paintpalette",
    title: "Reading themes",
    message: "Save the paper, type size and spacing you read best in."
  ),
  WhatsNewItem(
    systemImage: "icloud",
    title: "Sync across devices",
    message: "Sign in once and your bookmarks follow you to your iPad."
  )
]

#Preview("With version and close") {
  WhatsNewScreen(
    title: "What's New",
    version: "Version 2.4",
    items: previewItems,
    continueTitle: "Continue",
    onContinue: {},
    onClose: {}
  )
}

#Preview("No close button") {
  WhatsNewScreen(
    title: "What's New",
    version: "Version 2.4",
    items: previewItems,
    continueTitle: "Continue"
  ) {}
}

#Preview("Single item") {
  WhatsNewScreen(
    title: "What's New",
    items: [previewItems[0]],
    continueTitle: "Continue"
  ) {}
}
