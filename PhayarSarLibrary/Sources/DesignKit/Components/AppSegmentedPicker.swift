import SwiftUI
import UtilKit

// MARK: - Size

/// The height and label scale of an `AppSegmentedPicker`.
///
/// Declared at the top level rather than nested inside the generic picker, so
/// call sites don't have to spell out `AppSegmentedPicker<Item, Label>.Size`.
public enum AppSegmentedPickerSize: Sendable {
  /// 44pt — Apple's minimum touch target. Still noticeably taller than the
  /// system `.segmented` picker's ~32pt.
  case regular

  /// 56pt — a prominent, header-weight control.
  case large

  var height: CGFloat {
    switch self {
    case .regular: return 44
    case .large: return 56
    }
  }

  var font: Font {
    switch self {
    case .regular: return AppFont.button
    case .large: return AppFont.headline
    }
  }
}

// MARK: - Metrics

/// Layout constants for `AppSegmentedPicker`. Public because default arguments
/// on a `public init` can't reference `fileprivate` declarations.
public enum AppSegmentedPickerMetrics {
  /// Inset between the track edge and the thumb, on all four sides. Keeps the
  /// two capsules concentric.
  public static let trackPadding: CGFloat = 4

  /// Minimum horizontal breathing room inside a segment, so short labels still
  /// get a thumb wide enough to read as a capsule.
  public static let segmentHorizontalPadding: CGFloat = 12

  static let thumbShadowOpacity: Double = 0.12
  static let thumbShadowRadius: CGFloat = 3
  static let thumbShadowYOffset: CGFloat = 1
}

// MARK: - Picker

/// A capsule-shaped segmented picker, taller than SwiftUI's `.segmented` style
/// and drawn from the app's design tokens.
///
/// The selection thumb slides between segments. On iOS/macOS 26 and later it is
/// interactive Liquid Glass; below that it falls back to a blurred material
/// capsule. Segments are always equal width, the way the system control is.
///
/// ```swift
/// AppSegmentedPicker(selection: $activeSegment, items: Segment.allCases) { segment in
///   Text(segment.displayText)
/// }
/// ```
///
/// Labels are supplied by the caller, so anything that composes in a
/// `ViewBuilder` works — `Text`, `Label`, an icon-only `Image`. The picker
/// applies a font and foreground colour as defaults; content that sets its own
/// wins, per normal SwiftUI environment rules.
///
/// The picker draws no outer horizontal inset — pad it at the call site, with
/// ``SwiftUI/View/appHorizontalInset()`` if it needs to line up with
/// `AppListSection`.
public struct AppSegmentedPicker<Item: Hashable, Label: View>: View {
  @Binding private var selection: Item
  private let items: [Item]
  private let size: AppSegmentedPickerSize
  private let label: (Item) -> Label

  @Namespace private var thumbNamespace
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(
    selection: Binding<Item>,
    items: [Item],
    size: AppSegmentedPickerSize = .large,
    @ViewBuilder label: @escaping (Item) -> Label
  ) {
    self._selection = selection
    self.items = items
    self.size = size
    self.label = label
  }

  /// The height of a segment, so the thumb sits inside the track's padding
  /// rather than adding to the overall height.
  private var segmentHeight: CGFloat {
    size.height - AppSegmentedPickerMetrics.trackPadding * 2
  }

  private var shape: Capsule {
    Capsule(style: .continuous)
  }

  public var body: some View {
    HStack(spacing: 0) {
      ForEach(items, id: \.self) { item in
        segment(for: item)
      }
    }
    .padding(AppSegmentedPickerMetrics.trackPadding)
    .background(track)
    .animation(selectionAnimation, value: selection)
  }

  private var selectionAnimation: Animation? {
    // `.snappy` would suit this better but it's iOS 17 / macOS 14, and the
    // package floor is iOS 16 / macOS 13.
    reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
  }

  private var track: some View {
    // Grey rather than `AppColor.surface` — the surface token is pure white in
    // light mode, which would leave the track indistinguishable from the
    // white/glass thumb sitting on it.
    shape
      .fill(AppColor.grey200)
      .overlay(shape.strokeBorder(AppColor.border, lineWidth: 0.5))
  }

  private func segment(for item: Item) -> some View {
    let isSelected = item == selection

    return Button {
      selection = item
    } label: {
      label(item)
        .font(size.font)
        .foregroundStyle(isSelected ? AppColor.textPrimary : AppColor.textSecondary)
        .lineLimit(1)
        .padding(.horizontal, AppSegmentedPickerMetrics.segmentHorizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: segmentHeight)
        .contentShape(shape)
        .background {
          if isSelected {
            thumb.matchedGeometryEffect(id: Self.thumbID, in: thumbNamespace)
          }
        }
    }
    // Without `.plain`, AppKit draws its own bordered button chrome over the
    // capsule on macOS.
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  private var thumb: some View {
    Color.clear.capsuleGlass()
  }

  private static var thumbID: String { "AppSegmentedPicker.thumb" }
}

// MARK: - Previews

#Preview("Variants") {
  AppSegmentedPickerPreview()
}

private struct AppSegmentedPickerPreview: View {
  private enum Pair: String, CaseIterable {
    case text = "Text"
    case audio = "Audio"
  }

  private enum Trio: String, CaseIterable {
    case rosary = "Rosary"
    case worship = "Worship"
    case paritta = "Paritta"
  }

  private enum Mode: String, CaseIterable {
    case read = "Read"
    case listen = "Listen"
    case chant = "Chant"

    var icon: String {
      switch self {
      case .read: return "book"
      case .listen: return "headphones"
      case .chant: return "waveform"
      }
    }
  }

  @State private var pair: Pair = .text
  @State private var trio: Trio = .rosary
  @State private var mode: Mode = .read
  @State private var iconOnly: Mode = .listen

  /// Fonts are normally registered in `PhayarSarApp.init()`, which previews skip.
  init() {
    Typography.registerFonts()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        labelled("Two segments — .large (default)") {
          AppSegmentedPicker(selection: $pair, items: Pair.allCases) { segment in
            Text(segment.rawValue)
          }
        }

        labelled("Three segments — .large") {
          AppSegmentedPicker(selection: $trio, items: Trio.allCases) { segment in
            Text(segment.rawValue)
          }
        }

        labelled("Three segments — .regular") {
          AppSegmentedPicker(selection: $trio, items: Trio.allCases, size: .regular) { segment in
            Text(segment.rawValue)
          }
        }

        labelled("Icon + text") {
          AppSegmentedPicker(selection: $mode, items: Mode.allCases) { segment in
            Label(segment.rawValue, systemImage: segment.icon)
          }
        }

        labelled("Icon only — .regular") {
          AppSegmentedPicker(selection: $iconOnly, items: Mode.allCases, size: .regular) { segment in
            Image(systemName: segment.icon)
          }
        }
      }
      .appHorizontalInset()
      .padding(.vertical)
    }
    .appBackground()
  }

  private func labelled(
    _ title: String,
    @ViewBuilder content: () -> some View
  ) -> some View {
    VStack(alignment: .leading, spacing: AppListSectionMetrics.labelGap) {
      Text(title)
        .font(AppFont.sectionLabel)
        .textCase(.uppercase)
        .kerning(0.6)
        .foregroundStyle(AppColor.textSecondary)

      content()
    }
  }
}
