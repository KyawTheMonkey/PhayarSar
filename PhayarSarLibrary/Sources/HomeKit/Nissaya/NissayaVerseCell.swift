#if canImport(UIKit)
import DesignKit
import LocalisationKit
import PrayersKit
// For the `UIColor(_: Color)` bridge — the design tokens are SwiftUI `Color`s.
import SwiftUI
import UIKit

/// One verse of a prayer, as the row that opens it.
///
/// The Pali as recited, in the quieter of the screen's two settings — it is
/// here to be referred back to, not to be read through — with its number above
/// it and a chevron at the trailing edge. Tapping the row unfolds the meaning
/// underneath it; see ``NissayaMeaningCell``.
///
/// Paper edge to edge and a rule at the bottom, not a card: the page is one
/// continuous sheet, and this is a stretch of it. See ``NissayaPageView``.
///
/// Self-sizing — the table sets `automaticDimension` and the text's constraints
/// to the page's margins are what give the row its height.
final class NissayaVerseCell: UITableViewCell {
  static let reuseIdentifier = "NissayaVerseCell"

  private let page = NissayaPageView()
  /// The verse's number, and its name where the source gives one.
  private let headerLabel = UILabel()
  private let paliLabel = UILabel()
  private let chevron = UIImageView()

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
    // The page is not a list of buttons to be picked out of; a tap opens a
    // verse and the paper coming out is the answer to it.
    selectionStyle = .none

    headerLabel.numberOfLines = 1
    paliLabel.numberOfLines = 0

    chevron.image = UIImage(
      systemName: "chevron.down",
      withConfiguration: UIImage.SymbolConfiguration(
        pointSize: NissayaListMetrics.chevronSize,
        weight: .semibold
      )
    )
    chevron.contentMode = .center
    // The glyph is a hair wider than it is tall; without this the row's text
    // would shuffle sideways when the chevron turns.
    chevron.setContentHuggingPriority(.required, for: .horizontal)
    chevron.setContentCompressionResistancePriority(.required, for: .horizontal)

    let text = UIStackView(arrangedSubviews: [headerLabel, paliLabel])
    text.axis = .vertical
    text.alignment = .fill
    text.spacing = NissayaListMetrics.headerSpacing

    let row = UIStackView(arrangedSubviews: [text, chevron])
    row.axis = .horizontal
    // Against the middle of the row rather than the top: the chevron belongs to
    // the whole verse, and on a two-line one a top-aligned chevron reads as
    // belonging to the number line alone.
    row.alignment = .center
    row.spacing = NissayaListMetrics.chevronGap
    row.translatesAutoresizingMaskIntoConstraints = false

    page.translatesAutoresizingMaskIntoConstraints = false
    page.content.addSubview(row)
    contentView.addSubview(page)

    NSLayoutConstraint.activate(
      [
        // Edge to edge. The margins that hold the text off the sides of the
        // screen are the *page's*, so that the paper runs the full width and
        // one row cannot be told from the next.
        page.topAnchor.constraint(equalTo: contentView.topAnchor),
        page.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        page.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        page.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
      ] + page.column(for: row)
    )
  }

  // MARK: - Content

  /// - Parameter position: 1-based place in the prayer. Taken from the list
  ///   rather than from `Prayer.Verse.index`, which is hand-kept JSON and has a
  ///   repeat or two in it.
  func configure(with verse: Prayer.Verse, position: Int, open: Bool) {
    page.content.directionalLayoutMargins = NissayaListMetrics.contentInsets(
      for: traitCollection
    )

    headerLabel.attributedText = Self.header(for: verse, position: position)
    paliLabel.attributedText = NissayaText.attributed(
      verse.content,
      font: AppUIFont.jasmine(
        size: NissayaListMetrics.paliTextSize,
        relativeTo: .callout
      ),
      lineSpacing: NissayaListMetrics.paliLineSpacing,
      color: UIColor(AppColor.textSecondary)
    )

    setOpen(open, animated: false)

    // The row is one thing to VoiceOver, not a number, a name and a paragraph.
    isAccessibilityElement = true
    accessibilityTraits = .button
    accessibilityLabel = Self.accessibilityLabel(for: verse, position: position)
  }

  /// The number line: the verse's place, and — where the source gives one, which
  /// currently means the 24 paccayas of ပဋ္ဌာန်းအကျယ် — its name.
  ///
  /// The name is set in the Myanmar face rather than in the app's section-label
  /// style: the names that exist are Burmese, and Inter has no glyphs for them.
  private static func header(for verse: Prayer.Verse, position: Int) -> NSAttributedString {
    let header = NSMutableAttributedString(
      string: "\(position)",
      attributes: [
        .font: AppUIFont.captionBold,
        .foregroundColor: UIColor(AppColor.primary)
      ]
    )

    guard let name = verse.name, !name.isEmpty else { return header }

    header.append(
      NSAttributedString(
        string: "  ·  ",
        attributes: [
          .font: AppUIFont.captionBold,
          .foregroundColor: UIColor(AppColor.primary.opacity(0.5))
        ]
      )
    )
    header.append(
      NSAttributedString(
        string: name,
        attributes: [
          .font: AppUIFont.jasmine(
            size: NissayaListMetrics.nameTextSize,
            relativeTo: .footnote
          ),
          .foregroundColor: UIColor(AppColor.textSecondary)
        ]
      )
    )

    return header
  }

  private static func accessibilityLabel(for verse: Prayer.Verse, position: Int) -> String {
    [
      "\(L10n.verses) \(position)",
      verse.name.flatMap { $0.isEmpty ? nil : $0 },
      verse.content
    ]
      .compactMap { $0 }
      .joined(separator: ", ")
  }

  // MARK: - Open and shut

  /// Turns the chevron over, and says which way the row is going.
  func setOpen(_ open: Bool, animated: Bool) {
    accessibilityHint = open ? L10n.hideMeaning : L10n.showMeaning

    let turn = {
      // Not exactly `.pi`. A transform is interpolated as a matrix, and half a
      // turn is the one rotation whose matrix says nothing about which way
      // round it went — the chevron collapses through zero width and comes back
      // instead of turning over. A thousandth short of it is a rotation with an
      // answer.
      self.chevron.transform = open
        ? CGAffineTransform(rotationAngle: .pi * 0.999)
        : .identity
      self.chevron.tintColor = open
        ? UIColor(AppColor.primary)
        : UIColor(AppColor.textTertiary)
    }

    guard animated else { return turn() }

    UIView.animate(
      withDuration: NissayaListMetrics.foldDuration,
      delay: 0,
      // The same spring the sheet below is folding on, so the two read as one
      // movement rather than as a control and a consequence.
      usingSpringWithDamping: NissayaListMetrics.foldDamping,
      initialSpringVelocity: 0,
      // `beginFromCurrentState` so a row tapped twice in a second carries on
      // from wherever the chevron has got to; `allowUserInteraction` so the
      // page can still be scrolled while it turns.
      options: [.beginFromCurrentState, .allowUserInteraction],
      animations: turn
    )
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    // A recycled row starts shut. `configure` sets it again, before the cell is
    // shown, from what the reader has actually opened.
    setOpen(false, animated: false)
  }
}
#endif
