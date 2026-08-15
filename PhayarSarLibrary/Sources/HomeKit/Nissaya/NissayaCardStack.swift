import DesignKit
import LocalisationKit
import PrayersKit
import SwiftUI

// MARK: - Metrics

enum NissayaCardMetrics {
  /// Softer than `AppListSection`'s 16 — these cards are objects the reader
  /// pushes around rather than panels bolted to the page, and the extra radius
  /// is what reads as a physical card.
  static let cornerRadius: CGFloat = 24

  /// How far each card behind the front one stands proud of it, at the trailing
  /// edge.
  ///
  /// Small on purpose. What is showing is the *edge* of the next verse, not a
  /// preview of it — the same sliver the Smart Stack shows under its front
  /// widget, turned on its side.
  static let stackPeek: CGFloat = 7

  /// What a card keeps of its size, and of its opacity, per place further back
  /// in the stack.
  static let stackScale: Double = 0.94
  static let stackOpacity: Double = 0.86

  /// How many cards are drawn behind the front one. Past this there is nothing
  /// left to see — the fourth card back would sit entirely under the third.
  static let stackDepth = 3

  /// Total width the stack fans into, past the front card's trailing edge.
  ///
  /// A card `d` places back is offset by `d * stackPeek` *after* its scaling
  /// has been undone (see ``NissayaCardPlacement``), so the deepest one
  /// protrudes by exactly this much and the trailing margin can be sized to it.
  static var stackReach: CGFloat { CGFloat(stackDepth) * stackPeek }

  /// Margin around the front card. The trailing side additionally carries
  /// ``stackReach``, which is why the stack is not centred — see
  /// ``NissayaCardStack``.
  static let pageMargin: CGFloat = 20

  /// How much of a card's travel has to be dragged, or flicked towards, before
  /// the swipe commits to the next verse rather than springing back.
  static let commitFraction: CGFloat = 0.26

  /// What a drag is worth once there is no verse left in that direction. The
  /// card still moves, so the gesture is never dead under the finger, but it
  /// clearly refuses.
  static let overscrollResistance: CGFloat = 0.3

  /// How far a finger travels before the gesture commits to being a horizontal
  /// swipe or a vertical scroll. See ``NissayaCardStack`` for why that choice
  /// has to be made at all.
  static let axisLockDistance: CGFloat = 8

  /// Padding inside a card, around its content.
  static let contentPadding: CGFloat = 20

  /// Gutter between the Pali column and the meaning column.
  static let columnGutter: CGFloat = 20

  /// Gap between the two blocks when they are stacked instead of side by side.
  static let stackedBlockGap: CGFloat = 18

  /// Card width at which the two strands split into columns.
  ///
  /// Measured against the *card*, not the window, and not read from
  /// `horizontalSizeClass`: on iPad this screen sits in a split view's detail
  /// column, so a regular-width window says nothing about how much room the
  /// card actually got. `PrayerSpecGrid` on the detail screen decides its
  /// column count the same way, for the same reason.
  ///
  /// Set so each column still clears ~250pt, which is about the narrowest a
  /// Burmese paragraph can be set at reading size without breaking most lines
  /// mid-word.
  static let sideBySideMinWidth: CGFloat = 560

  // MARK: Type scale
  //
  // The meaning is the text this screen exists to show, so it carries the
  // larger, darker setting and the Pali sits beside it as the reference — the
  // opposite of `PrayerScreen`, where the recited line is the point and
  // everything else is an aid to it.
  //
  // Both sizes step up on a card wide enough for columns. That is the same
  // measurement ``sideBySideMinWidth`` gates on, and for the same reason it is
  // a measurement rather than a size class: a wide card means an iPad held
  // further away than a phone, where 19pt Burmese is small.

  static let meaningTextSize: CGFloat = 19
  static let paliTextSize: CGFloat = 16

  static let wideMeaningTextSize: CGFloat = 24
  static let widePaliTextSize: CGFloat = 20

  /// Burmese stacks diacritics above and below the baseline, so the default
  /// leading crowds consecutive lines — the same reason the detail screen's
  /// about text carries its own. Opened up further at the larger size, where
  /// the taller glyphs would otherwise close the gap again.
  static let lineSpacing: CGFloat = 7
  static let wideLineSpacing: CGFloat = 9

