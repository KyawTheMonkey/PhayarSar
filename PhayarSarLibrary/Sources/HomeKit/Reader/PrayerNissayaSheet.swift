#if canImport(UIKit)
import LocalisationKit
import PrayersKit
import UIKit

/// Layout and feel constants for the inline nissaya sheet.
enum PrayerNissayaSheetMetrics {
  /// The panel's top corners once it has arrived.
  static let cornerRadius: CGFloat = 24

  /// The corner the panel wears at the instant it leaves the page: the one the
  /// tint behind a tapped line wears, so that what starts moving is a picked-out
  /// line rather than a sheet already drawn around it. Rounded out to
  /// ``cornerRadius`` on the way down.
  static let openingCornerRadius = PrayerReaderMetrics.focusCornerRadius

  /// The shadow under the panel once it has arrived.
  ///
  /// Grown from nothing, because on the page the line casts none. A shadow
  /// present in the first frame is the tell that a panel was laid over the page
  /// rather than lifted out of it — and its arriving is most of what makes the
  /// travel legible on the papers where panel and page are nearly the same
  /// colour.
  static let shadowOpacity: CGFloat = 0.2

  /// Air above the verse once the sheet has arrived, which is also the room the
  /// grabber sits in.
  ///
  /// Zero at the moment the sheet leaves the page, and grown to this on the way
  /// — that is what keeps the verse exactly where it was as the panel appears
  /// around it. A sheet that opened with this already in place would jog its own
  /// text down by this much in the first frame.
  static let contentTopInset: CGFloat = 26

  /// Air under the translation, above the home indicator.
  static let contentBottomInset: CGFloat = 24

  /// Gap between the rule that closes the line and the translation that rule
  /// now opens.
  ///
  /// The sheet draws no rule of its own. The line arrives with the one the page
  /// had already drawn under it, and that rule stays exactly where it was while
  /// the translation opens beneath it — one more thing that did not have to be
  /// faded in, and so one more thing that says this is the same line rather
  /// than a copy of it.
  static let ruleSpacing: CGFloat = 20

  /// Gap between the translation's label and the translation.
  static let captionSpacing: CGFloat = 8

  static let grabberSize = CGSize(width: 36, height: 5)
  static let grabberTopInset: CGFloat = 8

  /// How much of the travel is over before the translation starts to arrive.
  ///
  /// It arrives second, on purpose. Everything fading in at once over the same
  /// half second is a panel dissolving into place, and a dissolve has no
  /// direction — the eye is given the whole sheet at 40% and nothing to follow.
  /// Held back, the line moves first and alone, and the translation opens under
  /// it once it has somewhere to open into.
  static let additionsDelay: CGFloat = 0.38

  /// How far under its place the translation starts, in points.
  ///
  /// Small: this is the translation settling into the room the line has just
  /// made for it, not a second thing sliding in from somewhere.
  static let additionsRise: CGFloat = 14

  /// The share of the travel the translation gets on the way out.
  ///
  /// Quick, and ahead of the panel: what folds back into the line has to be the
  /// line alone, or the sheet lands on the page still carrying a paragraph the
  /// page has no room for.
  static let additionsExit: Double = 0.4

  /// The most of the screen the sheet will take, however long the translation
  /// is. Past this it scrolls — the page it grew out of has to stay in view,
  /// because the sheet is a reading aid for that page rather than a screen of
  /// its own.
  static let maximumHeightFraction: CGFloat = 0.72

  /// How far down the panel has to be dragged before letting go dismisses it,
  /// as a fraction of its height.
  static let dismissFraction: CGFloat = 0.28

  /// Downward velocity that dismisses regardless of how far it has been
  /// dragged, in points per second — a flick rather than a haul.
  static let dismissVelocity: CGFloat = 900

  static let scrimAlpha: CGFloat = 0.38

  /// The spring the sheet travels on. Barely any bounce: it is carrying a
  /// paragraph of text the reader is about to read, and text that overshoots and
  /// comes back is text that cannot be started on until it stops.
  static var travel: UIViewPropertyAnimator {
    UIViewPropertyAnimator(
      duration: PrayerReaderMetrics.sheetTravel,
      dampingRatio: 0.86
    )
  }
}

