import DesignKit
import SwiftUI

enum MiscStatusMetrics {
  /// The symbol itself. Reads as illustration at this size without needing an
  /// asset per screen — these screens have to render in a preview and in a
  /// module that ships no artwork.
  static let iconSize: CGFloat = 40

  /// The tinted disc behind the symbol, which is what stops a lone glyph on a
  /// mostly empty screen looking unfinished.
  static let iconWell: CGFloat = 96

  /// Between the icon well, the text block and whatever detail the screen adds.
  static let blockSpacing: CGFloat = 24

  /// Title to message. Tight, so the two read as one paragraph.
  static let textSpacing: CGFloat = 10

  /// Same reasoning as `AppEmptyStateMetrics.maxTextWidth` — these screens are
  /// two sentences in a lot of space, and full-width measure on an iPad is
  /// unreadable.
  static let maxTextWidth: CGFloat = 360

  /// Between stacked buttons in the bottom bar.
  static let actionSpacing: CGFloat = 12

  /// Clears the home indicator without stranding the buttons above it.
  static let actionBottomPadding: CGFloat = 12

  /// Breathing room above the buttons, so the bar's fill does not cut straight
  /// into the content it is covering.
  static let actionTopPadding: CGFloat = 12

  static let badgeHorizontalPadding: CGFloat = 12
  static let badgeVerticalPadding: CGFloat = 6

  /// Matches the tracking `AppListSection` puts on its uppercased headers, so
  /// the pill reads as the same kind of label.
  static let badgeKerning: CGFloat = 0.6

  /// Keeps the scrolling content from sliding under the bottom bar as it grows.
  static let contentBottomPadding: CGFloat = 24
}

/// The shape shared by every "the app cannot continue right now" screen.
///
/// Force update, error, maintenance and offline are the same arrangement with
/// different copy: a symbol, a title, a message, an optional supporting detail,
/// and up to two buttons at the bottom. This holds that arrangement once so the
/// four screens differ only in the words and the closures — which is the whole
/// point of them.
///
/// Internal on purpose. Callers reach for the named screen that says what has
/// happened, not for a blank layout they have to assemble themselves.
///
/// The content scrolls and the actions sit in a `safeAreaInset`, so the buttons
/// stay reachable at the largest Dynamic Type sizes and in landscape, where the
/// text alone can already be taller than the window.
struct MiscStatusLayout<Detail: View, Actions: View>: View {
  private let systemImage: String
  private let tint: Color
  private let badge: String?
  private let title: String
  private let message: String
  private let detail: Detail
  private let actions: Actions

  init(
    systemImage: String,
    tint: Color = AppColor.primary,
    badge: String? = nil,
    title: String,
    message: String,
    @ViewBuilder detail: () -> Detail,
    @ViewBuilder actions: () -> Actions
  ) {
    self.systemImage = systemImage
    self.tint = tint
    self.badge = badge
    self.title = title
    self.message = message
    self.detail = detail()
    self.actions = actions()
  }

  var body: some View {
    // The proxy is what lets the content centre itself when it is short and
    // scroll when it is not — a `ScrollView` alone sizes to its content, so
    // `Spacer`s inside it collapse to nothing.
    GeometryReader { proxy in
      ScrollView {
        content
          .frame(maxWidth: .infinity, minHeight: proxy.size.height)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      actionBar
    }
    .appBackground()
  }

  // MARK: - Content

  private var content: some View {
    VStack(spacing: MiscStatusMetrics.blockSpacing) {
      Spacer(minLength: 0)

      iconWell
      textBlock
      detail

      Spacer(minLength: 0)
    }
    .padding(.top, MiscStatusMetrics.blockSpacing)
    .padding(.bottom, MiscStatusMetrics.contentBottomPadding)
    .appHorizontalInset()
  }

  private var iconWell: some View {
    Circle()
      .fill(tint.opacity(0.12))
      .frame(width: MiscStatusMetrics.iconWell, height: MiscStatusMetrics.iconWell)
      .overlay {
        Image(systemName: systemImage)
          .font(.system(size: MiscStatusMetrics.iconSize, weight: .regular))
          .foregroundStyle(tint)
      }
      // The title says the same thing in words directly below it.
      .accessibilityHidden(true)
  }

  /// Above the title, where a label of this kind belongs — it qualifies the
  /// heading, and read after the message it is just a loose word.
  @ViewBuilder
  private var badgePill: some View {
    if let badge {
      Text(badge)
        .font(AppFont.sectionLabel)
        .textCase(.uppercase)
        .kerning(MiscStatusMetrics.badgeKerning)
        .foregroundStyle(tint)
        .padding(.horizontal, MiscStatusMetrics.badgeHorizontalPadding)
        .padding(.vertical, MiscStatusMetrics.badgeVerticalPadding)
        .background(tint.opacity(0.12), in: Capsule())
        // Nudges the pill off the title without widening the gap between title
        // and message, which `textSpacing` also controls.
        .padding(.bottom, MiscStatusMetrics.textSpacing / 2)
    }
  }

  private var textBlock: some View {
    VStack(spacing: MiscStatusMetrics.textSpacing) {
      badgePill

      Text(title)
        .font(AppFont.title)
        .foregroundStyle(AppColor.textPrimary)

      Text(message)
        .font(AppFont.body)
        .foregroundStyle(AppColor.textSecondary)
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: MiscStatusMetrics.maxTextWidth)
  }

  // MARK: - Actions

  private var actionBar: some View {
    VStack(spacing: MiscStatusMetrics.actionSpacing) {
      actions
    }
    .appHorizontalInset()
    .padding(.top, MiscStatusMetrics.actionTopPadding)
    .padding(.bottom, MiscStatusMetrics.actionBottomPadding)
    // Matches the width the text block is held to, so on an iPad the buttons
    // sit under the message rather than stretching the width of the window.
    .frame(maxWidth: MiscStatusMetrics.maxTextWidth + MiscStatusMetrics.blockSpacing * 2)
    .frame(maxWidth: .infinity)
    // A `safeAreaInset` does not stop content scrolling underneath it, and an
    // overscrolled message showing through the buttons reads as a glitch. Flat
    // rather than the gradient: `AppBackgroundGradient` finishes at 48% height,
    // so everything down here is this exact colour and the fill leaves no seam.
    .background(AppColor.background)
  }
}

// MARK: - Convenience

extension MiscStatusLayout where Detail == EmptyView {
  /// For the screens that have nothing to add between the message and the
  /// buttons, which is most of them.
  init(
    systemImage: String,
    tint: Color = AppColor.primary,
    badge: String? = nil,
    title: String,
    message: String,
    @ViewBuilder actions: () -> Actions
  ) {
    self.init(
      systemImage: systemImage,
      tint: tint,
      badge: badge,
      title: title,
      message: message,
      detail: { EmptyView() },
      actions: actions
    )
  }
}
