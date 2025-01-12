//
//  DailyPrayingTimeRepository.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 15/03/2024.
//

import SwiftUI
import CoreData

@MainActor
final class DailyPrayingTimeRepository: ObservableObject {
  @Published var prayingTimes: [DailyPrayingTime] = []
  @Published var today: DailyPrayingTime!
  
  private var timeInterval = Date().timeIntervalSince1970
  
  private let stack = CoreDataStack.shared
  private let calendar = Calendar.current
  private lazy var moc = stack.viewContext
  
  init() {
    do {
      try fetchPrayingTimes()
    } catch {
      print(error)
    }
  }
  
  func fetchPrayingTimes() throws {
    let request = DailyPrayingTime.timeFetchRequest
    prayingTimes = try moc.fetch(request)
    
    let datesFor2024 = getAllDatesForYear(year: 2024)
    if prayingTimes.isEmpty {
      try datesFor2024
        .map {
          let obj = DailyPrayingTime(context: moc)
          obj.date = $0
          obj.durationInSeconds = 0
          return obj
        }
        .forEach { _ in
          try moc.save()
        }
      
      prayingTimes = try moc.fetch(request)
    }

    if let today = prayingTimes.first(where: { calendar.isDateInToday($0.date) }) {
      self.today = today
    } else {
      let today = DailyPrayingTime(context: moc)
      today.date = .init()
      today.durationInSeconds = 0
      self.today = today
    }
  }
  
  func startRecordingTime() {
    timeInterval = Date().timeIntervalSince1970
  }
  
  func stopRecordingTime() {
    today.durationInSeconds += Int64(Date().timeIntervalSince1970 - timeInterval)
    do {
      try moc.save()
      withAnimation {
        today = today
      }
    } catch {
      print(error)
    }
  }
  
  func prayingDataForThisWeek() -> [DailyPrayingTime] {
    let date = Date().toStringWith(.EE) == "Sun" ? calendar.date(byAdding: .day, value: -1, to: .init())! : .init()
    return prayingTimes
      .filter { (date.startOfWeek ... date.endOfWeek).contains($0.date) }
      .sorted(by: { $1.date > $0.date })
  }
  
  func prayingDataForThisMonth() -> [DailyPrayingTime] {
    prayingTimes
      .filter { (Date().startOfMonth ... Date().endOfMonth).contains($0.date) }
      .sorted(by: { $1.date > $0.date })
  }
  
  private func getFirstAndLastDayOfMonth(year: Int) -> [(firstDay: Date, lastDay: Date)] {
    var result: [(firstDay: Date, lastDay: Date)] = []
    
    // Create a calendar instance
    let calendar = Calendar.current
    
    // Iterate through each month (1 to 12) in the given year
    for month in 1...12 {
      // Create date components for the first day of the month
      var firstDayComponents = DateComponents()
      firstDayComponents.year = year
      firstDayComponents.month = month
      firstDayComponents.day = 1
      let firstDayOfMonth = calendar.date(from: firstDayComponents)!
      
      // Determine the last day of the month
      let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
      let lastDayOfMonth = calendar.date(byAdding: .day, value: range.count - 1, to: firstDayOfMonth)!
      
      // Add the first and last day of the month to the result array as a tuple
      result.append((firstDayOfMonth, lastDayOfMonth))
    }
    
    return result
  }
  
  private func getAllDatesForYear(year: Int) -> [Date] {
      var datesArray = [Date]()
      
      // Create a calendar instance
      let calendar = Calendar.current
      
      // Create date components for January 1st of the specified year
      var dateComponents = DateComponents()
      dateComponents.year = year
      dateComponents.month = 1
      dateComponents.day = 1
      
      // Get the start date of the year
      guard let startDate = calendar.date(from: dateComponents) else {
          return datesArray
      }
      
      // Create date components for December 31st of the specified year
      dateComponents.month = 12
      dateComponents.day = 31
      
      // Get the end date of the year
      guard let endDate = calendar.date(from: dateComponents) else {
          return datesArray
      }
      
      // Iterate through each day of the year and add it to the datesArray
      var currentDate = startDate
      while currentDate <= endDate {
          datesArray.append(currentDate)
          currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
      }
      
      return datesArray
  }

}