/// The inline nissaya sheet: the line on the page, grown into a panel that
/// carries its translation.
///
/// The point of it is that it is the *same line*. It opens at the exact rect
/// that one row occupies on the page, set in the same face at the same size
/// with the same insets, and travels from there down into a bottom sheet with
/// the translation under it. Nothing cross-fades and nothing is replaced: the
/// text the reader was looking at is the text at the top of the sheet, and it
/// got there by moving. The page hides the row it came from for as long as the
/// sheet is up — see ``PrayerVerseLineCell/Emphasis/lifted`` — because a line
/// that is still on the page while the sheet carries it away is not one line
/// moving, it is two.
///
/// That is also why the panel is built around ``PrayerVerseLineView`` rather
/// than around a label of its own — the line has to be drawn by the same code
/// that drew it on the page, or the two do not line up in the first frame and
/// the whole effect is a panel appearing with a copy of the text in it.
///
/// One line rather than the whole verse the nissaya belongs to. The reader
/// asked about a row; a sheet that opened carrying every other row of the verse
/// would answer with a wall of Pali they already have on the page behind it, and
/// could not have grown out of the row they touched.
///
/// Inline rather than a `UIViewController` presentation. A sheet presented over
/// the reader would come from the bottom of the screen with no relationship to
/// the line it is about, and `UISheetPresentationController` owns its own
/// transition, which is the one thing this cannot give up.
final class PrayerNissayaSheet: UIView {

  // MARK: - Views

  private let scrim = UIView()
  private let panel = UIView()
  private let clipper = UIView()
  private let scrollView = UIScrollView()
  private let content = UIStackView()
  private let grabber = UIView()

  private let lineView = PrayerVerseLineView()
  private let caption = UILabel()
  private let meaning = UILabel()

  /// Grown from nothing as the sheet travels — see
  /// ``PrayerNissayaSheetMetrics/contentTopInset``.
  private var contentTop: NSLayoutConstraint?

  // MARK: - State

  /// Where on the page the line sits, in this view's coordinates. The sheet
  /// leaves from here and comes back to it.
  private var sourceRect: CGRect = .zero

  /// Where the sheet rests once it has arrived.
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
    // Grown on the way down — see `PrayerNissayaSheetMetrics.shadowOpacity`.
    panel.layer.shadowOpacity = 0
    panel.layer.shadowRadius = 28
    panel.layer.shadowOffset = CGSize(width: 0, height: -8)
    addSubview(panel)

    clipper.layer.cornerRadius = PrayerNissayaSheetMetrics.openingCornerRadius
    clipper.layer.cornerCurve = .continuous
    clipper.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    clipper.clipsToBounds = true
    clipper.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(clipper)

    scrollView.showsVerticalScrollIndicator = false
    scrollView.contentInsetAdjustmentBehavior = .never
    // Off until the sheet has arrived. A scroll view that can be dragged while
    // its own frame is still growing takes the drag that was meant for the
    // panel's grabber.
    scrollView.isScrollEnabled = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    clipper.addSubview(scrollView)

    content.axis = .vertical
    content.alignment = .fill
    content.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(content)

    caption.numberOfLines = 1
    meaning.numberOfLines = 0

    content.addArrangedSubview(lineView)
    content.addArrangedSubview(caption)
    content.addArrangedSubview(meaning)

    content.setCustomSpacing(PrayerNissayaSheetMetrics.ruleSpacing, after: lineView)
    content.setCustomSpacing(PrayerNissayaSheetMetrics.captionSpacing, after: caption)

    grabber.layer.cornerRadius = PrayerNissayaSheetMetrics.grabberSize.height / 2
    grabber.alpha = 0
    grabber.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(grabber)

    let inset = PrayerReaderMetrics.horizontalInset
    let frame = scrollView.frameLayoutGuide
    let contentGuide = scrollView.contentLayoutGuide
    let top = content.topAnchor.constraint(equalTo: contentGuide.topAnchor)
    contentTop = top

