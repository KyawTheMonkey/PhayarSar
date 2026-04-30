import Foundation
import SwiftUI

/// Language enum for supported languages
public enum Language: String, CaseIterable, Sendable {
  case english = "En"
  case myanmar = "Mm"
    
  public var displayName: String {
    switch self {
    case .english: return "English"
    case .myanmar: return "မြန်မာ"
    }
  }
}

/// Localization Manager handles language switching and string retrieval with multi-argument support
public final class LocalisationManager: ObservableObject, @unchecked Sendable {
  public static let shared = LocalisationManager()
    
  @Published public var currentLanguage: Language {
    didSet {
      UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
    }
  }
    
  private var stringsCache: [String: [String: String]] = [:]
  private let cacheQueue = DispatchQueue(label: "com.phayarsar.localisation.cache")
    
  init() {
    let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? Language.english.rawValue
    self.currentLanguage = Language(rawValue: savedLanguage) ?? .english
    loadStrings()
  }
  
  /// Set the current language and update the UI
  @MainActor
  public func setLanguage(_ language: Language) {
    currentLanguage = language
  }
  
  /// Get a localized string for the current language with optional multi-argument interpolation
  /// - Parameters:
  ///   - key: The localization key
  ///   - args: Optional array of arguments for placeholder replacement
  /// - Returns: The localized string with placeholders replaced by arguments, or key if not found
  public func getString(key: String, args: [String] = []) -> String {
    var result = cacheQueue.sync {
      stringsCache[key]?[currentLanguage.rawValue] ?? ""
    }
    
    // If string not found, return key as fallback
    if result.isEmpty {
      print("⚠️ Localisation: Key '\(key)' not found for language '\(currentLanguage.rawValue)'")
      return key
    }
    
    // Replace placeholders {0}, {1}, {2}, etc. with arguments
    if !args.isEmpty {
      for (index, argument) in args.enumerated() {
        result = result.replacingOccurrences(of: "{\(index)}", with: argument)
      }
    }
    
    return result
  }
    
  /// Load strings from the JSON resource
  private func loadStrings() {
    guard let url = Bundle.module.url(forResource: "strings", withExtension: "json") else {
      print("❌ Localisation: strings.json not found in bundle")
      return
    }
        
    do {
      let data = try Data(contentsOf: url)
      if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
        let typed = jsonObject as? [String: [String: String]] ?? [:]
        cacheQueue.async(flags: .barrier) { [typed] in
          self.stringsCache = typed
        }
      }
    } catch {
      print("❌ Localisation: Failed to load strings.json - \(error.localizedDescription)")
    }
  }
}
