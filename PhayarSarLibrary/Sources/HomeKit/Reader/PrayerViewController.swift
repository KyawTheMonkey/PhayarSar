#if canImport(UIKit)
import DesignKit
import LocalisationKit
import PrayersKit
// For the `UIColor(_: Color)` bridge — the design tokens are SwiftUI `Color`s.
import SwiftUI
import UIKit

/// The reading screen: a prayer's lines, one per row, each with the phonetic
/// respelling over the Pali it stands for.
///
/// UIKit rather than SwiftUI because of what this screen is going to become. A
/// reader has to hold a scroll position across a settings change, scroll a
/// named verse to a precise offset when playback moves to it, and keep a
/// thousand rows of reshaped Burmese smooth under the finger — `UITableView`
/// gives all three directly, where SwiftUI's `ScrollView` gives none of them
/// without fighting it.
///
/// Wrapped for the navigation stack by ``PrayerScreen``.
final class PrayerViewController: UIViewController {

  // MARK: - Diffable types

  /// One section for now. The enum, rather than a bare `Int`, is so the
  /// nissaya and meaning passes can be added as sections of their own without
  /// rewriting the data source.
  enum Section: Hashable {
    case verses
  }

  /// Identity only — which line of which prayer, not what it says.
  ///
  /// Deliberately carries nothing that a *settings* change would alter: with
  /// the text in here, changing the type size would diff as "every row deleted
  /// and a new one inserted" and animate the whole prayer out and back.
  /// Identity in the snapshot, content in the cell provider, and a settings
  /// change becomes a reconfigure of rows that never moved.
  ///
  /// It does carry the prayer, though, and has to. Without it a line is
  /// identified by its position alone — verse 1, line 0 — which every prayer in
  /// the catalog has. Swapping the prayer under the table then diffs as *no
  /// change at all* for every position the two prayers share: the rows are
  /// never reconfigured, the cell provider is never asked for their new text,
  /// and the reader goes on showing the prayer it was on under the new one's
  /// title, with only the tail beyond the shorter of the two inserted or
  /// deleted. With the prayer in here the whole snapshot is replaced, which is
  /// what a different prayer actually is.
  enum Item: Hashable {
    case line(prayer: Prayer.ID, line: PrayerVerseLine.ID)
  }

  private typealias DataSource = UITableViewDiffableDataSource<Section, Item>
  private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

  // MARK: - State

  private var prayer: Prayer
  private var settings: PrayerSettings
  private var style: PrayerReadingStyle

  /// The prayer's lines in reading order, which is what the table shows.
  private var lines: [PrayerVerseLine] = []

  /// The prayer's verses, deduplicated exactly as ``lines`` was built from
  /// them.
  ///
  /// Kept because the watch remote addresses the page by *verse* while the
  /// table is a list of lines — see ``remoteStepVerse(_:)``. Taken from the same
  /// filtered array rather than from `prayer.body` so an ordinal means the same
  /// thing on both sides of that translation, duplicates and all.
  private var verses: [Prayer.Verse] = []

  /// Where each verse's first line sits in ``lines``, so stepping to a verse is
  /// a lookup rather than a scan of the whole prayer on every turn of the crown.
  private var firstLineByVerse: [Prayer.Verse.ID: Int] = [:]

  /// Each verse's 0-based position in ``verses``, for the reverse trip — the
  /// line under the middle of the page back to the verse it belongs to. Looked
  /// up on every scroll event, which is why it is a dictionary and not a scan.
  private var ordinalByVerse: [Prayer.Verse.ID: Int] = [:]

  /// The verse last reported to the watch, so that a scroll which stays inside
  /// one verse says nothing. Scrolling reports at frame rate; the watch only
  /// cares when the answer changes.
  private var centredVerse: Int?

  /// Line by identity, for the cell provider. A dictionary rather than
  /// `lines[indexPath.row]`: the cell provider is handed an identifier, and
  /// looking it up is what keeps the two from drifting apart mid-update.
  private var linesByID: [PrayerVerseLine.ID: PrayerVerseLine] = [:]

  /// The nissaya of every verse that has one, by verse.
  ///
  /// Only the verses that have one: a handful across the catalog ship an empty
  /// `meaning`, and four prayers have none at all. A verse missing from here is
  /// one whose rows are never offered the action, rather than one that turns
  /// over to an empty face.
  private var meaningsByVerse: [Prayer.Verse.ID: String] = [:]

  /// The inline nissaya sheet, while one is up.
  private var nissayaSheet: PrayerNissayaSheet?

  /// The line the sheet is currently carrying, which the page hides for as long
  /// as it is up — see ``PrayerVerseLineCell/Emphasis/lifted``.
  private var liftedLine: PrayerVerseLine.ID?

  /// Told when a sheet opens and closes, so that the SwiftUI chrome floating
  /// over the reader can get out of the way — see ``PrayerScreen``. The switcher
  /// sits exactly where the sheet arrives, and it belongs to a view hierarchy
  /// this one cannot draw above.
  var onSheetChange: ((Bool) -> Void)?

  /// Whether the page is reading itself, and how far into doing so.
  ///
  /// Owned here rather than in ``PrayerScreen``, which only *asks*. The shell
  /// holds a copy to draw its controls from, but every way playback can end
  /// without being asked to — the prayer running out, a finger on the page, the
  /// screen going away — is something only the reader can see, so the reader is
  /// where the answer lives and ``onPlaybackChange`` is how the shell hears
  /// about it.
  private(set) var playback: PrayerPlaybackState = .stopped

  /// The row playback is resting on, or `nil` when it is stopped.
  ///
  /// A row rather than a line identity, because stepping is `+ 1` and the table
  /// is addressed by index everywhere else in here. It is turned into an
  /// identity only where the emphasis needs one — see ``recitedLine``.
  private var recitedRow: Int?

  /// What moves the page on. Invalidated on every exit from `.playing`, which
  /// is what makes pause a pause rather than a page that keeps going quietly.
  private var playbackTimer: Timer?

  /// How fast the page reads itself. Held here rather than read off the shell
  /// on every step, so the timer and the step it schedules cannot disagree.
  private var speed: PrayerPlaybackSpeed = .normal

  /// Whether the current pause was the app going away rather than the reader
  /// asking for one.
  ///
  /// The distinction is the whole of it: a reading interrupted by a phone call
  /// should pick itself up when the call ends, and one the reader paused on
  /// purpose before putting the phone down should still be paused when they take
  /// it out again. Cleared by every other way into and out of a pause, so only
  /// the interruption itself can set it.
  private var resumesWhenActive = false

