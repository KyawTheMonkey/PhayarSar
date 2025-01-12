//
//  DailyPrayingTime.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 15/03/2024.
//

import Foundation
import CoreData

struct DailyPrayingTimeVO: Identifiable, Equatable, Hashable, CustomStringConvertible {
  var id = UUID()
  var date: Date
  var durationInSeconds: Int64
  
  var description: String {
    "id: \(id) -- \(date.toStringWith(.ddMMyyyy)):: \(durationInSeconds)s"
  }
}

final class DailyPrayingTime: NSManagedObject {
  @NSManaged var date: Date
  @NSManaged var durationInSeconds: Int64
  
  func toVO() -> DailyPrayingTimeVO {
    .init(date: date, durationInSeconds: durationInSeconds)
  }
}

extension DailyPrayingTime {
  static var timeFetchRequest: NSFetchRequest<DailyPrayingTime> {
    NSFetchRequest(entityName: "DailyPrayingTime")
  }
  
  static func fetchRequestFor(startDate date: Date, endDate: Date, ascending: Bool = true) -> NSFetchRequest<DailyPrayingTime> {
    let req = timeFetchRequest
    req.predicate = NSPredicate(
      format: "date >= %@ AND date <= %@", date as NSDate, endDate as NSDate
    )
    req.sortDescriptors = [
      NSSortDescriptor(key: "date", ascending: ascending)
    ]
    return req
  }
  
  static func today() -> NSFetchRequest<DailyPrayingTime> {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    let request: NSFetchRequest<DailyPrayingTime> = timeFetchRequest
    request.predicate = .init(
      format: "date >= %@ AND date <= %@",
      today as NSDate,
      calendar.date(byAdding: .day, value: 1, to: today)! as NSDate
    )
    return request
  }
  
  static func preview(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) -> DailyPrayingTime {
    let obj = DailyPrayingTime(context: context)
    obj.date = .init()
    obj.durationInSeconds = 120
    return obj
  }
}
