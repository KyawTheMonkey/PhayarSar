import DesignKit
import EnvironmentKit
import Inject
import SwiftUI

/// One step of ``TutorialScreen``.
///
/// A symbol rather than an image: MiscKit ships no asset catalog on purpose, so
/// a tutorial can be assembled — or changed remotely — without a new build.
public struct TutorialPage: Identifiable, Equatable, Sendable {
  public let id: String
  public let systemImage: String
  public let title: String
  public let message: String

  /// - Parameters:
  ///   - id: Give a stable one when the pages come from remote config and the
  ///     caller reports which page was reached. The generated default is fine
  ///     for a list written in code.
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///   - message: One idea per page. A page that needs a paragraph is two pages.
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

/// The swipe-through introduction, shown once.
///
/// ```swift
/// TutorialScreen(
///   pages: [
///     TutorialPage(systemImage: "book", title: L10n.tourReadTitle, message: L10n.tourReadBody),
///     TutorialPage(systemImage: "bookmark", title: L10n.tourSaveTitle, message: L10n.tourSaveBody)
///   ],
///   nextTitle: L10n.next,
///   finishTitle: L10n.getStarted,
///   skipTitle: L10n.skip,
///   onFinish: { hasSeenTour = true },
///   onSkip: { hasSeenTour = true }
/// )
/// ```
///
/// The current page is `@State`. That is presentation state, not logic — the
/// same reasoning that lets ``ErrorScreen`` keep its disclosure toggle — and a
/// caller that had to own a page index would be writing paging code that belongs
/// in exactly one place. What the caller does own is the outcome: `onFinish`,
/// `onSkip`, and `onPageChange` for anyone who wants to know how far people get.
///
/// Nothing is remembered between presentations. Whether the tutorial has been
/// seen is the app's to store; this screen would only ever be guessing.
public struct TutorialScreen: View {
  @ObserveInjection private var injectionObserver

  @State private var index = 0

  private let pages: [TutorialPage]
  private let nextTitle: String
  private let finishTitle: String
  private let skipTitle: String?
  private let onFinish: () -> Void
  private let onSkip: (() -> Void)?
  private let onPageChange: ((Int) -> Void)?

  /// - Parameters:
  ///   - pages: In order. Three or four earn their place; more and the user
  ///     starts swiping to the end without reading.
  ///   - nextTitle: The button on every page but the last.
  ///   - finishTitle: The button on the last page. A different word from
  ///     `nextTitle` is what tells the user the tour is over.
  ///   - skipTitle: Required alongside `onSkip`; the control only appears when
  ///     both are given.
  ///   - onFinish: Reached the end and pressed the last button.
  ///   - onSkip: Left early. Usually the same handling as `onFinish`, but worth
  ///     being able to tell apart.
  ///   - onPageChange: Called with the index now on screen, including `0` when
  ///     the screen first appears — so a caller counting page views gets the
  ///     first one without a special case.
  public init(
    pages: [TutorialPage],
    nextTitle: String,
    finishTitle: String,
    skipTitle: String? = nil,
    onFinish: @escaping () -> Void,
    onSkip: (() -> Void)? = nil,
    onPageChange: ((Int) -> Void)? = nil
  ) {
    self.pages = pages
    self.nextTitle = nextTitle
    self.finishTitle = finishTitle
    self.skipTitle = skipTitle
    self.onFinish = onFinish
    self.onSkip = onSkip
    self.onPageChange = onPageChange
  }

  public var body: some View {
    VStack(spacing: 0) {
      topBar
      pager
      dots
      actions
    }
    .appBackground()
    // `task(id:)` rather than `onChange`: it fires on first appearance *and* on
    // every change, so the first page and the rest are one code path instead of
    // two — and it sidesteps the iOS 16/17 `onChange` signature split.
    .task(id: index) {
      onPageChange?(index)
    }
    .appSelectionFeedback(trigger: index)
    .enableInjection()
  }

  // MARK: - Top bar

  @ViewBuilder
  private var topBar: some View {
    HStack {
      Spacer(minLength: 0)

      if let skipTitle, let onSkip {
        Button(skipTitle, action: onSkip)
          .font(AppFont.button)
          .foregroundStyle(AppColor.textSecondary)
          .buttonStyle(PressableButtonStyle(pressedScale: 1))
      }
    }
    .frame(height: Metrics.topBarHeight)
    .appHorizontalInset()
  }

  // MARK: - Pages

