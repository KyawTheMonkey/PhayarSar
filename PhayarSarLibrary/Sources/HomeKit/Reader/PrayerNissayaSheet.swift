#if canImport(UIKit)
import DesignKit
import LocalisationKit
import UIKit

/// Layout, type and feel constants for the inline nissaya sheet.
enum PrayerNissayaSheetMetrics {
  static let cornerRadius: CGFloat = 24

  static let shadowOpacity: Float = 0.2
  static let shadowRadius: CGFloat = 28
  static let shadowOffset = CGSize(width: 0, height: -8)

  /// Air above the line, which is also the room the grabber sits in.
  static let contentTopInset: CGFloat = 26

  /// Air under the translation, above the home indicator.
  static let contentBottomInset: CGFloat = 24

  /// Gap between the line and the rule under it, and between that rule and the
  /// translation it opens.
  static let ruleSpacing: CGFloat = 18

  /// Gap between the translation's label and the translation.
  static let captionSpacing: CGFloat = 8

  static let grabberSize = CGSize(width: 36, height: 5)
  static let grabberTopInset: CGFloat = 8

  /// How deep the fade at the top of the scrolling content is.
  ///
  /// About the top inset, so that a sheet sitting still has nothing faded — the
  /// fade covers the air above the first line, and only text that has been
  /// scrolled up into that air is dimmed by it. It is also what keeps the
  /// content off the grabber: a line passing behind the grabber is a line
  /// crossed out by it, where a line thinning away under it has gone somewhere.
  static let topFadeHeight: CGFloat = 30

  /// The most of the screen the sheet will take, however long the translation
  /// is. Past this it scrolls — the page it was opened from has to stay in
  /// view, because the sheet is a reading aid for that page rather than a
  /// screen of its own.
  static let maximumHeightFraction: CGFloat = 0.72

  /// How far down the panel has to be dragged before letting go dismisses it,
  /// as a fraction of its height.
  static let dismissFraction: CGFloat = 0.28

  /// Downward velocity that dismisses regardless of how far it has been
  /// dragged, in points per second — a flick rather than a haul.
  static let dismissVelocity: CGFloat = 900

  static let scrimAlpha: CGFloat = 0.38

  /// The spring the sheet arrives and leaves on. Barely any bounce: it is
  /// carrying a paragraph of text the reader is about to read, and text that
  /// overshoots and comes back is text that cannot be started on until it
  /// stops.
  static var travel: UIViewPropertyAnimator {
    UIViewPropertyAnimator(
      duration: PrayerReaderMetrics.sheetTravel,
      dampingRatio: 0.86
    )
  }

  // MARK: - Type
  //
  // The sheet's own, and deliberately not the reader's. `PrayerSettings` is
  // about *reciting*: a face chosen for chanting Pali, a size chosen to be read
  // at arm's length, tracking that spaces the syllables out. None of that is
  // what this panel is for. It is a note about one line, read once and put
  // away — and at the reader's 28pt with two points of tracking, a paragraph of
  // Burmese prose fills the screen and still is not finished.
  //
  // Fixed sizes rather than fixed *type*: both faces still scale with Dynamic
  // Type, so a reader who has set the system large gets a large sheet without
  // having to go anywhere near the reading settings.

  /// The verse's lines. The sheet's subject, so a step above the prose that
  /// explains it.
  static var lineFont: UIFont { AppUIFont.jasmine(size: 19) }

  /// The translation.
  static var meaningFont: UIFont { AppUIFont.jasmine(size: 17) }

  /// The label over the translation — the app's own section label, the same one
  /// a verse name is set in on the page.
  static var captionFont: UIFont { AppUIFont.sectionLabel }

  /// Leading for the two Burmese blocks. Generous, because the script stacks
  /// above and below its baseline and lines set tight collide.
  static let lineLeading: CGFloat = 8
  static let meaningLeading: CGFloat = 7

  /// Gap between one line of the verse and the next.
  ///
  /// The sheet's own, not the reader's. Their verse and line spacing is set for
  /// following a chant down a full page; here the verse is a short block to be
  /// taken in at once.
  static let verseLineSpacing: CGFloat = 14

  // MARK: - The marker
  //
  // The line the reader actually asked about, picked out of the verse around
  // it. Fixed colours, on every paper: this is a highlighter drawn over the
  // line, and a highlighter that changed colour with the page would be one more
  // thing to work out instead of the thing that answers the question. Yellow
  // and black are also the pair that survives all six papers — the marker has
  // to read as marked on parchment as well as on true black, and black ink on
  // yellow is the highest contrast either end can be given.

