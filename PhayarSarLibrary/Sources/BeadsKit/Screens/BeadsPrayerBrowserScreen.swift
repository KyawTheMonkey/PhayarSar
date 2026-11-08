import DesignKit
import EnvironmentKit
import Inject
import PrayersKit
import SwiftUI

/// The catalog is a detour inside the creator's stack, so cancelling a browse
/// never replaces the active passage or any of the other creator fields.
public struct BeadsPrayerBrowserScreen: View {
  @ObserveInjection private var injectionObserver
  @EnvironmentObject private var navigator: AppNavigatorModel
  @EnvironmentObject private var draft: BeadsRecitationDraft
  @State private var query = ""
  private let sections = PrayerCatalog.shared.sections()

  public init() {}

  private var matchingSections: [PrayerSection] {
    let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return sections.compactMap { section in
      let prayers = section.prayers.filter { search.isEmpty || $0.title.localizedStandardContains(search) }
      return prayers.isEmpty ? nil : PrayerSection(category: section.category, prayers: prayers)
    }
  }

  public var body: some View {
    ScrollView {
      LazyVStack(spacing: AppListSectionMetrics.recommendedSectionSpacing) {
        ForEach(matchingSections) { section in
          AppListSection(section.category.displayText) {
            ForEach(section.prayers) { prayer in
              AppSettingsRow(prayer.title, systemImage: "book") {
                navigator.navigate(to: .beadsPrayerSelection(
                  prayerID: prayer.id,
                  location: draft.passage?.prayerID == prayer.id ? draft.passage?.location : nil
                ))
              }
              if prayer.id != section.prayers.last?.id { AppDivider() }
            }
          }
        }
        if matchingSections.isEmpty {
          AppEmptyStateView(systemImage: "magnifyingglass", title: L10n.beadsPrayerSearchEmpty)
            .appHorizontalInset()
        }
      }
      .padding(.vertical, BeadsCreatorMetrics.verticalPadding)
      .frame(maxWidth: BeadsCreatorMetrics.maxWidth)
      .frame(maxWidth: .infinity)
    }
    .appKeyboardDismissal()
    .appBackground()
    .navigationTitle(L10n.beadsPrayerChoose)
    .searchable(text: $query, prompt: L10n.beadsPrayerSearch)
    .toolbar {
      if draft.commitsRecitationImmediately {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.cancel) { navigator.dismissSheet() }
        }
      }
    }
    .enableInjection()
  }
}
