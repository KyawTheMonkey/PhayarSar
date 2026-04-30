import SwiftUI

struct PhayarSarMainTabView: View {
  var body: some View {
    if #available(iOS 18.0, *) {
      
    } else {
      
    }
  }
  
  @ViewBuilder
  private func TabView_iOS18() -> some View {
    TabView {

    }
  }
  
  @ViewBuilder
  private func TabView_Old() -> some View {
    
  }
}

#Preview {
  PhayarSarMainTabView()
}
