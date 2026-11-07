import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI

public enum MeditationScreenMetrics {
  /// Nudges the empty state above the true centre. Optically centred content
  /// sits a little high — dead centre reads as low once the nav bar has taken
  /// the top of the screen.
  public static let verticalOffset: CGFloat = -24
}

/// The meditation tab's root.
///
/// There is no meditation content yet, so the whole screen is its empty state:
/// what the tab will hold, and a way in. It is a real screen rather than a
/// placeholder `Text` in `AppTabView` because the tab is shipping in the tab bar
/// either way, and a tab that opens onto a bare title reads as a bug rather than
/// as a feature that has not arrived.
///
/// When sessions exist, the list goes in `body` and this becomes the branch
/// taken when it is empty — which is why the empty state is `AppEmptyStateView`
/// (rendered inside a feature's own layout) rather than one of MiscKit's
/// full-screen status screens.
public struct MeditationScreen: View {
  @ObserveInjection private var injectionObserver

  @EnvironmentObject private var navigator: AppNavigatorModel

  public init() {}

  public var body: some View {
    // `GeometryReader` around the scroll view rather than inside it: the empty
    // state has to sit in the middle of the screen at normal type sizes and
    // still scroll at the largest ones, and that needs the screen's height
    // pushed down as a `minHeight` on the content.
    GeometryReader { proxy in
      ScrollView {
        AppEmptyStateView(
          systemImage: "figure.mind.and.body",
          title: L10n.meditationEmptyTitle,
          message: L10n.meditationEmptyMessage,
          actionTitle: L10n.meditationStartSession
        ) {
          navigator.present(.meditationSessionCreator)
        }
        .appHorizontalInset()
        .offset(y: MeditationScreenMetrics.verticalOffset)
        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
      }
    }
    .appBackground()
    .enableInjection()
  }
}

// MARK: - Previews

#Preview("Empty") {
  MeditationScreenPreview()
}

private struct MeditationScreenPreview: View {
  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    NavigationStack {
      MeditationScreen()
        .navigationTitle(AppTab.meditation.title)
    }
    .environmentObject(AppNavigatorModel())
  }
}
