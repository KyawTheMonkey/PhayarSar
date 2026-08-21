import ActivitiesKit
import ActivityKit
import AppIntents
import DesignKit
import LocalisationKit
import SwiftUI
import WidgetKit

/// The reading, as the Lock Screen and the Dynamic Island show it.
///
/// Only ever seen from outside the app: iOS hides an app's own Live Activity
/// while that app is frontmost. So this is the reading picked up from the Lock
/// Screen, from another app, from the home screen — and its opposite number
/// inside the app is `PrayerIslandBar`, which hangs the same controls from the
/// same cutout in the app's own window. The two are drawn alike on purpose and
/// can never be on screen at the same time.
///
/// Shut, it says which prayer and how far in. Tapped, it expands into the
/// controls: play and pause, stop, and all five paces. See
/// ``PrayerReadingAttributes`` for what those controls can and cannot mean when
/// the page they belong to is not being looked at.
///
/// Everything here is drawn on the system's own dark ground, so it takes the
/// island's palette rather than the reader's paper: the six page colours never
/// reach this far.
@available(iOS 17.0, *)
struct PrayerReadingLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PrayerReadingAttributes.self) { context in
      lockScreen(context)
    } dynamicIsland: { context in
      DynamicIsland {
        // MARK: Expanded

        // Play and pause on one side, stop on the other, with the prayer
        // between them — rather than both transport controls together in one
        // corner. The two answer different questions, and the reader reaching
        // for pause mid-recitation should not have to pick it out of a pair.
        DynamicIslandExpandedRegion(.leading) {
          transport(context)
            .padding(.leading, 6)
        }

        DynamicIslandExpandedRegion(.trailing) {
          stop
            .padding(.trailing, 6)
        }

        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 1) {
            Text(context.attributes.title)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.7)

            Text(count(context.state))
              .font(.caption2)
              .monospacedDigit()
              .foregroundStyle(.secondary)
          }
        }

        DynamicIslandExpandedRegion(.bottom) {
          speeds(context)
            .padding(.top, 4)
        }
      } compactLeading: {
        // Status, not a control. The compact presentations are a few points
        // across and the reader has not asked for anything yet — the tap that
        // opens this into the controls above is the whole of what they can do
        // here, and a button would be competing with it for the same touch.
        glyph(isPlaying: context.state.isPlaying)
      } compactTrailing: {
        // The position rather than the title. Four characters is what this slot
        // is good for, and a Burmese prayer name truncated to four characters is
        // no name at all — where `4/22` is the whole fact.
        Text(count(context.state))
          .font(.caption2.weight(.semibold))
          .monospacedDigit()
          .foregroundStyle(tint)
      } minimal: {
        glyph(isPlaying: context.state.isPlaying)
      }
      .keylineTint(tint)
    }
  }

  // MARK: - Lock Screen

  /// The same card, given room — and the only presentation a reader with no
  /// Dynamic Island ever sees.
  private func lockScreen(_ context: ActivityViewContext<PrayerReadingAttributes>) -> some View {
    VStack(spacing: 14) {
      HStack(spacing: 12) {
        transport(context)
        stop

        VStack(alignment: .leading, spacing: 2) {
          Text(context.attributes.title)
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

          Text(count(context.state))
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      speeds(context)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    // The system paints its own ground behind this on the Lock Screen; naming a
    // colour here would only fight it.
    .activityBackgroundTint(nil)
  }

  // MARK: - Controls

  /// Play when paused, pause when playing — the only control that is live in
  /// both states, because the reading can be held and let go as often as the
  /// reader likes and neither of those is the end of it.
  private func transport(_ context: ActivityViewContext<PrayerReadingAttributes>) -> some View {
    Button(intent: PrayerReadingToggleIntent()) {
      Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(tint)
        // The triangle folds into two bars rather than cutting to them, the
        // same as the in-app pill does. No availability check needed here —
        // this whole extension is iOS 17 and up.
        .contentTransition(.symbolEffect(.replace))
        .frame(width: 38, height: 38)
        .background(Circle().fill(.fill.tertiary))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(context.state.isPlaying ? L10n.pausePrayer : L10n.playPrayer)
  }

  /// The one way out, and the only red on the card.
  ///
  /// Red because it is the only control here that does not simply change what is
  /// happening — it ends it and gives the page back. The in-app bar makes the
  /// same choice at more length.
  private var stop: some View {
    Button(intent: PrayerReadingStopIntent()) {
      Image(systemName: "stop.fill")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.red)
        .frame(width: 38, height: 38)
        .background(Circle().fill(.fill.tertiary))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L10n.stopPrayer)
  }

  /// Every pace at once, rather than one button that cycles.
  ///
  /// The reader picking a pace is choosing *between* these — a quarter speed to
  /// learn a line, double to run through something they know — and a control
  /// that shows the alternatives is one they can aim at rather than count taps
  /// through. It is also the reason the island has to be expanded to change
  /// pace: five of these do not fit beside a cutout.
  ///
  /// Driven off `attributes.speeds` rather than a list of its own, so there is
  /// nothing here to fall out of step with `PrayerPlaybackSpeed.allCases`.
  private func speeds(_ context: ActivityViewContext<PrayerReadingAttributes>) -> some View {
    HStack(spacing: 4) {
      ForEach(context.attributes.speeds, id: \.self) { speed in
        let isChosen = speed == context.state.speed

        Button(intent: PrayerReadingSpeedIntent(speed: speed)) {
          Text(PrayerReadingAttributes.speedLabel(speed))
            .font(.caption2.weight(isChosen ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(isChosen ? Color.black : Color.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background {
              // The same black-and-yellow the in-app bar uses for the chosen
              // pace, and for the same reason: it is the pairing the eye finds
              // fastest, and this card is read at arm's length in the middle of
              // something else.
              Capsule().fill(isChosen ? Color.yellow : Color.clear)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PrayerReadingAttributes.speedLabel(speed))
        .accessibilityAddTraits(isChosen ? .isSelected : [])
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(L10n.playbackSpeed)
  }

  // MARK: - Pieces

  /// The mark in the compact and minimal slots.
  ///
  /// The transport glyph rather than the app's own, because in these two
  /// presentations it is the only thing that fits and the only thing worth
  /// saying: whether the prayer is running.
  private func glyph(isPlaying: Bool) -> some View {
    Image(systemName: isPlaying ? "book.closed.fill" : "pause.fill")
      .foregroundStyle(tint)
  }

  /// Where the reading had got to.
  private func count(_ state: PrayerReadingAttributes.ContentState) -> String {
    "\(state.verse)/\(state.verses)"
  }

  /// The app's own colour, which is the only thing on this card that says whose
  /// card it is once the title has been truncated away.
  private var tint: Color { AppColor.primary }
}
