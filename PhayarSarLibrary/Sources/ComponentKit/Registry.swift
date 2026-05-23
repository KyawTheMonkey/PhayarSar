import SwiftUI

public final class ComponentsRegistry {
  typealias ComponentDecoder = @Sendable (KeyedDecodingContainer<Container.CodingKeys>) throws -> AnyComponent
  
  var decoders: [ComponentKind: ComponentDecoder] = [:]
  
  struct Container: Decodable {
    enum CodingKeys: CodingKey {
      case kind
      case payload
    }
    
    struct ComponentNotFound: Error {
      public var kind: ComponentKind
    }
    
    struct DecodersNotFound: Error {}
    
    static let decodersKey = CodingUserInfoKey(rawValue: "ComponentDecoders")!
    
    let component: AnyComponent
    
    public init(from decoder: any Decoder) throws {
      guard let decoders = decoder.userInfo[Self.decodersKey] as? [ComponentKind: ComponentDecoder] else {
        throw DecodersNotFound()
      }
      
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let kind = try container.decode(ComponentKind.self, forKey: .kind)
      
      guard let factory = decoders[kind] else {
        throw ComponentNotFound(kind: kind)
      }
      
      self.component = try factory(container)
    }
  }
  
  func decode(from data: Data) -> [AnyComponent] {
    do {
      let decoder = JSONDecoder()
      decoder.userInfo[Container.decodersKey] = decoders
      let container = try decoder.decode([Container].self, from: data)
      return container.map(\.component)
    } catch {
      print("Unable to parse \(error)")
      return []
    }
  }
}

public extension Component {
  static func register(in registry: ComponentsRegistry) {
    registry.decoders[kind] = { decoder in
      let data = try decoder.decode(Self.Data.self, forKey: .payload)
      return AnyComponent(Self(data: data))
    }
  }
}
