import AuthKit
import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI
import UtilKit

/// The fixed-height bar pinned above `HomeScreen`'s scroll view.
///
/// Holds the context buttons and the blurred background. The title is *not*
/// here — it is a single travelling view drawn in an overlay above this bar, so
/// that it can move continuously between the expanded and collapsed positions.
/// See ``HomeCollapsingTitle``.
///
/// This bar's height never changes — see `HomeNavMetrics.barHeight` for why.
struct HomeNavView: View {
  /// `0` at rest, `1` fully collapsed.
  let progress: CGFloat
  /// Overscroll distance in points, `0` unless the user is pulling past the top.
  let stretch: CGFloat
  /// `1` once the segment picker has docked directly beneath this bar. Drives
  /// the bottom edge from a soft fade to a hard join, so the bar and the picker
  /// read as one continuous blurred pane running to the top of the screen.
  let docked: CGFloat

  @ObserveInjection private var injectionObserver
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @EnvironmentObject private var navigator: AppNavigatorModel

  private var buttonScale: CGFloat {
    // Reduce Motion: the bar still gains its background, but nothing resizes.
    guard !reduceMotion else { return 1 }
    return lerp(1, HomeNavMetrics.buttonScaleFloor, progress)
  }

  private var backgroundIntensity: CGFloat {
    smoothstep(0...HomeNavMetrics.blurRampEnd, progress)
  }

  var body: some View {
    HStack {
      Spacer()
      contextButtons
        .scaleEffect(buttonScale, anchor: .trailing)
    }
    .frame(height: HomeNavMetrics.barHeight)
    .appHorizontalInset()
    // Fade tail, sitting just below the bar. Drawn first so it layers behind.
    // Fades out as the picker docks, since the picker then supplies the
    // continuation itself.
    .background(alignment: .bottom) {
      AppFadeBlurBackground(
        intensity: backgroundIntensity * (1 - docked),
        solidStop: 0
      )
      .frame(height: HomeNavMetrics.barFadeTail)
      .offset(y: HomeNavMetrics.barFadeTail)
    }
    // The bar itself stays solid edge to edge: the title sits at its centre, so
    // letting the blur fall away inside the bar would thin the backing out
    // right underneath the text.
    .background {
      AppFadeBlurBackground(intensity: backgroundIntensity, solidStop: 1)
        // Carry the blur up behind the status bar, which sits above the inset.
        .ignoresSafeArea(edges: .top)
    }
    .enableInjection()
  }

  private var contextButtons: some View {
    HStack(spacing: 9) {
      Button {} label: {
        Circle()
          .strokeBorder(AppColor.border, lineWidth: 3)
          .frame(width: 38, height: 38)
          .overlay {
            Circle()
              .trim(from: 0, to: 0.64)
              .stroke(
                AppColor.primary,
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
              )
              .rotationEffect(.degrees(-90))
              .frame(width: 36, height: 36)
          }
          .overlay {
            Text("12")
              .font(AppFont.listItemTitle)
              .foregroundStyle(AppColor.primary)
              .scaleEffect(0.65)
          }
      }

      Button {} label: {
        Image(systemName: "magnifyingglass")
          .font(.title2)
          .fontWeight(.medium)
          .foregroundStyle(AppColor.textPrimary)
          .padding(8)
          .toolBarButtonCircularGlass()
      }

      profileButton
    }
  }

  /// The way into ``ProfileScreen``, on the same glass as the two buttons
  /// beside it — this is a toolbar control, and it should not be the one that
  /// looks different.
  ///
  /// The avatar brings no circle of its own for exactly that reason: the glass
  /// *is* its surface, and a tinted circle inside it would be a second one. A
  /// picture fills the glass; failing that the user's monogram sits on it,
  /// which is the glass earning its keep — a bare letter would need a backing,
  /// and this one already has it. Only an account with no name at all falls
  /// back to the `person.crop.circle` glyph that used to be here always.
  ///
  /// Same font and same padding as the search button, and no size of its own —
  /// so the two come out identical without a constant to keep in step, and stay
  /// identical as Dynamic Type moves both.
  ///
  /// Presented rather than pushed. From here the profile is a detour, not a
  /// place in the home hierarchy — a sheet says "glance and flick away", and
  /// the user can do exactly that without going for the back button. Settings
  /// still pushes it, because there it *is* a level down.
  private var profileButton: some View {
    Button {
      navigator.present(.profile)
    } label: {
      ProfileAvatarView()
        .font(.title2)
        .fontWeight(.medium)
        .foregroundStyle(AppColor.textPrimary)
        .padding(8)
        .toolBarButtonCircularGlass()
    }
    .accessibilityLabel(L10n.profile)
  }
}