  /// A pale, washed yellow rather than a saturated one — the colour a
  /// highlighter leaves on paper, not the colour of the pen's barrel.
  ///
  /// Lightened by mixing rather than by dropping the alpha. A translucent mark
  /// takes the paper underneath with it: the same yellow that reads as a wash
  /// on parchment goes to a dark olive on true black, and black ink on dark
  /// olive is not readable. Opaque, the mark is the same wash on all six
  /// papers, which is what lets the ink on it be fixed too.
  static let markerColor = UIColor(red: 1, green: 0.941, blue: 0.639, alpha: 1)

  /// Always black, never the paper's ink. On the dark papers that ink is nearly
  /// white, and near-white on yellow is the one combination here that cannot be
  /// read at all.
  static let markerTextColor = UIColor.black

  /// Square, like a felt tip laid flat. Rounding the ends turns each line into
  /// its own pill, and a marked passage of several lines then reads as several
  /// marks rather than one stroke carried down the block.
  static let markerCornerRadius: CGFloat = 0

  /// How far the marker is drawn past the text it covers. Tight: the mark
  /// belongs to the words, so it takes just enough room not to clip the script,
  /// and the vertical figure is an overlap into the neighbouring line's band
  /// rather than air — it is what closes the seam between one line and the next.
  static let markerOutset = (horizontal: CGFloat(3), vertical: CGFloat(2))

  /// Air kept under the marked line when a verse too long to fit has to be
  /// scrolled to bring it into view.
  static let markerRevealMargin: CGFloat = 12

  /// How fast the mark is drawn on, in points a second — the speed of the pen
  /// rather than a duration, so a short line is marked in less time than a long
  /// one and a wrapped passage is marked a line at a time at one pace.
  static let markerSweepSpeed: CGFloat = 900

  /// The longest the whole stroke may take, however much text is under it. Past
  /// this the pen simply moves faster: the mark is an answer to a question the
  /// reader has already asked, and an answer is not worth waiting a second for.
  static let markerSweepLimit: TimeInterval = 0.55

  /// The beat between the sheet landing and the pen starting. Short, but not
  /// nothing: the two movements have to be seen as two.
  static let markerSweepDelay: TimeInterval = 0.08
}

/// The inline nissaya sheet: a bottom sheet carrying a verse of the prayer and
/// its translation, with the line the reader asked about marked in it.
///
/// It is a note about a verse, not a screen. It comes up over the page, takes as
/// much height as it needs up to a limit, and is put away by a tap on the scrim
/// or a drag on the panel. The page stays exactly where it was underneath.
///
/// The whole verse rather than the one line, because the nissaya is written for
/// the whole verse: a translation shown against a single line of it would be
/// making a claim about that line that it does not make. The marker is what
/// keeps the reader's place in it — they swiped one row, and that row is
/// findable in the block at a glance rather than by counting lines against the
/// page behind.
///
/// The verse is set in the sheet's own type rather than the reader's — see the
/// type section of ``PrayerNissayaSheetMetrics`` — and carries the recited text
/// alone. The phonetic respelling is left on the page: it is an aid for *saying*
/// the line, and nothing here is about saying it.
///
/// Inline rather than a `UIViewController` presentation. The reader is a UIKit
/// controller inside a SwiftUI stack, and presenting from it would open a second
/// presentation context inside SwiftUI's own for a panel that never leaves the
/// reading screen. The chrome floating over the reader is told to stand down
/// either way — see ``PrayerViewController/onSheetChange``.
final class PrayerNissayaSheet: UIView {

  // MARK: - Views

  private let scrim = UIView()
  private let panel = UIView()
  private let clipper = UIView()
  private let scrollView = PrayerNissayaScrollView()
  private let content = UIStackView()
  private let grabber = UIView()

  /// The verse, a line to a row — see ``PrayerNissayaVerseLineView``.
  private let verse = UIStackView()
  private let rule = UIView()
  private let caption = UILabel()
  private let meaning = UILabel()

  /// The marked row, kept so a verse too long to fit can be scrolled to it —
  /// and so the mark can be drawn on once the sheet has landed.
  private weak var markedLine: PrayerNissayaVerseLineView?

  // MARK: - State

  /// Where the sheet rests once it is up. It comes from below this and goes
  /// back below it.
  private var restingFrame: CGRect = .zero

