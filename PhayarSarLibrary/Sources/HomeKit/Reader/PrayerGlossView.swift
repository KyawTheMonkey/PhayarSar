#if canImport(UIKit)
import UIKit

/// A verse drawn as an interlinear gloss: each line's respelling with the Pali
/// it stands for beneath it, and a rule closing each pair.
///
/// A view per line rather than one label for the whole verse, because of the
/// rules: an attributed string has no way to draw a line across the page, and
/// the alternatives — an image attachment, an underlined run of spaces — are
/// both a rule that has to be told how wide the page is. A hairline view is
/// told by the layout.
final class PrayerGlossView: UIView {
  private let stack = UIStackView()

  /// One per line of the current verse. Kept across configures so that a cell
  /// recycled onto a verse of the same shape costs no new views at all.
  private var lineViews: [GlossLineView] = []

  override init(frame: CGRect) {
    super.init(frame: frame)

    // The verse is read as one passage, not as a list of loose lines.
    isAccessibilityElement = true
    accessibilityTraits = .staticText

    stack.axis = .vertical
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: topAnchor),
      stack.leadingAnchor.constraint(equalTo: leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(with gloss: PrayerVerseGloss, style: PrayerReadingStyle) {
    // Measured from the rule to the next respelling, since the rule is what a
    // line now ends on.
    stack.spacing = PrayerReaderMetrics.glossLineSpacing + style.lineSpacing

    resizeLineViews(to: gloss.lines.count)

    for (view, line) in zip(lineViews, gloss.lines) {
      view.configure(with: line, style: style)
    }
  }

  /// Releases the line views, for a cell that has gone back to showing a plain
  /// verse and is not going to want them again until it changes its mind.
  func reset() {
    resizeLineViews(to: 0)
  }

  private func resizeLineViews(to count: Int) {
    while lineViews.count > count {
      let view = lineViews.removeLast()
      stack.removeArrangedSubview(view)
      view.removeFromSuperview()
    }

    while lineViews.count < count {
      let view = GlossLineView()
      stack.addArrangedSubview(view)
      lineViews.append(view)
    }
  }
}

// MARK: - One glossed line

/// A respelling with its Pali beneath it, and the rule that closes them.
private final class GlossLineView: UIView {
  private let stack = UIStackView()
  private let label = UILabel()
  private let separator = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)

    // Both halves are paragraphs of one attributed string — see
    // ``PrayerReadingStyle/attributedGloss(_:)``.
    label.numberOfLines = 0

    stack.axis = .vertical
    stack.alignment = .fill
    stack.spacing = PrayerReaderMetrics.glossSeparatorSpacing
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(label)
    stack.addArrangedSubview(separator)
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

  func configure(with line: PrayerVerseGloss.Line, style: PrayerReadingStyle) {
    label.attributedText = style.attributedGloss(line)
    separator.backgroundColor = style.separatorColor
  }
}
#endif
