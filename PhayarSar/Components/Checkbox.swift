//
//  Checkbox.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 12/01/2025.
//

import SwiftUI

struct Checkbox: View {
  let title: String?
  @Binding var value: Bool
  
  init(title: String? = nil, value: Binding<Bool>) {
    self.title = title
    self._value = value
  }
  
  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: value ? "checkmark.square.fill" : "square")
      
      if let title {
        Text(title)
          .font(.qsSb(12))
      }
    }
    .contentShape(.rect)
    .onTapGesture {
      value.toggle()
    }
  }
}
