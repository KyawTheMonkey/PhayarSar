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
    ),
    .library(
      name: "EnvironmentKit",
      targets: ["EnvironmentKit"]
    ),
    .library(
      name: "ComponentKit",
      targets: ["ComponentKit"]
    ),
    .library(
      name: "KloudKit",
      targets: ["KloudKit"]
    ),
    .library(
      name: "AuthKit",
      targets: ["AuthKit"]
    ),
    .library(
      name: "HomeKit",
      targets: ["HomeKit"]
    ),
    .library(
      name: "PrayersKit",
      targets: ["PrayersKit"]
    ),
    .library(
      name: "SettingsKit",
      targets: ["SettingsKit"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/krzysztofzablocki/Inject.git", exact: "1.6.0")
  ],
  targets: [
    // MARK: - Helpers

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
    ),
    .target(
      name: "EnvironmentKit",
      dependencies: ["LocalisationKit", "UtilKit", "Inject"]
    ),
    .target(
      name: "ComponentKit",
      dependencies: ["EnvironmentKit"]
    ),
    .target(
      name: "KloudKit"
    ),

    // MARK: - Features
    .target(
      name: "AuthKit",
      dependencies: ["EnvironmentKit", "DesignKit", "KloudKit"],
      resources: [.process("Resources")]
    ),
    .target(
      name: "HomeKit",
      dependencies: ["EnvironmentKit", "DesignKit", "PrayersKit"]
    ),
    .target(
      name: "PrayersKit",
      dependencies: ["EnvironmentKit", "DesignKit"],
      resources: [.process("Prayers")]
    ),
    .target(
      name: "SettingsKit",
      dependencies: ["EnvironmentKit", "DesignKit", "AuthKit"]
    )
  ]
)
