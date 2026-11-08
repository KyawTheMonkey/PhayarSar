#if os(iOS)
import UIKit

/// Restore after layout, with synchronous glyph positions, so following a
/// breadcrumb reveals the actual passage rather than an offscreen estimate.
/// The repeating selection cue changes drawing only: moving the text view itself
/// would move the handles and magnifier while someone was trying to use them.
final class BeadsPrayerTextView: UITextView {
  var selectionToRestore: NSRange?
  private(set) var isRestoringSelection = false
  var isSelectionAnimationEnabled = true {
    didSet {
      if isSelectionAnimationEnabled != oldValue {
        selectionDidChange(hasSelection: hasTextSelection)
      }
    }
  }

  private var hasTextSelection = false
  private var jiggleRange: NSRange?
  private var jiggleStartedAt: CFTimeInterval = 0
  private var jiggleDisplayLink: CADisplayLink?

  static func make() -> BeadsPrayerTextView {
    let storage = NSTextStorage()
    let manager = BeadsSelectionLayoutManager()
    let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    container.widthTracksTextView = true
    storage.addLayoutManager(manager)
    manager.addTextContainer(container)
    // Supplying the TextKit 1 stack preserves the synchronous range layout
    // used by breadcrumb restoration and lets just the chosen glyphs move.
    return BeadsPrayerTextView(frame: .zero, textContainer: container)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      setNeedsLayout()
      selectionDidChange(hasSelection: hasTextSelection)
    } else {
      stopSelectionJiggle()
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard window != nil, bounds.width > 0, bounds.height > 0,
          let range = selectionToRestore,
          range.location != NSNotFound, range.length > 0,
          NSMaxRange(range) <= attributedText.length
    else { return }
    selectionToRestore = nil
    isRestoringSelection = true
    defer { isRestoringSelection = false }
    becomeFirstResponder()
    selectedRange = range
    layoutManager.ensureLayout(for: textContainer)
    scrollRangeToVisible(NSRange(location: range.location, length: 1))
    if let start = position(from: beginningOfDocument, offset: range.location) {
      let rect = caretRect(for: start)
      let top = -adjustedContentInset.top
      let bottom = max(top, contentSize.height - bounds.height + adjustedContentInset.bottom)
      let y = min(max(rect.minY - adjustedContentInset.top - textContainerInset.top, top), bottom)
      setContentOffset(CGPoint(x: contentOffset.x, y: y), animated: false)
    }
    selectionDidChange(hasSelection: true)
  }

  func selectionDidChange(hasSelection: Bool) {
    hasTextSelection = hasSelection
    guard hasSelection, isSelectionAnimationEnabled, window != nil,
          !UIAccessibility.isReduceMotionEnabled, selectedRange.length > 0
    else {
      stopSelectionJiggle()
      return
    }
    // Keep one clock running while handles change the range. Only drawing
    // follows the new selection; text layout and handle positions stay fixed.
    if let previousRange = jiggleRange, previousRange != selectedRange,
       NSMaxRange(previousRange) <= textStorage.length {
      layoutManager.invalidateDisplay(forCharacterRange: previousRange)
    }
    jiggleRange = selectedRange
    guard jiggleDisplayLink == nil else { return }
    jiggleStartedAt = CACurrentMediaTime()
    let target = SelectionAnimationTarget(view: self)
    let link = CADisplayLink(target: target, selector: #selector(SelectionAnimationTarget.step(_:)))
    jiggleDisplayLink = link
    link.add(to: .main, forMode: .common)
  }

  fileprivate func stepSelectionJiggle(at time: CFTimeInterval) {
    let elapsed = time - jiggleStartedAt
    guard isSelectionAnimationEnabled, window != nil, let range = jiggleRange,
          selectedRange == range,
          !UIAccessibility.isReduceMotionEnabled,
          let manager = layoutManager as? BeadsSelectionLayoutManager
    else {
      stopSelectionJiggle()
      return
    }
    let phase = max(0, elapsed) / BeadsPrayerSelectionMetrics.selectedTextJigglePeriod * 2 * .pi
    manager.movingCharacters = range
    manager.angle = CGFloat(sin(phase))
      * BeadsPrayerSelectionMetrics.selectedTextJiggleAngle * .pi / 180
    manager.invalidateDisplay(forCharacterRange: range)
  }

  private func stopSelectionJiggle() {
    jiggleDisplayLink?.invalidate()
    jiggleDisplayLink = nil
    if let manager = layoutManager as? BeadsSelectionLayoutManager, let range = jiggleRange {
      manager.angle = 0
      manager.movingCharacters = nil
      if NSMaxRange(range) <= textStorage.length {
        manager.invalidateDisplay(forCharacterRange: range)
      }
    }
    jiggleRange = nil
  }
}

/// The run loop retains display links. A weak target lets the view disappear
/// even if navigation removes it before its normal window callback arrives.
@MainActor
private final class SelectionAnimationTarget: NSObject {
  weak var view: BeadsPrayerTextView?

  init(view: BeadsPrayerTextView) { self.view = view }

  @objc func step(_ link: CADisplayLink) {
    guard let view else {
      link.invalidate()
      return
    }
    view.stepSelectionJiggle(at: link.timestamp)
  }
}

/// Rotate the selected glyphs a line at a time. Native highlighting, handles,
/// hit testing and text storage remain unchanged; even a passage longer than
/// the viewport cannot swing the rest of the page around one distant pivot.
private final class BeadsSelectionLayoutManager: NSLayoutManager {
  var movingCharacters: NSRange?
  var angle: CGFloat = 0

  override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    guard angle != 0, let characters = movingCharacters,
          let context = UIGraphicsGetCurrentContext(), let container = textContainers.first
    else {
      super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
      return
    }
    let moving = NSIntersectionRange(
      glyphsToShow, glyphRange(forCharacterRange: characters, actualCharacterRange: nil)
    )
    guard moving.length > 0 else {
      super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
      return
    }
    if glyphsToShow.location < moving.location {
      super.drawGlyphs(forGlyphRange: NSRange(
        location: glyphsToShow.location, length: moving.location - glyphsToShow.location
      ), at: origin)
    }
    if NSMaxRange(moving) < NSMaxRange(glyphsToShow) {
      super.drawGlyphs(forGlyphRange: NSRange(
        location: NSMaxRange(moving), length: NSMaxRange(glyphsToShow) - NSMaxRange(moving)
      ), at: origin)
    }
    var cursor = moving.location
    while cursor < NSMaxRange(moving) {
      var line = NSRange()
      _ = lineFragmentUsedRect(forGlyphAt: cursor, effectiveRange: &line)
      let part = NSIntersectionRange(line, moving)
      guard part.length > 0 else { break }
      let rect = boundingRect(forGlyphRange: part, in: container).offsetBy(dx: origin.x, dy: origin.y)
      context.saveGState()
      context.translateBy(x: rect.midX, y: rect.midY)
      context.rotate(by: angle)
      context.translateBy(x: -rect.midX, y: -rect.midY)
      super.drawGlyphs(forGlyphRange: part, at: origin)
      context.restoreGState()
      cursor = NSMaxRange(part)
    }
  }
}
#endif
