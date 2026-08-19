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

  /// The air under each verse, taken from what follows its last line.
  ///
  /// A turned row stands in for the whole verse, so it has to be given the gap
  /// the verse had rather than the gap its own line had — otherwise the last
  /// verse of a prayer, turned over, would draw a rule and a line's worth of
  /// space under itself at the very bottom of the page.
  private var gapAfterVerse: [Prayer.Verse.ID: PrayerVerseLine.Next] = [:]

  /// The verses currently showing their nissaya rather than their lines.
  ///
  /// Here rather than in the cell, and by *verse* rather than by row. In the
  /// cell it would be recycled onto whatever line scrolled into that cell next;
  /// by row it would be a question the data has no answer to, since a nissaya
  /// belongs to a verse and a verse is a median of three rows long.
  private var flippedVerses: Set<Prayer.Verse.ID> = []

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

  /// Puts a row's current face on a cell.
  ///
  /// Split out of the cell provider because the turn needs it too: a row turning
  /// over has to be given its new face from *inside* the transition block, which
  /// is what makes the flip a flip rather than a cut. Both callers go through
  /// here so the two faces cannot drift apart.
  private func configure(_ cell: PrayerVerseLineCell, for item: Item) {
    guard case let .line(_, id) = item, let line = linesByID[id] else { return }

    if flippedVerses.contains(id.verse), let meaning = meaningsByVerse[id.verse] {
      cell.configure(
        nissaya: meaning,
        next: gapAfterVerse[id.verse] ?? .end,
        style: style
      )
    } else {
      cell.configure(with: line, style: style)
    }
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

    // The line that does *not* run on into another is the verse's last, and
    // what follows it is what follows the verse.
    gapAfterVerse = Dictionary(
      uniqueKeysWithValues: lines.compactMap { line in
        line.next == .line ? nil : (line.id.verse, line.next)
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

  /// The rows the table actually shows.
  ///
  /// A turned verse collapses to a single row — its first line, carrying the
  /// nissaya on the other side. The rest of its lines leave the snapshot
  /// entirely rather than being drawn at zero height: a self-sizing cell asked
  /// for no height at all is a fight with its own constraints, and diffable
  /// already knows how to animate rows out and back.
  private var visibleLines: [PrayerVerseLine] {
    lines.filter { !flippedVerses.contains($0.id.verse) || $0.id.line == 0 }
  }

  /// - Parameter reconfiguring: Rows whose *content* has changed as well as the
  ///   set of rows. A turned row is the only one there ever is: its identity is
  ///   deliberately unchanged — the same row, seen from the other side — so
  ///   without saying so the table would keep the height it measured for the
  ///   face that is no longer there.
  private func applySnapshot(animated: Bool, reconfiguring items: [Item] = []) {
    var snapshot = Snapshot()
    snapshot.appendSections([.verses])
    snapshot.appendItems(
      visibleLines.map { Item.line(prayer: prayer.id, line: $0.id) },
      toSection: .verses
    )

    if !items.isEmpty {
      snapshot.reconfigureItems(items)
    }

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

  private func emphasis(for item: Item) -> PrayerVerseLineCell.Emphasis {
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

      cell.setEmphasis(emphasis(for: item), animated: animated)
    }
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

    let inset = tableView.adjustedContentInset
    let pageHeight = tableView.bounds.height - inset.top - inset.bottom

    // Clamped to what the page can actually show, so a line near either end of
    // the prayer settles against that end rather than pulling the page past it.
    let top = -inset.top
    let bottom = max(top, tableView.contentSize.height + inset.bottom - tableView.bounds.height)
    let y = row.midY - inset.top - pageHeight / 2

    return CGPoint(x: current.x, y: min(max(y, top), bottom))
  }

  // MARK: - Turning a row over

  /// The card being turned, the paper it was lifted off, and the still of the
  /// page below it — the three views a turn puts on screen.
  ///
  /// Held rather than passed through the animation, so that a turn can be
  /// abandoned from outside it. The switcher can land on another prayer half
  /// way through one.
  private var turnStage: UIView?
  private var turnMask: UIView?
  private var turnTail: UIView?

  private var isTurning: Bool { turnStage != nil }

  /// Turns a verse over between its lines and its nissaya.
  ///
  /// A card lifted off the page and rotated, not a transition applied to the
  /// cell. The cells are transparent — the paper belongs to the table, and a
  /// cell painting its own would tile subtly different edges down a scrolling
  /// page — so a transition on one has nothing to turn but the glyphs, which is
  /// text swinging in mid-air rather than a row flipping. What turns here is a
  /// *still of the page itself*, taken from the table: opaque, paper-coloured,
  /// and carrying everything drawn on those rows.
  ///
  /// In halves, hinged on the instant the card is edge-on:
  ///
  /// 1. The still turns from flat to edge-on, darkening as it goes out of the
  ///    light. The perspective comes from the stage it sits on, so the near edge
  ///    swells and the far edge falls away rather than the whole card simply
  ///    narrowing.
  /// 2. Edge-on, the card has no width at all — the one instant in the turn when
  ///    the page underneath can be rebuilt without being seen doing it. The
  ///    verse's other rows leave the snapshot, the row re-measures for the face
  ///    it is about to show, and everything below it moves up.
  /// 3. A second still — the new face — turns the rest of the way in, coming up
  ///    out of the shade as it lands.
  ///
  /// The page below the verse really does move at that instant, and no card can
  /// hide it: a verse of five lines turning over to one row of prose takes four
  /// rows' height out of the page. So that part is *faded* rather than cut — a
  /// still of the old page below is left standing where it was and dissolved out
  /// across the second half, while the real rows settle underneath it.
  private func turn(verse: Prayer.Verse.ID) {
    guard meaningsByVerse[verse] != nil, !isTurning else { return }

    let isTurningOver = !flippedVerses.contains(verse)

    guard
      isViewLoaded,
      !UIAccessibility.isReduceMotionEnabled,
      let rows = onscreenRows(of: verse),
      let front = still(of: rows.rect, afterScreenUpdates: false)
    else {
      // Reduce Motion, or a verse that is not on the page to be turned. Either
      // way there is no card to watch, so the change is dissolved instead —
      // which is what Reduce Motion would have asked for regardless.
      dissolve(verse: verse, isTurningOver: isTurningOver)
      return
    }

    // The old page from the verse's top down, taken now while it still is the
    // old page and stood up at the half way point over what has moved by then.
    //
    // From the verse's *top* rather than its foot, so that the strip it covers
    // is always at least as tall as the row the card lands on. Started lower and
    // a verse collapsing to a shorter row would leave a band between the two
    // where the rebuilt page showed through outright.
    turnTail = still(of: page(from: rows.rect.minY), afterScreenUpdates: false)?.view

    // Blank paper where the rows are, so that what shows past the edges of a
    // half-turned card is the page rather than the same text again, unturned.
    //
    // A patch over them rather than the cells hidden: the still of the new face
    // is taken from the table itself half way through, and a table whose cells
    // are hidden has nothing to give.
    turnMask = makeMask(over: front.view.frame)

    // The stills are pinned to the screen rather than to the content, so the
    // page must not scroll out from under them mid-turn.
    tableView.isScrollEnabled = false
    turnStage = makeStage(over: front)

    let half = PrayerReaderMetrics.faceTurn / 2
    let edge = CGFloat.pi / 2 * (isTurningOver ? -1 : 1)

    UIView.animate(withDuration: half, delay: 0, options: [.curveEaseIn]) {
      front.view.transform3D = CATransform3DMakeRotation(edge, 0, 1, 0)
      front.shade.alpha = PrayerReaderMetrics.turnShade
    } completion: { [weak self] _ in
      self?.landTurn(verse: verse, isTurningOver: isTurningOver, front: front, over: half)
    }
  }

  /// The second half: the page rebuilt behind an edge-on card, and the new face
  /// turned the rest of the way in.
  private func landTurn(
    verse: Prayer.Verse.ID,
    isTurningOver: Bool,
    front: PrayerTurnFace,
    over half: TimeInterval
  ) {
    // Abandoned mid-turn — see ``endTurn()``.
    guard let stage = turnStage else { return }

    let faceItem = Item.line(prayer: prayer.id, line: PrayerVerseLine.ID(verse: verse, line: 0))

    if isTurningOver {
      flippedVerses.insert(verse)
    } else {
      flippedVerses.remove(verse)
    }

    applySnapshot(animated: false, reconfiguring: [faceItem])
    // Forced rather than left to the next pass: the still of the new face is
    // taken a few lines below, and there would be nothing laid out to take.
    tableView.layoutIfNeeded()

    guard let rows = onscreenRows(of: verse) else { return endTurn() }

    // Everything that has to be covering the page before it is next drawn —
    // and taking the new still is what draws it. The old page stands where it
    // was, the paper patch moves onto the row the verse now occupies, and the
    // card goes over both.
    //
    // The patch above the old page rather than below it: what shows past the
    // edges of a half-turned card has to be paper, and the old page there is the
    // very text the card is turning away from.
    if let turnTail, let turnMask {
      view.insertSubview(turnTail, belowSubview: turnMask)
    }
    turnMask?.frame = view.convert(rows.rect.intersection(tableView.bounds), from: tableView)
    view.bringSubviewToFront(stage)

    guard let back = still(of: rows.rect, afterScreenUpdates: true) else { return endTurn() }

    // The card is a different size on its other side. Resized here, edge-on,
    // where a change of shape cannot be seen.
    front.view.removeFromSuperview()
    stage.frame = back.view.frame
    back.view.frame = stage.bounds
    back.view.layer.isDoubleSided = false
    stage.addSubview(back.view)

    let edge = CGFloat.pi / 2 * (isTurningOver ? 1 : -1)
    back.view.transform3D = CATransform3DMakeRotation(edge, 0, 1, 0)
    back.shade.alpha = PrayerReaderMetrics.turnShade

    UIView.animate(withDuration: half, delay: 0, options: [.curveEaseOut]) {
      back.view.transform3D = CATransform3DIdentity
      back.shade.alpha = 0
      self.turnTail?.alpha = 0
    } completion: { [weak self] _ in
      self?.endTurn()
    }
  }

  /// Takes the turn's stills off the screen, whether it finished or was
  /// abandoned.
  private func endTurn() {
    for overlay in [turnStage, turnMask, turnTail] {
      overlay?.removeFromSuperview()
    }
    turnStage = nil
    turnMask = nil
    turnTail = nil

    tableView.isScrollEnabled = true
  }

  /// Turns the verse over without turning anything.
  private func dissolve(verse: Prayer.Verse.ID, isTurningOver: Bool) {
    let faceItem = Item.line(prayer: prayer.id, line: PrayerVerseLine.ID(verse: verse, line: 0))

    if isTurningOver {
      flippedVerses.insert(verse)
    } else {
      flippedVerses.remove(verse)
    }

    guard isViewLoaded, tableView.window != nil else {
      applySnapshot(animated: false)
      return
    }

    UIView.transition(
      with: tableView,
      duration: PrayerReaderMetrics.faceTurn,
      options: [.transitionCrossDissolve, .allowUserInteraction],
      animations: { self.applySnapshot(animated: false, reconfiguring: [faceItem]) }
    )
  }

  // MARK: - The card

  /// A still of part of the page, with a shade over it.
  ///
  /// The shade is a child of the still rather than a sibling so that it turns
  /// with it. A shade that stayed flat while the face turned would read as a
  /// dark pane the card was passing behind.
  private struct PrayerTurnFace {
    let view: UIView
    let shade: UIView
  }

  /// Lifts a still of the page off the table.
  ///
  /// Positioned in the controller's own coordinates rather than the table's: the
  /// table is rebuilt half way through a turn, and a still parented to it would
  /// be caught up in that.
  ///
  /// - Parameter afterScreenUpdates: `false` for the page as it is already
  ///   drawn, `true` for a change made in this same run loop that has yet to be.
  private func still(of rect: CGRect, afterScreenUpdates: Bool) -> PrayerTurnFace? {
    // Clipped to what is on screen, because that is all the table has drawn —
    // the part of a long verse below the fold has no cells behind it and would
    // come back as a blank strip of paper.
    let visible = rect.intersection(tableView.bounds)

    guard
      visible.height >= 1,
      let snapshot = tableView.resizableSnapshotView(
        from: visible,
        afterScreenUpdates: afterScreenUpdates,
        withCapInsets: .zero
      )
    else {
      return nil
    }

    snapshot.frame = view.convert(visible, from: tableView)

    let shade = UIView(frame: snapshot.bounds)
    shade.backgroundColor = style.textColor
    shade.alpha = 0
    shade.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    snapshot.addSubview(shade)

    return PrayerTurnFace(view: snapshot, shade: shade)
  }

  /// The stage a face turns on.
  ///
  /// It exists only to hold the perspective. A rotation with none above it is an
  /// orthographic one — the card narrows to nothing without ever looking like it
  /// is coming towards the reader, which is the flat and wrong version of this.
  private func makeStage(over face: PrayerTurnFace) -> UIView {
    let stage = UIView(frame: face.view.frame)
    stage.isUserInteractionEnabled = false

    var perspective = CATransform3DIdentity
    perspective.m34 = -1 / PrayerReaderMetrics.turnPerspective
    stage.layer.sublayerTransform = perspective

    face.view.frame = stage.bounds
    // There is nothing to see on the reverse of a face: the other side of this
    // card is the other still, not this one mirrored.
    face.view.layer.isDoubleSided = false
    stage.addSubview(face.view)

    view.addSubview(stage)

    return stage
  }

  private func makeMask(over frame: CGRect) -> UIView {
    let mask = UIView(frame: frame)
    mask.backgroundColor = style.pageColor
    mask.isUserInteractionEnabled = false
    view.addSubview(mask)

    return mask
  }

  // MARK: - Rows of a verse

  /// The rows a verse is drawn on and the page they cover, in table
  /// coordinates.
  private func onscreenRows(of verse: Prayer.Verse.ID) -> (indexPaths: [IndexPath], rect: CGRect)? {
    let indexPaths = dataSource.snapshot().itemIdentifiers
      .filter { item in
        guard case let .line(_, id) = item else { return false }
        return id.verse == verse
      }
      .compactMap { dataSource.indexPath(for: $0) }

    guard !indexPaths.isEmpty else { return nil }

    let rect = indexPaths
      .map { tableView.rectForRow(at: $0) }
      .reduce(CGRect.null) { $0.union($1) }

    return rect.isNull ? nil : (indexPaths, rect)
  }

  /// The strip of page from a given point down to the foot of the screen — the
  /// part that moves when a verse changes height.
  private func page(from y: CGFloat) -> CGRect {
    CGRect(
      x: tableView.bounds.minX,
      y: y,
      width: tableView.bounds.width,
      height: max(0, tableView.bounds.maxY - y)
    )
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

      // For the same reason, and one more: a verse id is only unique within its
      // prayer, so a turned verse 3 left standing would turn verse 3 of the new
      // prayer over before the reader had seen either side of it.
      flippedVerses.removeAll()
      // Its stills are of a page that is about to stop existing.
      endTurn()

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

  /// Turn the row over to its verse's nissaya, or back to the verse.
  ///
  /// One action rather than two, carrying which way it currently points: the
  /// row has two sides and this is the edge you push, so an "open" that does
  /// nothing on an already-turned row would be a second action for the same
  /// thing.
  case nissaya(isTurned: Bool)

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
    case .nissaya(let isTurned):
      return isTurned ? L10n.verse : L10n.nissaya
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
    case .nissaya(let isTurned):
      // Turning back is not another way into the nissaya, so it does not wear
      // the nissaya's glyph — it is the row being put back the way it was.
      return isTurned ? "arrow.uturn.backward" : "character.book.closed"
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
      focusedLine != nil,
      let cell = cell as? PrayerVerseLineCell,
      let item = dataSource.itemIdentifier(for: indexPath)
    else {
      return
    }

    // Outside the move's animation, even though it lands in the middle of one:
    // a line arriving at the edge of the page should already be stepped back,
    // not be caught fading into it.
    UIView.performWithoutAnimation {
      cell.setEmphasis(emphasis(for: item), animated: false)
    }
  }

  /// The reader taking hold of the page ends the follow: they have found what
  /// they were following, or they no longer care where it went.
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    stopFollowingScroll()
    releaseFocus()
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
    guard case let .line(_, id)? = dataSource.itemIdentifier(for: indexPath) else { return nil }

    let configuration = UISwipeActionsConfiguration(
      actions: lineActions(forVerse: id.verse).map { action in
        contextualAction(action, verse: id.verse)
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

    return [.beads, .nissaya(isTurned: flippedVerses.contains(verse)), .report]
  }

  private func contextualAction(
    _ action: PrayerLineAction,
    verse: Prayer.Verse.ID
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

      // After the tray, not under it. The turn and the tray sliding shut are
      // two animations over the same row, and run together they read as the row
      // coming apart rather than as one thing following the other.
      DispatchQueue.main.asyncAfter(deadline: .now() + PrayerReaderMetrics.trayClose) {
        self?.turn(verse: verse)
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

    // A push on the page is the reader taking hold of it, as far as any follow
    // in flight is concerned — same as a finger landing on it.
    stopFollowingScroll()
    releaseFocus()

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