  /// The verse name in the header, which tracks the strands rather than the
  /// section labels around it.
  static let nameTextSize: CGFloat = 14
  static let wideNameTextSize: CGFloat = 17
}

// MARK: - Placement

/// Where one card stands, given how many places it is from the one facing the
/// reader.
///
/// `depth` is continuous, not a whole number: mid-drag the front card sits at
/// some fraction below 0 and the next one at the same fraction below 1, which
/// is what makes the stack rearrange itself under the finger rather than
/// jumping when the swipe completes.
///
/// Two regimes, meeting continuously at 0:
/// - `depth >= 0` — in the stack. Scaled down and peeking at the trailing edge.
/// - `depth < 0` — leaving. Full size, sliding off the leading edge.
///
/// A plain struct rather than methods on the view, matching `CoverFlowPlacement`
/// on the detail screen's carousel: the maths is the interesting part and it is
/// worth being able to read it without a view around it.
private struct NissayaCardPlacement {
  /// Offset from where the card would otherwise be laid out.
  let x: CGFloat
  let scale: Double
  let opacity: Double
  let shadowOpacity: Double
  /// Nearest the front draws on top, and a card already leaving draws over the
  /// whole stack — it is in front of them in space, so it has to be in front of
  /// them in z too.
  let zIndex: Double

  /// - Parameters:
  ///   - cardWidth: Needed to undo the inset that scaling about the centre
  ///     creates. Without it the peek would vary with the card's width, and the
  ///     stack would fan differently on an iPhone and an iPad.
  ///   - travel: How far a card moves to leave the screen entirely.
  init(depth: Double, cardWidth: CGFloat, travel: CGFloat) {
    zIndex = -depth

    if depth >= 0 {
      let shrunk = pow(NissayaCardMetrics.stackScale, depth)
      scale = shrunk

      // `(1 - shrunk) * cardWidth / 2` is the gap scaling about the centre
      // opens at each side. Adding it back puts this card's trailing edge level
      // with the front card's, so the peek term below is the whole of what
      // shows — a clean `stackPeek` per place, at any card width.
      x = CGFloat(depth) * NissayaCardMetrics.stackPeek
        + CGFloat(1 - shrunk) * cardWidth / 2

      // Nothing to draw past the last place in the stack: that card is fully
      // covered by the one in front of it.
      opacity = depth > Double(NissayaCardMetrics.stackDepth)
        ? 0
        : pow(NissayaCardMetrics.stackOpacity, depth)

      // The stack's own shadows are what separate one card edge from the next,
      // but they are stacked up behind a card that already casts one — so they
      // fade fast, or the sliver at the trailing edge turns into a dark smear.
      shadowOpacity = Self.frontShadowOpacity * pow(0.45, depth)
    } else {
      // Leaving. Kept at full size: it is sliding out of the reader's way, not
      // going back into the deck, and shrinking it as it goes would read as it
      // falling away rather than being pushed aside.
      scale = 1
      x = CGFloat(depth) * travel

      // Held at full strength until it is most of the way out, then faded over
      // the last stretch. Fading from the moment it starts moving would dim the
      // card the reader is still actively dragging.
      opacity = min(1, max(0, (1 + depth) * 2.5))
      shadowOpacity = Self.frontShadowOpacity * opacity
    }
  }

  private static let frontShadowOpacity: Double = 0.17
}

// MARK: - Card stack

/// The prayer's verses as a deck of cards, swiped through one at a time.
///
/// Modelled on the Smart Stack widget rather than on a paging scroll view: one
/// card faces the reader at full size, the next few peek out from behind it, and
/// a swipe pushes the front one aside to bring the next up. Swiping back is the
/// same motion reversed — the card that left slides in from where it went, and
/// the current one settles back into the place in the deck it came from.
///
/// Hand-built on a `DragGesture` rather than assembled from `scrollPosition` and
/// `scrollTransition` the way `PrayerCoverCarousel` is. A scroll view can page,
/// but it cannot let the front page *leave* while the one behind stays put —
/// and that separation, one card moving against a stack that doesn't, is the
/// whole of the Smart Stack look. It also keeps the screen on iOS 16, where the
/// scroll-position API the cover carousel needs doesn't exist.
///
/// ## Gestures
///
/// Each card scrolls internally — the longest verse in the catalog runs to about
/// 1,700 characters and no card is going to hold that — so this view's swipe and
/// the card's scroll are competing for the same finger. The swipe is attached
/// with `simultaneousGesture` so the scroll view still gets its events, and the
/// axis is then locked on the first meaningful movement: a drag that starts out
/// vertical is ignored for the rest of its life, so scrolling a long verse never
/// drags the card sideways with it.
struct NissayaCardStack: View {
  let verses: [Prayer.Verse]
  /// Which verse is facing the reader. A binding because the screen's footer
  /// steps through it too, and both have to agree.
  @Binding var index: Int

