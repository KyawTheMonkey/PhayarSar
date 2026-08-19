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

/// Soft top-to-bottom glow used as the screen background. Pairs with
/// translucent .appSurface cards (see `GlassCard`) for depth instead of
/// a flat fill. Adapts automatically to light/dark mode.
public struct AppBackgroundGradient: View {
  @Environment(\.colorScheme) private var colorScheme
  
  public init() {}
  
  public var body: some View {
    LinearGradient(colors: [AppColor.primarySoft, AppColor.background], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.48))
      .ignoresSafeArea()
  }
}

extension View {
  /// Applies the app's calm gradient background behind this view.
  public func appBackground() -> some View {
    self.background(AppBackgroundGradient())
  }
}

