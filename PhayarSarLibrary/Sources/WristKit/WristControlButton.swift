#if os(watchOS)
import DesignKit
import SwiftUI

/// One of the remote's controls.
///
/// A hand-rolled button rather than `.borderedProminent` because the watch is
/// meant to read as the same app as the phone, and the system styles bring
/// their own tint ramp and corner radius — which on a screen showing three
/// buttons and nothing else is most of the design.
struct WristControlButton: View {

  let systemImage: String

  /// `true` for the controls that carry the reading forward — they take the
  /// accent, the rest take the quiet surface.
  var isProminent = false

  var height: CGFloat = WristMetrics.primaryControlHeight

  /// Drawn dimmed and refusing the tap. Used at either end of the catalog and
  /// whenever the phone is not there to hear it, so the reader finds out from
  /// the button rather than from nothing happening.
  var isEnabled = true

  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(background, in: .rect(cornerRadius: WristMetrics.cornerRadius))
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.35)
  }

  private var foreground: Color {
    // `buttonPrimaryText` rather than `textInverse`, which is the wrong token
    // here and invisibly so on the watch: `textInverse` is "the opposite of the
    // current appearance", and since every colour resolves to its dark half on
    // a watch (see `Color.dynamic`) it comes back as the near-black meant for
    // light backgrounds — drawn on the accent fill, at a disabled control's
    // opacity, that is a button with no icon on it at all.
    //
    // `buttonPrimaryText` is white in both appearances, which is what a filled
    // accent button wants on either platform.
    isProminent ? AppColor.buttonPrimaryText : AppColor.primary
  }

  private var background: Color {
    isProminent ? AppColor.primary : AppColor.primarySoft
  }
}
#endif