  /// How far the front card has been dragged from its resting place, in points.
  /// Positive is towards the previous verse.
  @State private var drag: CGFloat = 0

  /// Which way the current gesture turned out to be going, decided once and
  /// then held until the finger lifts. `nil` between gestures, and for the
  /// first few points of one, while it is still ambiguous.
  @State private var axis: DragAxis?

  private enum DragAxis {
    case horizontal
    case vertical
  }

  private var lastIndex: Int { max(0, verses.count - 1) }

  var body: some View {
    GeometryReader { proxy in
      let cardWidth = max(
        1,
        proxy.size.width - NissayaCardMetrics.pageMargin * 2 - NissayaCardMetrics.stackReach
      )

      // A whole container width, so a dismissed card is always clear of the
      // screen however wide the margins are.
      let travel = max(1, proxy.size.width)

      // Signed, and in cards rather than points: positive while swiping towards
      // the next verse. This is the one number the whole layout below is driven
      // from.
      let progress = Double(-drag / travel)

      ZStack {
        ForEach(window, id: \.self) { position in
          let place = NissayaCardPlacement(
            depth: Double(position - index) - progress,
            cardWidth: cardWidth,
            travel: travel
          )

          NissayaCard(
            verse: verses[position],
            position: position + 1,
            isSideBySide: cardWidth >= NissayaCardMetrics.sideBySideMinWidth
          )
          .frame(width: cardWidth, height: proxy.size.height)
          .scaleEffect(place.scale)
          .offset(x: place.x + centringCorrection)
          .opacity(place.opacity)
          .shadow(color: .black.opacity(place.shadowOpacity), radius: 16, x: 0, y: 8)
          .zIndex(place.zIndex)
          // Only the front card is live. Without this the cards behind would
          // take taps through the sliver they show, and VoiceOver would read
          // out three verses' worth of text as if it were all one page.
          .allowsHitTesting(position == index)
          .accessibilityHidden(position != index)
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      // On the container rather than on the front card, so the margins either
      // side of the deck are draggable too — the card is not the whole of what
      // looks like the deck.
      .simultaneousGesture(swipe(travel: travel))
      // Fires on a swipe and on the footer's chevrons alike, since both arrive
      // as a change to `index`.
      .nissayaSelectionFeedback(trigger: index)
    }
  }

  // MARK: - Layout

  /// Puts the front card at ``NissayaCardMetrics/pageMargin`` from the leading
  /// edge.
  ///
  /// The deck is deliberately not centred. Cards fan towards the trailing edge,
  /// so the trailing margin has to carry ``NissayaCardMetrics/stackReach`` on
  /// top of the page margin — and a card centred in what is left would sit half
  /// that reach too far in. Correcting for it here lets the cards keep a plain
  /// centred frame, with one constant accounting for the asymmetry.
  private var centringCorrection: CGFloat {
    -NissayaCardMetrics.stackReach / 2
  }

  /// The cards worth building: the one leaving, the one facing the reader, and
  /// the stack behind it.
  ///
  /// Clamped rather than wrapped — a nissaya is read from the first verse to the
  /// last, and a deck that looped would make it impossible to tell the end of
  /// the prayer from the start of it.
  ///
  /// The card *before* the current one is included because it is needed in both
  /// directions: it is the one animating off after a forward swipe, and the one
  /// sliding back in during a backward one.
  private var window: Range<Int> {
    let first = max(0, index - 1)
    let last = min(lastIndex, index + NissayaCardMetrics.stackDepth)
    return first ..< (last + 1)
  }

  // MARK: - Gesture

  private func swipe(travel: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: NissayaCardMetrics.axisLockDistance)
      .onChanged { value in
        if axis == nil {
          axis = Self.axis(of: value.translation)
        }

        guard axis == .horizontal else { return }
        drag = resisted(value.translation.width)
      }
      .onEnded { value in
        // Reset first: every path out of here ends the gesture, and a stray
        // early return that left the axis locked would deaden the next swipe.
        let wasHorizontal = axis == .horizontal
        axis = nil
        guard wasHorizontal else { return }

        settle(
          translation: value.translation.width,
          predicted: value.predictedEndTranslation.width,
          travel: travel
        )
      }
  }

  /// Which way a drag is going, once it has gone far enough to say.
  ///
  /// Biased towards vertical: the tie-break at 45° would otherwise send a
  /// slightly-off vertical scroll — which is most of them — sideways into the
  /// deck. A swipe between cards is a deliberate, near-horizontal gesture, so it
  /// can afford to be asked for.
  private static func axis(of translation: CGSize) -> DragAxis? {
    let horizontal = abs(translation.width)
    let vertical = abs(translation.height)

    guard max(horizontal, vertical) >= NissayaCardMetrics.axisLockDistance else {
      return nil
    }

    return horizontal > vertical * 1.2 ? .horizontal : .vertical
  }

  /// The drag, damped once it is pulling towards a verse that isn't there.
  private func resisted(_ translation: CGFloat) -> CGFloat {
    let beforeFirst = index == 0 && translation > 0
    let afterLast = index == lastIndex && translation < 0

    return beforeFirst || afterLast
      ? translation * NissayaCardMetrics.overscrollResistance
      : translation
  }

  /// Commits the swipe, or springs the card back.
  ///
  /// Distance *or* flick: a short, fast swipe should turn the card even though
  /// the finger never travelled far, which is what `predictedEndTranslation`
  /// carries. Taking whichever of the two is more decisive means a slow, long
  /// drag and a quick flick both work, without either having to be tuned
  /// against the other.
  private func settle(translation: CGFloat, predicted: CGFloat, travel: CGFloat) {
    let dragged = -translation / travel
    let flicked = -predicted / travel

    let target: Int
    if max(dragged, flicked) > NissayaCardMetrics.commitFraction {
      target = min(index + 1, lastIndex)
    } else if min(dragged, flicked) < -NissayaCardMetrics.commitFraction {
      target = max(index - 1, 0)
    } else {
      target = index
    }

    // Both in one animation, and both feeding the same `depth`: the outgoing
    // card carries on from wherever the finger left it out to -1, while the one
    // behind rises into its place. Animating them separately would show the
    // seam between the two.
    withAnimation(.nissayaCardSettle) {
      index = target
      drag = 0
    }
  }
}

// MARK: - Card

/// One verse: the Pali as recited, and what it means.
///
/// The two strands sit in columns when the card is wide enough to hold them and
/// stack when it isn't — but either way they are inside *one* scroll view rather
/// than two. A nissaya is read across, line against line, and two columns that
/// scrolled independently would let the reader put a verse next to the wrong
/// translation, which is the one thing this screen exists to prevent.
struct NissayaCard: View {
  let verse: Prayer.Verse
  /// 1-based, for the badge. `Prayer.Verse.index` is the same number, but this
  /// screen's position in the deck is the stack's business, not the model's.
  let position: Int
  let isSideBySide: Bool

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: NissayaCardMetrics.cornerRadius, style: .continuous)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header

