import DesignKit
import EnvironmentKit
import Inject
import KloudKit
import LocalisationKit
import SwiftUI

/// Who the user is, at the top of the settings screen.
///
/// ```swift
/// ScrollView {
///   VStack(spacing: AppSettingsRowMetrics.groupSpacing) {
///     AccountSection()
///     preferencesGroup
///     AccountSignOutRow()
///   }
/// }
/// ```
///
/// It ships from AuthKit rather than SettingsKit because everything it shows is
/// AuthKit's and KloudKit's — the signed-in profile and the sync state.
/// SettingsKit only decides where on the screen it goes, which is also why
/// signing out is a separate ``AccountSignOutRow``: the reference layout puts it
/// at the bottom of the screen, not next to the name.
///
/// Both halves of "am I signed in" are shown together on purpose. Sign in with
/// Apple and iCloud are different accounts (see ``KloudKit/KloudAccount``), so a
/// user can be signed in here and still have nothing syncing, and the only place
/// they could ever find that out is a row that says so.
public struct AccountSection: View {
  @ObserveInjection private var injectionObserver

  @ObservedObject private var auth = AuthManager.shared
  @ObservedObject private var kloud = KloudStack.shared

  /// `nil` until CloudKit answers. Reads as "no news" rather than "no account" —
  /// the row falls back to the store's own sync state while it is unset.
  @State private var accountStatus: KloudAccountStatus?
  @State private var isSigningIn = false

  private let onAccountSettings: (() -> Void)?

  /// - Parameter onAccountSettings: Opens whatever screen holds the rest of the
  ///   account's settings. The row is only shown when there is something to
  ///   open, and never to a guest, who has no account to configure.
  public init(onAccountSettings: (() -> Void)? = nil) {
    self.onAccountSettings = onAccountSettings
  }

