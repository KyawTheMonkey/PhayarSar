#if os(iOS)
import AudioToolbox
#endif
import SwiftUI

extension View {
  public func hideNavBar() -> some View {
    modifier(HideNavBar())
  }
}

private struct HideNavBar: ViewModifier {
  func body(content: Content) -> some View {
    // `ToolbarPlacement.navigationBar` doesn't exist on macOS — there's no
    // navigation bar to hide there — and the watch's navigation chrome is not
    // the screen's to hide. A no-op on both.
    #if os(iOS)
    if #available(iOS 18.0, *) {
      content.toolbarVisibility(.hidden, for: .navigationBar)
    } else {
      // Fallback on earlier versions
      content.navigationBarHidden(true)
    }
    #else
    content
    #endif
  }
}

extension View {
  /// Hides the tab bar for as long as this screen is on screen.
  ///
  /// Apply it to a *pushed* screen, not to a tab's root: the visibility belongs
  /// to the view, so the bar comes back on its own when the screen pops. Toggling
  /// a flag on the tab container instead would leave the bar hidden if the user
  /// swiped back mid-gesture and the pop never completed.
  ///
  /// ```swift
  /// var body: some View {
  ///   Content()
  ///     .hideTabBar()
  /// }
  /// ```
  ///
  /// Inert wherever there is no tab bar — macOS, and the iPad/Mac split view
  /// layout, which puts pushed screens in the detail column.
  ///
  /// - Parameter hidden: Pass `false` to keep the bar, for a screen that hides
  ///   it only in some states.
  public func hideTabBar(_ hidden: Bool = true) -> some View {
    modifier(HideTabBar(hidden: hidden))
  }
}

private struct HideTabBar: ViewModifier {
  let hidden: Bool

  func body(content: Content) -> some View {
    // `ToolbarPlacement.tabBar` is unavailable on macOS, where the sidebar
    // stands in for the tab bar and is not the pushed screen's business, and on
    // watchOS, which has no tab bar at all.
    #if os(iOS)
    if #available(iOS 18.0, *) {
      content.toolbarVisibility(hidden ? .hidden : .visible, for: .tabBar)
    } else {
      content.toolbar(hidden ? .hidden : .visible, for: .tabBar)
    }
    #else
    content
    #endif
  }
}

// MARK: - Haptics

extension View {
  /// Ticks the selection haptic whenever `trigger` changes.
  ///
  /// A shim, because `sensoryFeedback` is iOS 17 and the package ships to 16 —
  /// below that this is the view unchanged, and the change happens silently.
  ///
  /// Apply it to whatever *owns* the selection rather than to each control that
  /// can change it: a value that a drag, a button and a keyboard shortcut can all
  /// move should tick once from one place, not once per route into it.
  @ViewBuilder
  public func appSelectionFeedback(trigger: some Equatable) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      sensoryFeedback(.selection, trigger: trigger)
    } else {
      self
    }
  }

  /// A tap when a gesture crosses the point past which letting go does
  /// something, and a lighter one when it falls back inside.
  ///
  /// The cue a threshold needs is *arrival*, not arrangement: a reader dragging
  /// something towards a limit cannot see where the limit is, so the only way
  /// they learn they have reached it is to be told. Weighted differently in each
  /// direction because the two mean opposite things — one commits, one takes it
  /// back — and a threshold that ticked identically both ways would say only
  /// "something changed".
  ///
  /// A shim, like the tick above: `sensoryFeedback` is iOS 17 and the package
  /// ships to 16, so below that the crossing happens silently.
  @ViewBuilder
  public func appThresholdFeedback(armed: Bool) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      sensoryFeedback(trigger: armed) { _, isArmed in
        isArmed
          ? .impact(weight: .medium, intensity: 0.9)
          : .impact(weight: .light, intensity: 0.5)
      }
    } else {
      self
    }
  }
}

/// Constants for the selection tick.
public enum AppSelectionSound {
  /// The system's keyboard click — the shortest, driest tick iOS exposes, and
  /// the one already in every reader's ear as "a thing moved by one".
  ///
  /// iOS gives no public id for the picker wheel's own detent, which would be
  /// the closer match; this is the conventional stand-in for it.
  /// A plain `UInt32`, not `SystemSoundID`: that typealias comes from
  /// AudioToolbox, which is only imported on the platform that can play it.
  public static let tick: UInt32 = 1104

  /// Nothing plays sooner than this after the last one.
  ///
  /// A detent crossed every fifteen milliseconds is what a fast scrub actually
  /// produces, and firing a system sound that often is neither audible as
  /// separate ticks nor pleasant as a tone. Capped at about eighteen a second,
  /// a fast run reads as a drumroll thinning out as it slows — which is what a
  /// physical detent does.
  public static let minimumInterval: TimeInterval = 0.055
}

extension View {
  /// Ticks the system click whenever `trigger` changes.
  ///
  /// Meant to sit alongside ``appSelectionFeedback(trigger:)`` on the same
  /// value, not to replace it: the haptic is the part that works in a pocket,
  /// in silent mode, and for anyone who reads with the volume down. The sound
  /// is the confirmation on top, and everything still has to work without it.
  ///
  /// Rate-limited — see ``AppSelectionSound/minimumInterval``. iOS only:
  /// `AudioServicesPlaySystemSound`'s ids are a different set on the Mac, and
  /// none of them is this.
  public func appSelectionSound(trigger: some Equatable) -> some View {
    modifier(AppSelectionSoundModifier(trigger: trigger))
  }
}

private struct AppSelectionSoundModifier<Trigger: Equatable>: ViewModifier {
  let trigger: Trigger

  /// Held per-view rather than globally: two controls ticking at once should
  /// not silence each other.
  @State private var lastPlayed = Date.distantPast

  func body(content: Content) -> some View {
    // `onChange(of:perform:)` is deprecated from iOS 17, and the replacement
    // does not exist before it.
    if #available(iOS 17.0, macOS 14.0, *) {
      content.onChange(of: trigger) { _, _ in play() }
    } else {
      content.onChange(of: trigger) { _ in play() }
    }
  }

  private func play() {
    #if os(iOS)
    let now = Date()
    guard now.timeIntervalSince(lastPlayed) >= AppSelectionSound.minimumInterval else { return }

    lastPlayed = now
    AudioServicesPlaySystemSound(AppSelectionSound.tick)
    #endif
  }
}

// MARK: - Glass Effect
extension View {
  public func toolBarButtonCircularGlass() -> some View {
    modifier(ToolBarButtonCircularGlass())
  }
}


private struct ToolBarButtonCircularGlass: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
      content.glassEffect(.clear.interactive(), in: .circle)
    } else {
      content
        .background {
          Circle()
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.1), radius: 0.1, x: 0, y: 0)
        }
    }
  }
}

extension View {
  /// Liquid Glass on iOS/macOS 26+, `.regularMaterial` below, clipped to a capsule.
  ///
  /// - Parameter interactive: Whether the glass reacts to touch on 26+. Has no
  ///   effect on the material fallback, which can't animate under the finger.
  public func capsuleGlass(interactive: Bool = true) -> some View {
    modifier(CapsuleGlass(interactive: interactive))
  }
}

private struct CapsuleGlass: ViewModifier {
  let interactive: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
      content.glassEffect(interactive ? .regular.interactive() : .regular, in: .capsule)
    } else {
      content
        .background {
          Capsule(style: .continuous)
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
        }
    }
  }
}
