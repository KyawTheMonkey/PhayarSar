#if canImport(UIKit)
import UIKit

// MARK: - Metrics

/// How the paper is folded.
enum NissayaFoldMetrics {
  /// Roughly how tall one panel of the folded sheet is. The panel count is
  /// chosen by rounding the paper's height to whatever lands nearest this, so a
  /// short meaning folds into three panels and a long one into more, instead of
  /// a fixed count that would give a two-line answer folds the length of a
  /// paragraph.
  static let panelHeight: CGFloat = 66

  /// Fewer than four and the zigzag has no middle to it — it reads as one sheet
  /// tipping rather than as paper being opened out. Past eight the panels are
  /// narrower than the leading of the text on them, and the whole thing turns
  /// into a shimmer.
  ///
  /// Always an *even* number, which is geometry rather than taste: the panels
  /// alternate, so an even count is the one that brings the last crease back to
  /// the plane of the page. End on an odd panel and the bottom edge of the
  /// sheet is left standing off in depth, where the perspective divide draws it
  /// short — and the paper no longer reaches the bottom of the row it is
  /// folding inside.
  static let minPanels = 4
  static let maxPanels = 8

  /// How far the eye is from the paper, in points.
  ///
  /// Without a perspective term the fold is an affine squash: the far edge of a
  /// panel gets no further away, it just gets shorter. 500 is what
  /// `paperfold-for-ios` uses, and it is close: the panels visibly converge as
  /// they go back, which is most of what makes them read as being *turned*
  /// rather than merely shortened.
  static let perspective: CGFloat = 500

  // MARK: - Light
  //
  // What makes a fold read as a fold is not the geometry, which at a glance is
  // just a shorter row: it is the light. A sheet creased into panels is lit
  // twice over.
  //
  // Once per *panel*, by how it is turned. The panels alternate — one leaning
  // away from the reader as it goes down, the next leaning back towards them —
  // so one of every pair is turned into the light and comes up bright, and the
  // other is turned out of it and goes flat. That is ``facing``.
  //
  // And once per *edge*, by how little light reaches the inside of a crease.
  // A panel is brightest along the edge that is nearest the reader and darkest
  // along the edge that has gone furthest back, so each one carries a gradient
  // from ``highlight`` down to ``shadow``. The two sides of a valley are then
  // both dark where they meet and the two sides of a ridge are both bright,
  // which is the crease pattern — and it is the *alternation* of those, down
  // the sheet, that says paper.

  /// The deepest shadow, at the edge of a panel that has turned furthest away.
  ///
  /// Heavy, and it has to be. `paperfold-for-ios` takes its shadows to 0.9
  /// black at the deepest crease, which looks absurd written down and is what
  /// the effect lives on: a fold is a picture of *light being blocked*, and
  /// paper shaded gently just looks like a row dimming as it resizes.
  static let shadow: CGFloat = 0.62

  /// The brightest highlight, at the edge nearest the reader.
  static let highlight: CGFloat = 0.28

  /// The flat wash over a whole panel: dark on the ones turned away from the
  /// light, light on the ones turned into it. It separates one panel from the
  /// next even where neither edge is near a crease.
  static let facing: CGFloat = 0.12

  /// The crease itself. A hairline along each seam, drawn dark where two panels
  /// fold into a valley and light where they fold over a ridge, which is what
  /// gives the fold an edge rather than a soft gradient meeting another one.
  static let crease: CGFloat = 0.5
  static let creaseThickness: CGFloat = 0.75

  /// What a shut fold still stands at.
  ///
  /// Not zero, and it matters: a table view builds cells for the rows in its
  /// visible range, and a row of no height at all is one it may never ask for —
  /// which would leave the fold with no cell to animate at the moment it is
  /// asked to open. A single point is a cell that certainly exists and a sliver
  /// of paper nobody can see.
  static let shutHeight: CGFloat = 1
}

// MARK: - Fold

