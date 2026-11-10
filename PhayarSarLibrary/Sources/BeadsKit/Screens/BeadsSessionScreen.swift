import DesignKit
import EnvironmentKit
import Inject
import LocalisationKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// The session is the mala, the passage and a quiet count. Progress is
/// carried by the object: counted beads go down the near strand a shade
/// darker, the head bead comes round once a round, and the last bead takes
/// the strand with it. What remains as interface is the number, a hint, the
/// choice of what the mala is made of, and Start again.
public struct BeadsSessionScreen: View {
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var navigator: AppNavigatorModel
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var ambientColorScheme
  @ObservedObject private var theme = ThemeSwitcher.shared
  @ObservedObject private var store = BeadsStore.shared
  @StateObject private var session: BeadsSessionState
  @State private var isVisible = false
  @State private var didEnter = false
  private let beadsID: UUID

  public init(beadsID: UUID) {
    self.beadsID = beadsID
    _session = StateObject(wrappedValue: BeadsSessionState(beadsID: beadsID))
  }

  private var beads: Beads? { store.beads.first { $0.id == beadsID } }
  private var colorScheme: ColorScheme { theme.currentTheme.colorScheme ?? ambientColorScheme }
  private var shape: BeadsSessionShape? {
    beads.map { BeadsSessionShape(count: $0.count, rounds: $0.rounds, completed: $0.completedRecitations) }
  }

