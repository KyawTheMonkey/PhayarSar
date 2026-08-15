import DesignKit
import Inject
import LocalisationKit
import PrayersKit
import SwiftUI
import UtilKit

/// The reading screen — the prayer itself, verse by verse.
///
/// A SwiftUI shell around a UIKit reader (``PrayerViewController``), rather
/// than SwiftUI all the way down. The shell is what lets the screen sit in the
/// same `NavigationStack` and route table as every other screen; the UIKit
/// table underneath it is what the reading itself needs — see that type for
/// why.
///
/// Pushed from ``PrayerDetailScreen``'s "Start", via
/// `RouterDestination.prayer(prayerID:)`.
public struct PrayerScreen: View {
  @ObserveInjection private var injectionObserver

  /// Resolved from the id the route carried rather than passed in whole — see
  /// `RouterDestination`, whose payloads are ids so that routes stay `Codable`.
  private let prayer: Prayer?

  /// Held as state rather than read fresh each time, so that the reading
  /// settings sheet has something to bind to when it lands. Until then these
  /// are whatever ``PrayerSettings/settings(for:)`` returns and never change.
  @State private var settings: PrayerSettings

  public init(prayerID: String) {
    self.prayer = PrayerCatalog.shared.prayer(id: prayerID)
    _settings = State(initialValue: PrayerSettings.settings(for: prayerID))
  }

  public var body: some View {
    Group {
      if let prayer {
        PrayerReader(prayer: prayer, settings: settings)
          // The page colour runs to every edge — a reader with a strip of app
          // background under it reads as a card, not as a page.
          .ignoresSafeArea(edges: .bottom)
      } else {
        PrayerNotFoundView()
          .appBackground()
      }
    }
    .navigationTitle(prayer?.title ?? L10n.prayerNotFound)
    // No navigation bar on macOS, so no display mode to set either.
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    // Also set on the detail screen this is usually pushed from, but not
    // always: a resumed session or a notification can open this screen
    // directly, with the tab bar still showing.
    .hideTabBar()
    .enableInjection()
  }
}

// MARK: - Reader

#if canImport(UIKit)
/// Bridges ``PrayerViewController`` into SwiftUI.
///
/// Deliberately thin. Everything the reader does lives in the view controller;
/// this exists only to hand it its inputs and to let SwiftUI own its lifetime.
private struct PrayerReader: UIViewControllerRepresentable {
  let prayer: Prayer
  let settings: PrayerSettings

  func makeUIViewController(context: Context) -> PrayerViewController {
    PrayerViewController(prayer: prayer, settings: settings)
  }

  func updateUIViewController(_ controller: PrayerViewController, context: Context) {
    controller.update(prayer: prayer, settings: settings)
  }
}
#else
/// Stands in for the reader on macOS, which has no UIKit and so no
/// ``PrayerViewController``.
///
/// The Mac build exists for previews and for the split-view layout, not as a
/// shipping reading experience — so this says so rather than growing a second
/// reader in SwiftUI that would then have to be kept in step with the real one.
private struct PrayerReader: View {
  let prayer: Prayer
  let settings: PrayerSettings

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
    .background(settings.background.color)
  }
}
#endif

// MARK: - Previews

#Preview {
  NavigationStack {
    PrayerScreen(prayerID: "Khandha")
  }
}

#Preview("Named verses") {
  NavigationStack {
    PrayerScreen(prayerID: "ပဋ္ဌာန်းအကျယ်")
  }
}

#Preview("Not found") {
  NavigationStack {
    PrayerScreen(prayerID: "no-such-prayer")
  }
}
