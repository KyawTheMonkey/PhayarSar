import DesignKit
import EnvironmentKit
import Inject
import SwiftUI

/// One thing the app wants to tell the user, and what it wants them to do next.
///
/// ```swift
/// .sheet(isPresented: $hasAnnouncement) {
///   AnnouncementScreen(
///     badge: L10n.new,
///     title: announcement.title,
///     message: announcement.body,
///     primaryTitle: announcement.actionTitle,
///     onPrimary: { open(announcement.link) },
///     onClose: { hasAnnouncement = false }
///   )
/// }
/// ```
///
/// One message, one primary action. An announcement carrying two things is two
/// announcements, and a screen that fits them both is a screen the user will
/// dismiss without reading either.
///
/// The copy comes from the caller, which is what lets the same screen serve a
/// remote-config announcement, a seasonal message, and a one-off notice without
/// any of them being compiled in.
///
/// Sized to work either as a `fullScreenCover` or as a `.sheet` with
/// `.presentationDetents([.medium])` — the content is centred and scrolls, so
/// neither height strands the buttons.
public struct AnnouncementScreen: View {
  @ObserveInjection private var injectionObserver

  private let systemImage: String
  private let badge: String?
  private let title: String
  private let message: String
  private let primaryTitle: String
  private let onPrimary: () -> Void
  private let secondaryTitle: String?
  private let onSecondary: (() -> Void)?
  private let onClose: (() -> Void)?

  /// - Parameters:
  ///   - systemImage: Override when the announcement has a better symbol than a
  ///     megaphone — a gift for a giveaway, a calendar for a festival day.
  ///   - badge: A short pill above the title, e.g. "NEW". Omit it for anything
  ///     that is not actually new; a badge on every announcement stops meaning
  ///     anything.
  ///   - title: Already localised — pass `L10n.something`, not a raw string.
  ///   - message: The announcement itself. Long copy scrolls rather than
  ///     truncating, but an announcement that needs scrolling is usually a
  ///     screen of its own.
  ///   - onPrimary: What the announcement is asking for. Dismissing afterwards
  ///     is the caller's decision — some actions should leave the screen up.
  ///   - onSecondary: The considered "no". Distinct from `onClose`, which is
  ///     "not now" — the caller can tell the two apart and often needs to.
  ///   - onClose: Omit for an announcement the user must answer. Given, it puts
  ///     a close button in the corner.
  public init(
    systemImage: String = "megaphone.fill",
    badge: String? = nil,
    title: String,
    message: String,
    primaryTitle: String,
    onPrimary: @escaping () -> Void,
    secondaryTitle: String? = nil,
    onSecondary: (() -> Void)? = nil,
    onClose: (() -> Void)? = nil
  ) {
    self.systemImage = systemImage
    self.badge = badge
    self.title = title
    self.message = message
    self.primaryTitle = primaryTitle
    self.onPrimary = onPrimary
    self.secondaryTitle = secondaryTitle
    self.onSecondary = onSecondary
    self.onClose = onClose
  }

  public var body: some View {
    MiscStatusLayout(
      systemImage: systemImage,
      badge: badge,
      title: title,
      message: message
    ) {
      AppButton(primaryTitle, action: onPrimary)

      if let secondaryTitle, let onSecondary {
        AppButton(secondaryTitle, kind: .plain, action: onSecondary)
      }
    }
    // Overlaid rather than stacked above the layout, so the close button does
    // not take height from content that is already centring itself.
    .overlay(alignment: .topTrailing) {
      if let onClose {
        MiscCloseButton(action: onClose)
          .padding(Metrics.closeInset)
      }
    }
    .enableInjection()
  }

  // MARK: - Metrics

  private enum Metrics {
    static let closeInset: CGFloat = 8
  }
}

// MARK: - Previews

#Preview("With badge and close") {
  AnnouncementScreen(
    badge: "New",
    title: "Nissaya translations are here",
    message: "Every prayer in the library now has a word-by-word Burmese translation lined up with the Pali.",
    primaryTitle: "Take a look",
    onPrimary: {},
    onClose: {}
  )
}

#Preview("Must answer") {
  AnnouncementScreen(
    systemImage: "icloud.fill",
    title: "Turn on syncing?",
    message: "Your prayers, bookmarks and reading themes can follow you to every device you sign in on.",
    primaryTitle: "Turn on syncing",
    onPrimary: {},
    secondaryTitle: "Keep everything on this device",
    onSecondary: {}
  )
}

#Preview("As a sheet") {
  Color.clear
    .sheet(isPresented: .constant(true)) {
      AnnouncementScreen(
        badge: "New",
        title: "Reading themes",
        message: "Save the paper, type size and spacing you read best in.",
        primaryTitle: "Try it",
        onPrimary: {},
        onClose: {}
      )
      .presentationDetents([.medium])
    }
}