  /// `.page` is an iOS-only tab view style and the package also builds for
  /// macOS 13, where the same `#if` split is used for covers in `AuthGate` and
  /// for title display modes across the app. On macOS the page is swapped with a
  /// slide instead, driven by the button rather than by a gesture — a Mac has no
  /// swipe to make the paging gesture worth reimplementing.
  @ViewBuilder
  private var pager: some View {
    #if os(iOS)
    TabView(selection: $index) {
      ForEach(Array(pages.enumerated()), id: \.element.id) { position, page in
        Page(page)
          .tag(position)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    #else
    Group {
      if let page = pages.indices.contains(index) ? pages[index] : nil {
        Page(page)
          .transition(.opacity)
          .id(page.id)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(.easeInOut(duration: 0.25), value: index)
    #endif
  }

  @ViewBuilder
  private func Page(_ page: TutorialPage) -> some View {
    ScrollView {
      VStack(spacing: Metrics.pageSpacing) {
        Image(systemName: page.systemImage)
          .font(.system(size: Metrics.iconSize, weight: .light))
          .foregroundStyle(AppColor.primary)
          .accessibilityHidden(true)

        VStack(spacing: Metrics.textSpacing) {
          Text(page.title)
            .font(AppFont.title)
            .foregroundStyle(AppColor.textPrimary)

          Text(page.message)
            .font(AppFont.body)
            .foregroundStyle(AppColor.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: Metrics.maxTextWidth)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, Metrics.pageSpacing)
      .appHorizontalInset()
    }
  }

  // MARK: - Dots

  /// Hand-drawn rather than `indexDisplayMode: .automatic`: the system dots
  /// ignore a tint on several iOS versions and land white-on-cream against the
  /// app's background. They are also the only way to have dots at all on macOS.
  private var dots: some View {
    HStack(spacing: Metrics.dotSpacing) {
      ForEach(Array(pages.enumerated()), id: \.element.id) { position, _ in
        Circle()
          .fill(position == index ? AppColor.primary : AppColor.textTertiary.opacity(0.35))
          .frame(
            width: position == index ? Metrics.dotActiveSize : Metrics.dotSize,
            height: position == index ? Metrics.dotActiveSize : Metrics.dotSize
          )
      }
    }
    .animation(.easeInOut(duration: 0.2), value: index)
    .padding(.vertical, Metrics.dotsPadding)
    // The button below already says where the user is in the sequence, and a
    // row of dots read one by one is nothing but noise.
    .accessibilityHidden(true)
  }

  // MARK: - Actions

  private var actions: some View {
    AppButton(isLastPage ? finishTitle : nextTitle) {
      if isLastPage {
        onFinish()
      } else {
        withAnimation(.easeInOut(duration: 0.25)) {
          index += 1
        }
      }
    }
    .appHorizontalInset()
    .padding(.bottom, Metrics.actionBottomPadding)
    .frame(maxWidth: Metrics.maxTextWidth + Metrics.pageSpacing * 2)
    .frame(maxWidth: .infinity)
  }

  /// An empty `pages` is treated as the last page, so the button finishes rather
  /// than paging past the end. A tutorial with no pages is a caller's mistake,
  /// but it should not be one the user gets stuck in.
  private var isLastPage: Bool {
    index >= pages.count - 1
  }

  // MARK: - Metrics

  private enum Metrics {
    static let topBarHeight: CGFloat = 44
    static let iconSize: CGFloat = 64
    static let pageSpacing: CGFloat = 32
    static let textSpacing: CGFloat = 12

    /// Same measure the status screens hold their copy to.
    static let maxTextWidth: CGFloat = 360

    static let dotSize: CGFloat = 7
    static let dotActiveSize: CGFloat = 9
    static let dotSpacing: CGFloat = 8
    static let dotsPadding: CGFloat = 20
    static let actionBottomPadding: CGFloat = 12
  }
}

// MARK: - Previews

private let previewPages = [
  TutorialPage(
    systemImage: "books.vertical",
    title: "Every prayer in one place",
    message: "The full library, offline, from the moment you open the app."
  ),
  TutorialPage(
    systemImage: "textformat.size",
    title: "Read it your way",
    message: "Paper, type size and spacing you can set once and forget."
  ),
  TutorialPage(
    systemImage: "icloud",
    title: "Follows you everywhere",
    message: "Sign in and your bookmarks and themes reach every device."
  )
]

#Preview("Three pages") {
  TutorialScreen(
    pages: previewPages,
    nextTitle: "Next",
    finishTitle: "Get started",
    skipTitle: "Skip",
    onFinish: {},
    onSkip: {}
  )
}

#Preview("No skip") {
  TutorialScreen(
    pages: previewPages,
    nextTitle: "Next",
    finishTitle: "Get started"
  ) {}
}

#Preview("Single page") {
  TutorialScreen(
    pages: [previewPages[0]],
    nextTitle: "Next",
    finishTitle: "Get started"
  ) {}
}
