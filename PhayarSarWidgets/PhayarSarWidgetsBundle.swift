import SwiftUI
import WidgetKit

/// The extension's entry point.
///
/// One member so far, and the extension exists for it: the card that stands in
/// for a reading while the app is not the app on screen. Home Screen widgets, if
/// they ever come, go in here beside it.
@main
struct PhayarSarWidgetsBundle: WidgetBundle {
  var body: some Widget {
    // iOS 17 is where interactive Live Activities begin, and this card is its
    // controls — a version of it without them would be a play button that does
    // nothing. Below 17 the app simply posts no activity and the reader's
    // controls are the ones in the app; see `PrayerReadingActivity`.
    if #available(iOS 17.0, *) {
      PrayerReadingLiveActivity()
    }
  }
}
