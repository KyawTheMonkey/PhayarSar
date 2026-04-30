import Foundation

// MARK: - Main Entry Point

func main() {
  let arguments = CommandLine.arguments
    
  guard arguments.count >= 4 else {
    print("Usage: LocalisationKitCodeGen <input.json> <output.swift> <output_dir>")
    exit(1)
  }
    
  let inputPath = arguments[1]
  let outputPath = arguments[2]
  let outputDir = arguments[3]
    
  do {
    // Create output directory if it doesn't exist
    try FileManager.default.createDirectory(
      atPath: outputDir,
      withIntermediateDirectories: true,
      attributes: nil
    )
        
    // Read and parse JSON
    let jsonData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
    guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: [String: String]] else {
      print("Error: Invalid JSON structure")
      exit(1)
    }
        
    // Generate Swift code
    let swiftCode = generateStringsEnum(from: jsonObject)
        
    // Write to output file
    try swiftCode.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("✅ Generated Strings enum at: \(outputPath)")
        
  } catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
  }
}

// MARK: - Identifier Utilities

func makeLowerCamelIdentifier(from raw: String) -> String {
  // Split on any non-alphanumeric characters
  let parts = raw.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
  guard !parts.isEmpty else { return "" }

  // Build lowerCamelCase
  let head = parts.first!.lowercased()
  let tail = parts.dropFirst().map { part in
    let s = String(part).lowercased()
    return s.prefix(1).uppercased() + s.dropFirst()
  }
  var candidate = ([head] + tail).joined()

  // Remove any remaining invalid characters (just in case)
  candidate = candidate.filter { $0.isLetter || $0.isNumber || $0 == "_" }

  // Ensure it doesn't start with a number
  if let first = candidate.first, first.isNumber {
    candidate = "_" + candidate
  }

  // Avoid empty identifier
  return candidate.isEmpty ? "_" : candidate
}

// MARK: - Code Generation

func generateStringsEnum(from jsonData: [String: [String: String]]) -> String {
  var code = """
  // MARK: - Auto-generated L10n Enum
  // This file is auto-generated from strings.json. DO NOT EDIT manually.
  // Regenerate by building the LocalisationKit target.
  
  import Foundation
  
  public enum L10n {
      // Argument wrapper that supports EN/MM values and string literal default (EN)
      public struct Arg: ExpressibleByStringLiteral {
          public let en: String
          public let mm: String?
  
          public init(stringLiteral value: String) {
              self.en = value
              self.mm = nil
          }
  
          public init(en: String, mm: String) {
              self.en = en
              self.mm = mm
          }
  
          public static func both(en: String, mm: String) -> Arg {
              Arg(en: en, mm: mm)
          }
      }
  """
    
  // Sort keys for consistent output
  let sortedKeys = jsonData.keys.sorted()
    
  for key in sortedKeys {
    let name = makeLowerCamelIdentifier(from: key)
    guard let languageDict = jsonData[key] else { continue }
        
    // Analyze the English string to detect placeholders
    let enString = languageDict["En"] ?? ""
    let placeholders = detectPlaceholders(in: enString)
        
    if placeholders.isEmpty {
      // Simple property (no arguments)
      code += """
      
          public static var \(name): String {
              LocalisationManager.shared.getString(key: "\(key)")
          }
      """
    } else {
      // Method with arguments using L10n.Arg (string literal default to EN)
      let argCount = placeholders.count

      // Parameters: _ arg0: L10n.Arg = "", _ arg1: L10n.Arg = "", ...
      let parameters = (0..<argCount)
        .map { index in
          "_ arg\(index): L10n.Arg = \"\""
        }
        .joined(separator: ", ")

      // Build argument selection based on current language
      let selectedArgs = (0..<argCount)
        .map { index in
          "(LocalisationManager.shared.currentLanguage == .english ? arg\(index).en : (arg\(index).mm ?? arg\(index).en))"
        }
        .joined(separator: ", ")

      code += """
      
          public static func \(name)(\(parameters)) -> String {
              LocalisationManager.shared.getString(key: "\(key)", args: [\(selectedArgs)])
          }
      """
    }
  }
    
  code += "\n}\n"
  return code
}

// MARK: - Placeholder Detection

func detectPlaceholders(in string: String) -> [Int] {
  var placeholders: [Int] = []
  let pattern = "\\{(\\d+)\\}"
    
  if let regex = try? NSRegularExpression(pattern: pattern) {
    let nsString = string as NSString
    let range = NSRange(location: 0, length: nsString.length)
    let matches = regex.matches(in: string, range: range)
        
    for match in matches {
      if match.numberOfRanges > 1 {
        let numberRange = match.range(at: 1)
        if let number = Int(nsString.substring(with: numberRange)) {
          if !placeholders.contains(number) {
            placeholders.append(number)
          }
        }
      }
    }
  }
    
  return placeholders.sorted()
}

// Run main
main()
