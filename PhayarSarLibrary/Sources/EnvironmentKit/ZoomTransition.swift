import LocalisationKit
import SwiftUI

// MARK: - Namespace

private struct ZoomNamespaceKey: EnvironmentKey {
  static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
  /// The namespace that pairs a zoom transition's source with its destination.
  ///
  /// It has to be one namespace seen by both ends, and the two ends are built
  /// in different places: the source inside a feature screen, the destination
  /// inside the app target's `navigationDestination`, reached through
  /// `AppNavigatorModel` rather than a `NavigationLink`. A route cannot carry
  /// it — `RouterDestination` is `Codable` and a `Namespace.ID` is not — so
  /// the app declares one above its navigation stacks and passes it down here.
  ///
  /// `nil` wherever nobody has provided one (previews, sheets with their own
  /// stack); the modifiers below then do nothing and the push is a plain one.
  public var zoomNamespace: Namespace.ID? {
    get { self[ZoomNamespaceKey.self] }
    set { self[ZoomNamespaceKey.self] = newValue }
  }
}

// MARK: - Modifiers

extension View {
  /// Marks this view as where a zoom transition grows from and shrinks back to.
  ///
  /// Pair it with ``appZoomDestination(id:)`` on the pushed screen, using the
  /// same `id` — normally the id the route already carries. `cornerRadius`
  /// should match the view's own shape so the zoom starts from its outline
  /// instead of from its square bounding box.
  ///
  /// iOS 18 and later only. Earlier systems, and other platforms, get the
  /// ordinary push with no extra work at the call site.
  public func appZoomSource(id: some Hashable, cornerRadius: CGFloat = 0) -> some View {
    modifier(ZoomSource(id: AnyHashable(id), cornerRadius: cornerRadius))
  }

  /// Makes this pushed screen arrive by zooming out of the matching
  /// ``appZoomSource(id:cornerRadius:)``. The navigation bar is hidden and a
  /// close button is drawn inside the screen instead, so it travels with it. Pass `nil` to opt a particular push
  /// out — a screen reachable from several places usually only has a source
  /// to zoom from in one of them.
  ///
  /// `pull` is how far the screen's content has been dragged down past its
  /// resting position — see ``appZoomPullTracking(_:)``. The close button
  /// rides down with the content by that amount and fades as it goes, so a
  /// pull moves the whole screen as one piece instead of sliding the list out
  /// from under a button that stays behind.
  public func appZoomDestination(id: (some Hashable)?, pull: CGFloat = 0) -> some View {
    modifier(ZoomDestination(id: id.map { AnyHashable($0) }, pull: pull))
  }

  /// Reports how far a `ScrollView` is pulled down past its top, for
  /// ``appZoomDestination(id:pull:)``. Apply it to the scroll view itself.
  /// Writes nothing before iOS 18, where there is no zoom to coordinate with.
  public func appZoomPullTracking(_ pull: Binding<CGFloat>) -> some View {
    modifier(ZoomPullTracking(pull: pull))
  }
}

private struct ZoomSource: ViewModifier {
  @Environment(\.zoomNamespace) private var namespace
  let id: AnyHashable
  let cornerRadius: CGFloat

  func body(content: Content) -> some View {
    #if os(iOS)
    if #available(iOS 18.0, *), let namespace {
      content.matchedTransitionSource(id: id, in: namespace) { source in
        source.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      }
    } else {
      content
    }
    #else
    content
    #endif
  }
}

private struct ZoomDestination: ViewModifier {
  @Environment(\.zoomNamespace) private var namespace
  @Environment(\.dismiss) private var dismiss
  let id: AnyHashable?
  let pull: CGFloat

  func body(content: Content) -> some View {
    #if os(iOS)
    if #available(iOS 18.0, *), let namespace, let id {
      content
        // The close button is part of the screen, not of the navigation bar.
        // The bar belongs to the stack and stays where it is while a zoomed
        // screen is dragged down and shrinks, so a button in it was left
        // hanging at the top of the display with nothing under it. Inside the
        // content it moves, scales and disappears with the screen it closes.
        .safeAreaInset(edge: .top, spacing: 0) {
          HStack {
            ZoomCloseButton { dismiss() }
              .offset(y: pull)
              .opacity(max(0, 1 - pull / ZoomCloseMetrics.fadeDistance))
            Spacer(minLength: 0)
          }
          .padding(.horizontal, ZoomCloseMetrics.horizontalInset)
          .padding(.bottom, ZoomCloseMetrics.bottomSpacing)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationTransition(.zoom(sourceID: id, in: namespace))
    } else {
      content
    }
    #else
    content
    #endif
  }
}

// MARK: - Close button

private enum ZoomCloseMetrics {
  static let size: CGFloat = 44
  /// Matches the navigation bar button it replaces, which sits 16pt in.
  static let horizontalInset: CGFloat = 16
  static let bottomSpacing: CGFloat = 8
  /// Pull distance over which the button fades to nothing. Short, so it is
  /// gone before the pull is far enough to read as a dismissal.
  static let fadeDistance: CGFloat = 90
}

private struct ZoomPullTracking: ViewModifier {
  @Binding var pull: CGFloat

  func body(content: Content) -> some View {
    #if os(iOS)
    if #available(iOS 18.0, *) {
      content.onScrollGeometryChange(for: CGFloat.self) { geometry in
        // Resting offset is `-contentInsets.top`; anything above that is the
        // rubber-band stretch of a pull down.
        max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
      } action: { _, newValue in
        pull = newValue
      }
    } else {
      content
    }
    #else
    content
    #endif
  }
}

#if os(iOS)
/// A cross rather than a chevron: a zoomed screen opened *out of* something
/// instead of sliding in from the side, so it closes rather than goes back.
///
/// Drawn with system materials and `.primary` because EnvironmentKit sits
/// below DesignKit and cannot reach `AppColor`. `dismiss` pops through the
/// stack's path binding, so `AppNavigatorModel` stays in step.
@available(iOS 18.0, *)
private struct ZoomCloseButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.primary)
        .frame(width: ZoomCloseMetrics.size, height: ZoomCloseMetrics.size)
        .modifier(ZoomCloseSurface())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L10n.close)
  }
}

@available(iOS 18.0, *)
private struct ZoomCloseSurface: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular.interactive(), in: .circle)
    } else {
      content.background(.ultraThinMaterial, in: Circle())
    }
  }
}
#endif