  /// Told when playback changes on its own account, so the shell's controls can
  /// follow. Never called for a change the shell itself asked for — it already
  /// knows about those, and the round trip would only be a chance to disagree.
  var onPlaybackChange: ((PrayerPlaybackState) -> Void)?

  private lazy var tableView = UITableView(frame: .zero, style: .plain)
  private lazy var dataSource = makeDataSource()


  // MARK: - Life cycle

  init(prayer: Prayer, settings: PrayerSettings) {
    self.prayer = prayer
    self.settings = settings
    self.style = PrayerReadingStyle(settings: settings)
    super.init(nibName: nil, bundle: nil)
    indexVerses()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setUpTableView()
    applyStyle()
    applySnapshot(animated: false)

    // The fonts are scaled through `UIFontMetrics` at the moment they are
    // built, so a size change while the screen is open needs them rebuilt.
    // `adjustsFontForContentSizeCategory` can't do it for us — these labels
    // carry attributed text, whose fonts it leaves alone.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(contentSizeCategoryDidChange),
      name: UIContentSizeCategory.didChangeNotification,
      object: nil
    )

    // Resigning active rather than entering the background, which is the wider
    // net and the right one. Backgrounding stops the run loop, so the timer
    // would go quiet on its own — but a control centre pulled halfway down, an
    // incoming call, or the app switcher leaves the app running with the page
    // half covered, and a reading that carries on behind that is a reading the
    // reader has missed.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  // Registered here rather than in `viewDidLoad` so the host is driving the
  // reader that is actually on screen. A reader built for a push that the user
  // then cancelled mid-swipe is loaded but never appears, and must not take the
  // wrist from the one they swiped back to.
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    PrayerRemoteHost.shared.attach(reader: self)
    reportPosition()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    PrayerRemoteHost.shared.detach(reader: self)
    // A page nobody is looking at should not be turning itself. Reported, so
    // the shell's controls are not still showing pause when the reader comes
    // back to it.
    //
    // Also the only place the timer is invalidated on the way out, and it has to
    // be: the run loop holds the timer rather than this controller, so one left
    // running would go on firing into a dead closure. `deinit` cannot do it —
    // a `Timer` is not `Sendable`, and a nonisolated `deinit` may not touch it —
    // but nothing that never appeared can have started playing, and everything
    // that appeared comes through here.
    endPlayback(reporting: true)
  }

  // MARK: - Set up

  private func setUpTableView() {
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.register(
      PrayerVerseLineCell.self,
      forCellReuseIdentifier: PrayerVerseLineCell.reuseIdentifier
    )
    tableView.separatorStyle = .none
    // Tapping a line brings it to the middle of the page. The highlight stays
    // off — the cells draw no selected state, so the tap moves the page and
    // leaves nothing behind. When tapping also means "start playback from
    // here", the highlight comes back with it.
    tableView.allowsSelection = true
    tableView.delegate = self
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = PrayerReaderMetrics.estimatedRowHeight
    tableView.contentInset = UIEdgeInsets(
      top: PrayerReaderMetrics.topInset,
      left: 0,
      bottom: PrayerReaderMetrics.bottomInset,
      right: 0
    )
    // The reader is a page of text, and the indicator overlaying it is the only
    // moving thing on the screen while it scrolls.
    tableView.showsVerticalScrollIndicator = false
    // Touching `dataSource` is what builds it, and its initialiser is what
    // assigns itself to the table — there is no `tableView.dataSource =` to
    // write here.
    _ = dataSource

    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  private func makeDataSource() -> DataSource {
    DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
      let cell = tableView.dequeueReusableCell(
        withIdentifier: PrayerVerseLineCell.reuseIdentifier,
        for: indexPath
      )

      guard let self, let cell = cell as? PrayerVerseLineCell else { return cell }

      self.configure(cell, for: item)

      return cell
    }
  }

  private func configure(_ cell: PrayerVerseLineCell, for item: Item) {
    guard case let .line(_, id) = item, let line = linesByID[id] else { return }

    cell.configure(with: line, style: style)
  }

  // MARK: - Content

  /// Flattens the prayer into the rows the table shows.
  ///
  /// The verses are deduplicated by index first: a diffable snapshot traps on a
  /// repeated identifier, and `index` comes from hand-maintained JSON — a
  /// duplicate there would be a crash on open rather than a doubled verse.
  /// Dropping the repeat keeps the screen up.
  private func indexVerses() {
    var seen: Set<Prayer.Verse.ID> = []
    let verses = prayer.body.filter { seen.insert($0.id).inserted }

    self.verses = verses
    lines = PrayerVerseLine.lines(in: verses)
    linesByID = Dictionary(uniqueKeysWithValues: lines.map { ($0.id, $0) })

    meaningsByVerse = Dictionary(
      uniqueKeysWithValues: verses.compactMap { verse in
        let meaning = verse.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        return meaning.isEmpty ? nil : (verse.id, meaning)
      }
    )

    // First occurrence wins, which is the verse's opening line — the one the
    // remote centres when it is asked for that verse.
    firstLineByVerse = [:]
    for (row, line) in lines.enumerated() where firstLineByVerse[line.id.verse] == nil {
      firstLineByVerse[line.id.verse] = row
    }

    ordinalByVerse = Dictionary(
      uniqueKeysWithValues: verses.enumerated().map { ($0.element.id, $0.offset) }
    )

    centredVerse = nil
  }

  private func applySnapshot(animated: Bool) {
    var snapshot = Snapshot()
    snapshot.appendSections([.verses])
    snapshot.appendItems(
      lines.map { Item.line(prayer: prayer.id, line: $0.id) },
      toSection: .verses
    )
    dataSource.apply(snapshot, animatingDifferences: animated)
  }

  /// Pushes the current style into rows that are already on screen.
  ///
  /// `reconfigureItems` rather than `reloadItems`: reconfigure hands the
  /// existing cell back to the provider, so the rows keep their place and the
  /// reader's scroll position survives a change of type size.
  private func reconfigureVisibleLines() {
    var snapshot = dataSource.snapshot()
    snapshot.reconfigureItems(snapshot.itemIdentifiers)
    dataSource.apply(snapshot, animatingDifferences: false)
  }

  // MARK: - Following a tap

  /// The line the reader last tapped, for as long as the page is stepped back
  /// around it.
  private var focusedLine: PrayerVerseLine.ID?

  /// Puts the page back up. Held so a second tap can cancel the first one's
  /// release rather than have it land in the middle of the second.
  private var focusRelease: DispatchWorkItem?

  /// Carries a line to the middle of the page, with the page receding around it
  /// as it goes, and lets go a beat after it lands.
  ///
  /// The move is animated here rather than left to `scrollToRow(at:at:animated:)`
  /// so that it and the tint can share one animation: the same duration, the
  /// same curve, the same instant of starting and stopping. Handing the scroll
  /// to UIKit would mean guessing at the length of an animation it does not
  /// document and syncing to the guess.
  ///
  /// It also gives the release something dependable to hang off. The obvious
  /// hook, `scrollViewDidEndScrollingAnimation`, is the wrong one: a tap on a
  /// line the table cannot centre — near either end of the prayer, where the
  /// scroll is clamped — moves the page not at all and so never reports
  /// finishing, and the page would stay stepped back with nothing to put it
  /// right. A `UIView` animation's completion runs either way.
  private func follow(_ id: PrayerVerseLine.ID, at indexPath: IndexPath) {
    focusRelease?.cancel()
    focusRelease = nil

    focusedLine = id
    let offset = centredOffset(for: indexPath)

    UIView.animate(
      withDuration: PrayerReaderMetrics.focusScroll,
      delay: 0,
      // `beginFromCurrentState` so a second tap mid-move carries on from where
      // the page has got to; `allowUserInteraction` so the reader can take the
      // page back at any point.
      options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
      animations: {
        self.tableView.contentOffset = offset
        // Unanimated on its own account — it is this block that animates it,
        // which is what puts the page's receding on the move's clock.
        self.applyEmphasis(animated: false)
      },
      completion: { [weak self] finished in
        // An unfinished move was cut short by the reader dragging, or replaced
        // by a second tap. Either way the release it would schedule belongs to
        // a follow that is no longer happening.
        guard finished else { return }
        self?.scheduleRelease()
      }
    )
  }

  private func scheduleRelease() {
    focusRelease?.cancel()

    let release = DispatchWorkItem { [weak self] in
      self?.releaseFocus()
    }
    focusRelease = release
    DispatchQueue.main.asyncAfter(
      deadline: .now() + PrayerReaderMetrics.focusLinger,
      execute: release
    )
  }

  private func releaseFocus() {
    focusRelease?.cancel()
    focusRelease = nil

    guard focusedLine != nil else { return }
    focusedLine = nil
    applyEmphasis(animated: true)
  }

  /// Leaves a follow's scroll where the page has actually got to, for a reader
  /// who has grabbed it part way there.
  ///
  /// Without this the page jumps: a finger on a scroll view drives the offset
  /// from its *model* value, which an animation in flight has already set to
  /// the far end, so the page would leap the rest of the move before following
  /// the finger. Taking the offset off the presentation layer and dropping the
  /// animation makes the page carry on from where it looks like it is.
  private func stopFollowingScroll() {
    // Only ever a follow's own animation. Every other drag of the page reaches
    // here too, and none of them has anything to be cut short.
    guard
      focusedLine != nil,
      let presented = tableView.layer.presentation()?.bounds.origin
    else {
      return
    }

    UIView.performWithoutAnimation {
      // Only the scroll animation lives on the table's own layer; the page
      // receding is on the cells'.
      tableView.layer.removeAllAnimations()
      tableView.contentOffset = presented
    }
  }

  /// How a row is to be drawn.
  ///
  /// Takes the index path as well as the item because the wheel is measured in
  /// *rows away from the read line*, and an item identifier says which line it
  /// is without saying where. Both are already to hand at every call site.
  private func emphasis(
    for item: Item,
    at indexPath: IndexPath
  ) -> PrayerVerseLineCell.Emphasis {
    // Before the follow, because a lifted line is off the page entirely and a
    // page that is not being followed still has one to hide.
    if let liftedLine, item == .line(prayer: prayer.id, line: liftedLine) { return .lifted }

    // Above the follow too, and for the same reason it takes the page's
    // gestures away: while the page is reading itself, the line it is on is the
    // only one that can be picked out, and a tap's leftovers underneath would
    // be a second answer to the same question.
    if playback != .stopped, let recitedRow, lines.indices.contains(recitedRow) {
      let distance = indexPath.row - recitedRow
      return distance == 0 ? .reciting : .waiting(distance: distance)
    }

    guard let focusedLine else { return .none }
    return item == .line(prayer: prayer.id, line: focusedLine) ? .focused : .receded
  }

  private func applyEmphasis(animated: Bool) {
    for cell in tableView.visibleCells {
      guard
        let cell = cell as? PrayerVerseLineCell,
        let indexPath = tableView.indexPath(for: cell),
        let item = dataSource.itemIdentifier(for: indexPath)
      else {
        continue
      }

      cell.setEmphasis(emphasis(for: item, at: indexPath), animated: animated)
    }
  }

  // MARK: - Reading itself

  /// Takes the state ``PrayerScreen`` wants the page to be in.
  ///
  /// The one way in from the shell, and deliberately a state rather than three
  /// verbs: the shell holds a value and this makes the page match it, so a
  /// control tapped twice in a frame cannot leave the two disagreeing.
  func setPlayback(_ state: PrayerPlaybackState) {
    // Nothing can be started against a table that has not been laid out — there
    // are no rows to centre and no page to centre them in. The shell can only
    // reach this from a control on screen, so a reader who has not appeared has
    // nothing to say here.
    guard isViewLoaded, state != playback else { return }

    switch state {
    case .playing:
      playback == .paused ? resumePlayback() : startPlayback()
    case .paused:
      pausePlayback(reporting: false)
    case .stopped:
      endPlayback(reporting: false)
    }
  }

  /// Takes the pace ``PrayerScreen`` is showing.
  ///
  /// A change lands on the *next* line rather than the one being read: the
  /// clock is restarted from now, so choosing double speed part way through a
  /// line does not snatch it away mid-word, and choosing quarter does not leave
  /// the reader waiting out the remainder of the old pace first.
  func setSpeed(_ speed: PrayerPlaybackSpeed) {
    guard speed != self.speed else { return }

    self.speed = speed

    guard playback == .playing else { return }
    schedulePlaybackStep()
  }

  /// Starts the page reading itself from the first line the reader can see.
  ///
  /// From what is on screen rather than from the top of the prayer: a reader who
  /// has scrolled half way in and pressed play means *here*. On an unscrolled
  /// page the two are the same thing, which is the common case answering
  /// correctly for free.
  private func startPlayback() {
    resumesWhenActive = false

    // Both of these are the page doing something else with the same line. A tap
    // still being followed would fight the first step for the scroll, and the
    // sheet is about one verse of a prayer the page is about to walk out of.
    releaseFocus()
    nissayaSheet?.dismiss()
    settleScroll()

    guard let first = firstReadableRow else {
      // A prayer with no lines in it at all. Nothing to read, so the shell is
      // told to put its controls away rather than left showing a bar over a
      // page that is never going to move.
      //
      // Reported a beat later because this is reached from inside a SwiftUI
      // update pass, which is no place to write the shell's state.
      DispatchQueue.main.async { [weak self] in
        self?.onPlaybackChange?(.stopped)
      }
      return
    }

    playback = .playing
    recitedRow = first
    applyPlaybackGestures()
    recite()
    schedulePlaybackStep()
  }

  /// Goes on from the line playback was left on.
  ///
  /// Re-centres that line rather than simply restarting the clock, because the
  /// commonest way to pause is to have grabbed the page — so the line playback
  /// is on is usually no longer where the reader left it.
  private func resumePlayback() {
    resumesWhenActive = false

    guard let resumingAt = recitedRow else { return startPlayback() }

    // Nothing left to go on to. A reading that ran out has already stopped and
    // rewound, so this is a reader who paused on the last line themselves — and
    // play at the end of something means play it again.
    if resumingAt >= lines.count - 1 {
      recitedRow = 0
    }

    playback = .playing
    applyPlaybackGestures()
    recite()
    schedulePlaybackStep()
  }

  /// Holds the page where it is, keeping the line, the wheel turned away around
  /// it, and the gestures playback has taken.
  ///
  /// - Parameter reporting: whether the shell needs telling. `true` for every
  ///   pause it did not ask for — a hand on the page, a turn of the crown, the
  ///   prayer running out under the reading.
  private func pausePlayback(reporting: Bool) {
    guard playback == .playing else { return }

    // Set again by the interruption itself, if that is what this is. Anything
    // else reaching here — a hand on the page, the pause button, the end of the
    // prayer — is a pause the app has no business undoing later.
    resumesWhenActive = false

    playbackTimer?.invalidate()
    playbackTimer = nil
    // The step that was in flight stops where it has got to rather than
    // carrying on to a line the reader has just asked it to stop at.
    settleScroll()
    playback = .paused

    if reporting {
      onPlaybackChange?(.paused)
    }
  }

  /// Puts the page back the way it was found.
  ///
  /// - Parameter reporting: whether the shell needs telling. `true` for every
  ///   way playback ends that the shell did not ask for — the prayer running
  ///   out, a page being swapped under it, the screen going away.
  private func endPlayback(reporting: Bool) {
    resumesWhenActive = false

    guard playback != .stopped else { return }

    playbackTimer?.invalidate()
    playbackTimer = nil
    settleScroll()

    playback = .stopped
    recitedRow = nil
    applyPlaybackGestures()
    // Animated, so the prayer comes back up around the line it finished on
    // rather than snapping to full strength.
    applyEmphasis(animated: true)

    if reporting {
      onPlaybackChange?(.stopped)
    }
  }

  /// Moves to the next line, or finishes if there is not one.
  private func stepPlayback() {
    guard playback == .playing, let current = recitedRow else { return }

    let next = current + 1
    guard lines.indices.contains(next) else {
      // The end of the prayer. The reading is over, so this is a stop and not a
      // pause: the page comes back up whole, the gestures and the menu come
      // back, and the bar puts itself away — everything the Stop button does,
      // because the reader has arrived at the same place by reading rather than
      // by deciding to leave.
      //
      // Not the next prayer, either. The reader asked for *this* one to be
      // read, and carrying on into whatever follows it in the catalog is a
      // decision they did not make.
      endPlayback(reporting: true)
      // And back to the opening line, so the prayer is left as it was found
      // rather than at the tail the reading ran out on — ready to be read
      // again, by eye or by pressing play.
      scrollToTop()
      return
    }

    recitedRow = next
    recite()
  }

  /// Carries the line playback is on into the middle of the page, with the rest
  /// of the prayer drawing back around it.
  ///
  /// One animation for the move and the emphasis, exactly as ``follow(_:at:)``
  /// does it and for the same reason: two clocks over one movement is two
  /// movements.
  private func recite() {
    guard let recitedRow, lines.indices.contains(recitedRow) else { return }

    let indexPath = IndexPath(row: recitedRow, section: 0)
    let offset = offset(centring: tableView.rectForRow(at: indexPath))

    // A step is a line's worth of travel and is meant to be watched. Anything
    // further than a screenful is not a step — it is the reading starting again
    // from the top, or going on from a line the reader has scrolled a long way
    // off from — and the same curve stretched over that distance is a smear
    // rather than a scroll.
    guard abs(offset.y - tableView.contentOffset.y) <= tableView.bounds.height else {
      UIView.performWithoutAnimation {
        tableView.contentOffset = offset
        applyEmphasis(animated: false)
      }
      return
    }

    // A property animator rather than `UIView.animate`, for the curve alone:
    // the four named UIKit curves cannot say how much of the move is spent
    // lifting off and how much setting down, and this move is the one the
    // reader follows down the page. Its views stay interactive while it runs —
    // the page has to be there to be grabbed, which is the gesture that pauses
    // this.
    eased(for: speed.scroll) {
      self.tableView.contentOffset = offset
      // Unanimated on its own account — it is the animator that animates it,
      // which is what puts the wheel's turning on the move's clock.
      self.applyEmphasis(animated: false)
    }
  }

  /// Runs a change on playback's curve — see
  /// ``PrayerReaderMetrics/playbackEaseIn``.
  private func eased(for duration: TimeInterval, _ change: @escaping () -> Void) {
    let animator = UIViewPropertyAnimator(
      duration: duration,
      controlPoint1: PrayerReaderMetrics.playbackEaseIn,
      controlPoint2: PrayerReaderMetrics.playbackEaseOut
    )
    animator.addAnimations(change)
    animator.startAnimation()
  }

  /// The app is going away, or being covered over.
  ///
  /// Reported like any other pause, so the bar shows what is true — and so the
  /// reader who comes back to a paused page and presses play themselves gets
  /// exactly what they asked for rather than a page that starts twice.
  @objc private func applicationWillResignActive() {
    guard playback == .playing else { return }

    pausePlayback(reporting: true)
    resumesWhenActive = true
  }

  /// And coming back.
  ///
  /// Only for the reader still looking at this page. A reader who left the
  /// screen has already stopped playback on the way out — see
  /// ``viewDidDisappear(_:)`` — and the window check covers the rest: a reader
  /// pushed forward to another screen leaves this one loaded, and it must not
  /// start reading to itself underneath whatever they went to.
  @objc private func applicationDidBecomeActive() {
    guard resumesWhenActive else { return }

    resumesWhenActive = false

    guard playback == .paused, view.window != nil else { return }

    resumePlayback()
    onPlaybackChange?(.playing)
  }

  /// Puts the page back at the opening line.
  ///
  /// Timed from the distance rather than fixed, and on the same curve as every
  /// step was — this can be a move of five lines or of five hundred, and one
  /// duration cannot serve both. See ``PrayerReaderMetrics/rewindSpeed``.
  ///
  /// `setContentOffset(_:animated:)` would have been the one-liner, but its
  /// animation is UIKit's own: a fixed length whatever the distance, and a
  /// curve that has nothing to do with the one the reader has been watching for
  /// the length of a prayer.
  private func scrollToTop() {
    let target = CGPoint(x: 0, y: -tableView.adjustedContentInset.top)
    let distance = abs(tableView.contentOffset.y - target.y)
    guard distance > 0 else { return }

    let duration = min(
      max(TimeInterval(distance / PrayerReaderMetrics.rewindSpeed), PrayerReaderMetrics.rewindShortest),
      PrayerReaderMetrics.rewindLongest
    )

    eased(for: duration) { self.tableView.contentOffset = target }
  }

  private func schedulePlaybackStep() {
    playbackTimer?.invalidate()

    // Repeating rather than rescheduled per step: every line is held for the
    // same beat, so there is nothing for a fresh timer each time to say that
    // this one does not.
    playbackTimer = Timer.scheduledTimer(
      withTimeInterval: speed.interval,
      repeats: true
    ) { [weak self] _ in
      self?.stepPlayback()
    }
  }

  /// Takes the page's own gestures away while it is reading itself, and gives
  /// them back when it stops.
  ///
  /// Both of them mean something that would fight the reading. A tap carries a
  /// line to the middle of the page, which is the very thing playback is doing
  /// on its own clock; a swipe opens a tray over a row that is about to be
  /// stepped past. Paused counts as playing here — the page is still given over
  /// to the reading, and a reader who wants their gestures back has Stop.
  ///
  /// Dragging is left alone on purpose: it is how playback is paused.
  private func applyPlaybackGestures() {
    tableView.allowsSelection = playback == .stopped
  }

  /// The first line the reader is actually looking at.
  ///
  /// Measured by the *middle* of each row rather than its top edge. The obvious
  /// test — the first row that begins at or below the top of the page — is
  /// wrong by a whole line on the commonest case there is: a page that has not
  /// been scrolled at all, where the first row starts at exactly the top and a
  /// fraction of a point of rounding between `contentOffset` and the adjusted
  /// inset decides whether it counts. It usually did not, and the reading
  /// started on the second line of the prayer.
  ///
  /// Half a row is also the better rule on its own account, for the case the
  /// top-edge test was reaching for: the row at the top of a scrolled page is
  /// often cut, and a line with most of itself on screen is one the reader is
  /// reading, where a line with a sliver showing is one they have left behind.
  private var firstReadableRow: Int? {
    guard !lines.isEmpty else { return nil }
    guard let visible = tableView.indexPathsForVisibleRows, !visible.isEmpty else {
      // No rows laid out yet, which is a page that has only just appeared: the
      // beginning is the only answer it has.
      return 0
    }

    let top = tableView.contentOffset.y + tableView.adjustedContentInset.top

    let readable = visible.first { tableView.rectForRow(at: $0).midY >= top }
    return (readable ?? visible[0]).row
  }

  // MARK: - Centring a line

  /// The band of the page a tapped line has to fall outside of before the page
  /// will move for it.
  ///
  /// There is a dead zone at all because otherwise every tap would scroll: a
  /// line a few points off the middle would slide to the middle, which reads as
  /// the page twitching under the finger rather than as a deliberate move.
  ///
  /// In content coordinates, and measured against the *inset* page — the safe
  /// area and the reader's own top and bottom insets are not somewhere a line
  /// can sit, so counting them would put the band off-centre from the part of
  /// the page that can actually be read.
  private var centredBand: (minY: CGFloat, maxY: CGFloat, height: CGFloat)? {
    let inset = tableView.adjustedContentInset
    let pageHeight = tableView.bounds.height - inset.top - inset.bottom
    guard pageHeight > 0 else { return nil }

    let pageTop = tableView.contentOffset.y + inset.top
    let margin = pageHeight * (1 - PrayerReaderMetrics.centredBandFraction) / 2

    return (
      minY: pageTop + margin,
      maxY: pageTop + pageHeight - margin,
      height: pageHeight - 2 * margin
    )
  }

  /// Where the page has to sit for a line to be in the middle of it — or where
  /// it sits now, if the line is near enough to the middle already.
  ///
  /// Returning the current offset rather than nothing, so that a tap which
  /// moves the page and a tap which does not are the same animation with the
  /// same completion. Only the distance differs.
  private func centredOffset(for indexPath: IndexPath) -> CGPoint {
    let current = tableView.contentOffset
    guard let band = centredBand else { return current }

    let row = tableView.rectForRow(at: indexPath)

    // A line taller than the band can never sit inside it, so it is judged by
    // where its middle falls instead. Without that, the page would move for
    // every tap on a line that long however well centred it already was — and
    // at the largest type sizes that is an ordinary line, not a freak one.
    let isCentred = row.height > band.height
      ? row.midY >= band.minY && row.midY <= band.maxY
      : row.minY >= band.minY && row.maxY <= band.maxY

    guard !isCentred else { return current }

    return offset(centring: row)
  }

  /// Where the page has to sit for a rect to be in the middle of it, with no
  /// dead zone and no question of whether it is near enough already.
  ///
  /// The dead zone in ``centredOffset(for:)`` is about *taps*: a page that
  /// twitched at every tap would be unusable. Playback is the other case
  /// entirely — it steps one line at a time, and neighbouring lines are exactly
  /// what fall inside that zone, so a step judged the same way would leave the
  /// page standing still for runs of a prayer at a time while the emphasis
  /// walked down it alone.
  private func offset(centring row: CGRect) -> CGPoint {
    let inset = tableView.adjustedContentInset
    let pageHeight = tableView.bounds.height - inset.top - inset.bottom

    // Clamped to what the page can actually show, so a line near either end of
    // the prayer settles against that end rather than pulling the page past it.
    let top = -inset.top
    let bottom = max(top, tableView.contentSize.height + inset.bottom - tableView.bounds.height)
    let y = row.midY - inset.top - pageHeight / 2

    return CGPoint(x: tableView.contentOffset.x, y: min(max(y, top), bottom))
  }

  // MARK: - The inline nissaya sheet

  /// Brings the inline nissaya sheet up over the page.
  ///
  /// The sheet gets the whole verse, which is what the nissaya is written for,
  /// and the line the reader swiped, which is what it marks in it.
  ///
  /// The verse is taken from ``lines`` rather than from `prayer.body`, so that
  /// the sheet shows the very rows the page is showing: the two would otherwise
  /// be separate flattenings of the same verse and could split differently.
  private func openNissaya(for line: PrayerVerseLine.ID) {
    let verse = lines.filter { $0.id.verse == line.verse }

    guard
      nissayaSheet == nil,
      isViewLoaded,
      let meaning = meaningsByVerse[line.verse],
      !verse.isEmpty
    else {
      return
    }

    // A tap being followed would go on moving the page under the sheet, and the
    // reader would come back to a page that had wandered while they were
    // reading the translation.
    releaseFocus()

    let sheet = PrayerNissayaSheet()
    nissayaSheet = sheet
    onSheetChange?(true)

    sheet.present(
      in: view,
      lines: verse,
      marked: line,
      meaning: meaning,
      style: style
    ) { [weak self] in
      guard let self else { return }
      self.nissayaSheet = nil
      self.onSheetChange?(false)
    }
  }

  // MARK: - Style

  private func applyStyle() {
    view.backgroundColor = style.pageColor
    tableView.backgroundColor = style.pageColor
    // The page can be near-black or near-white, and the indicator has to stay
    // visible on both.
    tableView.indicatorStyle = style.pageColor.isDark ? .white : .black
  }

  @objc private func contentSizeCategoryDidChange() {
    style = PrayerReadingStyle(settings: settings)
    reconfigureVisibleLines()
  }

  // MARK: - Updates from SwiftUI

  /// Takes a new prayer or new settings from ``PrayerScreen``.
  ///
  /// Called on every SwiftUI update pass, most of which change nothing — hence
  /// the equality guards. Applying unconditionally would rebuild the fonts and
  /// re-diff the whole prayer on each pass.
  func update(prayer: Prayer, settings: PrayerSettings) {
    let prayerChanged = prayer.id != self.prayer.id
    let settingsChanged = settings != self.settings

    guard prayerChanged || settingsChanged else { return }

    self.prayer = prayer
    self.settings = settings
    style = PrayerReadingStyle(settings: settings)

    if isViewLoaded {
      applyStyle()
    }

    if prayerChanged {
      indexVerses()
      guard isViewLoaded else { return }

      // The tapped line belonged to the prayer that has just been replaced.
      // Left standing, its pending release would fire against the new page and
      // fade up a page that was never stepped back — and `focusedLine` would
      // recede every line of it in the meantime, because none of them matches.
      focusRelease?.cancel()
      focusRelease = nil
      focusedLine = nil

      // The sheet is about a verse of the prayer being replaced, and it folds
      // back into a rect on a page that is about to stop existing.
      nissayaSheet?.dismiss()

      // Playback belonged to the prayer that has just gone. Its row index means
      // something else entirely in the new one, and a reader who scrubbed to a
      // different prayer asked to read it, not to have it read to them from
      // wherever the last one had got to.
      //
      // Unreported, because this is reached from inside a SwiftUI update pass —
      // `updateUIViewController` — and writing the shell's state during one is
      // undefined behaviour. It does not need reporting either: the shell stops
      // playback itself as it commits the new prayer, which is what sent the
      // prayer down here in the first place.
      endPlayback(reporting: false)

      turnPage()
    } else if isViewLoaded {
      reconfigureVisibleLines()
    }
  }

  /// Puts the new prayer on the page.
  ///
  /// Deliberately instant, and deliberately not animated here. ``PrayerScreen``
  /// owns the transition: it blurs the whole reader out, waits for this to
  /// happen behind the blur, and resolves the new page in. A `UIView.transition`
  /// underneath that would be a second animation of the same change, running on
  /// a different clock — and a real blur is one modifier in SwiftUI and a
  /// snapshot-and-filter dance in UIKit, so the shell is the right owner
  /// regardless.
  private func turnPage() {
    applySnapshot(animated: false)
    // A different prayer starts at its own beginning rather than wherever the
    // last one had been scrolled to.
    tableView.setContentOffset(
      CGPoint(x: 0, y: -tableView.adjustedContentInset.top),
      animated: false
    )
  }
}

