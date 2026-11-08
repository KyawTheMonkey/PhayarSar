import EnvironmentKit
import Foundation

/// Save the chosen words as well as their address. A catalog correction must
/// not silently change someone's recitation; the address still opens the
/// original context even if that later version no longer matches the snapshot.
public struct PrayerPassage: Hashable, Codable, Sendable {
  public let prayerID: String
  public let prayerTitle: String
  public let text: String
  public let location: PrayerPassageLocation

  public init(prayerID: String, prayerTitle: String, text: String, location: PrayerPassageLocation) {
    self.prayerID = prayerID
    self.prayerTitle = prayerTitle
    self.text = text
    self.location = location
  }
}

/// One continuous selection surface, rather than a text view per verse. Native
/// handles can therefore cross a verse boundary without also capturing the
/// pronunciation, translation or decorative verse labels.
public struct PrayerPassageDocument: Sendable {
  public struct VerseRange: Sendable {
    public let verseID: Int
    public let range: NSRange
  }

  public let prayer: Prayer
  public let text: String
  public let verses: [VerseRange]

  public init(prayer: Prayer) {
    self.prayer = prayer
    var text = ""
    var verses: [VerseRange] = []
    var seen: Set<Int> = []
    for verse in prayer.body where seen.insert(verse.id).inserted {
      if !text.isEmpty { text += "\n\n" }
      let start = text.utf16.count
      text += verse.content
      verses.append(VerseRange(
        verseID: verse.id,
        range: NSRange(location: start, length: verse.content.utf16.count)
      ))
    }
    self.text = text
    self.verses = verses
  }

  public func passage(in selection: NSRange) -> PrayerPassage? {
    let source = text as NSString
    guard selection.location != NSNotFound, selection.location >= 0,
          selection.length > 0, selection.location < source.length,
          selection.length <= source.length - selection.location
    else { return nil }

    // Programmatic selections and accessibility can hand us arbitrary UTF-16
    // boundaries. Expand to composed characters before extracting so stacked
    // Burmese marks never become an orphan at either end of a recitation.
    var range = source.rangeOfComposedCharacterSequences(for: selection)
    let selected = source.substring(with: range) as NSString
    let ink = CharacterSet.whitespacesAndNewlines.inverted
    let firstInk = selected.rangeOfCharacter(from: ink)
    guard firstInk.location != NSNotFound else { return nil }
    let lastInk = selected.rangeOfCharacter(from: ink, options: .backwards)
    range = NSRange(
      location: range.location + firstInk.location,
      length: NSMaxRange(lastInk) - firstInk.location
    )
    range = source.rangeOfComposedCharacterSequences(for: range)
    let touched = verses.filter { NSIntersectionRange($0.range, range).length > 0 }
    guard let first = touched.first, let last = touched.last else { return nil }
    return PrayerPassage(
      prayerID: prayer.id, prayerTitle: prayer.title,
      text: source.substring(with: range),
      location: PrayerPassageLocation(
        firstVerseID: first.verseID, lastVerseID: last.verseID,
        startUTF16Offset: max(0, range.location - first.range.location),
        endUTF16Offset: min(last.range.length, NSMaxRange(range) - last.range.location)
      )
    )
  }

  /// Returns nil for a stale address instead of guessing at a different verse.
  /// Callers can still open the prayer and retain the saved text snapshot.
  public func range(for location: PrayerPassageLocation) -> NSRange? {
    guard let first = verses.first(where: { $0.verseID == location.firstVerseID }),
          let last = verses.first(where: { $0.verseID == location.lastVerseID }),
          location.startUTF16Offset >= 0, location.startUTF16Offset < first.range.length,
          location.endUTF16Offset > 0, location.endUTF16Offset <= last.range.length
    else { return nil }
    let start = first.range.location + location.startUTF16Offset
    let end = last.range.location + location.endUTF16Offset
    guard end > start else { return nil }
    return (text as NSString).rangeOfComposedCharacterSequences(
      for: NSRange(location: start, length: end - start)
    )
  }
}