/// A sheet of paper that folds and unfolds, vertically, in the manner of a
/// brochure: the content is cut into panels that hinge at their shared edges,
/// alternately away from and towards the reader, and the sheet's height is
/// exactly the height that zigzag projects onto the screen.
///
/// Callers fill ``content`` and drive the fold themselves, a frame at a time:
///
/// ```swift
/// fold.prepareFold(to: true)          // measure, render, cut up
/// // … then, on every frame of a display link:
/// fold.setFoldHeight(height)          // the sheet, this far open
/// fold.finishFold()                   // put the real content back
/// ```
///
/// ## Why a snapshot
///
/// The panels are slices of an *image* of the content, not the content itself.
/// A `UILabel` cannot be in eight places at once, and a fold is exactly that:
/// one sheet of text seen as several planes at several angles. Rendering once
/// and cutting up the result also means the folding costs nothing per frame
/// beyond a transform per panel — no text is re-laid-out while it moves.
///
/// ## Why a height rather than an animation
///
/// An accordion of `n` panels each `h` tall, folded to an angle `θ` off flat,
/// projects to `n · h · cos θ`. The panels and the height are one relationship,
/// not two animations to keep in step — so this view animates nothing at all.
/// It is told a height, and it puts the panels exactly where that height says
/// they are.
///
/// The height belongs to the caller because it is a *row height*: the table has
/// to be told the row changed, and the rest of the page has to move with it.
/// `NissayaListViewController` steps it from a display link, which is how
/// `paperfold-for-ios` does it too — its fold is a function of a scroll offset,
/// not a `UIView` animation.
///
/// It was a `UIView` animation here first, with `beginUpdates`/`endUpdates`
/// inside the block to bring the table along and the panels reading the height
/// back off the presentation layer. It never animated: a constraint constant
/// changed inside an animation block only animates if a layout pass runs inside
/// that same block, and the table's own update machinery does its layout in a
/// transaction of its own. The completion came back `finished` in three
/// milliseconds and the row simply appeared at its full height. Driving it
/// directly is both shorter and impossible to get wrong that way.
final class NissayaFoldView: UIView {
  /// The sheet. Callers add their content to this and constrain it to fill.
  let content = UIView()

  /// Whether the paper is out and open. Only meaningful between folds.
  private(set) var isOpen = false

  /// What holds the sheet shut, and what is animated to open it.
  ///
  /// Exactly one of this and ``openHeight`` is ever active, and both are
  /// required. An earlier version had this one required and the sheet's open
  /// height optional, so that the two could both be installed and the stronger
  /// win — which quietly destroyed the content: an optional constraint is not
  /// *ignored* when it cannot be met, it is minimised, and at `defaultHigh` it
  /// tied with the label's compression resistance. The solver split the
  /// difference by squashing the label to nothing, and a 127-character meaning
  /// measured 30pt — its two margins with nothing between them. Sizing is a
  /// question with one answer at a time, so only one constraint gets to answer
  /// it.
  private lazy var clamp: NSLayoutConstraint = {
    heightAnchor.constraint(equalToConstant: NissayaFoldMetrics.shutHeight)
  }()

  /// What makes an open sheet as tall as what is on it. Active only when the
  /// fold is open and at rest, which is what lets the content resize the row
  /// when Dynamic Type changes under it.
  private lazy var openHeight: NSLayoutConstraint = {
    heightAnchor.constraint(equalTo: content.heightAnchor)
  }()

  /// The panels, top of the sheet first. All siblings, and deliberately so —
  /// see ``layoutPanels(atHeight:)``.
  private var panels: [CALayer] = []

  /// The light over each panel, in the same order: the wash and the gradient
  /// into its creases, as one gradient layer.
  private var facets: [CALayer] = []

  /// The hairline along each seam, in the same order. One shorter than
  /// ``panels`` — the top edge of the sheet is not a crease.
  private var creases: [CALayer] = []

  /// The sheet's height with nothing folded, measured when a fold is prepared.
  /// Read by whoever is driving the fold, to work out the height for a frame.
  private(set) var paperHeight: CGFloat = 0

  /// Where the fold in flight is going, or `nil` when none is.
  private var target: Bool?

  // MARK: - Life cycle