// MARK: - Line actions

/// What a reader can ask of a single line, reached by swiping it in from the
/// trailing edge.
///
/// A swipe rather than a menu: the tap is already spoken for — it carries the
/// line to the middle of the page — and a long press over a page of text would
/// fight the selection gesture. A swipe tray also costs the page nothing while
/// it is closed, which matters on a screen whose whole job is to be read.
///
/// Ordered by how often a reader would reach for one, because the first case is
/// the one UIKit puts at the trailing edge, nearest the thumb that opened the
/// tray.
private enum PrayerLineAction {
  /// Count this line on the beads.
  case beads

  /// Open the verse's nissaya in the inline sheet.
  case nissaya

  /// Report a mistake in this line's text or its respelling.
  case report

  /// Deliberately one word each. Three actions share the tray, so each gets
  /// about a thumb's width, and a title that wraps to two lines reads as a
  /// mistake rather than as a label. The glyph above it carries the rest, and
  /// VoiceOver reads this — which is why they are words and not icons alone.
  var title: String {
    switch self {
    case .beads:
      return L10n.beads
    case .nissaya:
      return L10n.nissaya
    case .report:
      return L10n.report
    }
  }

  /// The same glyphs the detail screen gives its quick actions, so an action a
  /// reader has already met there is recognisable here without being read.
  var symbolName: String {
    switch self {
    case .beads:
      return "circle.hexagonpath"
    case .nissaya:
      return "character.book.closed"
    case .report:
      return "exclamationmark.bubble"
    }
  }

