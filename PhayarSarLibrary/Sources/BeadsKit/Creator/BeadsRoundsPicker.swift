import DesignKit
import Inject
import LocalisationKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

enum BeadsRoundsPickerMetrics {
  static let controlSize: CGFloat = 44
  static let spacing: CGFloat = 12
  static let controlsSpacing: CGFloat = 8
  static let fieldWidth: CGFloat = 100
  static let disabledOpacity: Double = 0.4
  static let numberTravel: CGFloat = 8
  static let numberDuration: Double = 0.2
  static let reducedMotionDuration: Double = 0.12
  static let labelSpacing: CGFloat = 4
  static let pressedScale: CGFloat = 0.97
  static let twistAngle: CGFloat = .pi * 0.42

}

/// A round is a target, not a completed-practice event. Keep one explicit value
/// beside the controls instead of additive chips that resemble logging actions.
/// Invalid draft text stays visible and disables Save; the last valid target
/// remains available for recovery with either adjustment button.
struct BeadsRoundsPicker: View {
  @ObserveInjection private var injectionObserver
  @ObservedObject private var localisation = LocalisationManager.shared
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Binding var rounds: Int
  @Binding var isValid: Bool
  @State private var enteredRounds: String
  @State private var showsEditor = false
  @State private var displayedRounds: Int
  @State private var isIncreasing = true
  @State private var feedbackSequence = 0
  @State private var previousFeedbackSequence = 0
  @State private var iconTwist: CGFloat = 0
  @State private var tasselSwing: CGFloat = 0
  @State private var lobeAsymmetry: CGFloat = 0
  @State private var strandSway: CGFloat = 0
  #if os(iOS)
  @State private var selectionFeedback = UISelectionFeedbackGenerator()
  #endif
  @FocusState private var isEditing: Bool

