import DesignKit
import Inject
import LocalisationKit
import SwiftUI

public enum BeadsRecitationTextMetrics {
  public static let textSize: CGFloat = 23
  public static let lineSpacing: CGFloat = 9
  public static let fadeHeight: CGFloat = 28
  public static let pullingOpacity = 0.55
  public static let dimDuration = 0.25
  static let shimmerSweep = 2.4
  static let shimmerBandWidth: CGFloat = 0.7
  static let shimmerSlant: CGFloat = 0.025
  static let shimmerBaseOpacity = 0.72
}

/// The passage sits directly in the light, with no card, border or shadow;
/// a container would be a second material on a stage that has one. While a
/// bead is being pulled the text steps back so the bead owns the moment.
struct BeadsRecitationText: View {
  @ObserveInjection private var injectionObserver
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ObservedObject var motion: BeadsRitualMotion
  @State private var shimmerProgress: CGFloat = 0
  let text: String

  private var isShimmering: Bool { motion.isActive && !reduceMotion }

  private var passage: some View {
    Text(text)
      .font(AppFont.mSquare(size: BeadsRecitationTextMetrics.textSize, relativeTo: .body))
      .lineSpacing(BeadsRecitationTextMetrics.lineSpacing)
      .fixedSize(horizontal: false, vertical: true)
  }

  var body: some View {
    ScrollView {
      passage
        .foregroundStyle(AppColor.BeadsSession.text)
        .opacity(isShimmering ? BeadsRecitationTextMetrics.shimmerBaseOpacity : 1)
        .textSelection(.enabled)
        .overlay {
          if isShimmering {
            // Use the same wrapping and glyphs as the passage while leaving
            // selection and accessibility with the original text.
            BeadsRecitationSheen(progress: shimmerProgress)
              .animation(
                .easeInOut(duration: BeadsRecitationTextMetrics.shimmerSweep).repeatForever(autoreverses: false),
                value: shimmerProgress
              )
              .mask { passage.foregroundStyle(.white) }
              .allowsHitTesting(false)
              .accessibilityHidden(true)
              .onAppear { shimmerProgress += 1 }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// The whole passage shares one light. Keep the tilt shallow even on a long
/// passage so the light reads as a sweep across the text.
private struct BeadsRecitationSheen: View, Animatable {
  nonisolated var progress: CGFloat

  nonisolated var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  var body: some View {
    Canvas { context, size in
      let band = size.width * BeadsRecitationTextMetrics.shimmerBandWidth
      let slant = BeadsRecitationTextMetrics.shimmerSlant
      let rise = band * slant
      // Include the tilt in the travel so both ends of the cycle are clear
      // across the full height, even when the passage extends off screen.
      let overhang = (band + (size.height + rise) * slant) / 2
      let phase = progress.truncatingRemainder(dividingBy: 1)
      let center = -overhang + phase * (size.width + 2 * overhang)
      let start = CGPoint(x: center - band / 2, y: (size.height + rise) / 2)
      let end = CGPoint(x: center + band / 2, y: (size.height - rise) / 2)
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
        Gradient(colors: [.clear, AppColor.BeadsSession.recitationSheen, .clear]),
        startPoint: start, endPoint: end
      ))
    }
  }
}
