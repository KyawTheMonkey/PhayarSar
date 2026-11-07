import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI

/// The session creator: one meditation style per screen, swiped through
/// sideways.
///
/// A sheet, because starting a session is a detour off the meditation tab that
/// ends in either a session or nothing — and a sheet is the shape of a decision
/// the user can back out of, with the flick to dismiss already in it.
///
/// The screens themselves are a `UICollectionView` (see
/// ``MeditationStyleCollectionViewController``); this is the thin SwiftUI shell
/// that holds it.
///
/// No chrome at all: no navigation bar, no Close button, no grabber, and no
/// background behind the styles. Each style is meant to be the whole surface,
/// and every one of those would have cut across it — a bar strips the top, and
/// a sheet background shows as a band above and below a style that does not
/// quite fill it.
///
/// What is left to dismiss with is the flick itself, which works from anywhere
/// on the sheet whether or not a grabber is drawn over it.
public struct MeditationSessionCreatorScreen: View {
  @ObserveInjection private var injectionObserver

  public init() {}

  public var body: some View {
    MeditationStyleCollection()
      .ignoresSafeArea(edges: .vertical)
      .creatorSheetPresentation()
      .enableInjection()
  }
}

// MARK: - Presentation

private extension View {
  /// How the creator sits in its sheet.
  ///
  /// Applied here rather than at the `sheet(item:)` call site in the app
  /// target, unlike the profile sheet's grabber. This is not presentation
  /// garnish — it is the screen's design: each style is meant to be the only
  /// surface on screen, which needs both the sheet's own background and its
  /// grabber out of the way. A second call site presenting this screen should
  /// get that without having to know to ask for it.
  @ViewBuilder
  func creatorSheetPresentation() -> some View {
    presentationDragIndicator(.hidden)
      .creatorSheetBackground()
  }

  /// Clearing the background needs iOS 16.4, and the app ships to 16.0.
  ///
  /// The fallback is the system's own opaque sheet — the styles, the paging and
  /// the swipe all work, and what 16.0–16.3 loses is seeing the app through the
  /// gap between two screens. That is the right way round for a two-point
  /// release nobody is left on.
  @ViewBuilder
  func creatorSheetBackground() -> some View {
    if #available(iOS 16.4, macOS 13.3, *) {
      presentationBackground(.clear)
    } else {
      self
    }
  }
}

// MARK: - Collection

#if canImport(UIKit)
/// Bridges ``MeditationStyleCollectionViewController`` into SwiftUI.
///
/// Deliberately thin. Everything the collection does lives in the view
/// controller; this exists only to let SwiftUI own its lifetime.
private struct MeditationStyleCollection: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> MeditationStyleCollectionViewController {
    MeditationStyleCollectionViewController()
  }

  func updateUIViewController(
    _ controller: MeditationStyleCollectionViewController,
    context: Context
  ) {
    // Nothing to push in: the contents are `MeditationStyle`'s cases, which
    // cannot change while the sheet is open.
  }
}
#else
/// Stands in for the collection on macOS, which has no UIKit and so no
/// ``MeditationStyleCollectionViewController``.
///
/// The Mac build exists for previews and for the split-view layout, not as a
/// shipping experience — so this says so rather than growing a second
/// collection in SwiftUI that would then have to be kept in step with the real
/// one.
private struct MeditationStyleCollection: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "iphone")
        .font(.largeTitle)
      Text(L10n.meditationCreatorUnavailable)
        .multilineTextAlignment(.center)
    }
    .foregroundStyle(AppColor.textSecondary)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColor.background)
  }
}
#endif

// MARK: - Previews

#Preview("Creator") {
  MeditationSessionCreatorScreenPreview()
}

private struct MeditationSessionCreatorScreenPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    MeditationSessionCreatorScreen()
  }
}
