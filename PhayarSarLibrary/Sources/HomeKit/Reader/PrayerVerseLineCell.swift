#if canImport(UIKit)
import LocalisationKit
import PrayersKit
import UIKit

/// One line of a prayer: its verse's name where this is the line that opens a
/// named verse, the line itself, and the rule that closes it.
///
/// With the respelling on, a line is an interlinear gloss — the respelling with
/// the Pali it stands for beneath it — because the respelling is what someone
/// reciting is actually reading off the page. With it off, the Pali stands
/// alone as the recited line. Either way the rule closes it: what it separates
/// is one line of the prayer from the next, which is a thing the reader needs
/// whether or not there is a respelling above it.
///
/// Self-sizing — the table sets `automaticDimension` and the stack's
/// constraints to the content guide are what give the cell its height.
final class PrayerVerseLineCell: UITableViewCell {
  static let reuseIdentifier = "PrayerVerseLineCell"

  /// How a line is taking part in a tap.
  ///
  /// A line is picked out mostly by what happens to the *others* — a tint alone
  /// would be lost the moment the page starts moving under it, where a page
  /// that has stepped back leaves only one line still fully on.
  enum Emphasis {
    /// No tap being followed.
    case none
    /// The line that was tapped.
    case focused
    /// One of the others, stepped back while the tapped line is followed.
    case receded
  }

  private let stack = UIStackView()
  private let nameLabel = UILabel()
  /// Both halves of the line, as paragraphs of one attributed string — see
  /// ``PrayerReadingStyle/attributedGloss(_:)``.
  private let lineLabel = UILabel()
  private let separator = UIView()
  /// The tint behind a focused line. Sized to the text rather than to the cell,
  /// which carries the gap to the next line as well.
  private let focusTint = UIView()

  private var emphasis: Emphasis = .none

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

    // `configure` drives the vertical margins from the spacing settings, and
    // inheriting the cell's own margins would put a floor under them that no
    // setting could get below.
    contentView.preservesSuperviewLayoutMargins = false

    for label in [nameLabel, lineLabel] {
      label.numberOfLines = 0
    }

    stack.axis = .vertical
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(nameLabel)
    stack.addArrangedSubview(lineLabel)
    stack.addArrangedSubview(separator)

    // Spacing is per-gap rather than uniform: the name sits close to the text
    // it titles, and the rule sits nearer the line it closes than the one it
    // opens.
    stack.setCustomSpacing(PrayerReaderMetrics.nameSpacing, after: nameLabel)
    stack.setCustomSpacing(PrayerReaderMetrics.glossSeparatorSpacing, after: lineLabel)

    focusTint.alpha = 0
    focusTint.layer.cornerRadius = PrayerReaderMetrics.focusCornerRadius
    focusTint.layer.cornerCurve = .continuous
    focusTint.translatesAutoresizingMaskIntoConstraints = false
    // Added first so it sits behind the text rather than over it.
    contentView.addSubview(focusTint)
    contentView.addSubview(stack)

    let outset = PrayerReaderMetrics.focusOutset

    // Pinned to the *layout margins* guide rather than to the content view, so
    // `configure` can vary the bottom margin per line — that margin is what the
    // line- and verse-spacing settings turn into.
    let margins = contentView.layoutMarginsGuide
    NSLayoutConstraint.activate([
      focusTint.topAnchor.constraint(equalTo: stack.topAnchor, constant: -outset.vertical),
      focusTint.bottomAnchor.constraint(equalTo: stack.bottomAnchor, constant: outset.vertical),
      focusTint.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: -outset.horizontal),
      focusTint.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: outset.horizontal),
      stack.topAnchor.constraint(equalTo: margins.topAnchor),
      stack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
      stack.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
      // A bare `UIView` has no height of its own, so the rule needs to be given
      // one before the stack can place it.
      separator.heightAnchor.constraint(
        equalToConstant: PrayerReaderMetrics.glossSeparatorThickness
      )
    ])
  }

  func configure(with line: PrayerVerseLine, style: PrayerReadingStyle) {
    // Two conditions, not one: the reader can switch the respelling off, and
    // several prayers ship none to begin with.
    let isGlossed = style.showsPronunciation && line.hasPronunciation

    contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: PrayerReaderMetrics.horizontalInset,
      bottom: gap(before: line.next, style: style),
      trailing: PrayerReaderMetrics.horizontalInset
    )

    if let name = line.name, !name.isEmpty {
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

    if isGlossed {
      lineLabel.attributedText = style.attributedGloss(line.gloss)
    } else {
      lineLabel.attributedText = style.attributedVerse(line.gloss.content)
    }

    separator.backgroundColor = style.separatorColor
    focusTint.backgroundColor = style.focusColor

    lineLabel.accessibilityLabel = accessibilityLabel(for: line, isGlossed: isGlossed)
  }

  /// The gap under this line.
  ///
  /// - Parameter next: What follows it. The last line of the prayer drops the
  ///   gap entirely — the table's bottom content inset already provides the
  ///   clearance there, and both together would read as a hole under it.
  private func gap(
    before next: PrayerVerseLine.Next,
    style: PrayerReadingStyle
  ) -> CGFloat {
    switch next {
    case .line:
      // Every line is closed by a rule, so every line needs more air under it
      // than the reader's leading alone would give — enough that the rule stays
      // nearer the line it closes than the one it opens.
      return PrayerReaderMetrics.glossLineSpacing + style.lineSpacing
    case .verse:
      return style.verseSpacing
    case .end:
      return 0
    }
  }

  /// VoiceOver gets the line whole. Read off the gloss it would come out as an
  /// alternation of two languages, neither of them followable.
  private func accessibilityLabel(
    for line: PrayerVerseLine,
    isGlossed: Bool
  ) -> String? {
    var parts: [String] = []

    if !line.gloss.content.isEmpty {
      parts.append(line.gloss.content)
    }

    if isGlossed, !line.gloss.pronunciation.isEmpty {
      parts.append("\(L10n.pronunciation), \(line.gloss.pronunciation)")
    }

    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }

  // MARK: - Focus

  /// Steps this line forward or back while a tap is being followed.
  ///
  /// - Parameter animated: `false` for a line arriving from off screen mid
  ///   scroll, which has to come on already stepped back — animating it in
  ///   would be a flash of full strength at the edge of a page that has
  ///   otherwise receded.
  func setEmphasis(_ emphasis: Emphasis, animated: Bool) {
    guard emphasis != self.emphasis else { return }
    self.emphasis = emphasis

    guard animated else { return applyEmphasis() }

    UIView.animate(
      withDuration: PrayerReaderMetrics.focusFade,
      delay: 0,
      // `beginFromCurrentState` so a second tap during the fade picks up where
      // the first left off; `allowUserInteraction` so the page can still be
      // scrolled or tapped while it plays.
      options: [.beginFromCurrentState, .allowUserInteraction],
      animations: { self.applyEmphasis() }
    )
  }

  private func applyEmphasis() {
    switch emphasis {
    case .none:
      contentView.alpha = 1
      focusTint.alpha = 0
    case .focused:
      contentView.alpha = 1
      focusTint.alpha = 1
    case .receded:
      contentView.alpha = PrayerReaderMetrics.recededAlpha
      focusTint.alpha = 0
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    nameLabel.attributedText = nil
    lineLabel.attributedText = nil
    lineLabel.accessibilityLabel = nil
    // A recycled cell starts level. The table sets it again from the tap being
    // followed, if there is one, before the cell is shown.
    emphasis = .none
    applyEmphasis()
  }
}
#endif