  /// The tray fill behind the glyph.
  ///
  /// Fills rather than tints, and each one dark enough to carry white: UIKit
  /// draws both glyph and title white on this colour, whatever it is. That is
  /// what rules out the obvious choice of the page's own ink — it is light on
  /// three of the six papers, and those three would draw white on white.
  var tint: UIColor {
    switch self {
    case .beads:
      // The app's own accent. Of the three this is the affirmative one — the
      // reader adding the line to something — so it gets the colour the app
      // uses everywhere else for that.
      return UIColor(AppColor.primary)
    case .nissaya:
      // Neutral, because opening a translation changes nothing. A tray of
      // three equally loud colours has no first among them.
      return .systemGray
    case .report:
      // Amber rather than red. Reporting a mistake is a caution, and red at
      // the trailing edge of a row is a promise that something is about to be
      // destroyed.
      return UIColor(AppColor.warning)
    }
  }
}

// MARK: - Selection

extension PrayerViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    // Selection is off through playback — see ``applyPlaybackGestures()`` — so
    // this is belt and braces against a tap already in flight when it started.
    guard playback == .stopped else { return }

    // The row is deselected straight away: the selected state draws nothing,
    // and a line left selected under the finger is state the reader can neither
    // see nor clear. What the tap looks like is `follow`'s business.
    tableView.deselectRow(at: indexPath, animated: false)

    guard case let .line(_, id)? = dataSource.itemIdentifier(for: indexPath) else { return }
    follow(id, at: indexPath)
  }

  /// A line scrolling into view during the follow has to arrive in the state
  /// the rest of the page is already in.
  func tableView(
    _ tableView: UITableView,
    willDisplay cell: UITableViewCell,
    forRowAt indexPath: IndexPath
  ) {
    guard
      focusedLine != nil || liftedLine != nil || playback != .stopped,
      let cell = cell as? PrayerVerseLineCell,
      let item = dataSource.itemIdentifier(for: indexPath)
    else {
      return
    }

    // Outside the move's animation, even though it lands in the middle of one:
    // a line arriving at the edge of the page should already be stepped back,
    // not be caught fading into it.
    UIView.performWithoutAnimation {
      cell.setEmphasis(emphasis(for: item, at: indexPath), animated: false)
    }
  }

  /// The reader taking hold of the page ends the follow: they have found what
  /// they were following, or they no longer care where it went.
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    stopFollowingScroll()
    releaseFocus()
    // A hand on the page pauses the reading rather than fighting it for the
    // scroll. It goes on from the same line when the reader presses play, which
    // is why this is not a stop.
    pausePlayback(reporting: true)
  }

  // MARK: - Line actions

  /// The tray of per-line actions — see ``PrayerLineAction`` for what is in it
  /// and why it is a swipe.
  ///
  /// Guarded on the row actually being a line rather than assumed: the section
  /// enum exists so that the nissaya and meaning passes can arrive as sections
  /// of their own, and rows in those are not lines to be counted or corrected.
  func tableView(
    _ tableView: UITableView,
    trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  ) -> UISwipeActionsConfiguration? {
    // Nothing is swiped out of a page that is reading itself: the row the tray
    // would open over is one or two steps from being scrolled past, and the
    // sheet Nissaya opens is the thing playback just dismissed to start.
    guard playback == .stopped else { return nil }

    guard case let .line(_, id)? = dataSource.itemIdentifier(for: indexPath) else { return nil }

    let configuration = UISwipeActionsConfiguration(
      actions: lineActions(forVerse: id.verse).map { action in
        contextualAction(action, line: id)
      }
    )
    // A full swipe would fire the first action outright, without the reader
    // ever seeing which one it was. That is a bargain worth making for Delete,
    // where the result is obvious and undoable; none of these three is either,
    // and a reader flicking a line aside to see what is under it has not asked
    // for any of them.
    configuration.performsFirstActionWithFullSwipe = false

    return configuration
  }

  /// What the tray offers for a row of this verse.
  ///
  /// Nissaya is left out where the verse has none rather than shown doing
  /// nothing: four of the catalog's prayers ship no translations at all, and an
  /// action that turns a row over to a blank face is worse than an action that
  /// was never there.
  private func lineActions(forVerse verse: Prayer.Verse.ID) -> [PrayerLineAction] {
    guard meaningsByVerse[verse] != nil else { return [.beads, .report] }

    return [.beads, .nissaya, .report]
  }

  private func contextualAction(
    _ action: PrayerLineAction,
    line: PrayerVerseLine.ID
  ) -> UIContextualAction {
    let contextual = UIContextualAction(
      style: .normal,
      title: action.title
    ) { [weak self] _, _, completion in
      // Reported as performed either way, so that the tray closes itself rather
      // than sitting open over the line. Beads and Report are not bound yet, so
      // for those that closing is the whole of it.
      completion(true)

      guard case .nissaya = action else { return }

      // After the tray, not under it. The sheet leaves from the row's own rect,
      // and a row still sliding back from a swipe is not yet where that rect
      // says it is.
      DispatchQueue.main.asyncAfter(deadline: .now() + PrayerReaderMetrics.trayClose) {
        self?.openNissaya(for: line)
      }
    }

    contextual.image = UIImage(systemName: action.symbolName)
    contextual.backgroundColor = action.tint

    return contextual
  }

  /// Keeps the watch in step with the page however the page came to move —
  /// under a finger, under the crown, or under a follow's own animation.
  ///
  /// Cheap enough to sit on the scroll path: it is a dictionary lookup and an
  /// `Int` comparison, and it tells the host nothing at all until the verse
  /// under the middle of the page actually changes.
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    reportPosition()
  }

}

