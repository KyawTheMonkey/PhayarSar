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
  /// settings sheet has something to bind to.
  ///
  /// ``PrayerThemeScreen`` writes straight through this binding, which is what
  /// makes the page react as the reader moves a control. Only its Save button
  /// puts the result in ``PrayerConfigurationStore``; this screen reloads from
  /// there on dismiss, so an abandoned experiment is dropped.
  @State private var configuration: PrayerConfiguration

  /// The drawing half of ``configuration``, which is all the page itself needs.
  private var settings: PrayerSettings { configuration.settings }

  /// The appearance the app is actually in, whether that came from the system or
  /// from the reader's own override.
  ///
  /// The reader had none until the paper became something to resolve rather than
  /// something to store — which is why a theme chosen in daylight used to keep
  /// its light paper here after dark while the detail screen swapped correctly.
  @Environment(\.colorScheme) private var colorScheme

  /// Whether the theme editor is up.
  @State private var isEditingTheme = false

  /// How far the switcher is open: 0 a pill, 1 a tray, and every value between
  /// a state a finger can hold it at.
  ///
  /// Held here rather than inside the switcher because the screen behind has to
  /// know how much of itself is covered — the catcher that closes the tray on a
  /// tap outside it cannot appear only once the tray is fully open.
  @State private var openness: CGFloat = 0

  /// How far through an exchange the page is: 0 sharp and in place, 1 blurred
  /// back and nearly gone.
  @State private var swapPhase: CGFloat = 0

  /// The pending exchange, held so a second turn started mid-blur replaces it
  /// rather than landing on top of it.
  @State private var swapWork: DispatchWorkItem?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Whether the reader has the inline nissaya sheet up.
  ///
  /// Reported up from the UIKit reader, which owns the sheet — see
  /// ``PrayerNissayaSheet``. The switcher has to know because it floats over the
  /// reader in *this* hierarchy, above anything the reader can draw, and it
  /// comes to rest exactly where the sheet arrives.
  @State private var isShowingNissaya = false

  /// Whether the page is reading itself, and whether that reading is halted.
  ///
  /// The shell's copy of what the reader owns. It is held here because the
  /// controls are here — the menu item that starts playback and the bar that
  /// pauses and stops it — and it is written from both ends: this screen sets it
  /// to ask, and the reader reports back through `onPlaybackChange` for every
  /// way playback ends that nobody asked for.
  @State private var playback: PrayerPlaybackState = .stopped

  /// How fast the page reads itself.
  ///
  /// Read straight off the configuration rather than held beside it, so there is
  /// no second copy to keep in step — scrubbing to another prayer brings that
  /// prayer's pace with it through the same reload the theme comes back on.
  private var speed: PrayerPlaybackSpeed { configuration.playbackSpeed }

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
    _configuration = State(initialValue: PrayerConfigurationStore.shared.configuration(for: prayerID))
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
    // The back button is the system's, and the bar keeps its own background:
    // this screen is a level down like any other, and a reader who has learned
    // where Back is should not have to find it again here.
    .toolbar {
      // Gone entirely while the page reads itself. Everything in here is
      // something to do *to* the page — start it reading, change how it is set —
      // and the reader has one thing to decide during a recitation, which the
      // bar at the foot of the page is holding. Leaving the menu up would also
      // leave a second way to open the theme sheet over a page that has just
      // dismissed one to start.
      if !isPlaying {
        // Its own button rather than an item in the menu beside it. Setting the
        // page reading is the one thing a reader does *to* a prayer often
        // enough to want it under the thumb rather than behind a tap — and it
        // is the odd one out among the menu's contents besides, which are all
        // ways of changing how the prayer is set rather than what it is doing.
        //
        // Before the menu, so it is the nearer of the two to the middle of the
        // bar and the further from the corner.
        ToolbarItem(placement: .primaryAction) {
          Button(action: startPlayback) {
            Image(systemName: "play.square.stack")
              .accessibilityLabel(L10n.playPrayer)
          }
        }

        // A menu rather than a second button, because this is where the rest of
        // the reader's own actions belong as they arrive — bookmarking,
        // reporting a spelling, adding to a plan.
        ToolbarItem(placement: .primaryAction) {
          Menu {
            Button {
              isEditingTheme = true
            } label: {
              Label(L10n.themeAndSettings, systemImage: "textformat.size")
            }
          } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
              .accessibilityLabel(L10n.quickActions)
          }
        }
      }
    }
    .sheet(isPresented: $isEditingTheme, onDismiss: loadConfiguration) {
      PrayerThemeScreen(configuration: $configuration, prayerID: selectedID)
    }
    // A full reload, for the same reason the detail screen does one: this
    // screen's state outlives a push, and the prayer's configuration can have
    // been changed by anything else that shows those controls while it was away.
    //
    // Safe against the theme sheet's pending edits — presenting a sheet does not
    // re-run the presenter's `onAppear`, and dismissing it is handled by
    // `onDismiss` above.
    .onAppear(perform: loadConfiguration)
    // The switcher can land on a prayer set up quite differently, so the page has
    // to follow it rather than carry the last prayer's settings onto this one.
    .onValueChange(selectedID, perform: loadConfiguration)
    .onValueChange(colorScheme, perform: followAppearance)
    .onDisappear { swapWork?.cancel() }
    // The watch remote. Attached here rather than inside the reader because
    // these are the two things the reader has no say over — which prayer is up,
    // and how large it is set. See `PrayerRemoteHost` for why the handle only
    // ever writes.
    .onAppear {
      PrayerRemoteHost.shared.attach(screen: remoteHandle)
      publishToRemote()
    }
    .onDisappear { PrayerRemoteHost.shared.attach(screen: nil) }
    // Both of these tell the watch what it is looking at. `selectedID` covers
    // the page switcher and the wrist's own prayer steps; `textSize` covers the
    // theme sheet, so a size changed on the phone moves the watch's control too.
    .onValueChange(selectedID, perform: publishToRemote)
    .onValueChange(configuration.settings.textSize, perform: publishToRemote)
    .enableInjection()
  }

  // MARK: - The page

  /// The reader, with the switcher floating over it.
  private func page(_ prayer: Prayer) -> some View {
    ZStack(alignment: .bottom) {
      // Under the reader rather than only inside it. A page drawing back and
      // fading through an exchange has to reveal paper; without this it would
      // be showing the void the reader was covering.
      settings.background.color
        // Every edge, not just the bottom. The navigation bar's own background
        // is translucent, so what sits behind it shows through — and that should
        // be the page the reader is on, not a strip of app background above it.
        .ignoresSafeArea()

      PrayerReader(
        prayer: prayer,
        settings: settings,
        onSheetChange: showNissaya,
        playback: playback,
        speed: speed,
        onPlaybackChange: { playback = $0 }
      )
        // The page colour runs to every edge — a reader with a strip of app
        // background under it reads as a card, not as a page.
        .ignoresSafeArea(edges: .bottom)
        // The turn: the page fades out, is exchanged while it is gone, and
        // fades back. See ``PrayerReaderMetrics/pageFade`` for why that is all
        // it does.
        .opacity(swapOpacity)

      if isTrayOpening {
        // Anywhere off the tray closes it. Live from the moment the tray starts
        // to open rather than once it is fully open, so there is no window in
        // which a half-open tray cannot be dismissed — and gone the rest of the
        // time, so the verses keep every tap of their own.
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { close() }
      }

      if isEditingTheme {
        // The same catcher, for the theme sheet.
        //
        // The sheet leaves the page live on purpose — see
        // `undimmedThroughMediumDetent` — which is what lets the reader watch it
        // reflow as they move a control. The cost is that the strip of page
        // above the sheet is still the reader's own tap target, so a tap meant
        // as "put this away" would land on a verse and carry the page off to
        // centre it. This takes those taps and closes the sheet instead, which
        // is what a tap outside a sheet means everywhere else.
        //
        // Above the reader and below the switcher: the switcher is mostly behind
        // the sheet anyway, and what shows of it should stay itself rather than
        // become more backdrop.
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { isEditingTheme = false }
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
      // Out of the way while the nissaya sheet is up, rather than floating on
      // top of it. Faded rather than removed: taken out of the layout it would
      // be rebuilt on the way back, and it would come back shut even if the
      // reader had left it open.
      //
      // Out of the way through playback too, and for a stronger reason: the
      // playback bar arrives in its exact place, and scrubbing to another
      // prayer mid-reading is a request that has no sensible answer.
      .opacity(isShowingNissaya || isPlaying ? 0 : 1)
      .allowsHitTesting(!isShowingNissaya && !isPlaying)
      .animation(.readerPageSettle, value: isShowingNissaya)
      .animation(PrayerPlaybackMetrics.handover, value: isPlaying)

      // The switcher's replacement, in the switcher's own place. Both are kept
      // in the hierarchy and faded past one another so that the pill's tray
      // state, and its measured ends, survive a reading.
      PrayerPlaybackBar(
        state: playback,
        speed: speed,
        settings: settings,
        onToggle: togglePlayback,
        onStop: stopPlayback,
        onSpeed: setSpeed
      )
      .appHorizontalInset()
      .padding(.bottom, PrayerPageSwitcherMetrics.bottomPadding)
      .opacity(isPlaying ? 1 : 0)
      .allowsHitTesting(isPlaying)
      .animation(PrayerPlaybackMetrics.handover, value: isPlaying)
    }
  }

  /// Whether the page is given over to playback, paused or not.
  private var isPlaying: Bool { playback != .stopped }

  // MARK: - Configuration

  /// Reads back the prayer the switcher has landed on.
  ///
  /// Also the dismiss handler for the theme sheet, which is what makes Save and
  /// swipe-away behave differently without a flag between them: Save has already
  /// written, so this reads it back, and an abandoned experiment has not, so this
  /// drops it.
  private func loadConfiguration() {
    configuration = PrayerConfigurationStore.shared
      .configuration(for: selectedID)
      .resolvingBackground(for: colorScheme)
  }

  /// Puts the page on the right half of its theme.
  ///
  /// Not persisted: it answers the system rather than the reader, and the paper
  /// is a pure function of the stored theme and the appearance.
  private func followAppearance() {
    configuration = configuration.resolvingBackground(for: colorScheme)
  }

  // MARK: - Playback

  /// Sets the page reading itself, a line at a time.
  ///
  /// Everything about *how* belongs to the reader — see
  /// ``PrayerViewController/setPlayback(_:)``. All this screen does is hold the
  /// state its controls are drawn from and hand it down; the reader is what
  /// knows where the page is, which line comes next, and when there is no next
  /// line.
  private func startPlayback() {
    // The page is about to be given over to the reading, so everything laid over
    // it goes first. The tray would otherwise be left open under the bar that is
    // about to take its place, and the theme sheet would be sitting over the
    // very lines the wheel is turning — with its own catcher swallowing the taps
    // meant for the bar underneath.
    //
    // Dismissing the sheet this way drops any edits it was carrying, which is
    // what dismissing it any other way does too: only its Save button writes,
    // and `onDismiss` reads the stored theme back over whatever the sheet had
    // been trying out.
    close()
    isEditingTheme = false
    playback = .playing
  }

  private func togglePlayback() {
    playback = playback == .playing ? .paused : .playing
  }

  private func stopPlayback() {
    playback = .stopped
  }

  /// Changes the pace, and keeps it.
  ///
  /// Persisted at the moment it is chosen, like a size set from the wrist and
  /// unlike the theme sheet's live edits: there is no Save here and no sheet to
  /// abandon, so choosing a pace mid-recitation is a decision rather than an
  /// experiment.
  private func setSpeed(_ speed: PrayerPlaybackSpeed) {
    guard speed != configuration.playbackSpeed else { return }

    // Built whole and then assigned, rather than mutated in place and read back
    // — see `remoteHandle` for why that distinction matters to `@State`.
    var updated = configuration
    updated.playbackSpeed = speed
    configuration = updated

    PrayerConfigurationStore.shared.save(updated, for: selectedID)
  }

  // MARK: - The watch remote

  /// What the watch is allowed to change on this screen.
  ///
  /// Writes only, and every one of them through the same path the equivalent
  /// gesture takes — the wrist has no privileges the finger does not, which is
  /// what keeps the two from producing different states.
  private var remoteHandle: PrayerRemoteScreenHandle {
    PrayerRemoteScreenHandle(
      show: { id in
        // Straight through the switcher's own commit, so a prayer chosen on the
        // wrist dissolves in exactly as one scrubbed to does, and lands in the
        // same state — nothing pushed, nothing popped, Back unchanged.
        guard let target = prayers.firstIndex(where: { $0.id == id }) else { return }
        commit(target, .settled)
      },
      setTextSize: { size in
        // Clamped to what the theme sheet itself offers. The watch has no way to
        // know whether the phone is showing a compact or a regular layout, so it
        // sends a number and this decides whether the number is allowed.
        let clamped = min(
          max(size, Int(PrayerThemeMetrics.minTextSize)),
          Int(PrayerThemeMetrics.compactMaxTextSize)
        )
        guard clamped != configuration.settings.textSize else { return }

        // Built whole and then assigned, rather than mutated in place and read
        // back. Writes to `@State` are not necessarily visible to a read in the
        // same synchronous block, so `save(configuration:)` after an in-place
        // mutation could persist the size the reader had *before* this.
        var updated = configuration
        updated.settings.textSize = clamped
        configuration = updated

        // Persisted, unlike the theme sheet's live edits: there is no Save on a
        // watch and no sheet to abandon, so a size set from the wrist is a
        // decision rather than an experiment.
        PrayerConfigurationStore.shared.save(updated, for: selectedID)
      }
    )
  }

  /// Tells the host which prayer is up and how large it is set.
  ///
  /// The host keeps this rather than reading it back, because there is nothing
  /// here to read it back *from* — see `PrayerRemoteHost`.
  private func publishToRemote() {
    PrayerRemoteHost.shared.screenDidChange(
      prayerID: selectedID,
      textSize: configuration.settings.textSize
    )
  }

  // MARK: - The turn

  private var swapOpacity: Double {
    1 - Double(swapPhase) * PrayerReaderMetrics.pageFade
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
  /// Nothing here opens or shuts the tray, even though in practice a commit is
  /// always followed by one shutting. That belongs to the gesture that let go
  /// of the ruler — see `PrayerPageSwitcher.workTheTray` — because it is the
  /// release that decides it, not the landing: a scrub that comes back to the
  /// prayer it started on commits nothing and still shuts the tray.
  private func commit(_ target: Int, _ kind: PrayerPageCommit) {
    guard prayers.indices.contains(target) else { return }

    guard target != index else { return }

    // Playback belonged to the prayer being left. Stopped here rather than left
    // to the reader to notice, so that the new prayer and the state of the
    // reading arrive together in one pass: the reader would otherwise be handed
    // the new page and, in the same breath, a request to go on reading — which
    // it would start doing before the shell could take it back.
    //
    // Only reachable from the wrist in practice. The switcher is out of the way
    // while the page reads itself, so a finger has nothing here to scrub.
    playback = .stopped

    guard kind == .settled else {
      // Following a finger on the shut pill. The page changes outright: a turn
      // per tick crossed would be half a second of dissolve each, stacked on
      // top of one another, and the reader is scrubbing precisely *because*
      // they want to see what is there.
      //
      // Any turn already in flight is dropped, and its half-faded page put
      // back — the reader has taken hold again, and finishing an exchange they
      // have already scrubbed past would be a page they did not ask for.
      swapWork?.cancel()
      swapWork = nil
      withoutAnimation {
        swapPhase = 0
        selectedID = prayers[target].id
      }
      return
    }

    swapWork?.cancel()
    withAnimation(.readerPageDissolve) { swapPhase = 1 }

    let exchange = DispatchWorkItem {
      // On an empty page, so there is nothing for the exchange to be seen
      // against.
      withoutAnimation { selectedID = prayers[target].id }

      withAnimation(.readerPageResolve) { swapPhase = 0 }
      swapWork = nil
    }

    swapWork = exchange
    DispatchQueue.main.asyncAfter(
      deadline: .now() + PrayerReaderMetrics.pageDissolve,
      execute: exchange
    )
  }

  /// Makes a change that SwiftUI must not animate, whatever animation the call
  /// happens to be nested inside.
  private func withoutAnimation(_ change: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, change)
  }

  /// The reader has opened or closed the inline nissaya sheet.
  private func showNissaya(_ isShowing: Bool) {
    isShowingNissaya = isShowing

    // A tray left open under the sheet would still be open behind it when the
    // sheet went away.
    if isShowing {
      close()
    }
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
  /// Called when the reader opens or closes its inline nissaya sheet.
  let onSheetChange: (Bool) -> Void
  /// What the shell's controls are asking the page to do.
  let playback: PrayerPlaybackState
  /// And how fast to do it.
  let speed: PrayerPlaybackSpeed
  /// Called when playback changes on the reader's own account — the prayer
  /// running out, or a hand on the page.
  let onPlaybackChange: (PrayerPlaybackState) -> Void

  func makeUIViewController(context: Context) -> PrayerViewController {
    let controller = PrayerViewController(prayer: prayer, settings: settings)
    controller.onSheetChange = onSheetChange
    controller.onPlaybackChange = onPlaybackChange

    return controller
  }

  func updateUIViewController(_ controller: PrayerViewController, context: Context) {
    // Re-set on every pass, because the closure captures the current `body`'s
    // state — a stale one would be writing to a `State` that has moved on.
    controller.onSheetChange = onSheetChange
    controller.onPlaybackChange = onPlaybackChange
    controller.update(prayer: prayer, settings: settings)
    // Before the playback state, so a reading that is about to start takes the
    // pace the reader has chosen rather than beginning at the last one and
    // correcting itself a line later.
    controller.setSpeed(speed)
    // After the update, so a prayer and a playback state arriving together are
    // applied in the order they have to be: the new page first, then the
    // reading of it. The reader ignores a state it is already in, which is what
    // most passes through here are.
    controller.setPlayback(playback)
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
  /// Unused on macOS, which has no reader and so no sheet. Here so that the
  /// call site does not have to know which platform it is building for.
  let onSheetChange: (Bool) -> Void
  /// Unused for the same reason: there is no page here to read itself.
  let playback: PrayerPlaybackState
  let speed: PrayerPlaybackSpeed
  let onPlaybackChange: (PrayerPlaybackState) -> Void

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
