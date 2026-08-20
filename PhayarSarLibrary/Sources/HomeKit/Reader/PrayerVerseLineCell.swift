#if canImport(UIKit)
import DesignKit
import PrayersKit
// For the `UIColor(_: Color)` bridge — the design tokens are SwiftUI `Color`s.
import SwiftUI
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
  enum Emphasis: Equatable {
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
    /// The line the page is currently reading itself through.
    ///
    /// Not the same thing as ``focused``, though it draws much like it: a tap
    /// is a moment and this is a state, held until playback moves on. The
    /// difference is all in the others — see ``waiting``.
    case reciting
    /// One of the lines playback has not reached, or has left behind, and how
    /// many rows away from the read line it is — negative above it, positive
    /// below.
    ///
    /// The distance is the whole of the effect. A waiting line is dimmed,
    /// shrunk, tilted away and drawn in towards the read line, all of it by how
    /// far off it is, so that the page curves away either side of the one line
    /// held flat and full strength. Nothing is highlighted; the read line is
    /// simply the only one the page has not carried off.
    case waiting(distance: Int)
  }

  private let lineView = PrayerVerseLineView()
  /// The tint behind a focused line. Sized to the text rather than to the cell,
  /// which carries the gap to the next line as well.
  private let focusTint = UIView()
  /// The mark against the line the page is reading — see ``Emphasis/reciting``.
  private let recitingDot = UIView()

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

    recitingDot.alpha = 0
    // The same red as the bar's Stop, and the only other one in the reader. Both
    // are about the reading rather than about the prayer: this is where it has
    // got to, that is how to end it.
    recitingDot.backgroundColor = UIColor(AppColor.error)
    recitingDot.layer.cornerRadius = PrayerReaderMetrics.recitingDotSize / 2
    recitingDot.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(recitingDot)

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
      lineView.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
      // In the gutter, level with the middle of the line — including a line that
      // has wrapped, where the middle is the only honest answer: the mark is
      // against the whole line, not against its first row of text.
      recitingDot.centerYAnchor.constraint(equalTo: lineView.centerYAnchor),
      recitingDot.trailingAnchor.constraint(
        equalTo: lineView.leadingAnchor,
        constant: -PrayerReaderMetrics.recitingDotGap
      ),
      recitingDot.widthAnchor.constraint(equalToConstant: PrayerReaderMetrics.recitingDotSize),
      recitingDot.heightAnchor.constraint(equalToConstant: PrayerReaderMetrics.recitingDotSize)
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

  /// Steps this line forward or back while a tap is being followed, or while the
  /// page is reading itself.
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
      recitingDot.alpha = 0
      lineView.layer.transform = CATransform3DIdentity
      sharpen()
    case .focused:
      contentView.alpha = 1
      focusTint.alpha = 1
      recitingDot.alpha = 0
      lineView.layer.transform = CATransform3DIdentity
      sharpen()
    case .receded:
      contentView.alpha = PrayerReaderMetrics.recededAlpha
      focusTint.alpha = 0
      recitingDot.alpha = 0
      lineView.layer.transform = CATransform3DIdentity
      sharpen()
    case .lifted:
      contentView.alpha = 0
      focusTint.alpha = 0
      recitingDot.alpha = 0
      lineView.layer.transform = CATransform3DIdentity
      sharpen()
    case .reciting:
      contentView.alpha = 1
      // No tint, unlike ``focused``, which this otherwise resembles. A tap
      // needs marking because the page around it is still legible; the read
      // line does not, because the page around it has turned away. A fill under
      // it here would be answering a question the wheel has already answered.
      focusTint.alpha = 0
      // The dot does that job instead, and does it without touching the text:
      // it says *this* line, and it says the page is being read rather than
      // merely scrolled — no other state in the reader shows it.
      recitingDot.alpha = 1
      // And never scaled, even by a hair. This is the line being read, and text
      // drawn through a transform is text drawn soft.
      lineView.layer.transform = CATransform3DIdentity
      sharpen()
    case let .waiting(distance):
      contentView.alpha = Self.waitingAlpha(atDistance: distance)
      focusTint.alpha = 0
      recitingDot.alpha = 0
      lineView.layer.transform = Self.waitingTransform(atDistance: distance)
      soften(atDistance: distance)
    }
  }

  // MARK: - The wheel

  /// Draws this line out of focus, by how far off it is.
  ///
  /// Rasterisation rather than a blur filter, which iOS does not offer on a
  /// layer anyway: the line is rendered at a fraction of the screen's
  /// resolution and scaled back up to fill its place, and the interpolation on
  /// the way up is the softness. It costs one render per line per step, cached
  /// until the step after — where a real Gaussian would cost one per frame, out
  /// of the same budget the scrolling is drawn from.
  ///
  /// Set outside the animation deliberately. `rasterizationScale` is animatable,
  /// and animating it means re-rendering the line at a new resolution on every
  /// frame of the step — the one thing this is here to avoid. It changes in a
  /// single jump under the alpha and transform that *are* animating, which is
  /// far too much else moving for the jump to be seen.
  private func soften(atDistance distance: Int) {
    let steps = PrayerReaderMetrics.waitingSteps(fromDistance: distance)
    let sharpness = max(
      1 / (1 + PrayerReaderMetrics.waitingSoftening * steps),
      PrayerReaderMetrics.waitingMinimumSharpness
    )

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    lineView.layer.rasterizationScale = displayScale * sharpness
    lineView.layer.shouldRasterize = true
    CATransaction.commit()
  }

  /// Puts the line back to the resolution it is really drawn at.
  private func sharpen() {
    guard lineView.layer.shouldRasterize else { return }

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    lineView.layer.shouldRasterize = false
    lineView.layer.rasterizationScale = displayScale
    CATransaction.commit()
  }

  /// The screen's scale, or the commonest one if the cell is not in a window
  /// yet to have an opinion.
  private var displayScale: CGFloat {
    let scale = traitCollection.displayScale
    return scale > 0 ? scale : 3
  }

  /// How much ink a line this far from the read one keeps.
  ///
  /// Compounding per step and floored — see ``PrayerReaderMetrics/waitingFalloff``.
  private static func waitingAlpha(atDistance distance: Int) -> CGFloat {
    let steps = PrayerReaderMetrics.waitingSteps(fromDistance: distance)

    return max(
      pow(PrayerReaderMetrics.waitingFalloff, steps),
      PrayerReaderMetrics.waitingMinimumAlpha
    )
  }

  /// Where a line this far from the read one sits, how big it is drawn, and how
  /// far it has turned away.
  ///
  /// Built on the line view rather than on the content view, which matters:
  /// the table sizes a row by laying out its content view, and a content view
  /// carrying a transform is a content view whose frame the table has to guess
  /// at. Nothing measures this one. The tint is constrained to its *anchors*,
  /// which a transform leaves alone, and is invisible on a waiting line anyway.
  private static func waitingTransform(atDistance distance: Int) -> CATransform3D {
    let steps = PrayerReaderMetrics.waitingSteps(fromDistance: distance)
    // Which side of the read line this is, and so which way it turns and which
    // way it is drawn in. A line above leans back from its top edge; one below
    // leans back from its bottom.
    let side: CGFloat = distance < 0 ? -1 : 1

    var transform = CATransform3DIdentity
    // The eye. Without this the rotation is an affine squash — the far edge of
    // a line gets no nearer or further away, it just gets shorter.
    transform.m34 = -1 / PrayerReaderMetrics.waitingPerspective

    transform = CATransform3DTranslate(
      transform,
      0,
      -side * PrayerReaderMetrics.waitingPull * steps,
      0
    )
    transform = CATransform3DRotate(
      transform,
      -side * PrayerReaderMetrics.waitingTilt * steps,
      1,
      0,
      0
    )

    let scale = 1 - PrayerReaderMetrics.waitingShrink * steps
    return CATransform3DScale(transform, scale, scale, 1)
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
