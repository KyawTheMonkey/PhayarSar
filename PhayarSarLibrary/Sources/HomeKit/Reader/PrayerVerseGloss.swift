import Foundation

/// A verse paired line for line with its respelling, ready to be drawn as an
/// interlinear gloss: each line of respelling with the Pali it stands for
/// directly beneath it.
///
/// The pairing is positional — the *n*th line of the respelling against the
/// *n*th line of the verse — because that is the only correspondence the source
/// gives us. Nothing in the JSON marks which respelled line belongs to which
/// Pali one, and the two are hand-maintained, so a verse whose halves disagree
/// on line count is a thing that happens rather than a thing to guard against.
/// Where they disagree the longer half keeps going against blanks, which puts
/// the mismatch on the page where it can be spotted and fixed, rather than
/// dropping lines or trapping.
struct PrayerVerseGloss {

  /// One line of the gloss: a respelling over the Pali it stands for.
  struct Line: Equatable {
    /// The Burmese phonetic respelling — the line the reader actually recites.
    /// Empty when the respelling ran out of lines before the verse did.
    let pronunciation: String

    /// The Pali the respelling stands for. Empty in the opposite case.
    let content: String

    var isEmpty: Bool { pronunciation.isEmpty && content.isEmpty }
  }

  let lines: [Line]

  var isEmpty: Bool { lines.isEmpty }

  init(content: String, pronunciation: String) {
    let pali = Self.lines(in: content)
    let recited = Self.lines(in: pronunciation)

    lines = (0..<max(pali.count, recited.count)).compactMap { index in
      let line = Line(
        pronunciation: index < recited.count ? recited[index] : "",
        content: index < pali.count ? pali[index] : ""
      )
      return line.isEmpty ? nil : line
    }
  }

  /// Splits a half of the verse into its lines.
  ///
  /// Blank lines are dropped rather than kept: a half that ends with a stray
  /// newline would otherwise pair a whole empty line against a real one and
  /// stagger everything under it, and the source is hand-maintained enough for
  /// that to be worth being forgiving about.
  private static func lines(in text: String) -> [String] {
    text
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }
}