  private var animator: UIViewPropertyAnimator?

  /// Called once the sheet has left the screen, whether it was dismissed by the
  /// reader or torn down from outside.
  private var onDismiss: (() -> Void)?

  // MARK: - Life cycle

  override init(frame: CGRect) {
    super.init(frame: frame)
    setUpSubviews()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setUpSubviews() {
    scrim.backgroundColor = UIColor.black.withAlphaComponent(PrayerNissayaSheetMetrics.scrimAlpha)
    scrim.alpha = 0
    scrim.translatesAutoresizingMaskIntoConstraints = false
    addSubview(scrim)

    scrim.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(scrimTapped))
    )

    // The shadow is on the panel and the rounding is on the view inside it: a
    // layer cannot both clip its children and cast a shadow past its own edge.
    panel.backgroundColor = .clear
    panel.layer.shadowColor = UIColor.black.cgColor
    panel.layer.shadowOpacity = PrayerNissayaSheetMetrics.shadowOpacity
    panel.layer.shadowRadius = PrayerNissayaSheetMetrics.shadowRadius
    panel.layer.shadowOffset = PrayerNissayaSheetMetrics.shadowOffset
    addSubview(panel)

    clipper.layer.cornerRadius = PrayerNissayaSheetMetrics.cornerRadius
    clipper.layer.cornerCurve = .continuous
    clipper.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    clipper.clipsToBounds = true
    clipper.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(clipper)

    scrollView.showsVerticalScrollIndicator = false
    scrollView.contentInsetAdjustmentBehavior = .never
    // Off until the sheet has arrived. A scroll view that can be dragged while
    // its own panel is still moving takes the drag that was meant for the
    // panel's grabber.
    scrollView.isScrollEnabled = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    clipper.addSubview(scrollView)

    content.axis = .vertical
    content.alignment = .fill
    content.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(content)

    meaning.numberOfLines = 0
    caption.numberOfLines = 1

    verse.axis = .vertical
    verse.alignment = .fill
    verse.spacing = PrayerNissayaSheetMetrics.verseLineSpacing

    content.addArrangedSubview(verse)
    content.addArrangedSubview(rule)
    content.addArrangedSubview(caption)
    content.addArrangedSubview(meaning)

    content.setCustomSpacing(PrayerNissayaSheetMetrics.ruleSpacing, after: verse)
    content.setCustomSpacing(PrayerNissayaSheetMetrics.ruleSpacing, after: rule)
    content.setCustomSpacing(PrayerNissayaSheetMetrics.captionSpacing, after: caption)

    grabber.layer.cornerRadius = PrayerNissayaSheetMetrics.grabberSize.height / 2
    grabber.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(grabber)

    let inset = PrayerReaderMetrics.horizontalInset
    let frame = scrollView.frameLayoutGuide
    let contentGuide = scrollView.contentLayoutGuide

