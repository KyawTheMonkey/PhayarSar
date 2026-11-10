import DesignKit
import Inject
import LocalisationKit
import SwiftUI

public enum BeadsRecitationTextMetrics {
  public static let textSize: CGFloat = 19
  public static let lineSpacing: CGFloat = 9
  public static let fadeHeight: CGFloat = 28
  public static let pullingOpacity = 0.55
  public static let dimDuration = 0.25
}

/// The passage sits directly in the light, with no card, border or shadow;
/// a container would be a second material on a stage that has one. While a
/// bead is being pulled the text steps back so the bead owns the moment.
struct BeadsRecitationText: View {
  @ObserveInjection private var injectionObserver
  @ObservedObject var motion: BeadsRitualMotion
  let text: String

  var body: some View {
    ScrollView {
      Text(text)
        .font(AppFont.jasmine(size: BeadsRecitationTextMetrics.textSize, relativeTo: .body))
        .lineSpacing(BeadsRecitationTextMetrics.lineSpacing)
        .foregroundStyle(AppColor.BeadsSession.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, BeadsSessionMetrics.horizontalPadding)
        .padding(.bottom, BeadsRecitationTextMetrics.fadeHeight)
    }
    .mask {
      VStack(spacing: 0) {
        Color.black
        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
          .frame(height: BeadsRecitationTextMetrics.fadeHeight)
      }
    }
    .opacity(motion.isPulling ? BeadsRecitationTextMetrics.pullingOpacity : 1)
    .animation(.easeOut(duration: BeadsRecitationTextMetrics.dimDuration), value: motion.isPulling)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(L10n.beadsRecitation)
    .enableInjection()
  }
}
