import DesignKit
import SwiftUI

struct HomeSegmentView: View {
  @Binding var activeSegment: HomeScreen.Segment

  var body: some View {
    AppSegmentedPicker(selection: $activeSegment, items: HomeScreen.Segment.allCases, size: .regular) { segment in
      Text(segment.displayText)
    }
  }
}