    NSLayoutConstraint.activate([
      scrim.topAnchor.constraint(equalTo: topAnchor),
      scrim.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrim.trailingAnchor.constraint(equalTo: trailingAnchor),
      scrim.bottomAnchor.constraint(equalTo: bottomAnchor),

      // The panel's own frame is set by hand — it is the thing that moves — so
      // only what is inside it is laid out against it.
      clipper.topAnchor.constraint(equalTo: panel.topAnchor),
      clipper.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
      clipper.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
      clipper.bottomAnchor.constraint(equalTo: panel.bottomAnchor),

      scrollView.topAnchor.constraint(equalTo: clipper.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: clipper.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: clipper.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: clipper.bottomAnchor),

      content.topAnchor.constraint(
        equalTo: contentGuide.topAnchor,
        constant: PrayerNissayaSheetMetrics.contentTopInset
      ),
      content.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor, constant: inset),
      content.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor, constant: -inset),
      content.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor),
      content.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -inset * 2),

      rule.heightAnchor.constraint(
        equalToConstant: PrayerReaderMetrics.glossSeparatorThickness
      ),

      grabber.topAnchor.constraint(
        equalTo: panel.topAnchor,
        constant: PrayerNissayaSheetMetrics.grabberTopInset
      ),
      grabber.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
      grabber.widthAnchor.constraint(
        equalToConstant: PrayerNissayaSheetMetrics.grabberSize.width
      ),
      grabber.heightAnchor.constraint(
        equalToConstant: PrayerNissayaSheetMetrics.grabberSize.height
      )
    ])

    panel.addGestureRecognizer(
      UIPanGestureRecognizer(target: self, action: #selector(panned))
    )
  }

  // MARK: - Opening

  /// Brings the sheet up over the reader.
  ///
  /// - Parameters:
  ///   - lines: The verse, in reading order. Their recited text only — see the
  ///     class documentation for why the respelling is left behind.
  ///   - marked: The line the reader asked about, which is the one the marker
  ///     goes behind.
  ///   - text: The nissaya. Of the whole verse, which is the unit a translation
  ///     is written for.
  ///   - style: For the sheet's colours only, which do follow the reader: the
  ///     panel sits on their paper and has to be cut from it. The type does
  ///     not — see ``PrayerNissayaSheetMetrics``.
  func present(
    in host: UIView,
    lines: [PrayerVerseLine],
    marked: PrayerVerseLine.ID,
    meaning text: String,
    style: PrayerReadingStyle,
    onDismiss: @escaping () -> Void
  ) {
    self.onDismiss = onDismiss

    frame = host.bounds
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    host.addSubview(self)

    apply(style: style)
    setUpVerse(lines, marked: marked, style: style)
    caption.attributedText = attributed(
      L10n.nissayaMeaning.uppercased(),
      font: PrayerNissayaSheetMetrics.captionFont,
      leading: 0,
      color: style.secondaryTextColor
    )
    meaning.attributedText = attributed(
      text,
      font: PrayerNissayaSheetMetrics.meaningFont,
      leading: PrayerNissayaSheetMetrics.meaningLeading,
      color: style.textColor
    )
    meaning.accessibilityLabel = "\(L10n.nissayaMeaning), \(text)"

    layoutIfNeeded()

    // Measured at the width the sheet will actually be. The content cannot be
    // measured against a panel that has no width yet, and the panel has none
    // until it is given a frame.
    panel.frame = bounds
    panel.layoutIfNeeded()

    scrollView.contentInset.bottom = PrayerNissayaSheetMetrics.contentBottomInset
      + host.safeAreaInsets.bottom
    restingFrame = measureRestingFrame()
    panel.frame = offscreenFrame
    // Again at the height it will actually open at, so that the reveal below is
    // measured against the sheet's own bounds rather than the screen's.
    panel.layoutIfNeeded()
    revealMarkedLine()

    let animator = PrayerNissayaSheetMetrics.travel
    animator.addAnimations {
      self.scrim.alpha = 1
      self.panel.frame = self.restingFrame
    }
    animator.addCompletion { _ in
      // Only where the translation actually runs past the bottom of the sheet.
      // Otherwise the panel keeps every drag for itself, and a sheet short
      // enough to read whole can be pushed away from anywhere on it rather than
      // only by its grabber.
      self.scrollView.isScrollEnabled =
        self.scrollView.contentSize.height + self.scrollView.contentInset.bottom
          > self.scrollView.bounds.height

      // The sheet has landed; now the line it was opened for is marked.
      self.markedLine?.revealMark()
    }

    self.animator = animator
    animator.startAnimation()
  }

  /// Puts the sheet away.
  func dismiss() {
    animator?.stopAnimation(true)
    scrollView.isScrollEnabled = false

    let animator = PrayerNissayaSheetMetrics.travel
    animator.addAnimations {
      self.scrim.alpha = 0
      self.panel.frame = self.offscreenFrame
    }
    animator.addCompletion { _ in
      self.removeFromSuperview()
      self.onDismiss?()
      self.onDismiss = nil
    }

    self.animator = animator
    animator.startAnimation()
  }

  // MARK: - Drawing

  private func apply(style: PrayerReadingStyle) {
    clipper.backgroundColor = style.sheetColor
    rule.backgroundColor = style.separatorColor
    grabber.backgroundColor = style.secondaryTextColor.withAlphaComponent(0.4)
  }

  /// Lays the verse out, a line to a row, with the marker behind the one the
  /// reader asked about.
  ///
  /// Rebuilt rather than reused: a sheet is made for one opening and thrown
  /// away with it, and rows kept between openings would have to be reconciled
  /// with a verse of a different length.
  private func setUpVerse(
    _ lines: [PrayerVerseLine],
    marked: PrayerVerseLine.ID,
    style: PrayerReadingStyle
  ) {
    for row in verse.arrangedSubviews {
      verse.removeArrangedSubview(row)
      row.removeFromSuperview()
    }

    for line in lines {
      let isMarked = line.id == marked
      let row = PrayerNissayaVerseLineView()

      func set(in color: UIColor) -> NSAttributedString {
        attributed(
          line.gloss.content,
          font: PrayerNissayaSheetMetrics.lineFont,
          leading: PrayerNissayaSheetMetrics.lineLeading,
          color: color
        )
      }

      row.configure(
        set(in: style.textColor),
        marked: isMarked ? set(in: PrayerNissayaSheetMetrics.markerTextColor) : nil
      )

      verse.addArrangedSubview(row)

      if isMarked {
        markedLine = row
      }
    }
  }

  /// Scrolls a verse too long to fit far enough that its marked line is on
  /// screen.
  ///
  /// Only far enough. The sheet still opens at the top of the verse wherever it
  /// can, because the lines above the marked one are the run-up to it and a
  /// reader dropped into the middle of a verse has to find their way back to
  /// its beginning.
  private func revealMarkedLine() {
    guard
      let markedLine,
      let frame = markedLine.superview.map({ scrollView.convert(markedLine.frame, from: $0) })
    else {
      return
    }

    let visible = scrollView.bounds.height - scrollView.contentInset.bottom
    let overshoot = frame.maxY + PrayerNissayaSheetMetrics.markerRevealMargin - visible

    guard overshoot > 0 else { return }

    let limit = scrollView.contentSize.height + scrollView.contentInset.bottom
      - scrollView.bounds.height

    scrollView.contentOffset.y = max(0, min(overshoot, limit))
  }

  /// The sheet's text: its own face and leading, in whichever ink the caller is
  /// setting this piece in.
  ///
  /// None of the reader's tracking. Letter-spacing is a setting about chanting a
  /// line of Pali, and neither a marked line nor a paragraph of Burmese prose
  /// survives being set with it.
  private func attributed(
    _ text: String,
    font: UIFont,
    leading: CGFloat,
    color: UIColor
  ) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = leading

    return NSAttributedString(
      string: text,
      attributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
      ]
    )
  }

  /// Where the sheet comes to rest: as tall as it needs to be, up to a limit,
  /// and sitting on the bottom of the screen.
  private func measureRestingFrame() -> CGRect {
    let wanted = scrollView.contentSize.height + scrollView.contentInset.bottom
    let limit = bounds.height * PrayerNissayaSheetMetrics.maximumHeightFraction
    let height = min(wanted, limit)

    return CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
  }

  /// Where the sheet waits before it comes up, and where it goes back to.
  ///
  /// Below the screen by its own height and then by the reach of its shadow,
  /// which is thrown upwards — without that last part the panel is out of sight
  /// while a smudge of its shadow is still lying along the bottom edge.
  private var offscreenFrame: CGRect {
    restingFrame.offsetBy(
      dx: 0,
      dy: restingFrame.height + PrayerNissayaSheetMetrics.shadowRadius
    )
  }

  // MARK: - Dismissing

  @objc private func scrimTapped() {
    dismiss()
  }

  /// Drag the panel down to put it away.
  ///
  /// Only downward: this is a bottom sheet at its one and only height, so there
  /// is nothing above it to drag towards. Upward drags are held at rest rather
  /// than rubber-banded, which would promise a taller sheet that does not exist.
  @objc private func panned(_ gesture: UIPanGestureRecognizer) {
    let translation = max(0, gesture.translation(in: self).y)

    switch gesture.state {
    case .changed:
      panel.frame.origin.y = restingFrame.minY + translation
      // The page comes back up as the sheet is drawn away from it, so that a
      // drag half way down is half way back to reading.
      scrim.alpha = 1 - translation / restingFrame.height

    case .ended, .cancelled:
      let velocity = gesture.velocity(in: self).y
      let isFar = translation > restingFrame.height * PrayerNissayaSheetMetrics.dismissFraction

      if isFar || velocity > PrayerNissayaSheetMetrics.dismissVelocity {
        dismiss()
      } else {
        settle()
      }

    default:
      break
    }
  }

  /// Puts a drag that did not go far enough back where it started.
  private func settle() {
    let animator = PrayerNissayaSheetMetrics.travel
    animator.addAnimations {
      self.panel.frame = self.restingFrame
      self.scrim.alpha = 1
    }

    self.animator = animator
    animator.startAnimation()
  }

  // MARK: - Hit testing

  /// Taps outside the panel belong to the scrim, and nothing at all reaches the
  /// page behind: the sheet is a note about the line the reader asked about, and
  /// a page scrolling under it would leave that question behind.
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)

    return hit == self ? scrim : hit
  }
}

