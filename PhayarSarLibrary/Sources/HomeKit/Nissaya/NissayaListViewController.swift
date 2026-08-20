#if canImport(UIKit)
import DesignKit
import LocalisationKit
import PrayersKit
// For the `UIColor(_: Color)` bridge — the design tokens are SwiftUI `Color`s.
import SwiftUI
import UIKit

/// The study screen: every verse of a prayer down the page, each one opening on
/// to what it means.
///
/// One continuous sheet, ruled into verses, rather than the deck of cards this
/// screen used to be. A nissaya is
/// read *through* — verse after verse, back a couple when one does not land —
/// and a deck answers only "what is this one verse", one card at a time, with
/// the rest of the prayer put away behind it. A table gives the whole prayer at
/// a glance, keeps the reader's place in it, and lets any number of meanings be
/// open at once.
///
/// UIKit rather than SwiftUI for the reveal. The meaning arrives on a sheet of
/// paper that unfolds out of the row above it (see ``NissayaFoldView``), which
/// needs a render of the content cut into planes and a row height animated in
/// step with them — `UITableView` and Core Animation give both directly.
///
/// Wrapped for the navigation stack by ``NissayaScreen``.
final class NissayaListViewController: UIViewController {

  // MARK: - Diffable types

  enum Section: Hashable {
    case verses
  }

  /// Identity only — which verse of which prayer, and which of its two rows.
  /// Nothing that a change of *setting* would alter: with the text in here, a
  /// change of type size would diff as "every row deleted and a new one
  /// inserted" and animate the whole prayer out and back. Identity in the
  /// snapshot, content in the cell provider.
  ///
  /// The prayer is in here and has to be. Without it a row is identified by its
  /// verse's position alone, which every prayer in the catalog has — swapping
  /// the prayer under the table would then diff as *no change at all* for every
  /// position the two share.
  enum Item: Hashable {
    case verse(prayer: Prayer.ID, verse: Prayer.Verse.ID)
    case meaning(prayer: Prayer.ID, verse: Prayer.Verse.ID)
  }

  private typealias DataSource = UITableViewDiffableDataSource<Section, Item>
  private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

  // MARK: - State

  private var prayer: Prayer

  /// The prayer's verses, deduplicated by identity: a diffable snapshot traps
  /// on a repeated identifier, and `index` comes from hand-maintained JSON — a
  /// duplicate there would be a crash on open rather than a doubled verse.
  private var verses: [Prayer.Verse] = []

  /// Verse by identity, for the cell provider — which is handed an identifier,
  /// and looking it up is what keeps the two from drifting apart mid-update.
  private var versesByID: [Prayer.Verse.ID: Prayer.Verse] = [:]

  /// Each verse's 1-based place in the prayer, which is what the rows show.
  /// Taken from the deduplicated list rather than from `Verse.index`, for the
  /// same reason the list is deduplicated at all.
  private var positionByVerse: [Prayer.Verse.ID: Int] = [:]

  /// The verses the reader has opened. Any number of them: this is a page to
  /// study from, and closing one meaning to read another would make comparing
  /// two verses impossible.
  private var opened: Set<Prayer.Verse.ID> = []

  /// The verse whose sheet is folding or unfolding, while it is doing so.
  ///
  /// Two things hang off it. Taps are ignored while it is set — a fold caught
  /// half way and reversed would be animating a row the table is already
  /// removing — and the cell provider builds *this* verse's meaning row shut,
  /// so that the fold has somewhere to start from.
  private var folding: Prayer.Verse.ID?

  /// The cell whose sheet is moving, and which way, while ``foldLink`` is
  /// running. See "Running the fold".
  private var foldingCell: NissayaMeaningCell?
  private var foldingOpen = false
  private var foldStarted: CFTimeInterval = 0
  private var foldLink: CADisplayLink?

  /// Whether the page has already shown the reader what it does — see
  /// ``introduce()``. Once per prayer, not once per appearance: coming back
  /// from a sheet is not arriving.
  private var hasIntroduced = false

  private lazy var tableView = UITableView(frame: .zero, style: .plain)
  private lazy var dataSource = makeDataSource()
  private let selection = UISelectionFeedbackGenerator()

  // MARK: - Life cycle

