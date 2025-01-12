//
//  YearlyPrayingTimeChartView.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 11/01/2025.
//

import SwiftUI
import Charts
import CoreData

struct YearlyPrayingTimeChartView: View {
  private let calendar = Calendar.current
  private let stack = CoreDataStack.shared
  @State private var isFetching = false
  @State private var yearlData: [DailyPrayingTimeVO] = []
  @State private var totalSeconds: Double = 0
  @EnvironmentObject private var preferences: UserPreferences
  
  var body: some View {
    VStack(spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 0) {
          TotalDuration()
            .font(.dmSerif(28))
          LocalizedText(.within_this_year)
            .font(.qsR(10))
        }
        
        Spacer()
      }
      
      ZStack {
        if isFetching {
          Text("Calclating...⌛")
        } else {
          Chart(yearlData) { data in
            ForEach(yearlData) { data in
              BarMark(
                x: .value(
                  "Month",
                  LocalizedKey(
                    rawValue: data.date.toStringWith(.MMM).lowercased()
                  )?.localize(preferences.appLang) ?? ""
                ),
                y: .value("Seconds", Double(data.durationInSeconds) / 60)
              )
              .foregroundStyle(
                by: .value(
                  "Month",
                  LocalizedKey(
                    rawValue: data.date.toStringWith(.MMM).lowercased()
                  )?.localize(preferences.appLang) ?? ""
                )
              )
            }
          }
        }
      }
      .frame(height: 360)
    }
    .task {
      await fetch()
    }
  }
  
  private func fetch() async {
    isFetching = true
    
    Task {
      let calendar = Calendar.current
      let startDate = Date().startOfYear()
      let endDate = Date().endOfYear()
      
      // Fetch data safely
      let fetchRequest = DailyPrayingTime.fetchRequestFor(startDate: startDate, endDate: endDate)
      let results = (try? stack.viewContext.fetch(fetchRequest)) ?? []
      
      // Organize data by date (without string conversion)
      var dailyData: [Date: DailyPrayingTimeVO] = [:]
      for entity in results {
        let date = calendar.startOfDay(for: entity.date)
        dailyData[date, default: .init(date: date, durationInSeconds: 0)].durationInSeconds += entity.durationInSeconds
      }
      
      // Aggregate data monthly
      var monthlyData: [DailyPrayingTimeVO] = []
      var tempMonthly: [DailyPrayingTimeVO] = []
      
      for offset in stride(from: 0, through: Date().getDaysInYear() - 1, by: 1) {
        guard let currentDate = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
        
        // Detect month change and sum up
        if let lastDate = tempMonthly.last?.date, !calendar.isDate(currentDate, equalTo: lastDate, toGranularity: .month) {
          let monthlySum = tempMonthly.reduce(into: 0) { $0 += $1.durationInSeconds }
          monthlyData.append(.init(date: lastDate, durationInSeconds: monthlySum))
          tempMonthly.removeAll()
        }
        
        // Append daily data or zero if missing
        let dayData = dailyData[currentDate] ?? .init(date: currentDate, durationInSeconds: 0)
        tempMonthly.append(dayData)
      }
      
      // Handle the last month data
      if !tempMonthly.isEmpty {
        let lastMonthSum = tempMonthly.reduce(into: 0) { $0 += $1.durationInSeconds }
        monthlyData.append(.init(date: tempMonthly[0].date, durationInSeconds: lastMonthSum))
      }
      
      // Update UI on the main thread
      await MainActor.run {
        isFetching = false
        yearlData = monthlyData
        totalSeconds = Double(yearlData.reduce(0) { $0 + $1.durationInSeconds })
        yearlData.forEach { print($0) }
      }
    }
  }
  
  @ViewBuilder
  private func TotalDuration() -> some View {
    let minutes = totalSeconds / 60
    let hours = minutes / 60
    
    if hours >= 1 {
      LocalizedText(.x_hour_y_min, args: [String(format: "%.0f", hours)])
    }
//    if totalMinutes >= 1 {
//      LocalizedText(.x_min_s, args: [String(format: "%.0f", totalMinutes)])
//    } else {
//      LocalizedText(.x_sec, args: [String(format: "%.0f", totalMinutes * 60)])
//    }
  }
}