// MARK: - The scrolling content

/// The sheet's scrolling content, with the top of it faded out rather than cut
/// off at the panel's edge.
///
/// A verse longer than the sheet scrolls, and scrolled text arriving at a hard
/// edge under the grabber reads as text sliding behind the furniture. Fading it
/// says the same thing the edge was trying to say — there is more above — while
/// letting the grabber keep the top of the panel to itself.
///
/// The fade is a mask on this view's own layer rather than a shade laid over
/// it, because a shade would have to be painted in the paper's colour and the
/// paper is the reader's to change. A mask takes the panel's colour by taking
/// nothing at all.
private final class PrayerNissayaScrollView: UIScrollView {
  private let fade = CAGradientLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)

    // Only the alpha of these matters: a mask is read for its transparency, and
    // black is simply the opaque end of it.
    fade.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
    fade.startPoint = CGPoint(x: 0.5, y: 0)
    fade.endPoint = CGPoint(x: 0.5, y: 1)
    layer.mask = fade
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    guard bounds.height > 0 else { return }

    // No implicit animation: this runs on every frame of a scroll, and a mask
    // easing towards each new position would lag the content it is masking.
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    // `bounds` and not `bounds.size`: a scroll view scrolls by moving its own
    // bounds origin, and the mask lives in that same space. Given the bounds
    // whole, it travels with the offset and so stays pinned to the top of the
    // *panel* while the content runs underneath it.
    fade.frame = bounds

    let depth = PrayerNissayaSheetMetrics.topFadeHeight / bounds.height
    fade.locations = [0, NSNumber(value: Float(min(depth, 1)))]

    CATransaction.commit()
  }
}

