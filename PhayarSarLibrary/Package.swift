// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "PhayarSarLibrary",
  products: [
    .library(
      name: "PhayarSarLibrary",
      targets: ["PhayarSarLibrary"]
    ),
  ],
  targets: [
    .target(
      name: "PhayarSarLibrary"
    ),
  ]
)
