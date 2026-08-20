#if canImport(UIKit)
import PrayersKit
import UIKit

/// One line of a prayer as a row of the reading page.
///
/// The line itself is drawn by ``PrayerVerseLineView``. What this adds is
/// everything about being a *row*: the margins that turn the reader's spacing
/// settings into the gap under the line, the tint behind a line that has been
/// tapped, and reuse.
///
/// Self-sizing — the table sets `automaticDimension` and the line view's
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
    /// Not on the page at all: the line has been lifted into the inline nissaya
    /// sheet, which is drawing it — see ``PrayerNissayaSheet``. The sheet opens
    /// at this row's exact rect and travels away from it, and a row still
    /// showing the same text underneath is what turns that from one line moving
    /// into two lines, one of which stayed behind.
    case lifted
  }

  private let lineView = PrayerVerseLineView()
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

    focusTint.alpha = 0
    focusTint.layer.cornerRadius = PrayerReaderMetrics.focusCornerRadius
    focusTint.layer.cornerCurve = .continuous
    focusTint.translatesAutoresizingMaskIntoConstraints = false
    // Added first so it sits behind the text rather than over it.
    contentView.addSubview(focusTint)

    lineView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(lineView)

    let outset = PrayerReaderMetrics.focusOutset

    // Pinned to the *layout margins* guide rather than to the content view, so
    // `configure` can vary the bottom margin per line — that margin is what the
    // line- and verse-spacing settings turn into.
    let margins = contentView.layoutMarginsGuide
    NSLayoutConstraint.activate([
      focusTint.topAnchor.constraint(equalTo: lineView.topAnchor, constant: -outset.vertical),
      focusTint.bottomAnchor.constraint(equalTo: lineView.bottomAnchor, constant: outset.vertical),
      focusTint.leadingAnchor.constraint(
        equalTo: lineView.leadingAnchor,
        constant: -outset.horizontal
      ),
      focusTint.trailingAnchor.constraint(
        equalTo: lineView.trailingAnchor,
        constant: outset.horizontal
      ),
      lineView.topAnchor.constraint(equalTo: margins.topAnchor),
      lineView.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      lineView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
      lineView.bottomAnchor.constraint(equalTo: margins.bottomAnchor)
    ])
  }

  func configure(with line: PrayerVerseLine, style: PrayerReadingStyle) {
    contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: PrayerReaderMetrics.horizontalInset,
      bottom: style.gap(before: line.next),
      trailing: PrayerReaderMetrics.horizontalInset
    )

    lineView.configure(with: line, style: style)
    focusTint.backgroundColor = style.focusColor
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
    case .lifted:
      contentView.alpha = 0
      focusTint.alpha = 0
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    // A recycled cell starts level. The table sets it again from the tap being
    // followed, if there is one, before the cell is shown.
    emphasis = .none
    applyEmphasis()
  }
}
#endif