// MARK: - One line of the verse

/// One line of the verse as the sheet sets it, with the marker behind it when it
/// is the line the reader asked about.
///
/// The marked line is set twice, one label over the other: underneath in the
/// paper's own ink, on top in black on yellow. What is animated is how much of
/// the top one is showing — see ``revealMark()`` — so the highlighter and the
/// ink it forces the text into arrive together, the way they would if someone
/// had actually drawn it.
///
/// A drawn mark rather than an `NSAttributedString` background attribute. That
/// attribute paints tight to each run of glyphs — which on Burmese, where the
/// script stacks well above and below its baseline, comes out as a ragged band
/// that follows the accents rather than a mark drawn over a line. This is one
/// even band per line of text, the way a highlighter leaves one.
private final class PrayerNissayaVerseLineView: UIView {
  /// The line in the paper's ink. Always there, marked or not; on a marked line
  /// it is what shows through the part of the mark that has not been drawn yet.
  private let label = UILabel()

  /// The mark and the ink that goes with it. Solid yellow, carrying a second
  /// copy of the line in black, and shaped into bands by its mask — so the mask
  /// is both what makes the mark a mark and what the sweep animates.
  private let mark = UIView()
  private let markLabel = UILabel()

  /// One band per line of text, in the mark's coordinates. Empty until the view
  /// has a width to lay the text out against.
  private var bands: [CGRect] = []

  /// The band shapes, as the mask that cuts them out of ``mark``.
  private let maskLayer = CALayer()
  private var bandLayers: [CALayer] = []

  /// The width the bands were last measured against, so a layout pass that did
  /// not change the width does not rebuild them.
  private var measuredWidth: CGFloat = -1

  private var isMarked = false

  /// Whether the mark has been drawn on yet. A marked line starts *un*drawn —
  /// the sheet travels up carrying an unmarked-looking line and the mark is put
  /// on once it lands, so this is also what a relayout in between has to
  /// preserve rather than quietly completing the stroke early.
  private var isDrawn = false

  /// A sweep asked for before the bands existed. The sheet opens the mark as it
  /// comes to rest, which can land before this row has been laid out at its
  /// final width; the sweep then plays as soon as it has been.
  private var awaitingSweep = false