      ScrollView(.vertical) {
        strands
          .padding(.bottom, 4)
      }
    }
    .padding(NissayaCardMetrics.contentPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background {
      // Two fills, not one. `AppColor.surface` is a translucent panel colour —
      // in dark mode it is white at 7% — and a translucent card in a stack
      // would show the cards behind it through its own face. The opaque base
      // under it is what keeps the deck reading as solid objects; the surface
      // tint on top is what keeps it matching every other card in the app.
      shape.fill(AppColor.background)
      shape.fill(AppColor.surface)
    }
    .overlay(shape.strokeBorder(AppColor.border, lineWidth: 0.5))
    .clipShape(shape)
  }

  // MARK: - Header

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text("\(position)")
        .font(AppFont.captionBold)
        .monospacedDigit()
        .foregroundStyle(AppColor.primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(AppColor.primarySoft, in: Capsule(style: .continuous))

      // Set in the Myanmar face rather than the app's section-label style: the
      // names that exist are Burmese (the 24 paccayas in ပဋ္ဌာန်းအကျယ်), and
      // Inter has no glyphs for them.
      if let name = verse.name, !name.isEmpty {
        Text(name)
          .font(
            AppFont.jasmine(
              size: isSideBySide
                ? NissayaCardMetrics.wideNameTextSize
                : NissayaCardMetrics.nameTextSize,
              relativeTo: .footnote
            )
          )
          .foregroundStyle(AppColor.textSecondary)
          .lineLimit(2)
      }

      Spacer(minLength: 0)
    }
  }

  // MARK: - Strands

  @ViewBuilder
  private var strands: some View {
    if isSideBySide {
      HStack(alignment: .top, spacing: NissayaCardMetrics.columnGutter) {
        pali
        Divider()
        meaning
      }
    } else {
      VStack(alignment: .leading, spacing: NissayaCardMetrics.stackedBlockGap) {
        pali
        Divider()
        meaning
      }
    }
  }

  /// The recited text — kept in the quieter setting of the two. It is here to
  /// be referred back to, not to be read through.
  private var pali: some View {
    strand(caption: L10n.nissayaPali) {
      Text(verse.content)
        .font(
          AppFont.jasmine(
            size: isSideBySide
              ? NissayaCardMetrics.widePaliTextSize
              : NissayaCardMetrics.paliTextSize,
            relativeTo: .callout
          )
        )
        .foregroundStyle(AppColor.textSecondary)
        .lineSpacing(lineSpacing)
    }
  }

  /// What the verse says — the reason this screen exists, and so the loudest
  /// thing on the card.
  private var meaning: some View {
    strand(caption: L10n.nissayaMeaning) {
      // 37 of the catalog's 452 verses ship no translation, so this is a state
      // the screen has to say something about rather than an empty column —
      // and on this screen it is the *main* column that goes missing.
      if verse.meaning.isEmpty {
        Text(L10n.nissayaNoMeaning)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textTertiary)
      } else {
        Text(verse.meaning)
          .font(
            AppFont.jasmine(
              size: isSideBySide
                ? NissayaCardMetrics.wideMeaningTextSize
                : NissayaCardMetrics.meaningTextSize,
              relativeTo: .body
            )
          )
          .foregroundStyle(AppColor.textPrimary)
          .lineSpacing(lineSpacing)
      }
    }
  }

  private var lineSpacing: CGFloat {
    isSideBySide
      ? NissayaCardMetrics.wideLineSpacing
      : NissayaCardMetrics.lineSpacing
  }

  /// One labelled block of text, sized to fill whatever column it is given.
  private func strand(
    caption: String,
    @ViewBuilder content: () -> some View
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(caption)
        .font(AppFont.sectionLabel)
        .textCase(.uppercase)
        .kerning(0.6)
        .foregroundStyle(AppColor.textTertiary)

      content()
        .frame(maxWidth: .infinity, alignment: .leading)
        // A study screen — being able to lift a line out of it is the point.
        .textSelection(.enabled)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Motion

extension Animation {
  /// The curve a card settles on, whether it turned or sprang back.
  ///
  /// A spring rather than the detail screen's `.smooth`, and with a little
  /// bounce left in it: this is a physical object being flicked, and the small
  /// overshoot at the end is what sells the weight. Deliberately quick — the
  /// card is in the reader's way until it lands.
  static var nissayaCardSettle: Animation {
    .spring(response: 0.38, dampingFraction: 0.82)
  }
}

extension View {
  /// A tick as the deck lands on another verse, where the OS supports it.
  ///
  /// Wrapped rather than called directly because `sensoryFeedback` is iOS 17,
  /// and this screen runs on 16 — unlike the detail screen's carousel, whose
  /// whole paging implementation is already behind that check.
  @ViewBuilder
  func nissayaSelectionFeedback(trigger: Int) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      sensoryFeedback(.selection, trigger: trigger)
    } else {
      self
    }
  }
}
