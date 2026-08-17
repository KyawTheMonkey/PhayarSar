import DesignKit
import Inject
import KloudKit
import LocalisationKit
import SwiftUI

/// Who the user is, and what the app is keeping on their behalf.
///
/// Reached from two places that are both asking the same question — the avatar
/// button in the home nav bar, and the account row in settings — so it is one
/// screen, presented as a sheet from the first and pushed from the second.
///
/// Laid out as a field of cards rather than as rows, which is the point of the
/// screen existing separately from settings: settings is a column of controls you
/// operate, and this is a set of figures you read. Rows would have made the two
/// indistinguishable, and would have left a destructive action looking exactly
/// like the value it destroys.
///
/// The card count is expected to grow — a daily streak, an activity log — so the
/// grid is measured rather than fixed, and a wider display genuinely gets more
/// columns instead of wider cards. See ``DesignKit/AppCardGrid``.
public struct ProfileScreen: View {
  @ObserveInjection private var injectionObserver

  /// The shared managers are observed directly rather than taken from the
  /// environment — each is a singleton either way, and this matches every other
  /// AuthKit view.
  @ObservedObject private var auth = AuthManager.shared
  @ObservedObject private var kloud = KloudStack.shared

  /// Closes the screen after a sign-out. Works either way it was opened: a
  /// dismiss pops a pushed screen and drops a sheet.
  @Environment(\.dismiss) private var dismiss

  /// `nil` until the first measurement lands. Reads as "not counted yet" rather
  /// than as an empty store, so the card shows a placeholder instead of claiming
  /// zero.
  @State private var footprint: KloudStorageFootprint?
  @State private var isConfirmingSignOut = false
  @State private var didFailToDelete = false

  /// Which category is open, if any, and the records inside it.
  ///
  /// One id rather than a set: two open lists at once would push the figure that
  /// prompted the tap off the screen, and the point of opening one is to compare
  /// its rows against the total.
  @State private var openCategoryID: String?
  @State private var openItems: [KloudStorageItem] = []

