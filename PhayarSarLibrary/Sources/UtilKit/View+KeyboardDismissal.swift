import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
  /// Apply to the scroll container of an input screen, rather than individual
  /// fields. Native scrolling owns the interactive keyboard transition; the
  /// tap observer lets controls keep receiving their original touches.
  @ViewBuilder
  public func appKeyboardDismissal() -> some View {
    #if os(iOS)
    scrollDismissesKeyboard(.interactively)
      .modifier(KeyboardDismissalModifier())
    #else
    self
    #endif
  }
}

#if os(iOS)
private struct KeyboardDismissalModifier: ViewModifier {
  @State private var isVisible = false

  func body(content: Content) -> some View {
    content
      .background(KeyboardDismissalObserver(isActive: isVisible))
      .onAppear { isVisible = true }
      .onDisappear { isVisible = false }
  }
}

private struct KeyboardDismissalObserver: UIViewRepresentable {
  let isActive: Bool

  func makeUIView(context: Context) -> KeyboardDismissalView {
    let view = KeyboardDismissalView()
    view.isUserInteractionEnabled = false
    view.isAccessibilityElement = false
    view.isActive = isActive
    return view
  }

  func updateUIView(_ view: KeyboardDismissalView, context: Context) {
    view.isActive = isActive
  }

  static func dismantleUIView(_ view: KeyboardDismissalView, coordinator: ()) {
    view.detach()
  }
}

/// A SwiftUI parent tap gesture also sees taps inside its text fields and can
/// immediately undo their focus. Observe UIKit touches instead, excluding text
/// input descendants and allowing buttons and other gestures to proceed.
/// The window attachment observes sibling controls without adding a hit-test
/// overlay. Bounds and visibility keep it local to the visible input screen.
private final class KeyboardDismissalView: UIView, UIGestureRecognizerDelegate {
  var isActive = false
  private weak var observedWindow: UIWindow?
  private weak var responderToDismiss: UIView?
  private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))

  override func didMoveToWindow() {
    super.didMoveToWindow()
    detach()
    guard let window else { return }
    tap.cancelsTouchesInView = false
    tap.delaysTouchesBegan = false
    tap.delaysTouchesEnded = false
    tap.delegate = self
    window.addGestureRecognizer(tap)
    observedWindow = window
  }

  func detach() {
    observedWindow?.removeGestureRecognizer(tap)
    observedWindow = nil
    responderToDismiss = nil
  }

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    responderToDismiss = nil
    guard isActive, bounds.contains(touch.location(in: self)), let window else { return false }
    var touchedView = touch.view
    while let view = touchedView {
      // Includes field adornments and text-selection interactions. A read-only
      // text view also keeps its selection and contextual menu undisturbed.
      if view is UITextInput { return false }
      touchedView = view.superview
    }
    responderToDismiss = editableResponder(in: window)
    return responderToDismiss != nil
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    true
  }

  @objc private func dismissKeyboard() {
    // Capture the original responder at touch-down. A button can open a new
    // field during this same tap; ending editing on the whole window would
    // dismiss that newly focused field as well.
    responderToDismiss?.resignFirstResponder()
    responderToDismiss = nil
  }

  private func editableResponder(in view: UIView) -> UIView? {
    if view.isFirstResponder {
      if view is UITextField { return view }
      if let textView = view as? UITextView, textView.isEditable { return textView }
    }
    for child in view.subviews {
      if let responder = editableResponder(in: child) { return responder }
    }
    return nil
  }
}
#endif
