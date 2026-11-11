import DesignKit
import Inject
import PrayersKit
import SwiftUI

// MARK: - Metrics

private enum HomeHeroMetrics {
  static let height: CGFloat = 176
  static let cornerRadius: CGFloat = 24
  static let padding: CGFloat = 18
  /// Generous for a caption gap: the Burmese title's stacked diacritics reach
  /// well below its baseline and collide with the summary at 4pt.
  static let textSpacing: CGFloat = 8

  /// The cover hangs off the card's trailing corner, tilted, so it reads as an
  /// object resting on the card rather than as a thumbnail placed in it.
  static let artworkSize: CGFloat = 150
  static let artworkCornerRadius: CGFloat = 22
  static let artworkOverhang: CGFloat = 18
  static let artworkTilt: Double = 8

  /// How much of the card's width the text may take before it would run under
  /// the artwork.
  static let textWidthFraction: CGFloat = 0.6

  static let pillHeight: CGFloat = 36
  static let pillHorizontalPadding: CGFloat = 18

  static let dotSize: CGFloat = 6
  static let activeDotWidth: CGFloat = 18
  static let dotSpacing: CGFloat = 6
  static let dotsTopSpacing: CGFloat = 12
}

// MARK: - Page

/// One card in Home's hero: something to resume, or the pick for this time of
/// day. A value type with a closure rather than a protocol, so prayers, bead
/// sessions and whatever comes next can all be pages without the pager knowing
/// about any of them.
struct HomeHeroPage: Identifiable {
  enum Artwork {
    case prayer(Prayer.ID)
    case symbol(String)
  }

  let id: String
  /// Small caps line above the title: "Continue", "This morning", "Beads".
  let eyebrow: String
  let title: String
  let summary: String
  let actionTitle: String
  let tint: AppColor.Tint
  let artwork: Artwork
  let action: () -> Void
}

// MARK: - Pager

/// Home's top card: one page per thing the user could do next, swiped
/// sideways, with dots.
///
/// Replaces both the Continue carousel and the featured shelf. Those were two
/// stacked sections competing for the top of the screen; as pages of one card
/// they take the height of one, which is what lets the moments grid start
/// above the fold.
///
/// A `TabView` in page style rather than a horizontal `ScrollView`: paging that
/// settles on a card needs `scrollTargetBehavior` in a scroll view, which is
/// iOS 17, and this has to page on iOS 16. The cost is that the next card does
/// not peek in from the edge — the dots carry that hint instead, so they are
/// drawn whenever there is more than one page.
struct HomeHeroPager: View {
  @ObserveInjection private var injectionObserver
  let pages: [HomeHeroPage]
  @State private var selection: String?

  /// The stored selection, or the first page when it has never been set or
  /// names a page that has since gone — finishing a prayer removes its page.
  private var currentID: String? {
    if let selection, pages.contains(where: { $0.id == selection }) { return selection }
    return pages.first?.id
  }

  var body: some View {
    if !pages.isEmpty {
      VStack(spacing: HomeHeroMetrics.dotsTopSpacing) {
        pager
        if pages.count > 1 {
          dots
        }
      }
      .enableInjection()
    }
  }

  @ViewBuilder
  private var pager: some View {
    #if os(iOS)
    TabView(selection: Binding(get: { currentID }, set: { selection = $0 })) {
      ForEach(pages) { page in
        HomeHeroCard(page: page)
          .appHorizontalInset()
          .tag(Optional(page.id))
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .frame(height: HomeHeroMetrics.height)
    #else
    // Page-style `TabView` does not exist on macOS, which only builds this
    // module for `swift build`. The first page keeps the layout honest there.
    if let page = pages.first {
      HomeHeroCard(page: page)
        .frame(height: HomeHeroMetrics.height)
        .appHorizontalInset()
    }
    #endif
  }

  private var dots: some View {
    HStack(spacing: HomeHeroMetrics.dotSpacing) {
      ForEach(pages) { page in
        let isCurrent = page.id == currentID
        Capsule()
          .fill(isCurrent ? AppColor.textPrimary : AppColor.textTertiary.opacity(0.5))
          .frame(
            width: isCurrent ? HomeHeroMetrics.activeDotWidth : HomeHeroMetrics.dotSize,
            height: HomeHeroMetrics.dotSize
          )
      }
    }
    .animation(.easeOut(duration: 0.2), value: currentID)
    // The pager itself is swipeable by VoiceOver; the dots would only repeat it.
    .accessibilityHidden(true)
  }
}

// MARK: - Card

private struct HomeHeroCard: View {
  let page: HomeHeroPage

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: HomeHeroMetrics.cornerRadius, style: .continuous)
  }

  var body: some View {
    Button(action: page.action) {
      GeometryReader { proxy in
        VStack(alignment: .leading, spacing: 0) {
          VStack(alignment: .leading, spacing: HomeHeroMetrics.textSpacing) {
            Text(page.eyebrow)
              .font(AppFont.sectionLabel)
              .textCase(.uppercase)
              .kerning(0.6)
              .opacity(0.85)
            Text(page.title)
              .font(AppFont.title)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
            Text(page.summary)
              .font(AppFont.caption)
              .opacity(0.9)
              .lineLimit(2)
          }
          .frame(width: proxy.size.width * HomeHeroMetrics.textWidthFraction, alignment: .leading)

          Spacer(minLength: 0)

          // Drawn as a label, not a second button: the whole card is the tap
          // target, and a button inside a button would split it in two.
          Text(page.actionTitle)
            .font(AppFont.button)
            .foregroundStyle(page.tint.background)
            .padding(.horizontal, HomeHeroMetrics.pillHorizontalPadding)
            .frame(height: HomeHeroMetrics.pillHeight)
            .background(page.tint.ink, in: Capsule())
        }
        .foregroundStyle(page.tint.ink)
        .padding(HomeHeroMetrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .bottomTrailing) {
          artwork
            .offset(x: HomeHeroMetrics.artworkOverhang, y: HomeHeroMetrics.artworkOverhang)
        }
        .background(page.tint.background)
        .clipShape(shape)
      }
    }
    .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var artwork: some View {
    let artShape = RoundedRectangle(
      cornerRadius: HomeHeroMetrics.artworkCornerRadius, style: .continuous
    )
    Group {
      switch page.artwork {
      case let .prayer(id):
        PrayerCoverImage(prayerID: id)
      case let .symbol(name):
        ZStack {
          page.tint.ink.opacity(0.14)
          Image(systemName: name)
            .font(.system(size: HomeHeroMetrics.artworkSize * 0.42, weight: .light))
            .foregroundStyle(page.tint.ink.opacity(0.9))
        }
      }
    }
    .frame(width: HomeHeroMetrics.artworkSize, height: HomeHeroMetrics.artworkSize)
    .clipShape(artShape)
    .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
    .rotationEffect(.degrees(HomeHeroMetrics.artworkTilt))
    .accessibilityHidden(true)
  }
}
