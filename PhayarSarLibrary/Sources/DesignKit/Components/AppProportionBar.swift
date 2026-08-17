import SwiftUI

// MARK: - Segment

/// One slice of an ``AppProportionBar``.
public struct AppProportionSegment: Identifiable, Equatable {
  public let id: String
  /// Any non-negative magnitude — the bar normalises against the total, so these
  /// can be bytes, counts, or seconds without being scaled first.
  public let value: Double
  public let color: Color

  public init(id: String, value: Double, color: Color) {
    self.id = id
    self.value = value
    self.color = color
  }
}

// MARK: - Metrics

public enum AppProportionBarMetrics {
  /// Thin. The bar answers "roughly how is this split", and height it does not
  /// need only takes emphasis from the figures beside it.
  public static let height: CGFloat = 12

  /// Gap between segments, in the surface colour behind the bar.
  ///
  /// The reason two adjacent segments are always distinguishable even when their
  /// hues are close for a colour-blind reader: there is a visible seam whether or
  /// not the colours separate.
  public static let segmentGap: CGFloat = 2

  /// No segment is ever drawn thinner than this, however small its share.
  ///
  /// A category holding 40 bytes next to one holding 40 kilobytes would round to
  /// nothing and vanish from a chart that is meant to be an inventory — the user
  /// would have no way to see the thing they came to delete. The distortion is
  /// deliberate and bounded, and exact figures are in the legend beside it, which
  /// is where anyone comparing sizes is reading anyway.
  public static let minimumSegmentWidth: CGFloat = 6
}

// MARK: - Bar

/// A single bar split into proportional segments — a part-to-whole picture of a
/// handful of categories.
///
/// ```swift
/// AppProportionBar(segments: categories.enumerated().map { index, category in
///   AppProportionSegment(
///     id: category.id,
///     value: Double(category.bytes),
///     color: AppChartColor.at(index)
///   )
/// })
/// ```
///
/// **Always pair it with a legend** that names each segment and gives its value.
/// The bar shows the split; it cannot show which slice is which, and the segment
/// colours are validated on the assumption that a second cue is present — see
/// ``AppChartColor``.
///
/// Not a chart for comparing across time or for precise reading: at this height,
/// with a minimum segment width, it is a shape you glance at. Anything needing
/// real comparison wants axes.
public struct AppProportionBar: View {
  private let segments: [AppProportionSegment]

  public init(segments: [AppProportionSegment]) {
    self.segments = segments
  }

  private var total: Double {
    segments.reduce(0) { $0 + max($1.value, 0) }
  }

  public var body: some View {
    GeometryReader { proxy in
      HStack(spacing: AppProportionBarMetrics.segmentGap) {
        ForEach(widths(in: proxy.size.width), id: \.segment.id) { sized in
          Rectangle()
            .fill(sized.segment.color)
            .frame(width: sized.width)
        }
      }
      // Rounds the two outer ends and leaves the inner seams square, which is
      // what makes the run read as one bar divided rather than as a row of
      // separate pills.
      .clipShape(Capsule(style: .continuous))
    }
    .frame(height: AppProportionBarMetrics.height)
    // The bar is a picture of the legend below it, which carries the same
    // information in text — announcing it twice would only slow VoiceOver down.
    .accessibilityHidden(true)
  }

  /// Segment widths for a given bar width.
  ///
  /// Small segments are floored first, then what they borrowed is taken back out
  /// of the space the rest share — otherwise the floors would push the total past
  /// the bar's width and the last segment would be clipped away.
  private func widths(in barWidth: CGFloat) -> [(segment: AppProportionSegment, width: CGFloat)] {
    guard total > 0, barWidth > 0, !segments.isEmpty else { return [] }

    let gaps = CGFloat(segments.count - 1) * AppProportionBarMetrics.segmentGap
    let available = max(barWidth - gaps, 0)

    let raw = segments.map { available * CGFloat(max($0.value, 0) / total) }
    let floor = AppProportionBarMetrics.minimumSegmentWidth

    let deficit = raw.reduce(CGFloat(0)) { $0 + max(floor - $1, 0) }
    let surplus = raw.reduce(CGFloat(0)) { $0 + max($1 - floor, 0) }

    // Nothing to redistribute from — every segment is at or under the floor, so
    // share the bar equally rather than overflowing it.
    guard surplus > 0 else {
      let equal = available / CGFloat(segments.count)
      return zip(segments, raw).map { ($0.0, equal) }
    }

    let scale = max(1 - deficit / surplus, 0)

    return zip(segments, raw).map { segment, width in
      guard width > floor else { return (segment, floor) }
      return (segment, floor + (width - floor) * scale)
    }
  }
}

// MARK: - Previews

#Preview("Splits") {
  VStack(alignment: .leading, spacing: 24) {
    AppProportionBar(segments: [
      AppProportionSegment(id: "a", value: 96, color: AppChartColor.at(0)),
      AppProportionSegment(id: "b", value: 52, color: AppChartColor.at(1)),
      AppProportionSegment(id: "c", value: 12, color: AppChartColor.at(2)),
    ])

    // The lopsided case the minimum width exists for.
    AppProportionBar(segments: [
      AppProportionSegment(id: "a", value: 40_000, color: AppChartColor.at(0)),
      AppProportionSegment(id: "b", value: 40, color: AppChartColor.at(1)),
    ])

    AppProportionBar(segments: [
      AppProportionSegment(id: "a", value: 1, color: AppChartColor.at(0)),
    ])
  }
  .padding()
  .background(AppColor.surface)
}