// MARK: - The watch remote

/// The reader's half of the watch remote.
///
/// The commands arrive already translated into the reader's own vocabulary —
/// see `PrayerRemoteHost`, which is the only caller. Nothing here knows a watch
/// exists; it is the same page being moved the same way, and a verse centred
/// from the wrist lands exactly where a tapped one does because it goes through
/// the same ``follow(_:at:)``.
extension PrayerViewController: PrayerRemoteReader {

  /// The verse under the middle of the page, which is what the watch shows.
  var remoteVerse: PrayerRemoteVerse? {
    guard let ordinal = centredVerseOrdinal, verses.indices.contains(ordinal) else { return nil }

    let verse = verses[ordinal]
    return PrayerRemoteVerse(
      index: ordinal,
      count: verses.count,
      name: verse.name,
      text: verse.content
    )
  }

  /// Moves the page by a fraction of its own height.
  ///
  /// A fraction rather than a distance because the watch cannot know how big
  /// this page is — see `PrayerRemoteCommand.scroll(fraction:)`. Here is where
  /// it becomes points, against the *inset* page, so a "screenful" is a
  /// screenful of readable text rather than one that counts the strip the page
  /// switcher floats over.
  func remoteScroll(fraction: Double) {
    guard isViewLoaded, fraction != 0 else { return }

    let inset = tableView.adjustedContentInset
    let pageHeight = tableView.bounds.height - inset.top - inset.bottom
    guard pageHeight > 0 else { return }

    // A push on the page is the reader taking hold of it, as far as anything in
    // flight is concerned — same as a finger landing on it.
    settleScroll()
    releaseFocus()
    pausePlayback(reporting: true)

    let lowest = -inset.top
    let highest = max(
      lowest,
      tableView.contentSize.height - tableView.bounds.height + inset.bottom
    )
    let target = tableView.contentOffset.y + pageHeight * CGFloat(fraction)
    let offset = CGPoint(x: 0, y: min(max(target, lowest), highest))

    guard abs(fraction) >= PrayerReaderMetrics.remoteScrollAnimationThreshold else {
      // A nudge from the crown. Set outright: see
      // `remoteScrollAnimationThreshold` for why animating these reads as a
      // stutter rather than as a scroll.
      tableView.contentOffset = offset
      return
    }

    UIView.animate(
      withDuration: PrayerReaderMetrics.remoteScroll,
      delay: 0,
      // The same options a follow uses, and for the same reasons: a second
      // press mid-move carries on from where the page is, and the reader can
      // take it back with a finger at any point.
      options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
      animations: {
        self.tableView.contentOffset = offset
      }
    )
  }

