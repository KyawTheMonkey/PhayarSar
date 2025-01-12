//
//  PrayingDurationChartView.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 15/03/2024.
//

import SwiftUI
import SwiftUICharts

enum PrayingDurationChartSegment: String, CaseIterable, Identifiable {
  var id: String { self.rawValue }
  
  case weekly
  case monthly
  case yearly
  
  var key: LocalizedKey {
    return .init(rawValue: self.rawValue) ?? .weekly
  }
}

struct PrayingDurationChartView: View {
  @State private var id = UUID()
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var preferences: UserPreferences
  @EnvironmentObject private var prayingTimeRepo: DailyPrayingTimeRepository
  
  @State private var selectedMode = PrayingDurationChartSegment.weekly
    
  var body: some View {
    VStack {
      Picker("", selection: $selectedMode) {
        ForEach(PrayingDurationChartSegment.allCases) { segment in
          LocalizedText(segment.key)
            .tag(segment)
        }
      }
      .pickerStyle(.segmented)
      
      if selectedMode == .weekly {
        DailyPrayingTimeChartView()
      }
      
      if selectedMode == .monthly {
        MonthlyPrayingTimeChartView()
      }
      
      if selectedMode == .yearly {
        YearlyPrayingTimeChartView()
      }
    }
  }
}

#Preview {
  PrayingDurationChartView()
    .previewEnvironment()
}
