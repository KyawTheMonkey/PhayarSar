// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "PhayarSarLibrary",
  platforms: [.iOS(.v16), .macOS(.v13), .watchOS(.v10)],
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
    .library(
      name: "MiscKit",
      targets: ["MiscKit"]
    ),
    .library(
      name: "RemoteKit",
      targets: ["RemoteKit"]
    ),
    .library(
      name: "ActivitiesKit",
      targets: ["ActivitiesKit"]
    ),
    .library(
      name: "WristKit",
      targets: ["WristKit"]
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
    .target(
      name: "RemoteKit"
    ),
    // Dependency-free on purpose: the widget extension links this and nothing
    // else of the app's, so that drawing a title on a card does not drag the
    // prayer catalog and the CloudKit stack into a second binary. See
    // `PrayerReadingAttributes`.
    .target(
      name: "ActivitiesKit"
    ),

    // MARK: - Features
    .target(
      name: "AuthKit",
      dependencies: ["EnvironmentKit", "DesignKit", "KloudKit"],
      resources: [.process("Resources")]
    ),
    .target(
      name: "HomeKit",
      dependencies: [
        "EnvironmentKit", "DesignKit", "PrayersKit", "AuthKit", "RemoteKit", "ActivitiesKit"
      ]
    ),
    .target(
      name: "PrayersKit",
      dependencies: ["EnvironmentKit", "DesignKit", "KloudKit"],
      resources: [.process("Prayers")]
    ),
    .target(
      name: "SettingsKit",
      dependencies: ["EnvironmentKit", "DesignKit", "AuthKit", "KloudKit"]
    ),
    // Deliberately *not* dependent on LocalisationKit — see `WristStrings`.
    // Its build-tool plugin gets one output directory per package target rather
    // than per platform, so a build that compiles it for both iOS and watchOS
    // (which embedding the watch app makes unavoidable) fails on two commands
    // writing the same generated file.
    .target(
      name: "WristKit",
      dependencies: ["RemoteKit", "DesignKit"]
    ),
    .target(
      name: "MiscKit",
      dependencies: ["EnvironmentKit", "DesignKit"]
    )
  ]
)
