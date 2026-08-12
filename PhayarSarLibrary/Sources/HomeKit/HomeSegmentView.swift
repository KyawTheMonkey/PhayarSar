import DesignKit
import SwiftUI

struct HomeSegmentView: View {
  @Binding var activeSegment: HomeScreen.Segment

  var body: some View {
//    AppSegmentedPicker(selection: $activeSegment, items: HomeScreen.Segment.allCases, size: .regular) { segment in
//      Text(segment.displayText)
//    }
    Picker("", selection: $activeSegment) {
      Text(HomeScreen.Segment.prayers.displayText)
        .tag(HomeScreen.Segment.prayers)
      
      Text(HomeScreen.Segment.audio.displayText)
        .tag(HomeScreen.Segment.audio)
    }
    .pickerStyle(.segmented)
  }
}