/// Reports where the expanded title belongs, and reserves its space in the list.
///
/// Draws nothing: the visible title is ``HomeCollapsingTitle``, in an overlay.
/// Keeping a full-size invisible copy in the scroll content means the expanded
/// anchor never has to be computed from font metrics — it is measured — and the
/// list below it sits exactly where it would if the title were drawn here.
///
/// Because this copy scrolls with the content, the anchor it reports travels
/// too, which is what lets the real title follow the list before converging on
/// the bar.
struct HomeTitleAnchor: View {
  var body: some View {
    Text(L10n.homeTab)
      .font(AppFont.largeTitle)
      .fixedSize()
      .background {
        GeometryReader { proxy in
          Color.clear.preference(
            key: HomeTitleAnchorKey.self,
            value: proxy.frame(in: .global)
          )
        }
      }
      .opacity(0)
      .accessibilityHidden(true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .appHorizontalInset()
  }
}

/// Global frame of the expanded title's resting place.
struct HomeTitleAnchorKey: PreferenceKey {
  static var defaultValue: CGRect { .zero }

  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    let next = nextValue()
    if next != .zero { value = next }
  }
}

/// The one and only "Home" title, travelling between its expanded and collapsed
/// positions under direct control of the scroll offset.
///
/// Rather than cross-fading a large left-aligned label into a separate small
/// centred one, this interpolates a single view along a path: leading edge
/// slides toward centred, 34pt scales toward 17pt, and the vertical anchor moves
/// from wherever ``HomeTitleAnchor`` currently sits to the middle of the nav
/// bar. Every term is a pure function of `progress`, so scrolling back down
/// retraces the identical path in reverse.
struct HomeCollapsingTitle: View {
  /// `0` at rest, `1` fully collapsed.
  let progress: CGFloat
  /// Overscroll distance in points, `0` unless pulling past the top.
  let stretch: CGFloat
  /// Where the expanded title sits right now, in global coordinates.
  let anchor: CGRect
  /// Global Y of the nav bar's bottom edge.
  let navBottom: CGFloat
  /// Global X to centre on when collapsed.
  ///
  /// Passed in rather than taken from this view's own bounds: the overlay
  /// ignores safe areas, and on iPad the screen sits in a `NavigationSplitView`
  /// detail column — so neither this view's width nor the screen's width is the
  /// column the title has to line up with.
  let centreX: CGFloat

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// 0.5 lands the 34pt face on the 17pt inline size. Only ever scaling *down*
  /// from the native size, so the glyphs stay crisp.
  private var scale: CGFloat {
    let collapsed = lerp(1, HomeNavMetrics.titleScaleFloor, progress)
    guard !reduceMotion else { return collapsed }

    let bounce = min(stretch / HomeNavMetrics.overscrollGain, HomeNavMetrics.maxOverscrollScale)
    return collapsed + bounce
  }

  var body: some View {
    GeometryReader { proxy in
      let bounds = proxy.frame(in: .global)
      let scaledWidth = anchor.width * scale

      // Interpolate the *leading* edge rather than the centre, so the title
      // stays pinned to the margin early in the scroll and only then drifts in.
      let leadingX = lerp(anchor.minX, centreX - scaledWidth / 2, progress)
      let centreX = leadingX + scaledWidth / 2
      let centreY = lerp(anchor.midY, navBottom - HomeNavMetrics.barHeight / 2, progress)

      Text(L10n.homeTab)
        .font(AppFont.largeTitle)
        .foregroundStyle(AppColor.textPrimary)
        .fixedSize()
        .scaleEffect(scale)
        .position(x: centreX - bounds.minX, y: centreY - bounds.minY)
    }
    // Decorative layer over the whole screen — must not block the list or the
    // bar's buttons.
    .allowsHitTesting(false)
  }
}

// MARK: - Previews

#Preview("Collapse states") {
  HomeNavViewPreview()
    .environmentObject(AppNavigatorModel())
}

private struct HomeNavViewPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    VStack(spacing: 0) {
      ForEach([0.0, 0.35, 0.7, 1.0], id: \.self) { progress in
        stage(progress)
      }
    }
    .appBackground()
  }

  /// One frozen point on the title's path: the bar, plus the travelling title
  /// positioned over it, in a box that stands in for the top of the screen.
  private func stage(_ progress: CGFloat) -> some View {
    let barHeight = HomeNavMetrics.barHeight
    let stageHeight: CGFloat = 120

    return VStack(spacing: 0) {
      HomeNavView(progress: progress, stretch: 0, docked: progress)
      Spacer(minLength: 0)
    }
    .frame(height: stageHeight)
    .overlay {
      GeometryReader { proxy in
        let bounds = proxy.frame(in: .global)
        // Where the expanded title would sit: below the bar, at the margin.
        let anchor = CGRect(
          x: bounds.minX + AppListSectionMetrics.compactHorizontalInset,
          y: bounds.minY + barHeight,
          width: 96,
          height: 44
        )

        HomeCollapsingTitle(
          progress: progress,
          stretch: 0,
          anchor: anchor,
          navBottom: bounds.minY + barHeight,
          centreX: bounds.midX
        )
      }
    }
    .overlay(alignment: .bottomLeading) {
      Text("progress \(progress, specifier: "%.2f")")
        .font(AppFont.sectionLabel)
        .textCase(.uppercase)
        .foregroundStyle(AppColor.textSecondary)
        .appHorizontalInset()
    }
  }
}
