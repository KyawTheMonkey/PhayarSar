import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI
import UtilKit

/// The study screen — each verse against its translation.
///
/// The prayer as a page rather than as a deck: every verse down the list in the
/// quieter setting, and a tap on one unfolds a sheet of paper underneath it
/// carrying what it means. See ``NissayaListViewController`` for why it is a
/// list, and ``NissayaFoldView`` for the fold.
///
/// A separate screen from ``PrayerScreen`` rather than a mode of it. That one is
/// for reciting — a continuous scroll, sized and coloured to be read aloud from
/// — and this one is for study, where the unit is a single verse and the point
/// is what it says. The two want opposite layouts, so they are two screens.
///
/// Pushed from ``PrayerDetailScreen``'s "Nissaya" quick action, via
/// `RouterDestination.nissaya(prayerID:)`.
public struct NissayaScreen: View {
  @ObserveInjection private var injectionObserver

  /// Resolved from the id the route carried rather than passed in whole — see
  /// `RouterDestination`, whose payloads are ids so that routes stay `Codable`.
  private let prayer: Prayer?

  /// The last thing the menu asked the list to do, if anything.
  ///
  /// A value handed down rather than a controller reached into: the list is a
  /// view here like any other, and this is the state it is built from. The
  /// token is what makes "open everything" twice in a row two commands rather
  /// than one — see ``NissayaListCommand``.
  @State private var command: NissayaListCommand?

  public init(prayerID: String) {
    self.prayer = PrayerCatalog.shared.prayer(id: prayerID)
  }

  private var hasVerses: Bool {
    guard let prayer else { return false }
    return !prayer.body.isEmpty
  }

  public var body: some View {
    // The menu drives a `UIViewController`, and there is not one on macOS — see
    // the stand-in at the foot of this file.
    #if canImport(UIKit)
    page.toolbar {
      if hasVerses {
        ToolbarItem(placement: .primaryAction) {
          menu
        }
      }
    }
    #else
    page
    #endif
  }

  // MARK: - Menu

  /// Opening and shutting the whole prayer at once.
  ///
  /// In the navigation bar rather than at the top of the page, because it is
  /// about the page rather than part of it — and because on a prayer of forty
  /// verses the reader who wants it is usually a long way down the sheet, where
  /// anything at the top has scrolled away.
  private var menu: some View {
    Menu {
      Button {
        send(open: true)
      } label: {
        Label(L10n.expandAll, systemImage: "chevron.down.circle")
      }

      Button {
        send(open: false)
      } label: {
        Label(L10n.collapseAll, systemImage: "chevron.up.circle")
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    // The glyph is the whole label, so VoiceOver gets words instead.
    .accessibilityLabel(L10n.quickActions)
  }

  private func send(open: Bool) {
    command = NissayaListCommand(
      // Never the same number twice, so a command is always a change to the
      // state the list is built from — otherwise asking for the same thing
      // again would be no change at all, and nothing would happen.
      token: (command?.token ?? 0) + 1,
      isOpen: open
    )
  }

  // MARK: - Page

  private var page: some View {
    Group {
      // An empty body is folded in with the missing prayer on purpose: a list
      // with no verses in it has nothing to say either, and both are the same
      // "this build can't show you that" to the reader.
      if let prayer, !prayer.body.isEmpty {
        NissayaList(prayer: prayer, command: command)
          // The page runs to the bottom edge; the list keeps the end of the
          // sheet clear of the home indicator with a content inset of its own,
          // which is what lets the paper scroll under it rather than stop
          // above it.
          .ignoresSafeArea(edges: .bottom)
      } else {
        PrayerNotFoundView()
      }
    }
    .background(AppColor.background)
    .navigationTitle(prayer?.title ?? L10n.prayerNotFound)
    // No navigation bar on macOS, so no display mode to set either.
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    // Also set on the detail screen this is pushed from, but the tab bar would
    // otherwise sit under the end of the sheet and compete with it for the
    // same thumb.
    .hideTabBar()
    .enableInjection()
  }
}

// MARK: - Command

/// What the screen's menu has asked the list to do, and when.
///
/// The `token` is the whole reason this is a type rather than a `Bool`: SwiftUI
/// hands a view's state down on every update, so without something that changes
/// each time, "open everything" issued twice would arrive as the same value
/// and the second one would be indistinguishable from a redraw.
struct NissayaListCommand: Equatable {
  let token: Int
  let isOpen: Bool
}

// MARK: - List

#if canImport(UIKit)
/// Bridges ``NissayaListViewController`` into SwiftUI.
///
/// Deliberately thin. Everything the screen does lives in the view controller;
/// this exists only to hand it its prayer and to let SwiftUI own its lifetime.
private struct NissayaList: UIViewControllerRepresentable {
  let prayer: Prayer
  let command: NissayaListCommand?

  /// Remembers which command has already been carried out, because
  /// `updateUIViewController` runs for every reason SwiftUI has to update —
  /// a rotation, a change of appearance — and not only for a new command.
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  final class Coordinator {
    var carriedOut = 0
  }

  func makeUIViewController(context: Context) -> NissayaListViewController {
    NissayaListViewController(prayer: prayer)
  }

  func updateUIViewController(_ controller: NissayaListViewController, context: Context) {
    controller.update(prayer: prayer)

    guard let command, command.token != context.coordinator.carriedOut else { return }

    context.coordinator.carriedOut = command.token
    controller.setAllOpen(command.isOpen)
  }
}
#else
/// Stands in for the list on macOS, which has no UIKit and so no
/// ``NissayaListViewController``.
///
/// The Mac build exists for previews and for the split-view layout, not as a
/// shipping reading experience — so this says so rather than growing a second
/// list in SwiftUI that would then have to be kept in step with the real one.
private struct NissayaList: View {
  let prayer: Prayer
  /// Unused on macOS, which has no list to open or shut. Here so that the call
  /// site does not have to know which platform it is building for.
  let command: NissayaListCommand?

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "iphone")
        .font(.largeTitle)
      Text(L10n.readerUnavailable)
        .multilineTextAlignment(.center)
    }
    .foregroundStyle(.secondary)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
#endif

// MARK: - Previews

#Preview {
  NavigationStack {
    NissayaScreen(prayerID: "Khandha")
  }
}

#Preview("Named verses") {
  NavigationStack {
    NissayaScreen(prayerID: "ပဋ္ဌာန်းအကျယ်")
  }
}

#Preview("Long meanings") {
  NavigationStack {
    NissayaScreen(prayerID: "ဓဇဂ္ဂသုတ်")
  }
}

#Preview("Not found") {
  NavigationStack {
    NissayaScreen(prayerID: "no-such-prayer")
  }
}