  init(prayer: Prayer) {
    self.prayer = prayer
    super.init(nibName: nil, bundle: nil)
    indexVerses()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    introduce()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = UIColor(AppColor.background)
    setUpTableView()
    applySnapshot()

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

  /// Opens the first verse, once, a moment after the page arrives — and opens
  /// it *by folding it*, in front of the reader.
  ///
  /// Deliberately not seeded into the first snapshot, which is how this was
  /// written first. A page found with its first meaning already showing says
  /// that meanings exist; a page that opens one while the reader is looking at
  /// it says how to get the others, which is the thing they actually need to
  /// know. It costs a quarter of a second and it is the only demonstration this
  /// screen will ever get.
  private func introduce() {
    guard !hasIntroduced, let first = verses.first else { return }
    hasIntroduced = true

    DispatchQueue.main.asyncAfter(deadline: .now() + NissayaListMetrics.introDelay) {
      [weak self] in
      guard
        let self,
        // All the ways the reader can have got there first: gone back, opened
        // that verse themselves, or opened the lot from the menu.
        view.window != nil,
        folding == nil,
        !opened.contains(first.id)
      else {
        return
      }

      toggle(first.id)
    }
  }

  /// A fold has nothing to open on to once the screen is off the page, and its
  /// display link would go on firing into it.
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    endFold()
  }

  /// Takes a different prayer, for the rare pass where the screen is reused
  /// rather than rebuilt.
  func update(prayer: Prayer) {
    guard prayer.id != self.prayer.id else { return }

    self.prayer = prayer
    endFold()
    // Clears `opened` and `hasIntroduced` both: a different prayer arrives shut
    // and then opens its own first verse, rather than inheriting whatever the
    // reader had open in the last one.
    indexVerses()
    applySnapshot()
    introduce()
  }

  // MARK: - Set up

