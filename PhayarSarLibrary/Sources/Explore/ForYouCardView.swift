import DesignKit
import Inject
import SwiftUI

struct ForYouCardView: View {
  @ObserveInjection private var injectionObserver

  var body: some View {
    Section {
      VStack {
        Text("something to show off 1")
        Text("something to show off 2")
      }
    } header: {
      Text("On this day")
        .font(AppFont.title2)
        .foregroundStyle(AppColor.textPrimary)
    }
    .enableInjection()
  }
}
