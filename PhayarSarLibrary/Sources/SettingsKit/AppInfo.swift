import Foundation

/// The app's own identity, read from the main bundle's Info.plist.
///
/// Reads `Bundle.main` rather than `Bundle.module` on purpose: this package is
/// linked into the app, so the interesting values are the host app's, not the
/// resource bundle's.
public enum AppInfo {
  /// Display name if the app sets one, otherwise the bundle name.
  public static var name: String {
    string(for: "CFBundleDisplayName")
      ?? string(for: "CFBundleName")
      ?? "PhayarSar"
  }

  /// Marketing version, e.g. `2.1.0`.
  public static var version: String {
    string(for: "CFBundleShortVersionString") ?? "—"
  }

  /// Build number, e.g. `42`.
  public static var build: String {
    string(for: "CFBundleVersion") ?? "—"
  }

  /// Version and build together, the way an about screen usually shows them.
  public static var displayVersion: String {
    "\(version) (\(build))"
  }

  private static func string(for key: String) -> String? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
          !value.isEmpty
    else { return nil }
    return value
  }
}
