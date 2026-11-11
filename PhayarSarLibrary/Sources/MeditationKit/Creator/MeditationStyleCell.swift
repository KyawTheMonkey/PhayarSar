#if canImport(UIKit)
import DesignKit
import LocalisationKit
// For the `UIColor(_: Color)` bridge — the design tokens are SwiftUI `Color`s.
import SwiftUI
import UIKit

enum MeditationStyleCellMetrics {
  /// Placeholder glyph size. Large enough to hold the middle of an otherwise
  /// empty screen — it is standing in for artwork, and artwork is what this
  /// screen will mostly be.
  static let symbolSize: CGFloat = 72

  /// Between the symbol and the text block.
  static let spacing: CGFloat = 20

  /// Title to summary, tighter than ``spacing`` so the two read as one block.
  static let textSpacing: CGFloat = 8

  /// Keeps the summary off the cell's edges. Generous because Burmese stacks
  /// diacritics above and below the line.
  static let horizontalInset: CGFloat = 32
}

/// One meditation style, as a whole screen of the creator's collection view.
///
/// Deliberately plain: a neutral canvas, a placeholder glyph, a title and a line
/// of summary, centred. Each style is getting its own artwork and its own
/// controls — see ``MeditationStyle`` — and this is the shape they will grow
/// into rather than a card they will replace.
final class MeditationStyleCell: UICollectionViewCell {
  static let reuseIdentifier = "MeditationStyleCell"

  private let symbolView = UIImageView()
  private let titleLabel = UILabel()
  private let summaryLabel = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setUpSubviews()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setUpSubviews() {
    contentView.backgroundColor = UIColor(AppColor.background)

    // Square, and no corner radius of its own. The sheet already clips its
    // content to the system's corner, so rounding here would round *inside*
    // that — and, worse, would leave a notch of the app showing where two
    // styles meet, even with no spacing between them. Letting the sheet do the
    // clipping also means the corner matches whatever the OS draws, which a
    // hand-set radius never quite does.
    symbolView.contentMode = .center
    symbolView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
      pointSize: MeditationStyleCellMetrics.symbolSize,
      weight: .light
    )
    symbolView.tintColor = UIColor(AppColor.textSecondary)

    titleLabel.numberOfLines = 0
    titleLabel.textAlignment = .center
    titleLabel.textColor = UIColor(AppColor.textPrimary)
    titleLabel.font = .preferredFont(forTextStyle: .title1)
    titleLabel.adjustsFontForContentSizeCategory = true

    summaryLabel.numberOfLines = 0
    summaryLabel.textAlignment = .center
    summaryLabel.textColor = UIColor(AppColor.textSecondary)
    summaryLabel.font = .preferredFont(forTextStyle: .subheadline)
    summaryLabel.adjustsFontForContentSizeCategory = true

    let textStack = UIStackView(arrangedSubviews: [titleLabel, summaryLabel])
    textStack.axis = .vertical
    textStack.spacing = MeditationStyleCellMetrics.textSpacing

    let stack = UIStackView(arrangedSubviews: [symbolView, textStack])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = MeditationStyleCellMetrics.spacing
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stack)

    // The field remains full bleed, but a vertical system bar can reserve
    // just one side of the cell. Centre and constrain the readable content
    // inside its own safe area so it follows that asymmetry while resizing.
    let safeArea = contentView.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      stack.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
      stack.leadingAnchor.constraint(
        equalTo: safeArea.leadingAnchor,
        constant: MeditationStyleCellMetrics.horizontalInset
      ),
      stack.trailingAnchor.constraint(
        equalTo: safeArea.trailingAnchor,
        constant: -MeditationStyleCellMetrics.horizontalInset
      ),
    ])
  }

  func configure(with style: MeditationStyle) {
    symbolView.image = UIImage(systemName: style.systemImage)
    titleLabel.text = style.title
    summaryLabel.text = style.summary
  }
}
#endif
