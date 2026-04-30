import SwiftUI

struct LanguageKey: EnvironmentKey {
  static let defaultValue: Language = .english
}

public extension EnvironmentValues {
  var language: Language {
    get { self[LanguageKey.self] }
    set { self[LanguageKey.self] = newValue }
  }
}
