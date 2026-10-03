import CombatPadKit
import CombatPadUI
import Foundation

/// `CardSnapshots OUTPUT_FOLDER KEY[:elite|:weak][:condition=value]...`
///
/// Writes a PNG of each creature's battle card, for comparing with the printed Battle Cards.
let arguments = CommandLine.arguments.dropFirst()
guard let output = arguments.first.map({ URL(fileURLWithPath: $0) }) else {
    print("Usage: CardSnapshots OUTPUT_FOLDER KEY[:elite|:weak][:slug=value]...")
    exit(2)
}
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for argument in arguments.dropFirst() {
    let parts = argument.split(separator: ":").map(String.init)
    let template = parts.dropFirst().compactMap(CreatureTemplate.init(rawValue:)).first ?? .normal
    let conditions = parts.dropFirst().filter { $0.contains("=") }.map { part -> AppliedCondition in
        let pair = part.split(separator: "=").map(String.init)
        return AppliedCondition(slug: pair[0], value: Int(pair[1]))
    }
    let data = await MainActor.run { CardSnapshot.png(key: parts[0], template: template, conditions: conditions) }
    guard let data else {
        print("Rendering \(parts[0]) failed: not in the bestiary.")
        continue
    }
    let file = output.appendingPathComponent(argument.replacingOccurrences(of: ":", with: "_") + ".png")
    try data.write(to: file)
    print("Wrote \(file.path)")
}
