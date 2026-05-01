import DesignKit
import Inject
import SwiftUI

struct ForYouCardView: View {
  @ObserveInjection private var injectionObserver

  var body: some View {
    VStack(alignment: .leading) {
      Text("On this day")
        .font(AppFont.title2)
        .foregroundStyle(AppColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
      
      VStack(alignment: .leading) {
        Text("something to show off 1")
        Text("something to show off 2")
      }
    }
    .enableInjection()
  }
}
