import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
public final class ThemeSwitcher: ObservableObject, @unchecked Sendable {
  public static let shared = ThemeSwitcher()
  
  private static let defaultsKey = "appTheme"
  
  @Published public private(set) var currentTheme: Theme {
    didSet { ThemeOverride.current = currentTheme }
  }
  
  private init() {
    let saved = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? ""
    let resolved = Theme(rawValue: saved) ?? .system
    self.currentTheme = resolved
    ThemeOverride.current = resolved
  }
  
  public func switchTheme(to theme: Theme) {
    currentTheme = theme
    UserDefaults.standard.set(theme.rawValue, forKey: Self.defaultsKey)
  }
}

public enum Theme: String, CaseIterable, Identifiable, Sendable {
  case system // follow UITraits
  case light
  case dark
  
  public var id: String { rawValue }
  
  public var colorScheme: ColorScheme? {
    switch self {
    case .light:
      return .light
    case .dark:
      return .dark
    case .system:
      return nil
    }
  }
}

enum ThemeOverride {
  // nonisolated(unsafe): Swift 6 mutable global. Safe because all writes come
  // from ThemeSwitcher.switchTheme(to:) which is @MainActor.
  nonisolated(unsafe) static var current: Theme = .system
}

extension Color {
  static func dynamic(light: Color, dark: Color) -> Color {
    #if os(watchOS)
    // The watch has no light appearance to resolve against, and no
    // `UIColor(dynamicProvider:)` to resolve it with. Every token is its dark
    // half, which is not a fallback but the right answer: the dark ramp is what
    // the app's colours were tuned to look like against black.
    dark
    #elseif canImport(UIKit)
    Color(UIColor { trait in
      switch ThemeOverride.current {
      case .light:   return UIColor(light)
      case .dark:    return UIColor(dark)
      case .system: return trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
      }
    })
    #else
    Color(NSColor(name: nil) { appearance in
      switch ThemeOverride.current {
      case .light:   return NSColor(light)
      case .dark:    return NSColor(dark)
      case .system:
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? NSColor(dark) : NSColor(light)
      }
    })
    #endif
  }
}

// MARK: - Screen background gradient

public enum AppBackgroundGradientMetrics {
  public static let glowCenter = UnitPoint(x: 0.5, y: 0.08)
  public static let glowHeightFraction: CGFloat = 0.38
  public static let glowEndRadiusFraction: CGFloat = 0.68
  public static let orbitRadiusFraction: CGFloat = 0.22
  public static let orbitDuration: TimeInterval = 24
  public static let entranceDuration: TimeInterval = 2
  public static let frameInterval: TimeInterval = 1.0 / 30
}

/// Draw the tab glow in a shallow band so it can spread across the header and
/// finish fading before it reaches the content below.
public struct AppBackgroundGradient: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var isVisible = false
  @State private var elapsedBeforePause: TimeInterval = 0
  @State private var resumedAt: Date?

  public init() {}

  private var shouldAnimate: Bool {
    isVisible && scenePhase == .active && !reduceMotion
  }
  
  public var body: some View {
    GeometryReader { proxy in
      let glowSize = CGSize(
        width: proxy.size.width,
        height: proxy.size.height * AppBackgroundGradientMetrics.glowHeightFraction
      )
      TimelineView(.animation(
        minimumInterval: AppBackgroundGradientMetrics.frameInterval,
        paused: !shouldAnimate
      )) { context in
        EllipticalGradient(
          colors: [AppColor.tabBackgroundGlow, AppColor.background],
          center: glowCenter(at: context.date, size: glowSize),
          endRadiusFraction: AppBackgroundGradientMetrics.glowEndRadiusFraction
        )
      }
      .frame(width: glowSize.width, height: glowSize.height)
    }
    .background(AppColor.background)
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onAppear { isVisible = true }
    .onDisappear {
      isVisible = false
      updateClock(isRunning: false)
    }
    .onChange(of: shouldAnimate) { updateClock(isRunning: $0) }
  }

  /// Start at the resting centre and ease outward into the orbit. Using elapsed
  /// visible time avoids jumping to a wall-clock position on first appearance,
  /// and pausing the clock keeps returning tabs at the position they left.
  private func glowCenter(at date: Date, size: CGSize) -> UnitPoint {
    let center = AppBackgroundGradientMetrics.glowCenter
    guard size.width > 0, size.height > 0 else { return center }
    let runningTime = resumedAt.map { max(date.timeIntervalSince($0), 0) } ?? 0
    let elapsed = elapsedBeforePause + runningTime
    let phase = elapsed
      .truncatingRemainder(dividingBy: AppBackgroundGradientMetrics.orbitDuration)
      / AppBackgroundGradientMetrics.orbitDuration * 2 * .pi
    let entrance = min(elapsed / AppBackgroundGradientMetrics.entranceDuration, 1)
    let easedEntrance = entrance * entrance * (3 - 2 * entrance)
    // Normalise by each dimension so the orbit stays circular on wide windows.
    let radius = min(size.width, size.height)
      * AppBackgroundGradientMetrics.orbitRadiusFraction * easedEntrance
    return UnitPoint(
      x: center.x + cos(phase) * radius / size.width,
      y: center.y + sin(phase) * radius / size.height
    )
  }

  private func updateClock(isRunning: Bool) {
    if isRunning {
      if resumedAt == nil { resumedAt = .now }
    } else if let resumedAt {
      elapsedBeforePause += Date.now.timeIntervalSince(resumedAt)
      self.resumedAt = nil
    }
  }
}

extension View {
  /// Applies the neutral canvas behind a screen, including its safe areas.
  public func appBackground() -> some View {
    background(AppColor.background.ignoresSafeArea())
  }

  /// Applies the brand gradient behind the root screen of a tab.
  public func appTabBackground() -> some View {
    background(AppBackgroundGradient())
  }
}

