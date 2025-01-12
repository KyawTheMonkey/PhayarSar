//
//  DailyPrayingTimeChartView.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 11/01/2025.
//

import SwiftUI
import Charts
import CoreData

struct DailyPrayingTimeChartView: View {
  private let calendar = Calendar.current
  private let stack = CoreDataStack.shared
  @State private var isFetching = false
  @State private var weekData = [DailyPrayingTimeVO]()
  @EnvironmentObject private var preferences: UserPreferences

  var body: some View {
    ZStack {
      if isFetching {
        Text("Calclating...⌛")
      } else {
        Chart {
          ForEach(weekData) { data in
            BarMark(x: .value("Day of Week", data.date.toStringWith(.EE)),
                    y: .value("Seconds", data.durationInSeconds))
            .foregroundStyle(preferences.accentColor.color)
          }
        }
      }
    }
    .frame(height: 360)
    .task {
      await fetch()
    }
  }
  
  private func fetch() async {
    isFetching = true
    
    Task {
      let endDate = Date()
      let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? .init()
      
      let fetchRequest = DailyPrayingTime.fetchRequestFor(startDate: startDate, endDate: endDate)
      let results = try? stack.viewContext.fetch(fetchRequest)
      
      var dict: [String: DailyPrayingTimeVO] = [:]
      
      for entity in results.orElse([]) {
        let current = dict[entity.date.toStringWith(.ddMMyyyy)]
        
        if current == nil {
          // There is no duplicate, just append the entity
          dict[entity.date.toStringWith(.ddMMyyyy)] = entity.toVO()
        } else {
          // There is a duplicate, add `durationInSeconds` to the original model
          dict[entity.date.toStringWith(.ddMMyyyy)] = .init(
            date: entity.date,
            durationInSeconds: (current?.durationInSeconds).orElse(0) + entity.durationInSeconds
          )
        }
      }
      
      var sortedArray = [DailyPrayingTimeVO]()
      
      for index in 1 ... 7 {
        let date = calendar.date(byAdding: .day, value: index, to: startDate) ?? .init()
        if let value = dict[date.toStringWith(.ddMMyyyy)] {
          sortedArray.append(value)
        } else {
          sortedArray.append(.init(date: date, durationInSeconds: 0))
        }
      }

      await MainActor.run {
        weekData = sortedArray
        isFetching = false
      }
    }
  }
}
