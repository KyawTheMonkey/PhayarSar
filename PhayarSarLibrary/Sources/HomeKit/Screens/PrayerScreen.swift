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
/// The shell also owns moving between prayers. A floating
/// ``PrayerPageSwitcher`` scrubs the catalog and reports where it landed, and
/// the reader is simply handed a different prayer —
/// ``PrayerViewController/update(prayer:settings:)`` has always known how to
/// swap one in place. Nothing is pushed and nothing is popped, so Back still
/// leads to wherever the reader came in from however far they have scrubbed
/// since.
///
/// Pushed from ``PrayerDetailScreen``'s "Start", via
/// `RouterDestination.prayer(prayerID:)`.
public struct PrayerScreen: View {
  @ObserveInjection private var injectionObserver

  /// The catalog in reading order — which is the order the switcher scrubs in.
  /// See ``PrayerCatalog/orderedPrayers()``, whose whole purpose is that "next"
  /// means the next prayer the reader would have scrolled to on the home list,
  /// even where that crosses into the following category.
  ///
  /// Cheap to hold whole: the catalog has decoded and cached every prayer by
  /// the time this screen can open, so this is a reference to storage that
  /// exists anyway.
  private let prayers: [Prayer]

  /// Positions in ``prayers`` where a new category begins, which the switcher
  /// draws as landmarks along its strip.
  ///
  /// Worked out once here rather than in the switcher: it is a fact about the
  /// catalog, and the switcher redraws on every frame of a scrub.
  private let sectionStarts: Set<Int>

  /// Whether the id the route carried names a prayer this build ships. Only the
  /// *opening* id can fail this; every id after it comes from the switcher.
  private let isKnownPrayer: Bool

  /// Which prayer is being read. Everything else on the screen follows from it.
  @State private var selectedID: Prayer.ID

  /// Held as state rather than read fresh each time, so that the reading
  /// settings sheet has something to bind to when it lands. Until then these
  /// are whatever ``PrayerSettings/settings(for:)`` returns and never change.
  @State private var settings: PrayerSettings

  /// How far the switcher is open: 0 a pill, 1 a tray, and every value between
  /// a state a finger can hold it at.
  ///
  /// Held here rather than inside the switcher because the screen behind has to
  /// know how much of itself is covered — the catcher that closes the tray on a
  /// tap outside it cannot appear only once the tray is fully open.
  @State private var openness: CGFloat = 0

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Resolved from the id the route carried rather than passed in whole — see
  /// `RouterDestination`, whose payloads are ids so that routes stay `Codable`.
  public init(prayerID: String) {
    let catalog = PrayerCatalog.shared

    self.prayers = catalog.orderedPrayers()
    self.isKnownPrayer = catalog.prayer(id: prayerID) != nil

    var starts: Set<Int> = []
    var cursor = 0
    for section in catalog.sections() {
      starts.insert(cursor)
      cursor += section.prayers.count
    }
    self.sectionStarts = starts

    _selectedID = State(initialValue: prayerID)
    _settings = State(initialValue: PrayerSettings.settings(for: prayerID))
  }

  private var prayer: Prayer? {
    guard isKnownPrayer else { return nil }
    // A dictionary lookup rather than a scan of `prayers` — this is read on
    // every `body` evaluation.
    return PrayerCatalog.shared.prayer(id: selectedID)
  }

  /// Where the current prayer sits in the catalog, 0-based.
  private var index: Int {
    prayers.firstIndex { $0.id == selectedID } ?? 0
  }

  public var body: some View {
    Group {
      if let prayer {
        page(prayer)
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

  // MARK: - The page

  /// The reader, with the switcher floating over it.
  private func page(_ prayer: Prayer) -> some View {
    ZStack(alignment: .bottom) {
      PrayerReader(prayer: prayer, settings: settings)
        // The page colour runs to every edge — a reader with a strip of app
        // background under it reads as a card, not as a page.
        .ignoresSafeArea(edges: .bottom)

      if isTrayOpening {
        // Anywhere off the tray closes it. Live from the moment the tray starts
        // to open rather than once it is fully open, so there is no window in
        // which a half-open tray cannot be dismissed — and gone the rest of the
        // time, so the verses keep every tap of their own.
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { close() }
      }

      PrayerPageSwitcher(
        prayers: prayers,
        index: index,
        sectionStarts: sectionStarts,
        settings: settings,
        openness: $openness,
        onCommit: commit
      )
      .appHorizontalInset()
      .padding(.bottom, PrayerPageSwitcherMetrics.bottomPadding)
    }
  }

  /// Whether the tray has begun to open at all.
  ///
  /// A hair off zero rather than zero itself: the spring that shuts it
  /// undershoots through a little negative openness on the way to rest, and a
  /// bare `> 0` would leave the catcher flickering back for a frame at the end
  /// of every close.
  private var isTrayOpening: Bool {
    openness > 0.02
  }

  // MARK: - Changing prayer

  /// Moves the reader to the prayer the switcher landed on.
  ///
  /// The whole change is this one assignment. `updateUIViewController` carries
  /// it into ``PrayerViewController/update(prayer:settings:)``, which re-indexes
  /// the verses, re-applies the snapshot and puts the page back at the top.
  ///
  /// Nothing here opens or shuts the tray. Where it settles is decided by the
  /// gesture that let go of it — see `PrayerPageSwitcher.workTheTray` — and a
  /// commit is not evidence either way: the same release can land on a new
  /// prayer and leave the tray open to pick another.
  private func commit(_ target: Int) {
    guard prayers.indices.contains(target) else { return }

    selectedID = prayers[target].id
  }

  private func close() {
    guard openness != 0 else { return }

    withAnimation(reduceMotion ? nil : .readerPageSettle) { openness = 0 }
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
