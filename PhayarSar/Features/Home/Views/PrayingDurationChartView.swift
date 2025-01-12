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
//    .id(id)
//    .onAppear {
//      setupWeeklyData()
//      setupMonthlyData()
//      setupYearlyData()
//      id = .init()
//    }
  }
  
  /*
  func setupWeeklyData() {
    let thisWeekData = prayingTimeRepo.prayingDataForThisWeek()
    let totalForThisWeek = thisWeekData.map(\.durationInSeconds).reduce(0, +)
    
    weeklyData = {
      let data: BarDataSet =
      BarDataSet(
        dataPoints: thisWeekData
          .map {
//            let localizedDesc = if $0.durationInSeconds < 60 {
//              $0.durationInSeconds == 0 ? LocalizedKey.second.localize(preferences.appLang) : LocalizedKey.seconds.localize(preferences.appLang)
//            } else if $0.durationInSeconds >= 60 && $0.durationInSeconds < 3600 {
//              $0.durationInSeconds == 60 ? LocalizedKey.minute.localize(preferences.appLang) : LocalizedKey.minutes.localize(preferences.appLang)
//            } else {
//              $0.durationInSeconds == 3600 ? LocalizedKey.hour.localize(preferences.appLang) : LocalizedKey.hours.localize(preferences.appLang)
//            }
            let localizedDesc = $0.durationInSeconds == 0 ? LocalizedKey.second.localize(preferences.appLang) : LocalizedKey.seconds.localize(preferences.appLang)
            return BarChartDataPoint(
              value: Double($0.durationInSeconds),
              xAxisLabel: DaysOfWeek(rawValue: $0.date.toStringWith(.EE).lowercased())!.shortName(appLang: preferences.appLang),
              description: localizedDesc,
              colour: .init(
                colours: [.red, .orange],
                startPoint: .top,
                endPoint: .bottom
              )
            )
          }
      )
      
      let localizedTitle = if totalForThisWeek < 60 {
        LocalizedKey.x_sec.localize(preferences.appLang, args: ["\(totalForThisWeek)"]).orEmpty
      } else if totalForThisWeek >= 60 && totalForThisWeek < 3600 {
        LocalizedKey.x_min.localize(preferences.appLang, args: [localizeNumber(preferences.appLang, str: "\(totalForThisWeek / 60)")]).orEmpty
      } else {
        LocalizedKey.x_hour_y_min.localize(
          preferences.appLang,
          args: [
            localizeNumber(preferences.appLang, str: "\(totalForThisWeek / 3600)"),
            localizeNumber(preferences.appLang, str: "\((totalForThisWeek % 3600) / 60)")
          ]
        ).orEmpty
      }
      
      let metadata = ChartMetadata(
        title: localizedTitle,
        subtitle: LocalizedKey.within_this_week.localize(preferences.appLang).orEmpty + "\n",
        titleFont: .dmSerif(24),
        subtitleFont: .qsB(14),
        subtitleColour: .secondary
      )
      
      let gridStyle = GridStyle(
        numberOfLines: 7,
        lineColour: preferences.accentColor.color.opacity(0.25),
        lineWidth: 0.5,
        dash: [3, 5]
      )
      
      let chartStyle = BarChartStyle(
        infoBoxPlacement: .header,
        infoBoxValueFont: .qsSb(22),
        infoBoxDescriptionFont: .qsSb(14),
        infoBoxDescriptionColour: .secondary,
        markerType: .full(
          colour: preferences.accentColor.color,
          style: .init(lineWidth: 1.5, dash: [3, 5])
        ),
        xAxisGridStyle: gridStyle,
        xAxisLabelPosition: .bottom,
        xAxisLabelFont: .qsB(12),
        xAxisLabelColour: preferences.accentColor.color,
        xAxisLabelsFrom: .dataPoint(rotation: .degrees(0)),
        xAxisTitle: "",
        xAxisTitleFont: .qsSb(12),
        xAxisTitleColour: .secondary,
        yAxisGridStyle: gridStyle,
        yAxisLabelPosition: .leading,
        yAxisLabelFont: .qsB(12),
        yAxisLabelColour: preferences.accentColor.color,
        yAxisNumberOfLabels: 5,
        yAxisTitleFont: .qsSb(12),
        yAxisTitleColour: .secondary,
        baseline: .zero,
        topLine: .maximumValue
      )
      
      return BarChartData(
        dataSets: data,
        metadata: metadata,
        xAxisLabels: [],
        barStyle: BarStyle(
          barWidth: 0.5,
          cornerRadius: CornerRadius(top: 4, bottom: 0),
          colourFrom: .barStyle,
          colour: .init(
            colours: [
              preferences.accentColor.color.opacity(0.8),
              preferences.accentColor.color.opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        ),
        chartStyle: chartStyle
      )
    }()
  }
  
  func setupMonthlyData() {
    let thisMonthData = prayingTimeRepo.prayingDataForThisMonth()
    let totalForThisMonth = thisMonthData.map(\.durationInSeconds).reduce(0, +)
    
    let localizedTitle = if totalForThisMonth < 60 {
      LocalizedKey.x_sec.localize(preferences.appLang, args: ["\(totalForThisMonth)"]).orEmpty
    } else if totalForThisMonth >= 60 && totalForThisMonth < 3600 {
      LocalizedKey.x_min.localize(preferences.appLang, args: [localizeNumber(preferences.appLang, str: "\(totalForThisMonth / 60)")]).orEmpty
    } else {
      LocalizedKey.x_hour_y_min.localize(
        preferences.appLang,
        args: [
          localizeNumber(preferences.appLang, str: "\(totalForThisMonth / 3600)"),
          localizeNumber(preferences.appLang, str: "\((totalForThisMonth % 3600) / 60)")
        ]
      ).orEmpty
    }
    
    let data = LineDataSet(
      dataPoints: thisMonthData.map {
//        let localizedDesc = if $0.durationInSeconds < 60 {
//          $0.durationInSeconds == 0 ? LocalizedKey.second.localize(preferences.appLang) : LocalizedKey.seconds.localize(preferences.appLang)
//        } else if $0.durationInSeconds >= 60 && $0.durationInSeconds < 3600 {
//          $0.durationInSeconds == 60 ? LocalizedKey.minute.localize(preferences.appLang) : LocalizedKey.minutes.localize(preferences.appLang)
//        } else {
//          $0.durationInSeconds == 3600 ? LocalizedKey.hour.localize(preferences.appLang) : LocalizedKey.hours.localize(preferences.appLang)
//        }
        
        let localizedDesc = $0.durationInSeconds == 0 ? LocalizedKey.second.localize(preferences.appLang) : LocalizedKey.seconds.localize(preferences.appLang)
        
        return LineChartDataPoint(
          value: Double($0.durationInSeconds),
          xAxisLabel: "",
          description: localizedDesc,
          pointColour: .init(border: preferences.accentColor.color, fill: preferences.accentColor.color)
        )
      },
      legendTitle: "",
      pointStyle: PointStyle(),
      style: LineStyle(
        lineColour: ColourStyle(colours: [preferences.accentColor.color.opacity(0.8), preferences.accentColor.color.opacity(0.5)], startPoint: .top, endPoint: .bottom),
        lineType: .curvedLine
      )
    )
    
    let xGridStyle = GridStyle(
      numberOfLines: 15,
      lineColour: preferences.accentColor.color.opacity(0.25),
      lineWidth: 0.5,
      dash: [3, 5]
    )
    
    let yGridStyle = GridStyle(
      numberOfLines: 10,
      lineColour: preferences.accentColor.color.opacity(0.25),
      lineWidth: 0.8,
      dash: [3, 5]
    )
    
    self.monthlyData = LineChartData(
      dataSets: data,
      metadata: ChartMetadata(
        title: localizedTitle,
        subtitle: LocalizedKey.within_this_month.localize(preferences.appLang).orEmpty + "\n",
        titleFont: .dmSerif(24),
        subtitleFont: .qsB(14),
        subtitleColour: .secondary
      ),
      xAxisLabels: thisMonthData.map(\.date).map { $0.toStringWith(.d) },
      chartStyle: LineChartStyle(
        infoBoxPlacement: .header,
        infoBoxValueFont: .qsSb(22),
        infoBoxDescriptionFont: .qsSb(14),
        infoBoxDescriptionColour: .secondary,
        markerType: .full(
          attachment: .point,
          colour: preferences.accentColor.color,
          style: .init(lineWidth: 1.5, dash: [3, 5])
        ),
        xAxisGridStyle: xGridStyle,
        xAxisLabelPosition: .bottom,
        xAxisLabelFont: .qsB(8),
        xAxisLabelColour: preferences.accentColor.color,
        xAxisLabelsFrom: .chartData(rotation: .degrees(0)),
        xAxisTitleFont: .qsSb(12),
        xAxisTitleColour: .secondary,
        yAxisGridStyle: yGridStyle,
        yAxisLabelPosition: .leading,
        yAxisLabelFont: .qsB(12),
        yAxisLabelColour: preferences.accentColor.color,
        yAxisNumberOfLabels: 5,
        yAxisTitleFont: .qsSb(12),
        yAxisTitleColour: .secondary,
        baseline: .zero
      )
    )
  }
  
  func setupYearlyData() {
    let thisYearData = prayingTimeRepo.prayingDataForThisYear()
    let totalForThisYear = thisYearData.map(\.1).reduce(0, +)
    
    let localizedTitle = if totalForThisYear < 60 {
      LocalizedKey.x_sec.localize(preferences.appLang, args: ["\(totalForThisYear)"]).orEmpty
    } else if totalForThisYear >= 60 && totalForThisYear < 3600 {
      LocalizedKey.x_min.localize(preferences.appLang, args: [localizeNumber(preferences.appLang, str: "\(totalForThisYear / 60)")]).orEmpty
    } else {
      LocalizedKey.x_hour_y_min.localize(
        preferences.appLang,
        args: [
          localizeNumber(preferences.appLang, str: "\(totalForThisYear / 3600)"),
          localizeNumber(preferences.appLang, str: "\((totalForThisYear % 3600) / 60)")
        ]
      ).orEmpty
    }
    
    let data = LineDataSet(
      dataPoints: thisYearData.map {
//        let localizedDesc = if $0.1 < 60 {
//          $0.1 == 0 ? LocalizedKey.second.localize(preferences.appLang) : LocalizedKey.seconds.localize(preferences.appLang)
//        } else if $0.1 >= 60 && $0.1 < 3600 {
//          $0.1 == 60 ? LocalizedKey.minute.localize(preferences.appLang) : LocalizedKey.minutes.localize(preferences.appLang)
//        } else {
//          $0.1 == 3600 ? LocalizedKey.hour.localize(preferences.appLang) : LocalizedKey.hours.localize(preferences.appLang)
//        }
        let localizedDesc = $0.1 == 0 ? LocalizedKey.second.localize(preferences.appLang) : LocalizedKey.seconds.localize(preferences.appLang)
        
        return LineChartDataPoint(
          value: Double($0.1),
          xAxisLabel: "",
          description: localizedDesc,
          pointColour: .init(border: preferences.accentColor.color, fill: preferences.accentColor.color)
        )
      },
      legendTitle: "",
      pointStyle: PointStyle(),
      style: LineStyle(
        lineColour: ColourStyle(colours: [preferences.accentColor.color.opacity(0.8), preferences.accentColor.color.opacity(0.5)], startPoint: .top, endPoint: .bottom),
        lineType: .curvedLine
      )
    )
    
    let xGridStyle = GridStyle(
      numberOfLines: 15,
      lineColour: preferences.accentColor.color.opacity(0.25),
      lineWidth: 0.5,
      dash: [3, 5]
    )
    
    let yGridStyle = GridStyle(
      numberOfLines: 10,
      lineColour: preferences.accentColor.color.opacity(0.25),
      lineWidth: 0.8,
      dash: [3, 5]
    )
    
    self.yearlyData = LineChartData(
      dataSets: data,
      metadata: ChartMetadata(
        title: localizedTitle,
        subtitle: LocalizedKey.within_this_year.localize(preferences.appLang).orEmpty + "\n",
        titleFont: .dmSerif(24),
        subtitleFont: .qsB(14),
        subtitleColour: .secondary
      ),
      xAxisLabels: thisYearData.map(\.0).map { $0.localize(preferences.appLang).orEmpty },
      chartStyle: LineChartStyle(
        infoBoxPlacement: .header,
        infoBoxValueFont: .qsSb(22),
        infoBoxDescriptionFont: .qsSb(14),
        infoBoxDescriptionColour: .secondary,
        markerType: .full(
          attachment: .point,
          colour: preferences.accentColor.color,
          style: .init(lineWidth: 1.5, dash: [3, 5])
        ),
        xAxisGridStyle: xGridStyle,
        xAxisLabelPosition: .bottom,
        xAxisLabelFont: .qsB(8),
        xAxisLabelColour: preferences.accentColor.color,
        xAxisLabelsFrom: .chartData(rotation: .degrees(0)),
        xAxisTitleFont: .qsSb(12),
        xAxisTitleColour: .secondary,
        yAxisGridStyle: yGridStyle,
        yAxisLabelPosition: .leading,
        yAxisLabelFont: .qsB(12),
        yAxisLabelColour: preferences.accentColor.color,
        yAxisNumberOfLabels: 5,
        yAxisTitleFont: .qsSb(12),
        yAxisTitleColour: .secondary,
        baseline: .zero
      )
    )
  }
   */
}

#Preview {
  PrayingDurationChartView()
    .previewEnvironment()
}

struct Pet {
  let type: String = "house"
}

struct Avatar: View {
  var pet: Pet
  @State private var selected: Bool = false
  
  var body: some View {
    Image(systemName: pet.type)
      .scaleEffect(selected ? 1.5 : 1.0)
      .onTapGesture {
        withAnimation {
          selected.toggle()
        }
      }
  }
}