  /// Carries the verse `delta` along from the middle of the page into it.
  ///
  /// Clamped rather than wrapped: the end of a prayer is a place to stop, and a
  /// crown turned past it should rest there rather than throw the reader back to
  /// the opening line.
  func remoteStepVerse(_ delta: Int) {
    guard isViewLoaded, !verses.isEmpty, delta != 0 else { return }

    // The wrist steering counts as the reader taking the page back, exactly as
    // a finger on it does.
    pausePlayback(reporting: true)

    let current = centredVerseOrdinal ?? 0
    // Equal after clamping means the page is already at the end the step was
    // heading for, and there is nothing to move.
    let target = min(max(current + delta, 0), verses.count - 1)
    guard target != current else { return }

    guard
      let row = firstLineByVerse[verses[target].id],
      lines.indices.contains(row)
    else {
      return
    }

    // The tap path, exactly. The verse arrives in the middle of the page with
    // the rest of it stepped back around it, and is let go of a beat later.
    follow(lines[row].id, at: IndexPath(row: row, section: .zero))
  }

  /// Brings the page to rest where it currently *looks* like it is, dropping any
  /// move still in flight.
  ///
  /// A broader version of ``stopFollowingScroll()``, which only ever cuts a
  /// follow short. This has to cut short a remote scroll and a playback step
  /// too — anything that moved the page without a finger on it. The
  /// difference matters on the commonest sequence there is: press the page-down
  /// button, then reach for the crown before its quarter-second animation has
  /// finished. `contentOffset` reads as the animation's destination the instant
  /// it starts, so the crown's nudges would be measured from a place the page
  /// has not reached, applied as model changes the running animation then
  /// overrides, and the whole turn of the wrist would be swallowed — followed by
  /// a jump when the animation ended.
  ///
  /// Checked against the layer's animations rather than against `focusedLine`,
  /// because a remote scroll leaves no focus behind to test.
  private func settleScroll() {
    guard
      tableView.layer.animationKeys()?.isEmpty == false,
      let presented = tableView.layer.presentation()?.bounds.origin
    else {
      return
    }

    UIView.performWithoutAnimation {
      // Only the scroll animation lives on the table's own layer; the page
      // receding through a follow is on the cells', and `releaseFocus` puts
      // that back.
      tableView.layer.removeAllAnimations()
      tableView.contentOffset = presented
    }
  }

