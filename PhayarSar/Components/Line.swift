//
//  Line.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 12/01/2025.
//

import SwiftUI

struct Line: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: .init(x: rect.minX, y: rect.midY))
      path.addLine(to: .init(x: rect.maxX, y: rect.midY))
    }
  }
}
