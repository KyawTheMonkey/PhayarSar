import DesignKit
import Inject
import SwiftUI

/// The user's picture, everywhere the user is shown.
///
/// ```swift
/// ProfileAvatarView(size: 60)   // settings header
/// ProfileAvatarView(size: 96)   // profile screen
///
/// ProfileAvatarView()           // toolbar button — takes the ambient font
///   .font(.title2)
///   .padding(8)
///   .toolBarButtonCircularGlass()
/// ```
///
/// One view rather than one per screen because the interesting part is not the
/// circle, it is the ladder of fallbacks behind it — picture, then monogram,
/// then a glyph — and three copies of that ladder would drift the first time any
/// rung changed. It reads ``AuthManager`` directly rather than taking a user, so
/// a sign-in or a name arriving from another device redraws every avatar in the
/// app at once.
///
/// Today the picture rung is never taken: Sign in with Apple returns no photo
/// and nothing else writes ``AuthUser/avatarURL``. It is wired up regardless, so
/// that the day a photo has somewhere to come from, this file is the only one
/// that has to know.
public struct ProfileAvatarView: View {
  @ObserveInjection private var injectionObserver

  @ObservedObject private var auth = AuthManager.shared

  /// The diameter, or `nil` for the ambient-font variant — see ``init()``.
  ///
  /// Doubles as which surface to draw. The two are not really independent: the
  /// only caller that wants no tinted circle is the toolbar button, and it is
  /// also the only one that cannot name a size. Splitting them into two
  /// parameters produced combinations no call site ever asked for.
  private let size: CGFloat?

  /// An avatar at a fixed diameter, on a soft tinted circle.
  ///
  /// - Parameter size: Diameter in points. The monogram and the glyph are
  ///   scaled from it, so any size is a usable one.
  public init(size: CGFloat) {
    self.size = size
  }

  /// An avatar that sizes itself from the ambient font, weight and tint —
  /// exactly the way `Image(systemName:)` does, and with no circle of its own.
  ///
  /// For a toolbar button that has to match the glyph buttons beside it. Given
  /// the same font and the same padding it comes out the same size as they do,
  /// by construction rather than by a constant that has to be kept in step, and
  /// it keeps matching them as Dynamic Type moves all three. The host's own
  /// backing — the glass, in the home nav bar — is what the content sits on.
  public init() {
    self.size = nil
  }

  /// Whether this instance draws its own circle behind the content.
  private var isTinted: Bool { size != nil }

  public var body: some View {
    // The glyph is the sizer in every state — hidden, and never the thing on
    // screen. A button must not resize when a photo finishes downloading, and
    // in the ambient variant this is also what pins the view to exactly the
    // footprint an `Image(systemName:)` would have had.
    glyph
      .hidden()
      .frameIfSized(size)
      .overlay {
        content
      }
      .background {
        if isTinted {
          Circle().fill(AppColor.primarySoft)
        }
      }
      .accessibilityHidden(true)
      .enableInjection()
  }

  @ViewBuilder
  private var content: some View {
    if let avatarURL = auth.profile?.avatarURL {
      AsyncImage(url: avatarURL) { image in
        image
          .resizable()
          .scaledToFill()
          // Clipped here rather than around the whole view: a glyph sizes
          // itself to its own box, which is not square, and a circle inscribed
          // in that box would shave the top and bottom off it. Only a picture
          // needs rounding.
          .clipShape(Circle())
      } placeholder: {
        // The fallback rather than a spinner: it is what the circle will settle
        // on if the download fails, so the avatar never flickers through a
        // third state on its way there.
        fallback
      }
    } else {
      fallback
    }
  }

  /// The monogram, or a person glyph when there is no name to take one from —
  /// which is every guest, and any user who hid their name from Apple.
  @ViewBuilder
  private var fallback: some View {
    if let initial {
      monogram(initial)
    } else {
      glyph
    }
  }

  /// The user's initial, on the display face.
  ///
  /// In the ambient variant the letter has to be measured into place rather
  /// than computed: the box is whatever the glyph asked the font for, and only
  /// the layout knows what that came to. Sizing it from the box — rather than
  /// letting it inherit the ambient font outright — is what keeps it on Lora,
  /// so the monogram in the nav bar is the same mark as the one in settings.
  @ViewBuilder
  private func monogram(_ initial: String) -> some View {
    if let size {
      letter(initial, boxSide: size)
    } else {
      GeometryReader { proxy in
        letter(initial, boxSide: min(proxy.size.width, proxy.size.height))
          .frame(width: proxy.size.width, height: proxy.size.height)
      }
    }
  }

  private func letter(_ initial: String, boxSide: CGFloat) -> some View {
    Text(initial)
      .font(AppFont.lora(size: boxSide * monogramScale))
      // Untinted in the ambient variant, so it takes the caller's foreground
      // style along with everything else — the same tint as the glyph it
      // replaces.
      .foregroundStyle(isTinted ? AnyShapeStyle(AppColor.primary) : AnyShapeStyle(.foreground))
      // A tall accent or descender must not push the letter off its own centre.
      .fixedSize()
  }

  /// How much of the box the letter's point size takes up.
  ///
  /// Far larger for the ambient variant because the two boxes mean different
  /// things: a tinted avatar's box is the whole circle, and a monogram that
  /// filled it would crowd the edge, while the ambient box is the glyph's own
  /// tight bounds — the letter has to fill it as completely as the glyph it
  /// stands in for, and the host's padding supplies the breathing room.
  private var monogramScale: CGFloat {
    isTinted ? 0.4 : 0.85
  }

  /// Styled to match its surface — inside the tinted circle it is an avatar's
  /// placeholder — except in the ambient variant, where taking the caller's
  /// font, weight and tint *is* the point.
  @ViewBuilder
  private var glyph: some View {
    let image = Image(systemName: glyphName)

    if let size {
      image
        .font(.system(size: size * glyphScale, weight: .light))
        .foregroundStyle(AppColor.primary)
    } else {
      image
    }
  }

  private var glyphName: String {
    // The tinted circle is already drawn, so its glyph is only the figure
    // inside it; the ambient one has to bring its own ring.
    guard isTinted else { return "person.crop.circle" }
    return auth.isSignedIn ? "person.fill" : "person"
  }

  private var glyphScale: CGFloat { 0.43 }

  private var initial: String? {
    guard
      let name = auth.profile?.displayName,
      let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first
    else {
      return nil
    }

    return String(first).uppercased()
  }
}

// MARK: - Sizing

private extension View {
  /// Pins to a square of `size`, or leaves the view to size itself when there
  /// is none.
  @ViewBuilder
  func frameIfSized(_ size: CGFloat?) -> some View {
    if let size {
      frame(width: size, height: size)
    } else {
      self
    }
  }
}

// MARK: - Previews

#Preview("Sizes") {
  HStack(spacing: 16) {
    ProfileAvatarView()
      .font(.title2)
      .fontWeight(.medium)
      .foregroundStyle(AppColor.textPrimary)
      .padding(8)
      .background(Circle().fill(AppColor.surface))

    ProfileAvatarView(size: 60)
    ProfileAvatarView(size: 96)
  }
  .padding()
}