  override init(frame: CGRect) {
    super.init(frame: frame)

    mark.backgroundColor = PrayerNissayaSheetMetrics.markerColor
    mark.isHidden = true
    mark.isUserInteractionEnabled = false
    // The mark repeats the line the label underneath already carries, and
    // VoiceOver reading a marked line twice is worse than not knowing it is
    // marked.
    mark.isAccessibilityElement = false
    mark.accessibilityElementsHidden = true
    mark.layer.mask = maskLayer
    mark.translatesAutoresizingMaskIntoConstraints = false

    for label in [label, markLabel] {
      label.numberOfLines = 0
      label.translatesAutoresizingMaskIntoConstraints = false
    }

    addSubview(label)
    addSubview(mark)
    mark.addSubview(markLabel)

    let outset = PrayerNissayaSheetMetrics.markerOutset

    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: topAnchor),
      label.leadingAnchor.constraint(equalTo: leadingAnchor),
      label.trailingAnchor.constraint(equalTo: trailingAnchor),
      label.bottomAnchor.constraint(equalTo: bottomAnchor),

      // The mark is the label's box grown by the outset on every side — the
      // room the bands are allowed to take past the text. Which of that box is
      // actually yellow is the mask's business, so these constraints only have
      // to guarantee the room; they do not set the width of the mark.
      mark.topAnchor.constraint(equalTo: label.topAnchor, constant: -outset.vertical),
      mark.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: outset.vertical),
      mark.leadingAnchor.constraint(equalTo: label.leadingAnchor, constant: -outset.horizontal),
      mark.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: outset.horizontal),

      // Sitting the second copy exactly over the first is what lets the sweep
      // read as one line changing ink rather than as two lines crossfading.
      markLabel.topAnchor.constraint(equalTo: label.topAnchor),
      markLabel.leadingAnchor.constraint(equalTo: label.leadingAnchor),
      markLabel.trailingAnchor.constraint(equalTo: label.trailingAnchor),
      markLabel.bottomAnchor.constraint(equalTo: label.bottomAnchor)
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// - Parameters:
  ///   - text: The line in the paper's ink, already set.
  ///   - marked: A second setting of the same line in the mark's own black —
  ///     see the marker section of ``PrayerNissayaSheetMetrics``. `nil` on the
  ///     lines the reader did not ask about.
  func configure(_ text: NSAttributedString, marked: NSAttributedString?) {
    label.attributedText = text
    markLabel.attributedText = marked
    isMarked = marked != nil
    mark.isHidden = !isMarked

    isDrawn = false
    measuredWidth = -1
    setNeedsLayout()
  }

  // MARK: - The bands

  override func layoutSubviews() {
    super.layoutSubviews()

    guard isMarked, mark.bounds.width > 0 else { return }
    guard mark.bounds.width != measuredWidth else { return }

    measuredWidth = mark.bounds.width
    rebuildBands()

    guard awaitingSweep else { return }

    awaitingSweep = false
    sweep()
  }

  private func rebuildBands() {
    guard let text = markLabel.attributedText else { return }

    bands = Self.bands(for: text, width: mark.bounds.width)

    // Implicit animation off: these are the mask's resting shapes, and letting
    // Core Animation cross-fade them would put a second, unasked-for movement
    // under the sweep.
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    for layer in bandLayers {
      layer.removeFromSuperlayer()
    }

    bandLayers = bands.map { band in
      let layer = CALayer()
      // Anchored on its left edge, so growing its width draws it rightwards
      // from where the line starts rather than outwards from its middle.
      layer.anchorPoint = CGPoint(x: 0, y: 0.5)
      layer.position = CGPoint(x: band.minX, y: band.midY)
      layer.bounds = CGRect(origin: .zero, size: band.size)
      layer.cornerRadius = PrayerNissayaSheetMetrics.markerCornerRadius
      layer.cornerCurve = .continuous
      // Any opaque colour: a mask is read for its alpha alone.
      layer.backgroundColor = UIColor.black.cgColor
      maskLayer.addSublayer(layer)

      return layer
    }

    maskLayer.frame = mark.bounds

    CATransaction.commit()

    // Rebuilt at a new width mid-life — a rotation, say — the mark stays as
    // drawn as it already was. Rebuilt before the sweep, it starts at nothing,
    // which is what the sweep draws it on from.
    setBandsShown(isDrawn)
  }

  /// Where the mark's bands sit for a given setting of the line at a given
  /// width.
  ///
  /// The text is laid out a second time here rather than read off the label,
  /// because the label will not say where its lines ended. Same string, same
  /// container width, same wrapping, so it breaks where the label breaks.
  ///
  /// Width comes from each line fragment's *used* rect — where that line's
  /// glyphs actually stop, which is what keeps the mark on the words instead of
  /// running to the margin as a full-width bar. Height comes from the *fragment*
  /// rect, the whole slot the line was given, line spacing included: fragment
  /// rects tile the block without gaps, so consecutive lines come out as one
  /// unbroken stroke rather than a stack of bars with the paper showing between
  /// them.
  private static func bands(for text: NSAttributedString, width: CGFloat) -> [CGRect] {
    let outset = PrayerNissayaSheetMetrics.markerOutset
    // The label's width: the mark is the label's box already grown by the
    // outset, and the text was wrapped to the label.
    let textWidth = width - outset.horizontal * 2

    guard text.length > 0, textWidth > 0 else { return [] }

    let storage = NSTextStorage(attributedString: text)
    let manager = NSLayoutManager()
    let container = NSTextContainer(
      size: CGSize(width: textWidth, height: .greatestFiniteMagnitude)
    )

    // `UILabel` insets nothing and wraps on words; the default text container
    // pads its fragments, which would break the lines a little early.
    container.lineFragmentPadding = 0
    container.lineBreakMode = .byWordWrapping
    container.maximumNumberOfLines = 0

    manager.addTextContainer(container)
    storage.addLayoutManager(manager)
    manager.ensureLayout(for: container)

    var bands: [CGRect] = []

    manager.enumerateLineFragments(
      forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)
    ) { fragment, used, _, _, _ in
      guard used.width > 0, fragment.height > 0 else { return }

      // Back into the mark's coordinates: the text sits an outset in from its
      // top left corner, and the band is that rect grown by the outset again —
      // which lands its origin back on the text's own.
      bands.append(
        CGRect(
          x: used.minX,
          y: fragment.minY,
          width: used.width + outset.horizontal * 2,
          height: fragment.height + outset.vertical * 2
        )
      )
    }

    return bands
  }

  // MARK: - Drawing it on

  /// Draws the mark on, left to right, a line at a time.
  ///
  /// Called once the sheet has come to rest rather than with it: a highlighter
  /// stroke is someone's hand moving, and a hand moving on a panel that is
  /// itself still travelling is two movements the eye has to separate. Landing
  /// first and marking second also makes the mark the thing that answers the
  /// question — the reader watches the line they asked about being picked out.
  func revealMark() {
    guard isMarked else { return }

    // Not laid out at its real width yet, so there is nothing to sweep along.
    // The next layout pass plays it.
    guard !bands.isEmpty else { return awaitingSweep = true }

    sweep()
  }

  private func sweep() {
    guard !bandLayers.isEmpty else { return }

    isDrawn = true
    setBandsShown(true)

    guard !UIAccessibility.isReduceMotionEnabled else { return }

    let total = bands.reduce(0) { $0 + $1.width }

    guard total > 0 else { return }

    // One pen, at one speed, carried across every line of the passage — so a
    // long line takes longer than a short one and the lines are drawn in
    // reading order, not all at once. Capped, because a passage long enough to
    // fill the sheet would otherwise be a stroke the reader has to sit through.
    let duration = min(
      TimeInterval(total / PrayerNissayaSheetMetrics.markerSweepSpeed),
      PrayerNissayaSheetMetrics.markerSweepLimit
    )
    let start = CACurrentMediaTime() + PrayerNissayaSheetMetrics.markerSweepDelay
    var elapsed: TimeInterval = 0

    for (layer, band) in zip(bandLayers, bands) {
      let share = duration * TimeInterval(band.width / total)

      let animation = CABasicAnimation(keyPath: "bounds.size.width")
      animation.fromValue = 0
      animation.toValue = band.width
      animation.beginTime = start + elapsed
      animation.duration = share
      // Linear, and the same speed on every line: a stroke that eased in and
      // out on each line would read as several separate marks.
      animation.timingFunction = CAMediaTimingFunction(name: .linear)
      // Held at nothing until this line's turn comes, rather than sitting there
      // fully drawn while the line above is still being drawn.
      animation.fillMode = .backwards

      layer.add(animation, forKey: "sweep")

      elapsed += share
    }
  }

  /// Puts the bands straight to drawn or undrawn, with no animation of their
  /// own: the two ends the sweep runs between, and where a rebuilt mask has to
  /// pick up from.
  private func setBandsShown(_ shown: Bool) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    for (layer, band) in zip(bandLayers, bands) {
      layer.bounds = CGRect(
        origin: .zero,
        size: CGSize(width: shown ? band.width : 0, height: band.height)
      )
    }

    CATransaction.commit()
  }
}
#endif
