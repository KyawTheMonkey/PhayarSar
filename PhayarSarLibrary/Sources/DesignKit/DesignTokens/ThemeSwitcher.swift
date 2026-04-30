import SwiftUI

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
}

enum ThemeOverride {
  // nonisolated(unsafe): Swift 6 mutable global. Safe because all writes come
  // from ThemeSwitcher.switchTheme(to:) which is @MainActor.
  nonisolated(unsafe) static var current: Theme = .system
}

extension Color {
  static func dynamic(light: Color, dark: Color) -> Color {
    Color(UIColor { trait in
      switch ThemeOverride.current {
      case .light:   return UIColor(light)
      case .dark:    return UIColor(dark)
      case .system: return trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
      }
    })
  }
}
