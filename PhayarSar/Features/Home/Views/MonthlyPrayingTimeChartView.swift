//
//  MonthlyPrayingTimeChartView.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 11/01/2025.
//

import SwiftUI
import Charts
import CoreData

struct MonthlyPrayingTimeChartView: View {
  private let calendar = Calendar.current
  private let stack = CoreDataStack.shared
  @State private var isFetching = false
  @State private var monthlyData: [DailyPrayingTimeVO] = []
  
  @EnvironmentObject private var preferences: UserPreferences
  
  var body: some View {
    ZStack {
      if isFetching {
        Text("Calclating...⌛")
      } else {
        Chart(monthlyData) { chartMarker in
          let baselineMarker = getBaselineMarker(chartMarker)
          baselineMarker
            .symbol() {
              Circle().strokeBorder(
                preferences.accentColor.color,
                lineWidth: 2
              )
              .background(Circle().foregroundColor(preferences.accentColor.color)).frame(width: 5)
            }

          AreaMark(
            x: .value("Date", chartMarker.date.toStringWith(.d)),
            y: .value("Second", chartMarker.durationInSeconds)
          )
          .interpolationMethod(.monotone)
          .foregroundStyle(
            LinearGradient(
              colors: [
                preferences.accentColor.color.opacity(0.1),
                preferences.accentColor.color.opacity(0.2),
                preferences.accentColor.color.opacity(0.3),
                preferences.accentColor.color.opacity(0.4),
                preferences.accentColor.color.opacity(0.5)
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          )
        }
      }
    }
    .frame(height: 360)
    .task {
      await fetch()
    }
  }
    
  private func getBaselineMarker(_ marker: DailyPrayingTimeVO) -> some ChartContent {
    return LineMark(
      x: .value("Date", marker.date.toStringWith(.d)),
      y: .value("Second", marker.durationInSeconds)
    )
    .lineStyle(.init(lineWidth: 1, lineCap: .round, lineJoin: .round))
    .foregroundStyle(preferences.accentColor.color)
    .interpolationMethod(.monotone)
    .symbolSize(60)
  }
  
  private func fetch() async {
    isFetching = true
    
    Task {
      let fetchRequest = DailyPrayingTime.fetchRequestFor(startDate: Date().startOfMonth, endDate: Date().endOfMonth)
      
      let results = try? stack.viewContext.fetch(fetchRequest)
      
      var dict: [String: DailyPrayingTimeVO] = [:]
      
      for entity in results.orElse([]) {
        let current = dict[entity.date.toStringWith(.ddMMyyyy)]
        
        if current == nil {
          // There is no duplicate, just append the entity
          dict[entity.date.toStringWith(.ddMMyyyy)] = entity.toVO()
        } else {
          dict[entity.date.toStringWith(.ddMMyyyy)] = .init(
            date: entity.date,
            durationInSeconds: (current?.durationInSeconds).orElse(0) + entity.durationInSeconds
          )
        }
      }
      
      var sortedArray = [DailyPrayingTimeVO]()
      for index in 0 ..< Date().getDaysInMonth() {
        let date = calendar.date(byAdding: .day, value: index, to: Date().startOfMonth) ?? .init()
        if let value = dict[date.toStringWith(.ddMMyyyy)] {
          sortedArray.append(value)
        } else {
          sortedArray.append(.init(date: date, durationInSeconds: 0))
        }
      }
      
      let chunkedArray = sortedArray.chunked(into: 2)
        .map { d in
          let total = d.reduce(0) { $0 + $1.durationInSeconds }
          return DailyPrayingTimeVO(date: d[0].date, durationInSeconds: total)
        }
      
      await MainActor.run {
        isFetching = false
        monthlyData = chunkedArray
      }
    }
  }
}