    NSLayoutConstraint.activate([
      scrim.topAnchor.constraint(equalTo: topAnchor),
      scrim.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrim.trailingAnchor.constraint(equalTo: trailingAnchor),
      scrim.bottomAnchor.constraint(equalTo: bottomAnchor),

      // The panel's own frame is set by hand — it is the thing that travels —
      // so only what is inside it is laid out against it.
      clipper.topAnchor.constraint(equalTo: panel.topAnchor),
      clipper.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
      clipper.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
      clipper.bottomAnchor.constraint(equalTo: panel.bottomAnchor),

      scrollView.topAnchor.constraint(equalTo: clipper.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: clipper.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: clipper.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: clipper.bottomAnchor),

      top,
      content.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor, constant: inset),
      content.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor, constant: -inset),
      content.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor),
      content.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -inset * 2),

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

  /// Grows the sheet out of a line.
  ///
  /// - Parameters:
  ///   - line: The line as the page has it — the very row it is drawn on.
  ///   - sourceRect: Where that row sits in `host`'s coordinates. The sheet
  ///     starts here, which is what makes it look like it came from there
  ///     rather than from the bottom of the screen.
  ///   - text: The nissaya. Of the *verse* the line belongs to, which is the
  ///     unit a translation is written for — the line is what the reader
  ///     pointed at, not what the meaning is divided by.
  func present(
    in host: UIView,
    from sourceRect: CGRect,
    line: PrayerVerseLine,
    meaning text: String,
    style: PrayerReadingStyle,
    onDismiss: @escaping () -> Void
  ) {
    self.onDismiss = onDismiss
    self.sourceRect = sourceRect

    frame = host.bounds
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    host.addSubview(self)

    apply(style: style)
    lineView.configure(with: line, style: style)
    caption.attributedText = style.attributedName(L10n.nissayaMeaning)
    meaning.attributedText = style.attributedMeaning(text)
    meaning.accessibilityLabel = "\(L10n.nissayaMeaning), \(text)"

    layoutIfNeeded()

    // Measured at the width the sheet will actually be, and with the panel's own
    // air already accounted for, before it is put back where it opens from. The
    // content cannot be measured against a panel that has no width yet, and the
    // panel has none until it is given a frame.
    contentTop?.constant = PrayerNissayaSheetMetrics.contentTopInset
    panel.frame = bounds
    panel.layoutIfNeeded()

    scrollView.contentInset.bottom = PrayerNissayaSheetMetrics.contentBottomInset
      + host.safeAreaInsets.bottom
    restingFrame = measureRestingFrame(in: host)

    // The line where it already is, with none of the panel's own air above it
    // yet: at this instant the sheet is indistinguishable from the page under
    // it, which is the whole trick.
    contentTop?.constant = 0
    panel.frame = openingFrame
    panel.layoutIfNeeded()

    fadeAdditions(to: 0)

    let animator = PrayerNissayaSheetMetrics.travel
    animator.addAnimations {
      self.scrim.alpha = 1
      self.panel.frame = self.restingFrame
      self.contentTop?.constant = PrayerNissayaSheetMetrics.contentTopInset
      self.panel.layoutIfNeeded()
    }
    // Second, once the line has somewhere to have arrived — see
    // `PrayerNissayaSheetMetrics.additionsDelay`.
    animator.addAnimations(
      { self.fadeAdditions(to: 1) },
      delayFactor: PrayerNissayaSheetMetrics.additionsDelay
    )

    travelLayers(opening: true)

    animator.addCompletion { _ in
      // Only where the translation actually runs past the bottom of the sheet.
      // Otherwise the panel keeps every drag for itself, and a sheet short
      // enough to read whole can be pushed away from anywhere on it rather than
      // only by its grabber.
      self.scrollView.isScrollEnabled =
        self.scrollView.contentSize.height + self.scrollView.contentInset.bottom
          > self.scrollView.bounds.height
    }

    self.animator = animator
    animator.startAnimation()
  }

  /// Folds the sheet back into the line it came from.
  func dismiss() {
    animator?.stopAnimation(true)
    scrollView.isScrollEnabled = false
    // Back to the top, so that what folds away into the line is the line
    // rather than whatever part of the translation had been scrolled to.
    scrollView.setContentOffset(.zero, animated: false)

    // Ahead of the panel and on its own clock — see
    // `PrayerNissayaSheetMetrics.additionsExit`.
    UIView.animate(
      withDuration: PrayerReaderMetrics.sheetTravel * PrayerNissayaSheetMetrics.additionsExit
    ) {
      self.fadeAdditions(to: 0)
    }

    let animator = PrayerNissayaSheetMetrics.travel
    animator.addAnimations {
      self.scrim.alpha = 0
      self.panel.frame = self.openingFrame
      self.contentTop?.constant = 0
      self.panel.layoutIfNeeded()
    }

    travelLayers(opening: false)

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
    grabber.backgroundColor = style.secondaryTextColor.withAlphaComponent(0.4)
  }

  /// Everything the sheet has that the line on the page did not: the grabber and
  /// the translation. All of it arrives by fading, because none of it has
  /// anywhere on the page to have come from — and rising the last few points
  /// with it, so that it reads as opening out from under the line rather than
  /// as a second panel developing on top of the first.
  private func fadeAdditions(to alpha: CGFloat) {
    grabber.alpha = alpha
    caption.alpha = alpha
    meaning.alpha = alpha

    // Not the grabber: it belongs to the panel's edge, and an edge that slides
    // is an edge that has come loose.
    let rise = CGAffineTransform(
      translationX: 0,
      y: (1 - alpha) * PrayerNissayaSheetMetrics.additionsRise
    )
    caption.transform = rise
    meaning.transform = rise
  }

  /// The two parts of the travel a `UIView` animation will not carry: the
  /// panel's corner and its shadow.
  ///
  /// Both live on layers rather than on views — `cornerRadius` on the clipper,
  /// `shadowOpacity` on the panel — and neither is a property `UIView`'s
  /// animation of a frame picks up, so setting them inside the animator's block
  /// would snap them to their new value in the first frame. Which is exactly the
  /// frame they must not be in: a full-strength shadow around a strip the height
  /// of one line is a panel that was placed there, not a line that lifted.
  ///
  /// Eased rather than sprung, unlike the panel itself. Neither of these has any
  /// weight to carry, and a corner that overshoots its radius is a corner that
  /// wobbles.
  private func travelLayers(opening: Bool) {
    let radius = opening
      ? PrayerNissayaSheetMetrics.cornerRadius
      : PrayerNissayaSheetMetrics.openingCornerRadius
    let shadow = opening ? PrayerNissayaSheetMetrics.shadowOpacity : 0

    travel(clipper.layer, "cornerRadius", to: radius)
    travel(panel.layer, "shadowOpacity", to: shadow)
  }

  /// Animates one layer property and leaves the model value at the far end, so
  /// that the layer stays where the animation put it when the animation is gone.
  private func travel(_ layer: CALayer, _ keyPath: String, to value: CGFloat) {
    let animation = CABasicAnimation(keyPath: keyPath)
    // From wherever it has actually got to, so that a sheet dismissed mid-open
    // carries on from there rather than jumping back to full.
    animation.fromValue = layer.presentation()?.value(forKeyPath: keyPath)
      ?? layer.value(forKeyPath: keyPath)
    animation.toValue = value
    animation.duration = PrayerReaderMetrics.sheetTravel
    animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

    layer.setValue(value, forKeyPath: keyPath)
    layer.add(animation, forKey: keyPath)
  }

  /// Where the sheet comes to rest: as tall as it needs to be, up to a limit,
  /// and sitting on the bottom of the screen.
  private func measureRestingFrame(in host: UIView) -> CGRect {
    let wanted = scrollView.contentSize.height + scrollView.contentInset.bottom
    let limit = bounds.height * PrayerNissayaSheetMetrics.maximumHeightFraction
    let height = min(wanted, limit)

    return CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
  }

  /// Where the sheet begins and ends its life: the rect the line occupies on
  /// the page, with a floor under the height so that a short line still has
  /// somewhere to put its rounded corners.
  private var openingFrame: CGRect {
    CGRect(
      x: 0,
      y: sourceRect.minY,
      width: bounds.width,
      height: max(sourceRect.height, PrayerNissayaSheetMetrics.cornerRadius)
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
  /// page behind: a sheet the page can be scrolled out from under is a sheet
  /// that has nowhere to fold back into.
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)

    return hit == self ? scrim : hit
  }
}
#endif
