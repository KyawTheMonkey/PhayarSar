import Inject
import SwiftUI

public enum BeadsSessionMetrics {
  public static let horizontalPadding: CGFloat = 24
  public static let verticalPadding: CGFloat = 12
  public static let contentSpacing: CGFloat = 16
  public static let minimumWideWidth: CGFloat = 540
  public static let wideAspectRatio: CGFloat = 1.2
  public static let recitationMaximumWidth: CGFloat = 520
  public static let recitationFraction: CGFloat = 0.34
  public static let wideRecitationFraction: CGFloat = 0.5
  public static let footerSpacing: CGFloat = 8
  public static let actionHeight: CGFloat = 44
  public static let footerAnimation = 0.35
}

/// A tall window stacks the passage above the bead; a wide one puts the
/// passage in the leading column and gives the bead the rest. The two
/// children keep the same position in the same ZStack in both arrangements,
/// so rotating or unfolding a device mid-roll re-flows the frame around a
/// running gesture and a scrolled passage instead of recreating them.
struct BeadsSessionLayout<Recitation: View, Ritual: View>: View {
  @ObserveInjection private var injectionObserver
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  private let recitation: Recitation
  private let ritual: Ritual

  init(@ViewBuilder recitation: () -> Recitation, @ViewBuilder ritual: () -> Ritual) {
    self.recitation = recitation()
    self.ritual = ritual()
  }

  var body: some View {
    GeometryReader { proxy in
      let wide = proxy.size.width >= BeadsSessionMetrics.minimumWideWidth
        && proxy.size.width > proxy.size.height * BeadsSessionMetrics.wideAspectRatio
        && !dynamicTypeSize.isAccessibilitySize
      let spacing = BeadsSessionMetrics.contentSpacing
      let recitationHeight = max(0, proxy.size.height - spacing) * BeadsSessionMetrics.recitationFraction
      let recitationWidth = min(BeadsSessionMetrics.recitationMaximumWidth,
        proxy.size.width * BeadsSessionMetrics.wideRecitationFraction)
      ZStack(alignment: .topLeading) {
        ritual
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(.top, wide ? 0 : recitationHeight + spacing)
          .padding(.leading, wide ? recitationWidth + spacing : 0)

        recitation
          .frame(width: wide ? recitationWidth : nil, height: wide ? nil : recitationHeight, alignment: .top)
          .frame(maxWidth: wide ? nil : .infinity, maxHeight: wide ? .infinity : nil, alignment: .top)
      }
      .padding(.vertical, BeadsSessionMetrics.verticalPadding)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .enableInjection()
  }
}
