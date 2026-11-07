#if canImport(UIKit)
import DesignKit
import SwiftUI
import UIKit

/// The creator's collection view: one meditation style per cell, swiped
/// through sideways.
///
/// A `UICollectionView` with a compositional layout rather than a SwiftUI
/// pager, because the cells are going to become real screens with their own
/// artwork and controls, and because the layout's orthogonal scrolling gives
/// paging, cell reuse and a per-frame scroll hook in one piece.
///
/// Wrapped for SwiftUI by ``MeditationSessionCreatorScreen``.
final class MeditationStyleCollectionViewController: UIViewController {

  // MARK: - Diffable types

  private enum Section: Hashable {
    case styles
  }

  private typealias DataSource = UICollectionViewDiffableDataSource<Section, MeditationStyle>
  private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, MeditationStyle>

  // MARK: - State

  private let styles: [MeditationStyle]

  private lazy var collectionView = makeCollectionView()
  private lazy var dataSource = makeDataSource()

  // MARK: - Life cycle

  init(styles: [MeditationStyle] = MeditationStyle.allCases) {
    self.styles = styles
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Clear all the way down, so the transparent sheet stays transparent: what
    // shows between two screens mid-swipe is the app behind the sheet, not a
    // surface of ours. See `MeditationSessionCreatorScreen`.
    view.backgroundColor = .clear

    collectionView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(collectionView)

    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    applySnapshot()
  }

  // MARK: - Collection view

  private func makeCollectionView() -> UICollectionView {
    let collectionView = UICollectionView(
      frame: .zero,
      collectionViewLayout: makeLayout()
    )
    collectionView.backgroundColor = .clear
    // The section scrolls orthogonally; the collection view itself has one row
    // and nothing to scroll vertically. Leaving its own scrolling on gives the
    // sheet a second gesture that does nothing but compete with the swipe to
    // dismiss it.
    collectionView.isScrollEnabled = false
    collectionView.register(
      MeditationStyleCell.self,
      forCellWithReuseIdentifier: MeditationStyleCell.reuseIdentifier
    )

    return collectionView
  }

  private func makeLayout() -> UICollectionViewLayout {
    UICollectionViewCompositionalLayout { _, _ in
      let item = NSCollectionLayoutItem(
        layoutSize: NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1),
          heightDimension: .fractionalHeight(1)
        )
      )

      let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1),
          heightDimension: .fractionalHeight(1)
        ),
        subitems: [item]
      )

      let section = NSCollectionLayoutSection(group: group)
      section.orthogonalScrollingBehavior = .groupPaging

      // No spacing and no insets, deliberately — not left at the default by
      // accident. The sheet has no background of its own, so any gap here is
      // not a margin but a hole: mid-swipe it shows a strip of the app between
      // one style and the next, and at the edges a band above and below. A
      // style is meant to be the whole surface, so the styles have to touch.

      return section
    }
  }

  private func makeDataSource() -> DataSource {
    DataSource(collectionView: collectionView) { collectionView, indexPath, style in
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: MeditationStyleCell.reuseIdentifier,
        for: indexPath
      )

      (cell as? MeditationStyleCell)?.configure(with: style)

      return cell
    }
  }

  private func applySnapshot() {
    var snapshot = Snapshot()
    snapshot.appendSections([.styles])
    snapshot.appendItems(styles, toSection: .styles)
    dataSource.apply(snapshot, animatingDifferences: false)
  }
}
#endif