  public var body: some View {
    AppSettingsGroup {
      identity

      if auth.isSignedIn {
        if let onAccountSettings {
          AppSettingsRow(
            L10n.accountSettings,
            systemImage: "person.crop.circle",
            action: onAccountSettings
          )
        }

        AppSettingsRow(
          L10n.icloudSync,
          systemImage: "icloud",
          detail: sync.text,
          detailColor: sync.tint,
          accessory: .none
        )

        if let warning {
          Text(warning)
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.leading, AppSettingsRowMetrics.iconColumn + AppSettingsRowMetrics.iconSpacing)
        }
      }
    }
    // Re-asked whenever the store changes which container it is mirroring to,
    // which is exactly the moment a stale answer would be wrong: signing in
    // moves it from none to one, signing out the other way.
    .task(id: kloud.mode.containerIdentifier) {
      accountStatus = await resolvedAccountStatus()
    }
    .requiresSignIn($isSigningIn, message: L10n.signInSubtitle) { _ in
      // Nothing to do — `AuthManager` republishes, and this view redraws into
      // its signed-in shape on its own.
    }
    .enableInjection()
  }

  // MARK: - Identity

  /// The name block. A button only for a guest, because signing in is the only
  /// thing there is to do here — a signed-in user has no profile to edit, since
  /// Apple owns the name and the email.
  @ViewBuilder
  private var identity: some View {
    if auth.isSignedIn {
      identityLabel
        .accessibilityElement(children: .combine)
    } else {
      Button {
        isSigningIn = true
      } label: {
        identityLabel
      }
      .buttonStyle(PressableButtonStyle())
    }
  }

  private var identityLabel: some View {
    HStack(spacing: 14) {
      avatar

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(AppFont.title)
          .foregroundStyle(AppColor.textPrimary)
          .lineLimit(1)

        HStack(spacing: 4) {
          Text(subtitle)
            .font(AppFont.body)
            .foregroundStyle(AppColor.textSecondary)
            // A private relay address is long enough to push the row wider than
            // the screen on a small phone.
            .lineLimit(1)
            .truncationMode(.middle)

          if !auth.isSignedIn {
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(AppColor.textTertiary)
          }
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.vertical, 12)
    .contentShape(Rectangle())
  }

  /// The user's initial, or a placeholder glyph when there is no name to take
  /// one from — which is every guest, and any user who hid their name from
  /// Apple.
  private var avatar: some View {
    Circle()
      .fill(AppColor.primarySoft)
      .frame(width: 60, height: 60)
      .overlay {
        if let initial {
          Text(initial)
            .font(AppFont.title)
            .foregroundStyle(AppColor.primary)
        } else {
          Image(systemName: auth.isSignedIn ? "person.fill" : "person")
            .font(.system(size: 26, weight: .light))
            .foregroundStyle(AppColor.primary)
        }
      }
      .accessibilityHidden(true)
  }

  private var title: String {
    guard auth.isSignedIn else { return L10n.guest }
    return auth.profile?.displayName ?? L10n.signedInWithApple
  }

  private var subtitle: String {
    guard auth.isSignedIn else { return L10n.signIn }

    if let email = auth.profile?.email { return email }
    // The Apple line has already been used as the title when there is no name,
    // so fall back to what the account is actually doing instead of repeating it.
    return auth.profile?.displayName == nil ? sync.text : L10n.signedInWithApple
  }

  private var initial: String? {
    guard
      let name = auth.profile?.displayName,
      let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first
    else {
      return nil
    }

    return String(first).uppercased()
  }

  // MARK: - Sync status

  /// Shown under the sync row only when there is something the user could act
  /// on. "Up to date" needs no explanation; "not syncing" does.
  private var warning: String? {
    switch accountStatus {
    case .noAccount, .restricted:
      return L10n.icloudUnavailable
    case .needsAttention:
      return L10n.icloudNeedsAttention
    case .available, .unknown, nil:
      return nil
    }
  }

  /// What the sync row says, and in what colour.
  ///
  /// The iCloud account is checked before the store's own state, because a
  /// device with no iCloud account reports a perfectly idle mirror — it just
  /// never mirrors anything. Saying "up to date" there would be a lie.
  private var sync: (text: String, tint: Color) {
    switch accountStatus {
    case .noAccount, .restricted:
      return (L10n.syncOff, AppColor.textSecondary)
    case .needsAttention:
      return (L10n.syncOff, AppColor.warning)
    case .available, .unknown, nil:
      break
    }

    switch kloud.syncState {
    case .idle:
      return (L10n.syncUpToDate, AppColor.textSecondary)
    case .syncing:
      return (L10n.syncInProgress, AppColor.textSecondary)
    case .failed:
      // The underlying message is a CloudKit string in English, and usually
      // something like "request rate limited" — true, unhelpful, and untranslated.
      return (L10n.syncFailed, AppColor.error)
    case .unavailable:
      return (L10n.syncOff, AppColor.warning)
    }
  }

  private func resolvedAccountStatus() async -> KloudAccountStatus? {
    guard let identifier = kloud.mode.containerIdentifier else { return nil }
    return await KloudAccount.status(containerIdentifier: identifier)
  }
}

// MARK: - Sign out

/// The sign-out row, and the confirmation in front of it.
///
/// Renders nothing at all when there is no one to sign out, so a settings screen
/// can place it unconditionally rather than branching around it.
public struct AccountSignOutRow: View {
  @ObserveInjection private var injectionObserver

  @ObservedObject private var auth = AuthManager.shared
  @State private var isConfirming = false

  public init() {}

  public var body: some View {
    if auth.isSignedIn {
      AppSettingsGroup {
        AppSettingsRow(
          L10n.signOut,
          systemImage: "rectangle.portrait.and.arrow.right",
          accessory: .none,
          emphasis: .destructive
        ) {
          isConfirming = true
        }
      }
      .confirmationDialog(
        L10n.signOutConfirmTitle,
        isPresented: $isConfirming,
        titleVisibility: .visible
      ) {
        Button(L10n.signOut, role: .destructive) { auth.signOut() }
        Button(L10n.cancel, role: .cancel) {}
      } message: {
        Text(L10n.signOutConfirmMessage)
      }
      .enableInjection()
    }
  }
}

// MARK: - Previews

#Preview {
  ScrollView {
    VStack(spacing: AppSettingsRowMetrics.groupSpacing) {
      AccountSection()
      AccountSignOutRow()
    }
    .padding(.vertical)
  }
}
