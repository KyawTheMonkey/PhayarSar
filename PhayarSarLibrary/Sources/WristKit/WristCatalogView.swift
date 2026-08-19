#if os(watchOS)
import DesignKit
import RemoteKit
import SwiftUI

/// The jump list: every prayer the phone knows about, in reading order.
///
/// The catalog arrives with the state rather than being bundled here — see
/// ``PrayerRemoteState/catalog``. That is what lets the watch app ship without
/// the prayer texts, the Burmese faces they need, or a copy of the catalog that
/// could fall out of step with the phone's after an update to one and not the
/// other.
struct WristCatalogView: View {

  @ObservedObject var remote: WristRemote

  @Environment(\.dismiss) private var dismiss

  private var strings: WristStrings { remote.strings }

  var body: some View {
    List {
      if remote.state.isReaderOpen {
        Section {
          textSizeStepper

          Button(role: .destructive) {
            remote.closeReader()
            dismiss()
          } label: {
            Label(strings.closeReader, systemImage: "xmark")
              .font(AppFont.caption)
          }
        }
      }

      Section {
        ForEach(remote.state.catalog) { entry in
          Button {
            remote.open(prayerID: entry.id)
            // Straight back to the controls: the reader chose a prayer, and
            // what they want next is the page it opened on, not the list they
            // chose it from.
            dismiss()
          } label: {
            HStack(spacing: 8) {
              Text(entry.title)
                .font(AppFont.jasmine(size: WristMetrics.titleSize))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)

              Spacer(minLength: 0)

              if entry.id == remote.state.prayerID {
                Image(systemName: "checkmark")
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(AppColor.primary)
              }
            }
          }
          .buttonStyle(.plain)
        }
      } header: {
        Text(strings.prayers)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textSecondary)
      }
    }
    .navigationTitle(strings.prayers)
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Text size

  /// Sets how large the recited text is on the phone.
  ///
  /// Here rather than on the remote screen because it is a decision made once
  /// at the start of a reading, and the remote screen's room belongs to the
  /// three controls used continuously through one.
  private var textSizeStepper: some View {
    Stepper(value: textSize, in: WristMetrics.textSizeRange, step: WristMetrics.textSizeStep) {
      HStack {
        Text(strings.textSize)
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textSecondary)

        Spacer(minLength: 4)

        Text("\(remote.state.textSize)")
          .font(AppFont.bodySemibold)
          .foregroundStyle(AppColor.textPrimary)
          .monospacedDigit()
      }
    }
    .disabled(!remote.isReachable)
  }

  /// Reads the phone's size and writes a command — with nothing in between.
  ///
  /// The number shown moves only once the phone has said it moved, like every
  /// other value on this watch. It costs a round trip of lag on a control that
  /// is pressed a handful of times, and buys the guarantee that the watch never
  /// shows a size the page is not actually set at — which is what an optimistic
  /// local copy would do every time a command was dropped.
  private var textSize: Binding<Int> {
    Binding(
      get: { remote.state.textSize },
      set: { remote.setTextSize($0) }
    )
  }
}
#endif
