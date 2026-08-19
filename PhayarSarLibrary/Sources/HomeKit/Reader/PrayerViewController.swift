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

    lines = PrayerVerseLine.lines(in: verses)
    linesByID = Dictionary(uniqueKeysWithValues: lines.map { ($0.id, $0) })

    meaningsByVerse = Dictionary(
      uniqueKeysWithValues: verses.compactMap { verse in
        let meaning = verse.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        return meaning.isEmpty ? nil : (verse.id, meaning)
      }
    )
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

  private func emphasis(for item: Item) -> PrayerVerseLineCell.Emphasis {
    // Before the follow, because a lifted line is off the page entirely and a
    // page that is not being followed still has one to hide.
    if let liftedLine, item == .line(prayer: prayer.id, line: liftedLine) { return .lifted }

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

  // MARK: - The inline nissaya sheet

  /// Grows the inline nissaya sheet out of a line.
  ///
  /// The sheet opens at the exact rect that one row occupies on the page, drawn
  /// by the same code in the same face at the same size, and travels from there
  /// into a bottom sheet with the translation under it. See
  /// ``PrayerNissayaSheet`` for why it is built that way rather than presented.
  ///
  /// Given a *line* even though the nissaya it carries is the whole verse's:
  /// the reader swiped one row, and that row is the only thing on the page the
  /// sheet can convincingly have come from. Handing it the verse would put four
  /// or five other lines in the sheet that are already legible on the page
  /// behind it, and would make the rect it grows out of a block the reader never
  /// pointed at.
  private func openNissaya(for line: PrayerVerseLine.ID) {
    guard
      nissayaSheet == nil,
      isViewLoaded,
      let meaning = meaningsByVerse[line.verse],
      let verseLine = linesByID[line],
      let source = sourceRect(of: line)
    else {
      return
    }

    // The page must not move while the sheet is up: the sheet folds back into
    // the rect it left from, and a page scrolled out from under it would have
    // nowhere to put it.
    tableView.isScrollEnabled = false
    // A tap being followed would put the page back up under the sheet, and the
    // verse the sheet came from would recede along with everything else.
    releaseFocus()

    // Off the page for as long as the sheet has it. Unanimated, because at this
    // instant the panel is exactly over the row and there is nothing to see —
    // fading it would be a fade under an opaque panel.
    liftedLine = line
    applyEmphasis(animated: false)

    let sheet = PrayerNissayaSheet()
    nissayaSheet = sheet
    onSheetChange?(true)

    sheet.present(
      in: view,
      from: source,
      line: verseLine,
      meaning: meaning,
      style: style
    ) { [weak self] in
      guard let self else { return }
      self.nissayaSheet = nil
      // Put back under the panel's last frame, which is the rect it left from,
      // so the line is on the page again before the panel is gone from over it.
      self.liftedLine = nil
      self.applyEmphasis(animated: false)
      self.tableView.isScrollEnabled = true
      self.onSheetChange?(false)
    }
  }

  /// Where a line is drawn, in this controller's coordinates.
  ///
  /// Clipped to the page: the last row on screen is usually cut off by the
  /// bottom of it, and a sheet that opened at the full height of one would start
  /// by covering a strip nobody can see.
  private func sourceRect(of line: PrayerVerseLine.ID) -> CGRect? {
    guard
      let indexPath = dataSource.indexPath(for: Item.line(prayer: prayer.id, line: line))
    else {
      return nil
    }

    let rect = tableView.rectForRow(at: indexPath).intersection(tableView.bounds)

    guard !rect.isNull, rect.height >= 1 else { return nil }

    return view.convert(rect, from: tableView)
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
      focusedLine != nil || liftedLine != nil,
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
