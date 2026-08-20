#if canImport(UIKit)
import LocalisationKit
import PrayersKit
import UIKit

/// A single line of a verse: its verse's name where this is the line that opens
/// one, the line itself, and the rule closing it.
///
/// The drawing half of ``PrayerVerseLineCell``, without any of the cell part —
/// no margins, no focus tint, no reuse. The cell keeps those because they are
/// about being a row in a table, which this is not.
///
/// Split from the cell so that how a line is *set* — the gloss pairing, the
/// name over the verse it opens, the rule closing it — can be read in one place
/// without the reuse and margin machinery around it.
final class PrayerVerseLineView: UIView {
  private let stack = UIStackView()
  private let nameLabel = UILabel()
  /// Both halves of the line, as paragraphs of one attributed string — see
  /// ``PrayerReadingStyle/attributedGloss(_:)``.
  private let lineLabel = UILabel()
  private let separator = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)

    for label in [nameLabel, lineLabel] {
      label.numberOfLines = 0
    }

    stack.axis = .vertical
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(nameLabel)
    stack.addArrangedSubview(lineLabel)
    stack.addArrangedSubview(separator)

    // Spacing is per-gap rather than uniform: the name sits close to the text it
    // titles, and the rule sits nearer the line it closes than the one it opens.
    stack.setCustomSpacing(PrayerReaderMetrics.nameSpacing, after: nameLabel)
    stack.setCustomSpacing(PrayerReaderMetrics.glossSeparatorSpacing, after: lineLabel)

    addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: topAnchor),
      stack.leadingAnchor.constraint(equalTo: leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor),
      // A bare `UIView` has no height of its own, so the rule needs to be given
      // one before the stack can place it.
      separator.heightAnchor.constraint(
        equalToConstant: PrayerReaderMetrics.glossSeparatorThickness
      )
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(with line: PrayerVerseLine, style: PrayerReadingStyle) {
    // Two conditions, not one: the reader can switch the respelling off, and
    // several prayers ship none to begin with.
    let isGlossed = style.showsPronunciation && line.hasPronunciation

    if let name = line.name, !name.isEmpty {
      nameLabel.attributedText = style.attributedName(name)
      nameLabel.isHidden = false
    } else {
      nameLabel.attributedText = nil
      nameLabel.isHidden = true
    }

    lineLabel.attributedText = isGlossed
      ? style.attributedGloss(line.gloss)
      : style.attributedVerse(line.gloss.content)

    separator.backgroundColor = style.separatorColor

    lineLabel.accessibilityLabel = Self.accessibilityLabel(for: line, isGlossed: isGlossed)
  }

  /// VoiceOver gets the line whole. Read off the gloss it would come out as an
  /// alternation of two languages, neither of them followable.
  static func accessibilityLabel(for line: PrayerVerseLine, isGlossed: Bool) -> String? {
    var parts: [String] = []

    if !line.gloss.content.isEmpty {
      parts.append(line.gloss.content)
    }

    if isGlossed, !line.gloss.pronunciation.isEmpty {
      parts.append("\(L10n.pronunciation), \(line.gloss.pronunciation)")
    }

    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }
}
#endif
