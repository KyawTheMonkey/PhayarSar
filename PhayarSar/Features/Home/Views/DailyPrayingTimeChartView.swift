//
//  DailyPrayingTimeChartView.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 11/01/2025.
//

import SwiftUI
import Charts
import CoreData

struct Line: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: .init(x: rect.minX, y: rect.midY))
      path.addLine(to: .init(x: rect.maxX, y: rect.midY))
    }
  }
}

struct DailyPrayingTimeChartView: View {
  private let calendar = Calendar.current
  private let stack = CoreDataStack.shared
  @State private var isFetching = false
  @State private var weekData = [DailyPrayingTimeVO]()
  @State private var totalSeconds = 0
  @State private var showAverage = false
  @EnvironmentObject private var preferences: UserPreferences
  
  var body: some View {
    VStack(spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 0) {
          LocalizedText(.x_sec, args: ["\(totalSeconds)"])
            .font(.dmSerif(28))
          LocalizedText(.within_this_week)
            .font(.qsR(10))
        }
        
        Spacer()
        
        Checkbox(title: "Show Avg.", value: $showAverage)
      }
      ZStack {
        if isFetching {
          Text("Calclating...⌛")
        } else {
          Chart {
            ForEach(weekData) { data in
              BarMark(
                x: .value(
                  "Day of Week",
                  DaysOfWeek(
                    rawValue: data.date.toStringWith(.EE).lowercased()
                  )?.shortName(appLang: preferences.appLang) ?? ""
                ),
                y: .value("Seconds", data.durationInSeconds)
              )
              .foregroundStyle(
                by: .value("Day of Week", DaysOfWeek(rawValue: data.date.toStringWith(.EE).lowercased())?.shortName(appLang: preferences.appLang) ?? "")
              )
            }
            
            RuleMark(y: .value("Average", Double(totalSeconds) / 7))
              .lineStyle(.init(lineWidth: 1.5, dash: [5], dashPhase: 3))
              .foregroundStyle(.blue)
              .annotation(alignment: .trailing) {
                Text("\(totalSeconds / 7) sec")
                  .foregroundStyle(.black)
                  .font(.qsB(8))
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background {
                    RoundedRectangle(cornerRadius: 4)
                      .fill(.white)
                      .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 0)
                  }
                  .opacity(showAverage ? 1 : 0)
              }
              .opacity(showAverage ? 1 : 0)
          }
        }
      }
      .frame(height: 350)
    }
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
        totalSeconds = Int(sortedArray.reduce(0) { $0 + $1.durationInSeconds })
        isFetching = false
      }
    }
  }
}

#Preview {
  DailyPrayingTimeChartView()
    .previewEnvironment()
}
