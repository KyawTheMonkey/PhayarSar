import Foundation
import LocalisationKit

/// A source address, not a copy of the prayer. UTF-16 offsets are local to
/// the first and last verses because UIKit's selection uses that coordinate
/// system. Keeping the address independent of rendered lines means changing
/// fonts, pronunciation or the device's width cannot move a breadcrumb.
public struct PrayerPassageLocation: Hashable, Codable, Sendable {
  public let firstVerseID: Int
  public let lastVerseID: Int
  public let startUTF16Offset: Int
  public let endUTF16Offset: Int

  public init(
    firstVerseID: Int, lastVerseID: Int,
    startUTF16Offset: Int, endUTF16Offset: Int
  ) {
    self.firstVerseID = firstVerseID
    self.lastVerseID = lastVerseID
    self.startUTF16Offset = startUTF16Offset
    self.endUTF16Offset = endUTF16Offset
  }

  @MainActor
  public var verseLabel: String {
    let locale = Locale(identifier:
      LocalisationManager.shared.currentLanguage == .myanmar ? "my_MM" : "en_US"
    )
    let first = firstVerseID.formatted(.number.grouping(.never).locale(locale))
    let last = lastVerseID.formatted(.number.grouping(.never).locale(locale))
    return firstVerseID == lastVerseID
      ? L10n.prayerVerse(.init(stringLiteral: first))
      : L10n.prayerVerseRange(.init(stringLiteral: first), .init(stringLiteral: last))
  }
}
