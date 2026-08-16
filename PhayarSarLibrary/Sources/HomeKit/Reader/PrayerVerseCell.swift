#if canImport(UIKit)
import LocalisationKit
import PrayersKit
import UIKit

/// One verse of a prayer: its name where the source gives one, and the verse
/// itself in one of two settings.
///
/// With the respelling on, the verse is drawn as an interlinear gloss — each
/// line's respelling with the Pali it stands for beneath it, ruled off — because
/// the respelling is what someone reciting is actually reading off the page.
/// With it off, the Pali stands alone as the recited line.
///
/// Self-sizing — the table sets `automaticDimension` and the stack's
/// constraints to the content guide are what give the cell its height.
final class PrayerVerseCell: UITableViewCell {
  static let reuseIdentifier = "PrayerVerseCell"

  private let stack = UIStackView()
  private let nameLabel = UILabel()
  private let glossView = PrayerGlossView()
  private let verseLabel = UILabel()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setUpSubviews()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setUpSubviews() {
    // The page colour is the table's, and it has to show through — a cell
    // painting its own would tile subtly different edges down a scrolling page.
    backgroundColor = .clear
    contentView.backgroundColor = .clear
    selectionStyle = .none

    // `configure` drives the vertical margins from the verse-spacing setting,
    // and inheriting the cell's own margins would put a floor under them that
    // no setting could get below.
    contentView.preservesSuperviewLayoutMargins = false

    for label in [nameLabel, verseLabel] {
      label.numberOfLines = 0
    }

    stack.axis = .vertical
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(nameLabel)
    // Only ever one of these two is on screen: the gloss when there is a
    // respelling to show, the plain verse when there is not.
    stack.addArrangedSubview(glossView)
    stack.addArrangedSubview(verseLabel)

    // The name sits close to the text it titles rather than at the gap between
    // one verse and the next.
    stack.setCustomSpacing(PrayerReaderMetrics.nameSpacing, after: nameLabel)

    contentView.addSubview(stack)

    // Pinned to the *layout margins* guide rather than to the content view, so
    // `configure` can vary the bottom margin per verse — that margin is what
    // `PrayerSettings.verseSpacing` turns into.
    let margins = contentView.layoutMarginsGuide
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: margins.topAnchor),
      stack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
      stack.bottomAnchor.constraint(equalTo: margins.bottomAnchor)
    ])
  }

  /// - Parameter isLast: The final verse drops the trailing gap — the table's
  ///   bottom content inset already provides the clearance there, and both
  ///   together would read as a hole under the prayer.
  func configure(with verse: Prayer.Verse, style: PrayerReadingStyle, isLast: Bool) {
    contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: PrayerReaderMetrics.horizontalInset,
      bottom: isLast ? 0 : style.verseSpacing,
      trailing: PrayerReaderMetrics.horizontalInset
    )

    if let name = verse.name, !name.isEmpty {
      nameLabel.attributedText = NSAttributedString(
        string: name.uppercased(),
        attributes: [
          .font: style.nameFont,
          .foregroundColor: style.secondaryTextColor,
          .paragraphStyle: style.paragraphStyle(lineSpacing: 0)
        ]
      )
      nameLabel.isHidden = false
    } else {
      nameLabel.attributedText = nil
      nameLabel.isHidden = true
    }

    // Two conditions, not one: the reader can switch the respelling off, and
    // several prayers ship none to begin with.
    let pronunciation = style.showsPronunciation ? verse.pronunciation : ""
    let gloss = pronunciation.isEmpty
      ? nil
      : PrayerVerseGloss(content: verse.content, pronunciation: pronunciation)

    if let gloss, !gloss.isEmpty {
      glossView.configure(with: gloss, style: style)
      glossView.isHidden = false
      // VoiceOver gets the verse whole. Read off the gloss it would come out as
      // an alternation of two languages, neither of them followable.
      glossView.accessibilityLabel =
        "\(verse.content), \(L10n.pronunciation), \(verse.pronunciation)"

      verseLabel.attributedText = nil
      verseLabel.isHidden = true
    } else {
      glossView.reset()
      glossView.isHidden = true
      glossView.accessibilityLabel = nil

      verseLabel.attributedText = style.attributedVerse(verse.content)
      verseLabel.isHidden = false
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    nameLabel.attributedText = nil
    verseLabel.attributedText = nil
    glossView.accessibilityLabel = nil
    // The gloss is left standing on purpose. `configure` either replaces it
    // line for line or resets it, and tearing it down here would throw away a
    // pool of line views that the next verse is about to want back.
  }
}
#endif