  private func setUpTableView() {
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.register(
      NissayaVerseCell.self,
      forCellReuseIdentifier: NissayaVerseCell.reuseIdentifier
    )
    tableView.register(
      NissayaMeaningCell.self,
      forCellReuseIdentifier: NissayaMeaningCell.reuseIdentifier
    )
    // Every row draws its own rule, full width and in the app's divider colour
    // — see `NissayaPageView`. The table's would be inset from the leading edge
    // and would stop at the last row rather than under it.
    tableView.separatorStyle = .none
    tableView.backgroundColor = .clear
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = NissayaListMetrics.estimatedRowHeight
    tableView.contentInset = UIEdgeInsets(
      top: NissayaListMetrics.topInset,
      left: 0,
      bottom: NissayaListMetrics.bottomInset,
      right: 0
    )
    // The page carries its own measure — see `NissayaListMetrics.maxTextWidth`
    // — and the readable guide would inset the text a second time on an iPad.
    tableView.cellLayoutMarginsFollowReadableWidth = false
    tableView.delegate = self
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
      switch item {
      case let .verse(_, id):
        let cell = tableView.dequeueReusableCell(
          withIdentifier: NissayaVerseCell.reuseIdentifier,
          for: indexPath
        )

        guard
          let self,
          let cell = cell as? NissayaVerseCell,
          let verse = self.versesByID[id]
        else {
          return cell
        }

        cell.configure(
          with: verse,
          position: self.positionByVerse[id] ?? verse.index,
          open: self.opened.contains(id)
        )

        return cell

      case let .meaning(_, id):
        let cell = tableView.dequeueReusableCell(
          withIdentifier: NissayaMeaningCell.reuseIdentifier,
          for: indexPath
        )

        guard
          let self,
          let cell = cell as? NissayaMeaningCell,
          let verse = self.versesByID[id]
        else {
          return cell
        }

        // Shut while this verse is the one folding, whichever way it is going:
        // the row has to arrive at the height the fold starts from, and the
        // fold is what takes it the rest of the way.
        cell.configure(with: verse, open: self.opened.contains(id) && self.folding != id)

        return cell
      }
    }
  }

  // MARK: - Content

  private func indexVerses() {
    var seen: Set<Prayer.Verse.ID> = []
    verses = prayer.body.filter { seen.insert($0.id).inserted }

    versesByID = Dictionary(uniqueKeysWithValues: verses.map { ($0.id, $0) })
    positionByVerse = Dictionary(
      uniqueKeysWithValues: verses.enumerated().map { ($0.element.id, $0.offset + 1) }
    )

    // Nothing open to begin with. The first verse opens itself a moment after
    // the page arrives — see ``introduce()``.
    opened = []
    hasIntroduced = false
  }

  /// The page as it now stands: every verse, and the meanings the reader has
  /// opened, in reading order.
  ///
  /// Never animated. Every change to the page that is worth seeing — a meaning
  /// arriving, a meaning going away — is animated by the fold instead, and the
  /// table's own fade would be a second, different answer to the same event.
  private func applySnapshot() {
    var snapshot = Snapshot()
    snapshot.appendSections([.verses])

    for verse in verses {
      snapshot.appendItems([verseItem(verse.id)], toSection: .verses)

      if opened.contains(verse.id) {
        snapshot.appendItems([meaningItem(verse.id)], toSection: .verses)
      }
    }

    dataSource.apply(snapshot, animatingDifferences: false)
  }

  private func verseItem(_ id: Prayer.Verse.ID) -> Item {
    .verse(prayer: prayer.id, verse: id)
  }

  private func meaningItem(_ id: Prayer.Verse.ID) -> Item {
    .meaning(prayer: prayer.id, verse: id)
  }

  @objc private func contentSizeCategoryDidChange() {
    reconfigureAll()
  }

  // MARK: - Opening a verse

  private func toggle(_ id: Prayer.Verse.ID) {
    // A fold in flight owns the page until it lands. See ``folding``.
    guard folding == nil else { return }

    opened.contains(id) ? close(id) : open(id)
  }

  private func open(_ id: Prayer.Verse.ID) {
    folding = id
    opened.insert(id)
    selection.selectionChanged()
    turnChevron(for: id, open: true)

    var snapshot = dataSource.snapshot()
    snapshot.insertItems([meaningItem(id)], afterItem: verseItem(id))
    dataSource.apply(snapshot, animatingDifferences: false)
    // Cells are made on the next layout pass, and the fold needs the new row's
    // one now — to measure the sheet, and to have something to animate.
    tableView.layoutIfNeeded()

    // Off screen, or nothing measurable on the sheet: there is no fold to run,
    // so the verse is simply open by the time the reader gets to it.
    guard let cell = meaningCell(for: id), cell.prepareFold(to: true) else {
      return settle(id)
    }

    fold(cell, of: id, to: true)
  }

  private func close(_ id: Prayer.Verse.ID) {
    folding = id
    opened.remove(id)
    selection.selectionChanged()
    turnChevron(for: id, open: false)

    guard let cell = meaningCell(for: id), cell.prepareFold(to: false) else {
      folding = nil
      return removeMeaning(id)
    }

    fold(cell, of: id, to: false)
  }

  // MARK: - Running the fold
  //
  // The fold is stepped from a display link rather than handed to
  // `UIView.animate`. A row height is not an animatable property: it is a
  // number the table asks for, and the only way to move it is to ask the table
  // again. So this owns the clock — every frame it works out how far through
  // the fold the page is, gives the sheet that height, and re-asks the table —
  // and the sheet puts its panels where that height says they are. Nothing is
  // animating, so nothing can fall out of step.

  private func fold(_ cell: NissayaMeaningCell, of id: Prayer.Verse.ID, to open: Bool) {
    foldingCell = cell
    foldingOpen = open
    foldStarted = CACurrentMediaTime()

    let link = CADisplayLink(target: self, selector: #selector(stepFold))
    // `.common` so the fold keeps running if the reader has a finger on the
    // page while it opens.
    link.add(to: .main, forMode: .common)
    foldLink = link

    // The first frame now rather than a sixtieth of a second from now: the row
    // was inserted shut, and this is what puts the folded paper on screen
    // before the page is next drawn.
    stepFold()
  }

  @objc private func stepFold() {
    guard
      let cell = foldingCell,
      let id = folding,
      cell.verse == id,
      cell.paperHeight > 0
    else {
      return endFold()
    }

    let elapsed = CACurrentMediaTime() - foldStarted
    let time = min(max(elapsed / NissayaListMetrics.foldDuration, 0), 1)
    let travelled = Self.ease(time)
    let fraction = foldingOpen ? travelled : 1 - travelled

    let shut = NissayaFoldMetrics.shutHeight
    let height = shut + (cell.paperHeight - shut) * fraction

    // Each frame is a *set*, not an animation. Without this the table would
    // start a quarter-second animation of its own towards the height it has
    // just been given, sixty times a second, and the page would swim.
    UIView.performWithoutAnimation {
      cell.setFoldHeight(height)
      // What re-measures the row and moves the rest of the prayer to suit. The
      // layout is forced here, in this frame, rather than left for the next
      // pass — the sheet's panels have already been put where this height says.
      tableView.beginUpdates()
      tableView.endUpdates()
      tableView.layoutIfNeeded()

      if foldingOpen {
        keepInView(id)
      }
    }

    guard time >= 1 else { return }

    endFold()
  }

  /// Ends whatever fold is running, wherever it has got to.
  private func endFold() {
    foldLink?.invalidate()
    foldLink = nil

    let cell = foldingCell
    let id = folding
    let wasOpening = foldingOpen

    foldingCell = nil
    folding = nil

    // Only if the cell is still showing this verse: one that scrolled off
    // mid-fold has been handed to another row, and has already put its own
    // paper away.
    if let cell, let id, cell.verse == id {
      cell.finishFold()
    }

    if let id, !wasOpening {
      removeMeaning(id)
    }

    // The sheet has just handed its height back to its content — see
    // `NissayaFoldView.finishFold()` — so the row is measured once more, from
    // the text rather than from the fold.
    UIView.performWithoutAnimation {
      tableView.beginUpdates()
      tableView.endUpdates()
    }
  }

  /// The curve the paper moves on: ease-in-out, and the same one in both
  /// directions — a sheet unfolds and folds by the same hinges.
  ///
  /// Half a cosine. It eases at each end and its acceleration is continuous the
  /// whole way, which is what a hand opening a sheet does; the cubic this was
  /// first written with spends so little time near the middle that the paper
  /// appears to snap through it. It is also the curve
  /// `UIView.AnimationOptions.curveEaseInOut` approximates, so the chevron
  /// turning over the row keeps step with it.
  ///
  /// A curve and not a spring — that was tried. Paper has weight and no bounce,
  /// and the overshoot put the row a few points taller than what was written on
  /// it at the moment it should have been settling.
  private static func ease(_ time: Double) -> Double {
    (1 - cos(.pi * time)) / 2
  }

  // MARK: - Every verse at once

  /// Opens or shuts every verse, for the screen's menu.
  ///
  /// A dissolve rather than forty folds. The fold is what one verse does when
  /// the reader asks it something — it takes the better part of a second, it
  /// moves the whole page under it, and it is worth that because it answers a
  /// tap. Played forty times over it is not forty answers, it is the page
  /// coming apart; and every sheet below the first would be folding somewhere
  /// off screen where nobody is looking anyway.
  ///
  /// The reader's place is kept across it. Opening every verse on a long prayer
  /// adds thousands of points above wherever they were reading, and a page that
  /// answers "show me everything" by throwing away where you were has not
  /// helped.
  func setAllOpen(_ open: Bool) {
    // Supersedes a fold in flight: that verse is about to be in whatever state
    // the whole page is in.
    endFold()

    let wanted = open ? Set(verses.map(\.id)) : []
    guard wanted != opened else { return }

    let anchor = topmostVerse()
    opened = wanted

    UIView.transition(
      with: tableView,
      duration: NissayaListMetrics.bulkDissolve,
      options: [.transitionCrossDissolve, .allowUserInteraction]
    ) { [self] in
      applySnapshot()
      // The rows that were already on the page have to be told as well: their
      // chevrons and their sheets both follow `opened`, and a snapshot that
      // only inserts and deletes leaves them as they were.
      reconfigureAll()

      if let anchor {
        scroll(to: anchor)
      }
    }
  }

  /// The verse the reader is currently at the top of, so the page can be put
  /// back to it once every other row has changed size.
  private func topmostVerse() -> Prayer.Verse.ID? {
    let top = tableView.contentOffset.y + tableView.adjustedContentInset.top

    guard
      let path = tableView.indexPathForRow(at: CGPoint(x: 0, y: top + 1))
        ?? tableView.indexPathsForVisibleRows?.first,
      let item = dataSource.itemIdentifier(for: path)
    else {
      return nil
    }

    switch item {
    case let .verse(_, id), let .meaning(_, id):
      return id
    }
  }

  private func scroll(to verse: Prayer.Verse.ID) {
    guard let path = dataSource.indexPath(for: verseItem(verse)) else { return }

    tableView.scrollToRow(at: path, at: .top, animated: false)
  }

  /// Hands every row back to the cell provider, keeping it where it is.
  ///
  /// `reconfigureItems` rather than `reloadItems`: reconfigure hands the
  /// existing cell back, so the rows keep their place and the reader's place in
  /// the prayer survives.
  private func reconfigureAll() {
    var snapshot = dataSource.snapshot()
    snapshot.reconfigureItems(snapshot.itemIdentifiers)
    dataSource.apply(snapshot, animatingDifferences: false)
  }

  /// Marks a meaning open without folding it — for a row the reader cannot see.
  private func settle(_ id: Prayer.Verse.ID) {
    folding = nil

    var snapshot = dataSource.snapshot()
    guard snapshot.indexOfItem(meaningItem(id)) != nil else { return }

    snapshot.reconfigureItems([meaningItem(id)])
    dataSource.apply(snapshot, animatingDifferences: false)
  }

  /// Takes the row away once its sheet has folded shut. Unanimated, and safe to
  /// be: the row is already nothing tall.
  private func removeMeaning(_ id: Prayer.Verse.ID) {
    var snapshot = dataSource.snapshot()
    guard snapshot.indexOfItem(meaningItem(id)) != nil else { return }

    snapshot.deleteItems([meaningItem(id)])
    dataSource.apply(snapshot, animatingDifferences: false)
  }

  private func meaningCell(for id: Prayer.Verse.ID) -> NissayaMeaningCell? {
    guard let path = dataSource.indexPath(for: meaningItem(id)) else { return nil }

    return tableView.cellForRow(at: path) as? NissayaMeaningCell
  }

  private func turnChevron(for id: Prayer.Verse.ID, open: Bool) {
    guard
      let path = dataSource.indexPath(for: verseItem(id)),
      let cell = tableView.cellForRow(at: path) as? NissayaVerseCell
    else {
      return
    }

    cell.setOpen(open, animated: true)
  }

  /// Scrolls far enough for the sheet to be on the page — and no further than
  /// the verse it belongs to can afford, so that opening a long meaning never
  /// carries its own verse off the top of the screen.
  ///
  /// Called from inside the fold's animation block, after the table has taken
  /// the new row height, so the rects it asks for are the ones the page is
  /// settling into.
  private func keepInView(_ id: Prayer.Verse.ID) {
    guard
      let meaningPath = dataSource.indexPath(for: meaningItem(id)),
      let versePath = dataSource.indexPath(for: verseItem(id))
    else {
      return
    }

    let insets = tableView.adjustedContentInset
    let top = tableView.contentOffset.y + insets.top
    let bottom = tableView.contentOffset.y + tableView.bounds.height - insets.bottom

    let overflow = tableView.rectForRow(at: meaningPath).maxY - bottom
    guard overflow > 0 else { return }

    let headroom = tableView.rectForRow(at: versePath).minY - top
    let travel = min(overflow, max(0, headroom))
    guard travel > 0 else { return }

    tableView.contentOffset.y += travel
  }

  /// The text of a row, for the copy action.
  private func text(for item: Item) -> String? {
    switch item {
    case let .verse(_, id):
      return versesByID[id]?.content
    case let .meaning(_, id):
      let meaning = versesByID[id]?.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
      return (meaning?.isEmpty ?? true) ? nil : meaning
    }
  }
}

// MARK: - Delegate

extension NissayaListViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)

    // Only the verse rows are controls. A tap on a meaning is a tap on the
    // answer, which has nothing to do.
    guard case let .verse(_, id)? = dataSource.itemIdentifier(for: indexPath) else { return }

    toggle(id)
  }

  /// Long press to copy. A study screen — being able to lift a line out of it is
  /// the point, and a `UILabel` gives nothing to a finger by itself.
  func tableView(
    _ tableView: UITableView,
    contextMenuConfigurationForRowAt indexPath: IndexPath,
    point: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard
      let item = dataSource.itemIdentifier(for: indexPath),
      let text = text(for: item)
    else {
      return nil
    }

    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
      UIMenu(
        children: [
          UIAction(
            title: L10n.copy,
            image: UIImage(systemName: "doc.on.doc")
          ) { _ in
            UIPasteboard.general.string = text
          }
        ]
      )
    }
  }
}
#endif
