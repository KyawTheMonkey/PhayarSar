#if canImport(UIKit)
import DesignKit
// For the `UIColor(_: Color)` bridge — the design tokens are SwiftUI `Color`s.
import SwiftUI
import UIKit

/// A stretch of the page: paper edge to edge, with a rule closing it.
///
/// Every row on this screen is one of these, and they are all the same colour,
/// so the seams between them do not show. What the reader sees is a single
/// continuous sheet ruled into verses — which is what the fold needs it to be.
/// A meaning cannot unfold out of a *card*: paper that opens out of a gap
/// between two floating panels reads as a drawer sliding, not as a sheet being
/// unfolded.
///
/// Two fills for the paper, not one. `AppColor.surface` is a translucent panel
/// colour meant to be layered over the canvas, and here the canvas has to be
/// painted underneath rather than borrowed from behind — the fold renders this
/// view into an image, away from whatever it happens to be sitting on.
final class NissayaPageView: UIView {
  /// Where a row's content goes. Laid out against
  /// `content.layoutMarginsGuide`, so set `content.directionalLayoutMargins` to
  /// the padding wanted around the text.
  let content = UIView()

  /// The rule closing the row. Full width, like a ruled page — an inset rule
  /// would draw the eye to where each row starts and stops, which is exactly
  /// what a continuous sheet is trying not to have.
  private let rule = UIView()

  /// Whether the row is closed off by a rule. The last row on the page has
  /// nothing under it to be separated from.
  var showsRule: Bool {
    get { !rule.isHidden }
    set { rule.isHidden = !newValue }
  }

  private let tint = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)

    backgroundColor = UIColor(AppColor.background)

    // One paper for every row, verses and meanings alike. The verses were
    // briefly set on a greyer one, and it worked against the fold: two papers
    // make a meaning a panel that arrives on top of the page rather than a
    // stretch of the page itself, which is the whole thing the fold is saying.
    tint.backgroundColor = UIColor(AppColor.surface)
    tint.isUserInteractionEnabled = false
    tint.translatesAutoresizingMaskIntoConstraints = false
    addSubview(tint)

    content.translatesAutoresizingMaskIntoConstraints = false
    addSubview(content)

    rule.backgroundColor = UIColor(AppColor.divider)
    rule.translatesAutoresizingMaskIntoConstraints = false
    addSubview(rule)

    NSLayoutConstraint.activate([
      tint.topAnchor.constraint(equalTo: topAnchor),
      tint.leadingAnchor.constraint(equalTo: leadingAnchor),
      tint.trailingAnchor.constraint(equalTo: trailingAnchor),
      tint.bottomAnchor.constraint(equalTo: bottomAnchor),

      content.topAnchor.constraint(equalTo: topAnchor),
      content.leadingAnchor.constraint(equalTo: leadingAnchor),
      content.trailingAnchor.constraint(equalTo: trailingAnchor),
      content.bottomAnchor.constraint(equalTo: bottomAnchor),

      rule.leadingAnchor.constraint(equalTo: leadingAnchor),
      rule.trailingAnchor.constraint(equalTo: trailingAnchor),
      rule.bottomAnchor.constraint(equalTo: bottomAnchor),
      rule.heightAnchor.constraint(equalToConstant: NissayaListMetrics.hairline)
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Constrains a row's content to the page's text column: the full width it is
  /// given, up to the point where the measure stops being readable, centred in
  /// whatever is left over.
  func column(for view: UIView) -> [NSLayoutConstraint] {
    let margins = content.layoutMarginsGuide

    // `defaultHigh` on the full width, so the cap can win on an iPad without
    // either constraint having to know about the other.
    let width = view.widthAnchor.constraint(equalTo: margins.widthAnchor)
    width.priority = .defaultHigh

    return [
      view.topAnchor.constraint(equalTo: margins.topAnchor),
      view.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
      view.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
      view.leadingAnchor.constraint(greaterThanOrEqualTo: margins.leadingAnchor),
      view.widthAnchor.constraint(
        lessThanOrEqualToConstant: NissayaListMetrics.maxTextWidth
      ),
      width
    ]
  }
}
#endif