  override init(frame: CGRect) {
    super.init(frame: frame)

    // The sheet is cut off at whatever height the fold has got to. Square: this
    // is a stretch of the page, and a rounded corner would make it a card
    // arriving on top of one.
    layer.masksToBounds = true

    content.translatesAutoresizingMaskIntoConstraints = false
    addSubview(content)

    // Note what is *not* here: nothing ties the content's bottom to the sheet's.
    // The content is hung from the top and left to be as tall as it likes, and
    // the sheet is separately either as tall as the content (``openHeight``) or
    // as tall as the fold has got to (``clamp``). That is what keeps the text
    // out of the sizing argument — it is measured once, at its full height,
    // whatever the sheet in front of it is doing.
    NSLayoutConstraint.activate([
      content.topAnchor.constraint(equalTo: topAnchor),
      content.leadingAnchor.constraint(equalTo: leadingAnchor),
      content.trailingAnchor.constraint(equalTo: trailingAnchor),
      clamp
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// A sheet on its way out of the table — a row scrolled off, or a cell about
  /// to be handed to another row — is not folding any more.
  override func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)

    if newWindow == nil {
      finishFold()
    }
  }

  // MARK: - State

  /// Puts the sheet straight into a state, with nothing animating.
  ///
  /// What every cell gets on being configured: a row arriving already open —
  /// scrolled back to, or reconfigured for a change of type size — has no fold
  /// to play, and one arriving shut is about to be handed to ``prepareFold(to:)``.
  func apply(open: Bool) {
    finishFold()

    isOpen = open
    clamp.constant = NissayaFoldMetrics.shutHeight
    setHeight(open: open)
    content.isHidden = false
  }

  /// Hands the sheet's height to whichever constraint owns it in this state,
  /// one at a time so the two are never both installed.
  private func setHeight(open: Bool) {
    if open {
      clamp.isActive = false
      openHeight.isActive = true
    } else {
      openHeight.isActive = false
      clamp.isActive = true
    }
  }

  // MARK: - Folding

  /// Measures the sheet, renders it, and cuts it into panels ready to move.
  ///
  /// - Returns: whether there is a fold to run. `false` means the sheet could
  ///   not be measured — it is not on screen, or has nothing on it — and the
  ///   caller should put it straight into its state with ``apply(open:)``
  ///   rather than step a fold that has no paper in it.
  @discardableResult
  func prepareFold(to open: Bool) -> Bool {
    finishFold()

    layoutIfNeeded()
    paperHeight = content.bounds.height

    guard paperHeight > 0, bounds.width > 0 else { return false }

    target = open
    // The fold owns the height from here until it lands, in either direction.
    clamp.constant = open ? NissayaFoldMetrics.shutHeight : paperHeight
    setHeight(open: false)

    // A reader who has asked for less motion still gets the sheet's height —
    // that is the row opening, not decoration — but not the paper turning in
    // space. The content stays where it is and is simply uncovered.
    guard !UIAccessibility.isReduceMotionEnabled, let paper = renderPaper() else { return true }

    buildPanels(from: paper)
    // The real thing is hidden for as long as the image of it is on screen.
    content.isHidden = true
    layoutPanels(atHeight: clamp.constant)

    return true
  }

  /// Puts the sheet at a height, and the panels where that height says they
  /// are. One call per frame, from whoever is driving the fold.
  func setFoldHeight(_ height: CGFloat) {
    guard target != nil else { return }

    clamp.constant = height
    layoutPanels(atHeight: height)
  }

  /// Puts the paper away and the real content back. Safe to call at any time,
  /// including when no fold is in flight.
  func finishFold() {
    guard let target else { return }
    self.target = nil

    panels.forEach { $0.removeFromSuperlayer() }
    panels = []
    facets = []
    creases = []
    layer.sublayerTransform = CATransform3DIdentity

    content.isHidden = false
    isOpen = target
    clamp.constant = NissayaFoldMetrics.shutHeight
    // The content takes the height back on the way open, so that from here a
    // change of type size resizes the row without anyone having to measure
    // anything again.
    setHeight(open: target)
  }

  // MARK: - The paper

  /// The sheet as an image, rendered in this view's own appearance.
  ///
  /// `performAsCurrent` because every colour in the content is a dynamic one:
  /// rendered outside the trait collection they belong to, they would resolve
  /// against whatever was last made current — a light card folding open on a
  /// dark screen.
  private func renderPaper() -> UIImage? {
    let size = content.bounds.size
    guard size.width > 0, size.height > 0 else { return nil }

    let format = UIGraphicsImageRendererFormat.preferred()
    format.opaque = false

    var paper: UIImage?
    traitCollection.performAsCurrent {
      paper = UIGraphicsImageRenderer(size: size, format: format).image { context in
        content.layer.render(in: context.cgContext)
      }
    }

    return paper
  }

  /// Cuts the sheet up into panels, all of them siblings.
  ///
  /// One image, sliced by `contentsRect` rather than rendered once per panel:
  /// the panels are strips of the same picture, and asking for eight of them
  /// would be eight passes over the same text.
  private func buildPanels(from paper: UIImage) {
    let count = panelCount(for: paperHeight)
    let height = paperHeight / CGFloat(count)
    let width = bounds.width
    let slice = 1 / CGFloat(count)

    // The eye, on the container. Set here rather than on each panel because a
    // sublayer transform applies to the whole chain hanging off it, which is
    // exactly one perspective for the whole sheet.
    var eye = CATransform3DIdentity
    eye.m34 = -1 / NissayaFoldMetrics.perspective
    layer.sublayerTransform = eye

    for index in 0 ..< count {
      let panel = CALayer()
      // Hinged at its top edge: rotating about the X axis pivots there rather
      // than about the middle, which is what makes a panel hang off the one
      // above it instead of sliding through it.
      // Hinged at its top edge, and every panel starts life at the top of the
      // sheet: where it actually hangs is carried by its transform, which
      // ``layoutPanels(atHeight:)`` sets from the crease pattern.
      panel.anchorPoint = CGPoint(x: 0.5, y: 0)
      panel.bounds = CGRect(x: 0, y: 0, width: width, height: height)
      panel.position = CGPoint(x: width / 2, y: 0)
      panel.contents = paper.cgImage
      panel.contentsScale = paper.scale
      panel.contentsGravity = .resize
      panel.contentsRect = CGRect(
        x: 0,
        y: CGFloat(index) * slice,
        width: 1,
        height: slice
      )
      let leaningAway = index.isMultiple(of: 2)

      let facet = CAGradientLayer()
      facet.frame = panel.bounds
      facet.startPoint = CGPoint(x: 0.5, y: 0)
      facet.endPoint = CGPoint(x: 0.5, y: 1)
      facet.colors = Self.facetColors(leaningAway: leaningAway)
      // Clear in the middle, so a panel is only touched at the edges the light
      // is actually doing something to — see `facetColors(leaningAway:)`.
      facet.locations = [0, 0.5, 1]
      // Opacity is the whole of how much light is showing — see
      // `layoutPanels(atHeight:)`. Every stop scales with it together, which is
      // one property to set per frame instead of three colours to rebuild.
      facet.opacity = 0
      panel.addSublayer(facet)
      facets.append(facet)

      // Along the top edge, where this panel meets the one it hangs from. The
      // first panel has nothing above it to crease against.
      if index > 0 {
        let crease = CALayer()
        crease.frame = CGRect(
          x: 0,
          y: 0,
          width: width,
          height: NissayaFoldMetrics.creaseThickness
        )
        // Which way this seam folds is settled by the panel hanging off it. One
        // that leans away hangs from an edge the panel above it has just
        // brought *forward* — a ridge, which catches the light. One that leans
        // back hangs from an edge that has gone away — a valley, which takes
        // the ink.
        crease.backgroundColor = (leaningAway ? UIColor.white : UIColor.black)
          .withAlphaComponent(NissayaFoldMetrics.crease)
          .cgColor
        crease.opacity = 0
        panel.addSublayer(crease)
        creases.append(crease)
      }

      layer.addSublayer(panel)
      panels.append(panel)
    }
  }

  private func panelCount(for height: CGFloat) -> Int {
    let wanted = Int((height / NissayaFoldMetrics.panelHeight).rounded())
    // Up to the next even number — see ``NissayaFoldMetrics/minPanels``.
    let even = wanted + wanted % 2

    return min(max(even, NissayaFoldMetrics.minPanels), NissayaFoldMetrics.maxPanels)
  }

  /// The light down one panel: a highlight along the edge nearest the reader, a
  /// shadow along the edge furthest from them, and the panel's own wash in
  /// between.
  ///
  /// Three stops rather than two, and the middle one all but clear. A gradient
  /// running white to black passes through a muddy half-opaque grey on the way,
  /// which would put a band of fog across the middle of every panel; going out
  /// to nothing and back keeps the light at the creases, which is where it
  /// belongs.
  private static func facetColors(leaningAway: Bool) -> [CGColor] {
    let highlight = UIColor.white
      .withAlphaComponent(NissayaFoldMetrics.highlight)
      .cgColor
    let shadow = UIColor.black
      .withAlphaComponent(NissayaFoldMetrics.shadow)
      .cgColor
    // The panel's own facing: turned away from the light, or into it.
    let wash = (leaningAway ? UIColor.black : UIColor.white)
      .withAlphaComponent(NissayaFoldMetrics.facing)
      .cgColor

    // A panel leaning away goes back as it goes down: its top edge is the near
    // one and its bottom edge the far one, so it runs bright to dark. The panel
    // hanging off it comes forward again, and runs the other way.
    return leaningAway ? [highlight, wash, shadow] : [shadow, wash, highlight]
  }

  /// Puts every panel where a sheet of this height has to have them.
  ///
  /// `cos θ` is the share of a panel's height that survives being tilted, so
  /// the fraction of the paper on show *is* the cosine of the angle everything
  /// is turned by, and the angle is what is left to work out. Panels then
  /// alternate: the first tilts back, the next tilts forward, and so on down
  /// the sheet.
  ///
  /// Each panel is placed **absolutely** — walked down the crease pattern to
  /// its own hinge, in height *and in depth*, and rotated there. The obvious
  /// alternative is to hang each panel off the one above it as a sublayer and
  /// let the transforms compose, which is shorter to write and wrong to look
  /// at: Core Animation applies the perspective divide at every level it
  /// descends, so a panel four deep is foreshortened four times over. The sheet
  /// came out visibly crushed — the first panel near enough flat, the last a
  /// smear, the whole accordion falling well short of the bottom of its row.
  /// Siblings are divided by the perspective exactly once, which is what
  /// perspective means.
  ///
  /// This is also how `paperfold-for-ios` places the second half of each of its
  /// folds: a rotation concatenated with a translation, rather than a layer
  /// inside a layer.
  private func layoutPanels(atHeight height: CGFloat) {
    guard !panels.isEmpty, paperHeight > 0 else { return }

    let fraction = min(max(height / paperHeight, 0), 1)
    // The share of a panel's height that survives being tilted is `cos θ`, so
    // the fraction of the paper on show *is* the cosine of the angle everything
    // is turned by. (`paperfold-for-ios` writes the same thing as
    // `(π/2) - asin(fraction)`, measuring the rotation from shut rather than
    // from flat.)
    let angle = acos(fraction)
    // How much of the light is showing — and straight off the fraction rather
    // than off `sin θ`, which is the same choice the reference makes. The
    // trigonometric one holds the shading at nearly full strength until the
    // sheet is most of the way open and then drops it all at once; linear lets
    // the creases fade out as the paper flattens, which is what stops an open
    // meaning from looking faintly grubby.
    let light = Float(1 - fraction)

    // Every one of these is being set on a layer that is not animating on its
    // own account. Without this each would pick up Core Animation's implicit
    // quarter-second, and the fold would lag a quarter of a second behind the
    // row it is in.
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    let panelHeight = paperHeight / CGFloat(panels.count)
    // How far down the page one panel carries, and how far back into it.
    let drop = panelHeight * cos(angle)
    let depth = panelHeight * sin(angle)

    // Where the crease at the top of the panel being placed sits: down the page
    // and back from it. Both are in the sheet's own space, before the
    // perspective divide.
    var hinge: CGFloat = 0
    var back: CGFloat = 0

    for (index, panel) in panels.enumerated() {
      let leansAway = index.isMultiple(of: 2)

      var placement = CATransform3DMakeTranslation(0, hinge, back)
      placement = CATransform3DRotate(placement, leansAway ? -angle : angle, 1, 0, 0)
      panel.transform = placement

      facets[index].opacity = light

      // One crease short of a panel, and it is the first panel that hasn't one.
      if index > 0 {
        creases[index - 1].opacity = light
      }

      hinge += drop
      // Away from the reader under a panel that leans away, back towards them
      // under the next one — which is the zigzag, and which brings the last
      // crease of an even-numbered sheet back to `0`.
      back += leansAway ? -depth : depth
    }

    CATransaction.commit()
  }
}
#endif