  /// The record awaiting confirmation. Held rather than passed to the dialog,
  /// because a `confirmationDialog` is built before the tap that fills it in.
  @State private var pendingDeletion: KloudStorageItem?

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(spacing: Metrics.sectionSpacing) {
        identity
        // Its own row rather than a grid cell: it carries a chart and a list, and
        // half an iPad column is not enough to read either in.
        storageCard
        cards
        signOut
      }
      .padding(.top, Metrics.topPadding)
      .padding(.bottom, Metrics.bottomPadding)
      .appHorizontalInset()
    }
    .navigationTitle(L10n.profile)
    // No navigation bar on macOS, so no display mode to set either.
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    // Re-measured whenever the mirror settles, which is when the number would
    // otherwise be stale: an import brings another device's records down, and an
    // export is what confirms a deletion has actually left.
    .task(id: kloud.syncState) {
      refreshFootprint()
    }
    // A flat fill rather than `appBackground()`'s gradient. The cards are what
    // carry this screen, and they need a plain ground to sit on — a gradient band
    // running behind the first row and not the rest would make two tiles of the
    // same colour look like two different colours.
    .background(AppColor.background.ignoresSafeArea())
    .enableInjection()
  }

  // MARK: - Identity

  /// Not a card. The person is the subject of the screen, not one of the figures
  /// reported on it, and boxing them would put them on the same footing as their
  /// storage usage.
  private var identity: some View {
    VStack(spacing: 20) {
      ProfileAvatarView(size: Metrics.avatarSize)

      Text(name)
        .font(AppFont.title)
        .foregroundStyle(AppColor.textPrimary)
        .multilineTextAlignment(.center)
        // Burmese stacks diacritics above and below the baseline, so the
        // default leading crowds consecutive lines.
        .lineSpacing(6)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(name)
  }

  /// The user's full name, or the closest thing to one. A signed-in user who hid
  /// their name from Apple has none to show, and falls back to how they signed
  /// in — the same ladder ``AccountSection`` uses, so the two screens never
  /// disagree about what to call the same person.
  private var name: String {
    guard auth.isSignedIn else { return L10n.guest }
    return auth.profile?.displayName ?? L10n.signedInWithApple
  }

  // MARK: - Cards

  private var cards: some View {
    AppCardGrid {
      if let memberSince = auth.memberSince {
        memberSinceCard(memberSince)
      }
    }
  }

  // MARK: - Storage

  /// What the app is holding, split by kind, with a way to clear individual
  /// records.
  ///
  /// The chart is the split and nothing more — the breakdown beneath it is what
  /// names each colour and gives its exact size, which is both the legend the
  /// chart needs to be readable and the list the user acts on. Neither half works
  /// alone: a bar with no legend is a decorative stripe, and sizes with no bar
  /// make you do the proportions in your head.
  private var storageCard: some View {
    AppCard {
      cardLabel(L10n.storage)

      if let footprint {
        if footprint.isEmpty {
          nothingToClear
        } else {
          cardValue(formattedSize)
          AppProportionBar(segments: segments(for: footprint))
            .padding(.top, Metrics.chartSpacing)
          breakdown(footprint)
        }

        Text(storageExplanation)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, Metrics.chartSpacing)
      } else {
        // Not "0 bytes" — the count has not finished, and claiming empty would be
        // a different, wrong answer.
        cardValue("—")
      }

      if didFailToDelete {
        Text(L10n.deleteFailed)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.error)
      }
    }
    .confirmationDialog(
      L10n.deleteItemConfirmTitle,
      isPresented: .init(
        get: { pendingDeletion != nil },
        set: { if !$0 { pendingDeletion = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button(L10n.delete, role: .destructive) {
        if let pendingDeletion {
          delete([pendingDeletion.id])
        }
      }
      Button(L10n.cancel, role: .cancel) {}
    } message: {
      Text(deleteExplanation)
    }
  }

  /// The empty state: a status colour with an icon *and* a sentence, never a bare
  /// green dot — the colour is the reassurance, the words are the information.
  private var nothingToClear: some View {
    HStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 22))
        .foregroundStyle(AppColor.success)

      Text(L10n.nothingToClear)
        .font(AppFont.bodySemibold)
        .foregroundStyle(AppColor.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }

  /// The legend and the controls in one list: a swatch, what it is, how much of
  /// it there is, and how many. Tapping opens the records inside.
  @ViewBuilder
  private func breakdown(_ footprint: KloudStorageFootprint) -> some View {
    VStack(spacing: 0) {
      // Not enumerated: the colour comes from the category's own identity, not
      // from its position here — see `color(for:in:)`.
      ForEach(footprint.categories) { category in
        categoryRow(category, color: color(for: category, in: footprint))

        if openCategoryID == category.id {
          itemList
        }
      }
    }
    .padding(.top, Metrics.chartSpacing)
  }

  private func categoryRow(_ category: KloudStorageCategory, color: Color) -> some View {
    Button {
      toggle(category)
    } label: {
      HStack(spacing: 10) {
        // Rounded rather than a circle, so it reads as a piece of the bar above.
        RoundedRectangle(cornerRadius: 3, style: .continuous)
          .fill(color)
          .frame(width: 10, height: 10)

        Text(category.label)
          .font(AppFont.bodySemibold)
          // Text tokens, never the series colour: a coloured label at this size
          // fails contrast, and the swatch already carries the identity.
          .foregroundStyle(AppColor.textPrimary)

        Spacer(minLength: 8)

        Text(itemCount(category.count))
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textTertiary)

        Text(category.bytes.formatted(.byteCount(style: .file)))
          .font(AppFont.body)
          .foregroundStyle(AppColor.textSecondary)
          .monospacedDigit()

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(AppColor.textTertiary)
          .rotationEffect(.degrees(openCategoryID == category.id ? 90 : 0))
      }
      .padding(.vertical, 10)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressableButtonStyle())
  }

  /// The records in the open category, each with its own delete.
  ///
  /// Indented past the swatch column so the rows read as belonging to the
  /// category above rather than as more categories.
  @ViewBuilder
  private var itemList: some View {
    VStack(spacing: 0) {
      ForEach(openItems) { item in
        HStack(spacing: 10) {
          Text(item.title)
            .font(AppFont.body)
            .foregroundStyle(AppColor.textPrimary)
            .lineLimit(1)

          Spacer(minLength: 8)

          Text(item.bytes.formatted(.byteCount(style: .file)))
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textSecondary)
            .monospacedDigit()

          Button {
            pendingDeletion = item
          } label: {
            Image(systemName: "trash")
              .font(.system(size: 15, weight: .medium))
              .foregroundStyle(AppColor.error)
              .frame(width: 32, height: 32)
              .contentShape(Rectangle())
          }
          .buttonStyle(PressableButtonStyle())
          .accessibilityLabel("\(L10n.delete) \(item.title)")
        }
        .padding(.vertical, 2)
      }
    }
    .padding(.leading, Metrics.itemIndent)
    .padding(.bottom, 8)
  }

  private func memberSinceCard(_ date: Date) -> some View {
    AppCard {
      cardLabel(L10n.memberSince)
      // Month and year, not a day: the exact date is a database fact, and
      // "August 2026" is what someone actually wants to know about themselves.
      cardValue(date.formatted(.dateTime.month(.wide).year()))
    }
  }

  /// The quiet uppercase line naming what the card is about, above the figure.
  private func cardLabel(_ text: String) -> some View {
    Text(text)
      .font(AppFont.sectionLabel)
      .textCase(.uppercase)
      .kerning(0.6)
      .foregroundStyle(AppColor.textSecondary)
  }

  /// The figure itself, on the display face and large enough to be the thing the
  /// card is read for.
  private func cardValue(_ text: String) -> some View {
    Text(text)
      .font(AppFont.largeTitle)
      .foregroundStyle(AppColor.textPrimary)
      // A long localised value must wrap rather than shave its own tail off.
      .minimumScaleFactor(0.6)
      .lineLimit(2)
  }

  // MARK: - Chart data

  /// A segment per category, coloured by **which category it is** rather than by
  /// where it landed in the sorted list.
  ///
  /// The distinction matters as soon as anything is deleted: sizes change, the
  /// order changes with them, and a colour taken from the row index would repaint
  /// every surviving segment. Keyed off the category's own identity, "Plans" stays
  /// the same colour whether it is the largest thing stored or the smallest.
  private func segments(for footprint: KloudStorageFootprint) -> [AppProportionSegment] {
    footprint.categories.map { category in
      AppProportionSegment(
        id: category.id,
        value: Double(category.bytes),
        color: color(for: category, in: footprint)
      )
    }
  }

  /// The category's slot in the palette, fixed to its identity.
  ///
  /// Derived from the alphabetical position of the entity name, which is stable
  /// across launches, sync, and deletions — the sorted-by-size order the screen
  /// displays is not.
  private func color(for category: KloudStorageCategory, in footprint: KloudStorageFootprint) -> Color {
    let stableOrder = footprint.categories.map(\.id).sorted()
    guard let slot = stableOrder.firstIndex(of: category.id) else { return AppChartColor.other }
    return AppChartColor.at(slot)
  }

  // MARK: - Actions

  private func toggle(_ category: KloudStorageCategory) {
    guard openCategoryID != category.id else {
      openCategoryID = nil
      openItems = []
      return
    }

    openCategoryID = category.id
    openItems = (try? kloud.storageItems(in: category.id)) ?? []
  }

  /// Last on the screen, and full width, which is where a way out belongs.
  /// Renders nothing for a guest — there is no session to end.
  @ViewBuilder
  private var signOut: some View {
    if auth.isSignedIn {
      AppButton(
        L10n.signOut,
        systemImage: "rectangle.portrait.and.arrow.right",
        kind: .destructive
      ) {
        isConfirmingSignOut = true
      }
      .confirmationDialog(
        L10n.signOutConfirmTitle,
        isPresented: $isConfirmingSignOut,
        titleVisibility: .visible
      ) {
        Button(L10n.signOut, role: .destructive) {
          auth.signOut()
          // The screen's whole subject has just left. Staying open to report
          // "Guest" would be a different screen than the one the user opened.
          dismiss()
        }
        Button(L10n.cancel, role: .cancel) {}
      } message: {
        Text(L10n.signOutConfirmMessage)
      }
    }
  }

  private func refreshFootprint() {
    footprint = try? kloud.storageFootprint()

    // An open list has to be re-read, not kept: its rows are what just changed,
    // and one of them may no longer exist.
    if let openCategoryID {
      openItems = (try? kloud.storageItems(in: openCategoryID)) ?? []
      // The last record of a category takes the category with it, so there is
      // nothing left to be open.
      if openItems.isEmpty { self.openCategoryID = nil }
    }
  }

  /// Deletes specific records, which is the only kind of deletion this screen
  /// does — clearing one plan out of three is the whole point, and "delete
  /// everything" is that same call over a longer list.
  ///
  /// Nothing here can reach the profile record: it declares itself unclearable,
  /// so it never appears in a category and `KloudKit` would skip it even if an id
  /// for it were passed. That is identity rather than content — a name Apple hands
  /// over exactly once — and it is not something a user tidying up is asking to
  /// lose.
  private func delete(_ itemIDs: [String]) {
    didFailToDelete = false
    pendingDeletion = nil

    do {
      try kloud.deleteStorageItems(itemIDs)
    } catch {
      // The underlying Core Data message is not something to put in front of a
      // user; the card says the delete did not happen and the figures, unchanged,
      // agree with it.
      didFailToDelete = true
    }

    refreshFootprint()
  }

  // MARK: - Values

  /// The measured size, or an em dash while the first count is still running.
  ///
  /// Formatted by `ByteCountFormatStyle`, which follows the *device* locale
  /// rather than the app's chosen language — a size is one of the few strings
  /// worth letting the system own, since it has the plural and unit rules for
  /// every locale already.
  private var formattedSize: String {
    guard let footprint else { return "—" }
    return footprint.bytes.formatted(.byteCount(style: .file))
  }

  /// "3 items", or "1 item". Two strings rather than a format with a count,
  /// because the code generator behind `L10n` has no plural support and a
  /// hand-rolled "item(s)" is worse than either.
  private func itemCount(_ count: Int) -> String {
    count == 1 ? L10n.itemCountOne : "\(count) \(L10n.itemCountOther)"
  }

  /// Where the bytes are. Worth saying rather than leaving to the card's label,
  /// because a guest's data is on the device only and no amount of deleting it
  /// frees anything in iCloud they may be worrying about.
  private var storageExplanation: String {
    footprint?.isMirrored == true ? L10n.storageMirroredNote : L10n.storageLocalNote
  }

  /// What the confirmation warns about, which is a different loss in each mode:
  /// a mirrored record is being deleted on every device the user owns, not just
  /// this one.
  private var deleteExplanation: String {
    footprint?.isMirrored == true ? L10n.deleteItemConfirmCloud : L10n.deleteItemConfirmLocal
  }

  // MARK: - Metrics

  private enum Metrics {
    /// Large enough to be the subject of the screen rather than a row's
    /// decoration, which is what the 60pt settings header avatar is.
    static let avatarSize: CGFloat = 96

    /// Sits the avatar clear of the inline title without pinning it to the bar.
    static let topPadding: CGFloat = 32

    /// Clearance under the sign-out button, so it is not flush with the home
    /// indicator on a phone.
    static let bottomPadding: CGFloat = 32

    /// Wider than ``DesignKit/AppCardMetrics/spacing``: the gaps between the
    /// person, their figures, and the way out are gaps between different kinds
    /// of thing, while the gap inside the grid is between tiles of one kind.
    static let sectionSpacing: CGFloat = 32

    /// Space above the chart, and above the caption under it. Wider than
    /// ``DesignKit/AppCardMetrics/contentSpacing`` so the bar reads as its own
    /// band rather than as another line of text.
    static let chartSpacing: CGFloat = 10

    /// Indent for a category's records. Clears the swatch column, so the rows
    /// read as belonging to the category above them.
    static let itemIndent: CGFloat = 20
  }
}

// MARK: - Previews

#Preview {
  NavigationStack {
    ProfileScreen()
  }
}