  // MARK: - Where the page is

  /// The 0-based verse nearest the middle of the readable page.
  private var centredVerseOrdinal: Int? {
    guard isViewLoaded, !lines.isEmpty else { return nil }

    let inset = tableView.adjustedContentInset
    let pageHeight = tableView.bounds.height - inset.top - inset.bottom
    guard pageHeight > 0 else { return nil }

    let midY = tableView.contentOffset.y + inset.top + pageHeight / 2

    guard let indexPath = tableView.indexPathForRow(at: CGPoint(x: 0, y: midY)) else {
      // The middle of the page is in one of the insets rather than on a row,
      // which is what the top of the first verse and the tail of the last one
      // look like. Both ends are a real answer — the reader is at the start or
      // at the finish — so they resolve rather than reporting nothing.
      return midY < 0 ? .zero : ordinalByVerse[lines[lines.count - 1].id.verse]
    }

    guard lines.indices.contains(indexPath.row) else { return nil }
    return ordinalByVerse[lines[indexPath.row].id.verse]
  }

  /// Tells the host where the page is, if it has moved to a different verse
  /// since the last time it was asked.
  fileprivate func reportPosition() {
    let ordinal = centredVerseOrdinal
    guard ordinal != centredVerse else { return }

    centredVerse = ordinal
    PrayerRemoteHost.shared.readerDidMove()
  }
}

// MARK: - Helpers

extension UIColor {
  /// Whether white text would sit better on this colour than black.
  ///
  /// Perceived luminance rather than a plain RGB average — the eye reads green
  /// as far brighter than blue at the same value, and the reader's page colours
  /// include a yellow that a flat average puts on the wrong side of the line.
  fileprivate var isDark: Bool {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return false }

    return (0.299 * red + 0.587 * green + 0.114 * blue) < 0.5
  }
}
#endif
