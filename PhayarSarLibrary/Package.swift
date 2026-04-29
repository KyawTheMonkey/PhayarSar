// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "PhayarSarLibrary",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .library(
      name: "UtilKit",
      targets: ["UtilKit"]
    ),
    .library(
      name: "DesignKit",
      targets: ["DesignKit"]
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
    )
  ]
)
