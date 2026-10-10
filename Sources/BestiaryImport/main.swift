import Foundation
import FoundryImport

/// `BestiaryImport [--pf2e DIR] [--out DIR] [--config DIR]`
///
/// Defaults: `~/git/pf2e`, `Generated`, and the current folder (for the optional `art-overrides.json`).
let home = FileManager.default.homeDirectoryForCurrentUser
var options = [
    "--pf2e": home.appendingPathComponent("git/pf2e").path,
    "--out": "Generated",
    "--config": "."
]
var arguments = CommandLine.arguments.dropFirst()
while let flag = arguments.popFirst() {
    guard options[flag] != nil, let value = arguments.popFirst() else {
        FileHandle.standardError.write(Data("Importing failed: unknown option \(flag).\n".utf8))
        exit(2)
    }
    options[flag] = value
}

let directories = options.mapValues { URL(fileURLWithPath: $0, isDirectory: true) }
let configuration = ImportConfiguration(
    repository: directories["--pf2e"]!,
    outputDirectory: directories["--out"]!,
    configurationDirectory: directories["--config"]!
)
do {
    let report = try BestiaryImporter(configuration: configuration).run()
    print("Imported \(report.creatureCount) creatures and complex hazards. See Generated/import-report.md.")
} catch {
    FileHandle.standardError.write(Data("Importing the bestiary failed: \(error)\n".utf8))
    exit(1)
}
