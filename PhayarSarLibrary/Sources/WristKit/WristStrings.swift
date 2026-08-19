#if os(watchOS)
import Foundation
import RemoteKit

/// The watch's own strings, in the two languages the app ships.
///
/// ## Why these are not in `LocalisationKit`
///
/// Two reasons, and the second is the one that decided it.
///
/// The first is mechanical: `LocalisationKit` generates its `L10n` enum with a
/// SwiftPM build-tool plugin, and Xcode gives that plugin one output directory
/// per package target — *not* per platform. Building the phone and the watch in
/// the same pass, which embedding the watch app in the phone app makes
/// unavoidable, has the two builds writing `L10n+Generated.swift` to the same
/// path and the build fails before it starts.
///
/// The second is that `LocalisationManager` reads the chosen language out of
/// `UserDefaults`, and the watch has its own — separate from the phone's, and
/// never written by the language switcher in Settings. A watch that asked it
/// would answer with the fallback on every install and go on answering with it
/// forever, showing English to a reader who set the phone to Burmese years ago.
///
/// So the language arrives over the wire with everything else the watch shows
/// (``PrayerRemoteState/language``) and these resolve against it. Twelve strings
/// is a table worth keeping by hand; the prayer titles, which are the words that
/// actually matter here, come from the phone already localised.
struct WristStrings {

  /// `Language`'s raw value, as sent by the phone.
  let language: String

  init(language: String) {
    self.language = language
  }

  init(state: PrayerRemoteState) {
    self.init(language: state.language)
  }

  private func pick(_ english: String, _ burmese: String) -> String {
    language == "Mm" ? burmese : english
  }

  var noPrayer: String { pick("No prayer open", "ဘုရားစာ မဖွင့်ရသေးပါ") }
  var readerClosed: String { pick("Choose a prayer to begin", "ဘုရားစာတစ်ပုဒ် ရွေးပါ") }
  var previousVerse: String { pick("Previous verse", "ယခင်ပိုဒ်") }
  var nextVerse: String { pick("Next verse", "နောက်ပိုဒ်") }
  var scrollDown: String { pick("Scroll down", "အောက်သို့ ရွှေ့ရန်") }
  var previousPrayer: String { pick("Previous prayer", "ယခင်ဘုရားစာ") }
  var nextPrayer: String { pick("Next prayer", "နောက်ဘုရားစာ") }
  var prayers: String { pick("Prayers", "ဘုရားစာများ") }
  var closeReader: String { pick("Close reader", "ဘုရားစာ ပိတ်ရန်") }
  var disconnected: String { pick("iPhone not reachable", "ဖုန်းနှင့် မချိတ်ဆက်ရသေးပါ") }
  var disconnectedHint: String {
    pick("Open PhayarSar on your iPhone", "ဖုန်းတွင် ဘုရားစာ အက်ပ်ကို ဖွင့်ပါ")
  }
  var connecting: String { pick("Connecting…", "ချိတ်ဆက်နေသည်…") }
}
#endif
