//
//  PositionObservingView.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 16/12/2023.
//

import SwiftUI
import SwiftUIIntrospect

struct PositionObservingView<Content: View>: View {
  var coordinateSpace: CoordinateSpace
  @Binding var position: CGPoint
  @ViewBuilder var content: () -> Content
  
  var body: some View {
    content()
      .background(GeometryReader { geometry in
        Color.clear.preference(
          key: PreferenceKey.self,
          value: geometry.frame(in: coordinateSpace).origin
        )
      })
      .onPreferenceChange(PreferenceKey.self) { position in
        self.position = position
      }
  }
}

private extension PositionObservingView {
  struct PreferenceKey: SwiftUI.PreferenceKey {
    static var defaultValue: CGPoint { .zero }
    
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
      // No-op
    }
  }
}

struct OffsetObservingScrollView<Content: View>: View {
  var axes: Axis.Set = [.vertical]
  var showsIndicators = true
  @Binding var offset: CGPoint
  @State private var scrollView: UIScrollView?
  @StateObject private var delegate = ScrollViewDelegate()
  @ViewBuilder var content: () -> Content
  var event: ((ScrollViewDelegateEvent) -> ())? = nil
  
  // The name of our coordinate space doesn't have to be
  // stable between view updates (it just needs to be
  // consistent within this view), so we'll simply use a
  // plain UUID for it:
  private let coordinateSpaceName = UUID()
  
  var body: some View {
    ScrollView(axes, showsIndicators: showsIndicators) {
      PositionObservingView(
        coordinateSpace: .named(coordinateSpaceName),
        position: Binding(
          get: { offset },
          set: { newOffset in
            offset = CGPoint(
              x: -newOffset.x,
              y: -newOffset.y
            )
          }
        ),
        content: content
      )
    }
    .introspect(.scrollView, on: .iOS(.v15, .v16, .v17, .v18)) { s in
      if scrollView == nil {
        scrollView = s
        scrollView?.delegate = delegate
      }
    }
    .onReceive(delegate.$event) { event in
      self.event?(event)
    }
    .coordinateSpace(name: coordinateSpaceName)
  }
}

enum ScrollViewDelegateEvent {
  case idle
  case willBeginDragging(UIScrollView)
  case didScroll(UIScrollView)
  case didEndDecelerating(UIScrollView)
  case didEndDragging(UIScrollView, Bool)
}

fileprivate final class ScrollViewDelegate: NSObject, ObservableObject, UIScrollViewDelegate {
  @Published var event: ScrollViewDelegateEvent = .idle
  
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    event = .willBeginDragging(scrollView)
  }
  
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    event = .didScroll(scrollView)
  }
  
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    event = .didEndDecelerating(scrollView)
  }
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    event = .didEndDragging(scrollView, decelerate)
  }
}
