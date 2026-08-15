import SwiftUI

// MARK: - Preference

/// Carries a scroll view's vertical content offset up the view tree.
///
/// Only one ``ScrollOffsetReader`` should report into a given scroll view, so
/// `reduce` deliberately keeps the first value rather than combining.
public struct ScrollOffsetKey: PreferenceKey {
  /// Computed rather than a stored `static var`: the package builds with
  /// swift-tools 6.2, where mutable static state trips concurrency checking.
  public static var defaultValue: CGFloat { 0 }

  public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    // No-op — see the type's doc comment.
  }
}

// MARK: - Reader

/// A zero-height probe that reports its own position inside a named coordinate
/// space, giving the enclosing scroll view's offset.
///
/// Place it as the **first** child of the scroll view's content, name the scroll
/// view's coordinate space to match, and read the value with
/// ``SwiftUI/View/onScrollOffsetChange(_:)``:
///
/// ```swift
/// ScrollView {
///   VStack(spacing: 0) {
///     ScrollOffsetReader(space: "home")
///     content
///   }
/// }
/// .coordinateSpace(name: "home")
/// .onScrollOffsetChange { offset = $0 }
/// ```
///
/// The reported value is `0` at rest, **negative** as the user scrolls up, and
/// **positive** while overscrolling past the top. Put it above any padding on
/// the content stack, or that padding becomes the resting value.
///
/// This is the iOS 16-compatible route. `onScrollGeometryChange` (iOS 18) and
/// `ScrollPosition` (iOS 17) would be simpler, but the app ships to iOS 16.
public struct ScrollOffsetReader: View {
  private let space: AnyHashable

  /// - Parameter space: Must match the `name` passed to `.coordinateSpace(name:)`
  ///   on the enclosing scroll view.
  public init(space: AnyHashable) {
    self.space = space
  }

  public var body: some View {
    GeometryReader { proxy in
      Color.clear
        .preference(
          key: ScrollOffsetKey.self,
          value: proxy.frame(in: .named(space)).minY
        )
    }
    .frame(height: 0)
  }
}

// MARK: - Observation

extension View {
  /// Receives the offset published by a ``ScrollOffsetReader`` further down the
  /// tree. Apply to the scroll view itself, alongside `.coordinateSpace(name:)`.
  public func onScrollOffsetChange(_ action: @escaping (CGFloat) -> Void) -> some View {
    onPreferenceChange(ScrollOffsetKey.self, perform: action)
  }
}
