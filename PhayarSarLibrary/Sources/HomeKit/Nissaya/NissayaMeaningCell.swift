#if canImport(UIKit)
import DesignKit
import LocalisationKit
import PrayersKit
// For the `UIColor(_: Color)` bridge — the design tokens are SwiftUI `Color`s.
import SwiftUI
import UIKit

/// What a verse means, on the stretch of page that unfolds from under it.
///
/// The loudest text on the screen — this is what the reader came for, and the
/// Pali above it is the reference. A row of its own rather than a second half
/// of ``NissayaVerseCell`` because it comes and goes: the table inserts and
/// removes it as verses are opened and shut, and ``NissayaFoldView`` turns that
/// into a sheet of paper being opened out rather than a row appearing.
///
/// The same paper as every other row, edge to edge and hard against the verse
/// above it. Nothing separates the two but the rule, so what unfolds is the
/// page itself rather than a panel arriving on top of it.
final class NissayaMeaningCell: UITableViewCell {
  static let reuseIdentifier = "NissayaMeaningCell"

  /// Which verse's meaning this row is carrying, so that a fold coming to an
  /// end can tell whether the cell it started on is still showing the same one.
  private(set) var verse: Prayer.Verse.ID?

  private let sheet = NissayaFoldView()
  private let page = NissayaPageView()
  private let meaningLabel = UILabel()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setUpSubviews()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setUpSubviews() {
    backgroundColor = .clear
    contentView.backgroundColor = .clear
    // Nothing to select: the row that opened this one is the control, and this
    // is what it produced.
    selectionStyle = .none

    meaningLabel.numberOfLines = 0
    meaningLabel.translatesAutoresizingMaskIntoConstraints = false

    page.translatesAutoresizingMaskIntoConstraints = false
    page.content.addSubview(meaningLabel)

    sheet.translatesAutoresizingMaskIntoConstraints = false
    sheet.content.addSubview(page)

    // Paper behind the paper, and two things need it. The panels that have gone
    // furthest back are drawn a shade short by the perspective divide, so the
    // zigzag can end a point above the bottom of the row it is folding inside;
    // and the spring the fold rides on overshoots, so for a moment the row is a
    // few points taller than the sheet in it. Through either gap the reader
    // would otherwise see the canvas, mid-fold, at the edge of a moving sheet.
    let backing = NissayaPageView()
    backing.showsRule = false
    backing.translatesAutoresizingMaskIntoConstraints = false
    // Before the sheet, so it is behind it.
    contentView.addSubview(backing)
    contentView.addSubview(sheet)

    NSLayoutConstraint.activate(
      [
        // Edge to edge and flush: no gap above, because the sheet has to come
        // out of the verse's own rule, and none below, because the next verse
        // is the same page.
        sheet.topAnchor.constraint(equalTo: contentView.topAnchor),
        sheet.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        sheet.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        sheet.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

        backing.topAnchor.constraint(equalTo: sheet.topAnchor),
        backing.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
        backing.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
        backing.bottomAnchor.constraint(equalTo: sheet.bottomAnchor),

        page.topAnchor.constraint(equalTo: sheet.content.topAnchor),
        page.leadingAnchor.constraint(equalTo: sheet.content.leadingAnchor),
        page.trailingAnchor.constraint(equalTo: sheet.content.trailingAnchor),
        page.bottomAnchor.constraint(equalTo: sheet.content.bottomAnchor)
      ] + page.column(for: meaningLabel)
    )
  }

  // MARK: - Content

  func configure(with verse: Prayer.Verse, open: Bool) {
    self.verse = verse.id

    page.content.directionalLayoutMargins = NissayaListMetrics.contentInsets(
      for: traitCollection
    )

    let meaning = verse.meaning.trimmingCharacters(in: .whitespacesAndNewlines)

    // 37 of the catalog's 452 verses ship no translation, and on this screen
    // that is the *main* text going missing rather than an aid to it — so the
    // sheet says so, in the quietest setting it has, instead of unfolding blank.
    meaningLabel.attributedText = meaning.isEmpty
      ? NissayaText.attributed(
          L10n.nissayaNoMeaning,
          font: AppUIFont.caption,
          lineSpacing: 0,
          color: UIColor(AppColor.textTertiary)
        )
      : NissayaText.attributed(
          meaning,
          font: AppUIFont.jasmine(
            size: NissayaListMetrics.meaningTextSize,
            relativeTo: .body
          ),
          lineSpacing: NissayaListMetrics.meaningLineSpacing,
          color: UIColor(AppColor.textPrimary)
        )

    sheet.apply(open: open)

    isAccessibilityElement = true
    accessibilityLabel = [
      L10n.nissayaMeaning,
      meaning.isEmpty ? L10n.nissayaNoMeaning : meaning
    ].joined(separator: ", ")
  }

  // MARK: - Folding
  //
  // Passed through to the sheet, because the height being folded is this row's
  // height and only the table can animate that — see ``NissayaFoldView``.

  /// The sheet's height with nothing folded, once it has been prepared.
  var paperHeight: CGFloat { sheet.paperHeight }

  @discardableResult
  func prepareFold(to open: Bool) -> Bool {
    sheet.prepareFold(to: open)
  }

  func setFoldHeight(_ height: CGFloat) {
    sheet.setFoldHeight(height)
  }

  func finishFold() {
    sheet.finishFold()
  }

  /// Puts the row straight into a state, for a fold that cannot be run.
  func apply(open: Bool) {
    sheet.apply(open: open)
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    verse = nil
    sheet.finishFold()
  }
}
#endif