  init(rounds: Binding<Int>, isValid: Binding<Bool>) {
    _rounds = rounds
    _isValid = isValid
    _enteredRounds = State(initialValue: Beads.roundsNumber(rounds.wrappedValue))
    _displayedRounds = State(initialValue: rounds.wrappedValue)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: AppListSectionMetrics.labelGap) {
      AppListSection(L10n.beadsRounds) {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: BeadsRoundsPickerMetrics.spacing) {
            target
            Spacer(minLength: BeadsRoundsPickerMetrics.spacing)
            controls
          }
          VStack(alignment: .leading, spacing: BeadsRoundsPickerMetrics.spacing) {
            target
            HStack {
              Spacer()
              controls
            }
          }
        }
      }
      if !isValid {
        Text(L10n.beadsRoundsHint)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.error)
          .padding(.horizontal, AppListSectionMetrics.contentInsets.leading)
          .appHorizontalInset()
      }
    }
    .onChange(of: enteredRounds) { value in
      let parsed = parsedRounds(value)
      isValid = parsed != nil
      if let parsed { rounds = parsed }
    }
    .onChange(of: localisation.currentLanguage) { _ in
      if isValid, !isEditing { enteredRounds = Beads.roundsNumber(rounds) }
    }
    .onChange(of: isEditing) { focused in
      if !focused, isValid {
        showsEditor = false
        presentChange()
      }
    }
    .task(id: MotionTrigger(sequence: feedbackSequence, reduceMotion: reduceMotion)) {
      let previousSequence = previousFeedbackSequence
      previousFeedbackSequence = feedbackSequence
      guard feedbackSequence != previousSequence, !reduceMotion else {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
          iconTwist = 0
          tasselSwing = 0
          lobeAsymmetry = 0
          strandSway = 0
        }
        return
      }
      await animateGesture()
    }
    .onAppear {
      #if os(iOS)
      selectionFeedback.prepare()
      #endif
    }
    .toolbar {
      #if os(iOS)
      ToolbarItemGroup(placement: .keyboard) {
        if isEditing {
          Spacer()
          Button(L10n.done) { isEditing = false }
        }
      }
      #endif
    }
    .enableInjection()
  }

  private var target: some View {
    HStack(spacing: BeadsRoundsPickerMetrics.spacing) {
      rosaryIcon
        .accessibilityHidden(true)

      // The formatted label includes the unit. Only the numeric draft is
      // editable, so switching languages never puts a unit into the parser.
      ZStack(alignment: .leading) {
        valueButton
          .opacity(showsEditor || !isValid ? 0 : 1)
          .allowsHitTesting(!showsEditor && isValid)
          .accessibilityHidden(showsEditor || !isValid)

        if showsEditor || !isValid {
          TextField(L10n.beadsRounds, text: $enteredRounds)
            .textFieldStyle(.plain)
            .font(AppFont.body)
            .foregroundStyle(AppColor.textPrimary)
            .frame(width: BeadsRoundsPickerMetrics.fieldWidth)
            .frame(minHeight: BeadsRoundsPickerMetrics.controlSize)
            .focused($isEditing)
            .onAppear { isEditing = true }
            .roundsKeyboard()
            .onSubmit { isEditing = false }
            .accessibilityLabel(L10n.beadsRounds)
            .accessibilityIdentifier("beads.rounds.input")
        }
      }
    }
  }

  private var valueButton: some View {
    Button {
      enteredRounds = Beads.roundsNumber(rounds)
      showsEditor = true
    } label: {
      HStack(spacing: BeadsRoundsPickerMetrics.labelSpacing) {
        // Reserve the supported range's width so digit boundaries never
        // move the icon, unit, or buttons. Leave vertical overflow visible
        // for stacked Burmese marks during the short number transition.
        Text(Beads.roundsNumber(Beads.roundsRange.upperBound))
          .monospacedDigit()
          .hidden()
          .overlay(alignment: .trailing) {
            ZStack(alignment: .trailing) {
              Text(Beads.roundsNumber(displayedRounds))
                .monospacedDigit()
                .id(displayedRounds)
                .transition(numberTransition)
            }
          }
        Text(L10n.beadsRoundsUnit)
          .hidden()
          .overlay(alignment: .leading) {
            Text(displayedRounds == 1 ? L10n.beadsRoundsUnitOne : L10n.beadsRoundsUnit)
          }
      }
      .font(AppFont.body)
      .foregroundStyle(AppColor.textPrimary)
      .fixedSize(horizontal: true, vertical: true)
      .frame(minHeight: BeadsRoundsPickerMetrics.controlSize)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L10n.beadsRounds)
    .accessibilityValue(Beads.roundsLabel(for: rounds))
    .accessibilityHint(L10n.beadsRoundsEdit)
    .accessibilityIdentifier("beads.rounds")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: adjust(by: 1)
      case .decrement: adjust(by: -1)
      @unknown default: break
      }
    }
  }

  private var numberTransition: AnyTransition {
    guard !reduceMotion else { return .opacity }
    let distance = isIncreasing ? BeadsRoundsPickerMetrics.numberTravel : -BeadsRoundsPickerMetrics.numberTravel
    return .asymmetric(
      insertion: .offset(y: distance).combined(with: .opacity),
      removal: .offset(y: -distance).combined(with: .opacity)
    )
  }

  private var controls: some View {
    HStack(spacing: BeadsRoundsPickerMetrics.controlsSpacing) {
      adjustmentButton(delta: -1)
      adjustmentButton(delta: 1)
    }
  }

  private func adjustmentButton(delta: Int) -> some View {
    let disabled = isValid && (delta < 0
      ? rounds <= Beads.roundsRange.lowerBound
      : rounds >= Beads.roundsRange.upperBound)
    return Button {
      adjust(by: delta)
    } label: {
      Image(systemName: delta < 0 ? "minus" : "plus")
        .font(AppFont.body)
        .foregroundStyle(AppColor.primary)
        .frame(width: BeadsRoundsPickerMetrics.controlSize, height: BeadsRoundsPickerMetrics.controlSize)
        .background(AppColor.primarySoft, in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(PressableButtonStyle(pressedScale: reduceMotion ? 1 : BeadsRoundsPickerMetrics.pressedScale))
    .disabled(disabled)
    .opacity(disabled ? BeadsRoundsPickerMetrics.disabledOpacity : 1)
    .accessibilityLabel(delta < 0 ? L10n.beadsRoundsRemoveOne : L10n.beadsRoundsAddOne)
    .accessibilityValue(Beads.roundsLabel(for: rounds))
    .accessibilityIdentifier(delta < 0 ? "beads.rounds.decrement" : "beads.rounds.increment")
  }

  private func adjust(by delta: Int) {
    rounds = min(max(rounds + delta, Beads.roundsRange.lowerBound), Beads.roundsRange.upperBound)
    enteredRounds = Beads.roundsNumber(rounds)
    isValid = true
    isEditing = false
    showsEditor = false
    presentChange()
  }

  /// The binding tracks valid typed drafts immediately for Save, while visual
  /// feedback follows committed edits only. Direct jumps transition once;
  /// rapid taps retarget the value and cancel the previous twist-release task.
  private func presentChange() {
    guard displayedRounds != rounds else { return }
    isIncreasing = rounds > displayedRounds
    withAnimation(.easeOut(duration: reduceMotion
      ? BeadsRoundsPickerMetrics.reducedMotionDuration
      : BeadsRoundsPickerMetrics.numberDuration
    )) {
      displayedRounds = rounds
    }
    feedbackSequence += 1
    #if os(iOS)
    selectionFeedback.selectionChanged()
    selectionFeedback.prepare()
    #endif
  }

  /// Retarget existing presentation values on another tap. Cancellable delays
  /// keep the previous release from fighting the next gesture. Separate springs
  /// let the lobes bend, the whole strand swing, and the tassel trail it rather
  /// than marching every part through the same symmetric pose at the same time.
  private func animateGesture() async {
    let motion = BeadsRoundsMotion()
    let direction: CGFloat = isIncreasing ? 1 : -1
    withAnimation(.easeOut(duration: motion.windUp)) {
      iconTwist = direction * BeadsRoundsPickerMetrics.twistAngle * motion.amplitude
    }
    withAnimation(.spring(
      response: motion.windUp * BeadsRoundsMotionMetrics.bendWindUpMultiplier,
      dampingFraction: motion.damping
    )) {
      lobeAsymmetry = motion.asymmetry
    }
    do {
      try await Task.sleep(for: .seconds(motion.lag))
      try Task.checkCancellation()
      withAnimation(.spring(
        response: motion.windUp * BeadsRoundsMotionMetrics.swayWindUpMultiplier,
        dampingFraction: motion.damping
      )) {
        strandSway = motion.sway
        tasselSwing = direction * motion.tassel
      }
      try await Task.sleep(for: .seconds(motion.windUp + motion.hold - motion.lag))
      try Task.checkCancellation()
      withAnimation(.spring(response: motion.release, dampingFraction: motion.damping)) {
        iconTwist = 0
      }
      try await Task.sleep(for: .seconds(motion.lag))
      try Task.checkCancellation()
      withAnimation(.spring(
        response: motion.release * BeadsRoundsMotionMetrics.bendReleaseMultiplier,
        dampingFraction: motion.damping
      )) {
        lobeAsymmetry = 0
      }
      withAnimation(.spring(
        response: motion.release * BeadsRoundsMotionMetrics.swayReleaseMultiplier,
        dampingFraction: BeadsRoundsMotionMetrics.secondaryDamping
      )) {
        strandSway = 0
      }
      try await Task.sleep(for: .seconds(motion.lag))
      try Task.checkCancellation()
      withAnimation(.spring(
        response: motion.release * BeadsRoundsMotionMetrics.tasselReleaseMultiplier,
        dampingFraction: BeadsRoundsMotionMetrics.tasselDamping
      )) {
        tasselSwing = 0
      }
    } catch { return }
  }

  private struct MotionTrigger: Hashable {
    let sequence: Int
    let reduceMotion: Bool
  }

  private func parsedRounds(_ input: String) -> Int? {
    let digits = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !digits.isEmpty, digits.allSatisfy({ $0.wholeNumberValue != nil }) else { return nil }
    let normalized = digits.compactMap(\.wholeNumberValue).map(String.init).joined()
    guard let value = Int(normalized), Beads.roundsRange.contains(value) else { return nil }
    return value
  }

  /// A fixed symbolic loop avoids implying that the icon's bead count or
  /// number of loops changes the strand configured by the illustration above.
  private var rosaryIcon: some View {
    BeadsRoundsIcon(
      twist: iconTwist, tasselSwing: tasselSwing,
      asymmetry: lobeAsymmetry, sway: strandSway
    )
      .frame(width: BeadsRoundsIconMetrics.width, height: BeadsRoundsIconMetrics.height)
  }
}

private extension View {
  @ViewBuilder
  func roundsKeyboard() -> some View {
    #if os(iOS)
    keyboardType(.numberPad)
      .submitLabel(.done)
    #else
    self
    #endif
  }
}
