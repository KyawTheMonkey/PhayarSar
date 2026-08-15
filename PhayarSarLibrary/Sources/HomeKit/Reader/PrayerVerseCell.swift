#if canImport(UIKit)
import LocalisationKit
import PrayersKit
import UIKit

/// One verse of a prayer: its name where the source gives one, the recited
/// text, and the phonetic respelling beneath it.
///
/// Self-sizing — the table sets `automaticDimension` and the stack's
/// constraints to the content guide are what give the cell its height.
final class PrayerVerseCell: UITableViewCell {
  static let reuseIdentifier = "PrayerVerseCell"

  private let stack = UIStackView()
  private let nameLabel = UILabel()
  private let verseLabel = UILabel()
  private let pronunciationLabel = UILabel()

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

    for label in [nameLabel, verseLabel, pronunciationLabel] {
      label.numberOfLines = 0
    }

    stack.axis = .vertical
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(nameLabel)
    stack.addArrangedSubview(verseLabel)
    stack.addArrangedSubview(pronunciationLabel)

    // Spacing is per-gap rather than uniform: the respelling sits close under
    // its verse, while the name sits closer still to the text it titles.
    stack.setCustomSpacing(PrayerReaderMetrics.nameSpacing, after: nameLabel)
    stack.setCustomSpacing(PrayerReaderMetrics.pronunciationSpacing, after: verseLabel)

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

    verseLabel.attributedText = style.attributedVerse(verse.content)

    // Two conditions, not one: the reader can switch the respelling off, and
    // several prayers ship none to begin with.
    let pronunciation = style.showsPronunciation ? verse.pronunciation : ""
    if pronunciation.isEmpty {
      pronunciationLabel.attributedText = nil
      pronunciationLabel.isHidden = true
    } else {
      pronunciationLabel.attributedText = style.attributedPronunciation(pronunciation)
      pronunciationLabel.isHidden = false
      // Otherwise VoiceOver reads the respelling as if it were more scripture.
      pronunciationLabel.accessibilityLabel = "\(L10n.pronunciation), \(pronunciation)"
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    nameLabel.attributedText = nil
    verseLabel.attributedText = nil
    pronunciationLabel.attributedText = nil
    pronunciationLabel.accessibilityLabel = nil
  }
}
#endif
