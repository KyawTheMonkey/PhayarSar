import PrayersKit

/// One line of a prayer, as the reading screen lays it out: a row of its own,
/// carrying everything a cell needs to draw it and nothing that a settings
/// change would alter.
///
/// The reader is a list of *lines* rather than a list of verses because a line
/// is the unit the screen has to be able to address — scrolling a particular
/// line to a particular offset when playback reaches it is a table method when
/// the line is a row, and hand-rolled arithmetic on a label's layout manager
/// when it is not.
struct PrayerVerseLine: Identifiable {

  /// Where a line sits in the prayer, and the only thing the diffable snapshot
  /// carries. Stable across a settings change: the line split is taken from the
  /// source text, never from the reader's preferences, so turning the
  /// respelling off restyles the rows rather than replacing them.
  struct ID: Hashable {
    let verse: Prayer.Verse.ID
    /// 0-based position within the verse.
    let line: Int
  }

  let id: ID

  /// The verse's name, on the first line of the verse and nowhere else — it
  /// titles the verse, and repeating it down every line would read as a new
  /// verse each time.
  let name: String?

  /// The line's two halves, already paired.
  let gloss: PrayerVerseGloss.Line

  /// Whether the verse this came from has a respelling at all.
  ///
  /// Per verse rather than per line: a verse whose halves disagree on line
  /// count has lines with an empty respelling in the middle of it, and those
  /// still belong in the glossed setting — a blank where the pairing broke is
  /// the point.
  let hasPronunciation: Bool

  /// What comes after this line, which is what decides the gap under it.
  let next: Next

  enum Next {
    /// Another line of the same verse.
    case line
    /// The first line of the next verse.
    case verse
    /// Nothing — the table's bottom inset takes it from here.
    case end
  }
}

// MARK: - Flattening

extension PrayerVerseLine {
  /// Lays a prayer's verses out as the rows the reader shows.
  ///
  /// The pairing is always built against the verse's real respelling, whether
  /// or not the reader is currently showing it. Splitting on the setting would
  /// make the *number* of rows depend on it — the two halves disagree on line
  /// count in a handful of verses — and every one of those verses would then
  /// diff as rows inserted and deleted each time the setting was toggled.
  static func lines(in verses: [Prayer.Verse]) -> [PrayerVerseLine] {
    var rows: [PrayerVerseLine] = []

    for (verseIndex, verse) in verses.enumerated() {
      let isLastVerse = verseIndex == verses.count - 1
      let gloss = PrayerVerseGloss(content: verse.content, pronunciation: verse.pronunciation)

      // A named verse with nothing in it still gets a row, so its name does not
      // go missing along with its text.
      var lines = gloss.lines
      if lines.isEmpty {
        guard let name = verse.name, !name.isEmpty else { continue }
        lines = [PrayerVerseGloss.Line(pronunciation: "", content: "")]
      }

      for (lineIndex, line) in lines.enumerated() {
        let isLastLine = lineIndex == lines.count - 1

        rows.append(
          PrayerVerseLine(
            id: ID(verse: verse.id, line: lineIndex),
            name: lineIndex == 0 ? verse.name : nil,
            gloss: line,
            hasPronunciation: !verse.pronunciation.isEmpty,
            next: isLastLine ? (isLastVerse ? .end : .verse) : .line
          )
        )
      }
    }

    return rows
  }
}
