import SwiftUI

public protocol Component: Sendable {
  associatedtype Data: ComponentData
  associatedtype ViewBody: View
  
  var data: Data { get }
  
  static var kind: ComponentKind { get }
  
  func make() -> ViewBody
  
  init(data: Data)
}

public struct AnyComponent: Sendable, Identifiable {
  private let component: any Component
  public var id: String = UUID().uuidString
  public let kind: ComponentKind
  
  private let _make: @Sendable () -> AnyView
  
  public init<ComponentType>(_ component: ComponentType) where ComponentType: Component {
    self.component = component
    self.kind = ComponentType.kind
    self._make = {
      AnyView(component.make())
    }
  }
  
  public var contentView: AnyView {
    _make()
  }
}

public protocol ComponentData: Sendable, Hashable, Decodable {}

public typealias ComponentKind = String

public extension Component {
  static var kind: ComponentKind {
    String(describing: Self.self).replacingOccurrences(of: "Component", with: "").lowercased()
  }
}
