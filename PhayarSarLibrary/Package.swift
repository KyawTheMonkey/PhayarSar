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
