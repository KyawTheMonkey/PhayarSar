import Foundation
import PackagePlugin

@main
struct LocalisationKitPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
    // Only process Swift/Clang source module targets and specifically the LocalisationKit target
    guard let sourceTarget = target as? SourceModuleTarget, sourceTarget.name == "LocalisationKit" else {
      return []
    }

    // Locate strings.json inside the Localisations resource folder of the target
    let resourcesDir = sourceTarget.directoryURL.appending(path: "Localisations")
    let stringsJsonURL = resourcesDir.appending(path: "strings.json")

    // Output directory under the plugin work directory
    let generatedDir = context.pluginWorkDirectoryURL.appending(path: "Generated")
    let outputURL = generatedDir.appending(path: "L10n+Generated.swift")

    // Build command that invokes the code generation tool
    return try [
      .buildCommand(
        displayName: "Generating Strings Enum from JSON",
        executable: context.tool(named: "LocalisationKitCodeGen").url,
        arguments: [
          stringsJsonURL.path(percentEncoded: false),
          outputURL.path(percentEncoded: false),
          generatedDir.path(percentEncoded: false)
        ],
        inputFiles: [stringsJsonURL],
        outputFiles: [outputURL]
      )
    ]
  }
}
