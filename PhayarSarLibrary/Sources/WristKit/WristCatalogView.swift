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
}
#endif