  public var body: some View {
    Group {
      if store.didFailToLoad {
        AppEmptyStateView(
          systemImage: "exclamationmark.circle", title: L10n.beadsLoadError,
          actionTitle: L10n.beadsTryAgain, foreground: AppColor.BeadsSession.text, action: store.reload
        )
        .appHorizontalInset()
      } else if let beads {
        content(beads)
          .safeAreaInset(edge: .bottom, spacing: 0) {
            BeadsSessionFooter(motion: session.motion, session: session, beads: beads)
          }
      } else {
        AppEmptyStateView(systemImage: "circle.hexagonpath", title: L10n.beadsSessionNotFound,
          foreground: AppColor.BeadsSession.text)
          .appHorizontalInset()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .modifier(BeadsStageBackdrop(motion: session.motion, stageScheme: colorScheme, material: session.material))
    .foregroundStyle(AppColor.BeadsSession.text)
    .tint(AppColor.BeadsSession.accent)
    .environment(\.colorScheme, colorScheme)
    .navigationTitle(beads?.name ?? AppTab.beads.title)
    .sessionNavigationAppearance(colorScheme)
    .toolbar {
      // The app installs a global UINavigationBarAppearance, which wins over
      // toolbarColorScheme for the title colour. Draw the title ourselves so
      // it is light on the stage like everything else.
      ToolbarItem(placement: .principal) {
        Text(beads?.name ?? AppTab.beads.title)
          .font(AppFont.listItemTitle)
          .foregroundStyle(AppColor.BeadsSession.text)
          .lineLimit(1)
          .accessibilityAddTraits(.isHeader)
      }
      if beads != nil {
        ToolbarItem(placement: .primaryAction) {
          Menu {
            Picker(L10n.beadsMaterial, selection: $session.material) {
              ForEach(BeadsMaterial.allCases) { Text($0.title).tag($0) }
            }
          } label: {
            Image(systemName: "circle.hexagongrid")
          }
          .accessibilityLabel(L10n.beadsMaterial)
        }
        ToolbarItem(placement: .primaryAction) {
          Button { navigator.navigate(to: .beadsEditor(beadsID: beadsID)) } label: {
            Image(systemName: "pencil")
          }
          .accessibilityLabel(L10n.beadsEdit)
        }
      }
    }
    .onAppear {
      store.reload()
      isVisible = true
      // A finished practice is not somewhere to come back to. Entering a set
      // that was completed last time begins it again from the first bead.
      // Only on entry: returning here from the editor must not wipe the
      // finish the person is still looking at.
      if !didEnter {
        didEnter = true
        if let beads, beads.completedRecitations >= beads.count * beads.rounds { session.restart(beads) }
      }
      if let shape { session.motion.sync(shape) }
      updateActivity()
    }
    .onDisappear {
      isVisible = false
      updateActivity()
    }
    .onChange(of: shape) { shape in
      if let shape { session.motion.sync(shape) }
      updateActivity()
    }
    .onChange(of: scenePhase) { _ in updateActivity() }
    .onChange(of: reduceMotion) { _ in updateActivity() }
    .onChange(of: navigator.presentedSheet) { _ in updateActivity() }
    .onChange(of: store.didFailToLoad) { _ in updateActivity() }
    .alert(L10n.beadsSessionSaveError, isPresented: $session.didFailToSave) {
      Button(L10n.done, role: .cancel) {}
    }
    .enableInjection()
  }

  private func content(_ beads: Beads) -> some View {
    BeadsSessionLayout {
      recitation(beads)
    } ritual: {
      BeadsRitualView(motion: session.motion, accessibilityValue: session.accessibilityValue(beads))
        .overlay {
          BeadsSessionCompletion(motion: session.motion, summary: session.completionSummary(beads)) {
            session.restart(beads)
          }
        }
    }
  }

  @ViewBuilder
  private func recitation(_ beads: Beads) -> some View {
    if let recitation = beads.recitation {
      BeadsRecitationText(motion: session.motion, text: recitation.text)
    } else {
      AppButton(
        L10n.beadsSessionAddRecitation, systemImage: "pencil", kind: .secondary,
        foreground: AppColor.BeadsSession.actionText, background: AppColor.BeadsSession.actionSurface
      ) {
        navigator.navigate(to: .beadsEditor(beadsID: beadsID))
      }
      .appHorizontalInset()
    }
  }

  private func updateActivity() {
    let active = isVisible && scenePhase == .active && navigator.presentedSheet == nil
      && beads != nil && !store.didFailToLoad
    session.motion.setActive(active, reduceMotion: reduceMotion)
    #if os(iOS)
    // A prayer takes minutes between touches; the screen must not dim out
    // from under the thumb. Cleared when the session leaves the screen.
    UIApplication.shared.isIdleTimerDisabled = active
    #endif
  }
}

/// The count, the hint, and starting over. Observes the motion model
/// so it alone re-renders when a pull begins or ends; the recitation and the
/// stage have their own observers for the same reason.
private struct BeadsSessionFooter: View {
  @ObserveInjection private var injectionObserver
  @ObservedObject var motion: BeadsRitualMotion
  @ObservedObject var session: BeadsSessionState
  let beads: Beads

  @State private var isConfirmingStartOver = false

  private var hint: String? {
    if motion.isAtHead { return L10n.beadsSessionTurnHint }
    return session.showsHint && motion.completion == .none ? L10n.beadsSessionPullHint : nil
  }

  /// Offered once there is something to start over from, and not after the
  /// finish, where the stage already offers the same thing.
  private var canStartOver: Bool { beads.completedRecitations > 0 && motion.completion == .none }

  var body: some View {
    VStack(alignment: .leading, spacing: BeadsSessionMetrics.footerSpacing) {
      if let hint {
        Text(hint)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.BeadsSession.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
          .transition(.opacity)
      }
      HStack(alignment: .center, spacing: BeadsSessionMetrics.contentSpacing) {
        VStack(alignment: .leading, spacing: BeadsSessionMetrics.footerSpacing / 2) {
          Text(session.progressLabel(beads))
            .font(AppFont.headline)
            .foregroundStyle(AppColor.BeadsSession.text)
            .monospacedDigit()
          if beads.rounds > 1 {
            Text(session.roundLabel(beads))
              .font(AppFont.caption)
              .foregroundStyle(AppColor.BeadsSession.secondaryText)
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.beadsCount)
        .accessibilityValue(session.accessibilityValue(beads))

        Spacer(minLength: 0)

        if canStartOver {
          Button { isConfirmingStartOver = true } label: {
            Label(L10n.beadsSessionStartOver, systemImage: "arrow.counterclockwise")
              .font(AppFont.subheadline)
              .foregroundStyle(AppColor.BeadsSession.secondaryText)
              .frame(minHeight: BeadsSessionMetrics.actionHeight)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .transition(.opacity)
        }
      }
      .frame(minHeight: BeadsSessionMetrics.actionHeight)
    }
    .animation(.easeInOut(duration: BeadsSessionMetrics.footerAnimation), value: hint)
    .animation(.easeInOut(duration: BeadsSessionMetrics.footerAnimation), value: canStartOver)
    .padding(.horizontal, BeadsSessionMetrics.horizontalPadding)
    .padding(.vertical, BeadsSessionMetrics.verticalPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    // Starting over throws away a count that cannot be recovered, and the
    // button sits where a thumb pulling beads can land on it. An alert, not a
    // confirmation dialog: on current iOS a dialog attaches itself to the
    // button as a small popover, which is too slight for a destructive choice.
    .alert(L10n.beadsSessionStartOver, isPresented: $isConfirmingStartOver) {
      Button(L10n.beadsSessionStartOver, role: .destructive) { session.restart(beads) }
      Button(L10n.cancel, role: .cancel) {}
    } message: {
      Text(L10n.beadsSessionStartOverConfirm)
    }
    .enableInjection()
  }
}

public enum BeadsSessionCompletionMetrics {
  public static let spacing: CGFloat = 10
  public static let buttonSpacing: CGFloat = 28
  public static let buttonHorizontalPadding: CGFloat = 26
  public static let buttonHeight: CGFloat = 48
  public static let borderWidth: CGFloat = 1
  public static let borderOpacity = 0.22
  public static let iconSpacing: CGFloat = 8
  public static let rise: CGFloat = 14
  public static let springResponse = 0.7
  public static let springDamping = 0.82
  public static let buttonDelay = 0.18
}

/// What the stage shows once the mala has let go: that the practice is done,
/// how much was said, and one way on. It stands where the mala hung, because
/// that is where the eye already is and the stage would otherwise be empty.
///
/// A bespoke capsule rather than `AppButton`: on this stage a filled button
/// reads as a slab, and the only light meant to be here is on the beads. A
/// hairline in the text colour is enough to make it a control.
private struct BeadsSessionCompletion: View {
  @ObserveInjection private var injectionObserver
  @ObservedObject var motion: BeadsRitualMotion
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let summary: String
  let restart: () -> Void

  private var isShown: Bool { motion.completion == .settled }

  var body: some View {
    VStack(spacing: BeadsSessionCompletionMetrics.spacing) {
      Text(L10n.beadsSessionComplete)
        .font(AppFont.title)
        .foregroundStyle(AppColor.BeadsSession.text)
        .multilineTextAlignment(.center)
      Text(summary)
        .font(AppFont.subheadline)
        .foregroundStyle(AppColor.BeadsSession.secondaryText)
        .monospacedDigit()
      Button(action: restart) {
        HStack(spacing: BeadsSessionCompletionMetrics.iconSpacing) {
          Image(systemName: "arrow.counterclockwise")
          Text(L10n.beadsSessionRestart)
        }
        .font(AppFont.button)
        .foregroundStyle(AppColor.BeadsSession.text)
        .padding(.horizontal, BeadsSessionCompletionMetrics.buttonHorizontalPadding)
        .frame(minHeight: BeadsSessionCompletionMetrics.buttonHeight)
        .background {
          Capsule().strokeBorder(
            AppColor.BeadsSession.text.opacity(BeadsSessionCompletionMetrics.borderOpacity),
            lineWidth: BeadsSessionCompletionMetrics.borderWidth)
        }
        .contentShape(Capsule())
      }
      .buttonStyle(.plain)
      .padding(.top, BeadsSessionCompletionMetrics.buttonSpacing - BeadsSessionCompletionMetrics.spacing)
      .opacity(isShown ? 1 : 0)
      .offset(y: isShown || reduceMotion ? 0 : BeadsSessionCompletionMetrics.rise)
      .animation(appear.delay(isShown ? BeadsSessionCompletionMetrics.buttonDelay : 0), value: isShown)
    }
    .padding(.horizontal, BeadsSessionMetrics.horizontalPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .opacity(isShown ? 1 : 0)
    .offset(y: isShown || reduceMotion ? 0 : BeadsSessionCompletionMetrics.rise)
    .animation(appear, value: isShown)
    .allowsHitTesting(isShown)
    .accessibilityHidden(!isShown)
    .enableInjection()
  }

  private var appear: Animation {
    .spring(response: BeadsSessionCompletionMetrics.springResponse,
      dampingFraction: BeadsSessionCompletionMetrics.springDamping)
  }
}

/// Keep the high-frequency driver in a stable owner without forwarding its
/// objectWillChange. SpriteKit owns frames; reshaping the Burmese recitation
/// and rebuilding the whole screen sixty times a second would waste the same
/// work that the UIKit prayer reader deliberately avoids.
@MainActor
private final class BeadsSessionState: ObservableObject {
  let motion = BeadsRitualMotion()
  @Published var didFailToSave = false
  @Published private(set) var showsHint = !BeadsSessionPreferences.isHintRetired
  @Published var material = BeadsSessionPreferences.material {
    didSet { BeadsSessionPreferences.material = material }
  }
  private let beadsID: UUID

  init(beadsID: UUID) {
    self.beadsID = beadsID
    motion.actions = BeadsRitualActions(
      count: { [weak self] in self?.count() ?? false },
      undo: { [weak self] in self?.undo() ?? false }
    )
    motion.formatNumber = { Beads.roundsNumber($0) }
  }

  private var current: Beads? { BeadsStore.shared.beads.first { $0.id == beadsID } }

  private func count() -> Bool {
    // Resolve again at the instant of the gesture. Two rapid inputs must not
    // both close over an older SwiftUI body and write the same next count.
    guard let current, current.completedRecitations < current.count * current.rounds else { return false }
    guard save(current, completed: current.completedRecitations + 1) else { return false }
    if showsHint {
      showsHint = false
      BeadsSessionPreferences.isHintRetired = true
    }
    return true
  }

  private func undo() -> Bool {
    guard let current, current.completedRecitations > 0 else { return false }
    return save(current, completed: current.completedRecitations - 1)
  }

  func restart(_ beads: Beads) { _ = save(beads, completed: 0) }

  private func save(_ beads: Beads, completed: Int) -> Bool {
    do {
      try BeadsStore.shared.setProgress(id: beads.id, completedRecitations: completed)
      return true
    } catch {
      didFailToSave = true
      return false
    }
  }

  // MARK: - Labels

  func progressLabel(_ beads: Beads) -> String {
    let position = motion.positionInRound
    return L10n.beadsSessionProgress(
      .init(stringLiteral: Beads.roundsNumber(position.count)),
      .init(stringLiteral: Beads.roundsNumber(beads.count))
    )
  }

  func roundLabel(_ beads: Beads) -> String {
    L10n.beadsSessionRound(
      .init(stringLiteral: Beads.roundsNumber(motion.positionInRound.round)),
      .init(stringLiteral: Beads.roundsNumber(beads.rounds))
    )
  }

  /// The whole practice in one line: every bead of every round.
  func completionSummary(_ beads: Beads) -> String {
    let total = L10n.beadsSessionProgress(
      .init(stringLiteral: Beads.roundsNumber(beads.count * beads.rounds)),
      .init(stringLiteral: Beads.roundsNumber(beads.count * beads.rounds))
    )
    return beads.rounds > 1 ? total + " · " + Beads.roundsLabel(for: beads.rounds) : total
  }

  func accessibilityValue(_ beads: Beads) -> String {
    let complete = beads.completedRecitations >= beads.count * beads.rounds
    var parts = [progressLabel(beads)]
    if beads.rounds > 1 { parts.append(roundLabel(beads)) }
    if complete { parts.append(L10n.beadsSessionComplete) }
    return parts.joined(separator: ", ")
  }
}

private extension View {
  @ViewBuilder
  func sessionNavigationAppearance(_ colorScheme: ColorScheme) -> some View {
    #if os(iOS)
    navigationBarTitleDisplayMode(.inline)
      .toolbar(.hidden, for: .tabBar)
      .toolbarBackground(.hidden, for: .navigationBar)
      .toolbarColorScheme(colorScheme, for: .navigationBar)
    #else
    self
    #endif
  }
}

// MARK: - Previews

#Preview("Strand") { BeadsRitualPreview() }

private struct BeadsRitualPreview: View {
  @StateObject private var motion = BeadsRitualMotion()

  init() { Typography.registerFonts() }

  var body: some View {
    BeadsRitualView(motion: motion, accessibilityValue: L10n.beadsCount)
      .modifier(BeadsStageBackdrop(motion: motion, stageScheme: .dark, material: .titanium))
      .onAppear {
        motion.sync(BeadsSessionShape(count: 9, rounds: 3, completed: 3))
        motion.setActive(true, reduceMotion: false)
      }
      .onDisappear { motion.stop() }
  }
}
