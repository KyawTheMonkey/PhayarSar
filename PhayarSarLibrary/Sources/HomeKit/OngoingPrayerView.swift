import DesignKit
import SwiftUI

struct OngoingPrayerView: View {
  var body: some View {
    HStack(spacing: 12) {
      RoundedRectangle(cornerRadius: 16)
        .frame(width: 48, height: 48)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Prayer name 3")
          .font(AppFont.listItemTitle)
          .foregroundStyle(AppColor.textPrimary)
        
        Text("Protection • 3 of 9 verses")
          .font(AppFont.caption)
          .foregroundStyle(AppColor.textSecondary)
          .padding(.bottom, 4)
        
        Capsule()
          .fill(AppColor.grey300)
          .frame(height: 5)
          .overlay(alignment: .leading) {
            Capsule()
              .fill(AppColor.primary)
              .frame(width: 100)
          }
        
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      
      Button {
        
      } label: {
        Image(systemName: "chevron.right")
      }
    }
  }
}
