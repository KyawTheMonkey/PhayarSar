// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "PhayarSarLibrary",
  platforms: [.iOS(.v16), .macOS(.v13)],
  products: [
    .library(
      name: "UtilKit",
      targets: ["UtilKit"]
    ),
    .library(
      name: "DesignKit",
      targets: ["DesignKit"]
    ),
    .library(
      name: "LocalisationKit",
      targets: ["LocalisationKit"]
    )
  ],
  targets: [
    .target(
      name: "UtilKit"
    ),
    .target(
      name: "DesignKit",
      dependencies: [
        "UtilKit"
      ],
      resources: [.process("Fonts")]
    ),
    .target(
      name: "LocalisationKit",
      resources: [.process("Localisations")],
      plugins: [
        .plugin(name: "LocalisationKitPlugin")
      ]
    ),
    .executableTarget(
      name: "LocalisationKitCodeGen"
    ),
    .plugin(
      name: "LocalisationKitPlugin",
      capability: .buildTool(),
      dependencies: [
        "LocalisationKitCodeGen"
      ]
    )
  ]
)
