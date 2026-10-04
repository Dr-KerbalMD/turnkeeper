import Foundation

/// Reads the pieces of a stat block written as text, the way the books print them, into structured values;
/// and writes them back. Shared by the custom creature editor and the import of copied stat blocks.
public enum StatBlockText {
    /// A whole number with a sign, reading Paizo's minus and en dash: "+7", "−2", "–1", "12".
    public static func integer(_ text: String) -> Int? {
        let normalized = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "+", with: "")
        let digits = normalized.prefix { $0.isNumber || $0 == "-" }
        return Int(digits)
    }

    /// Splits on commas (or another separator) that aren't inside parentheses, trimming each piece.
    public static func list(_ text: String, separator: Character = ",") -> [String] {
        var pieces: [String] = []
        var depth = 0
        var current = ""
        for character in text {
            if character == "(" { depth += 1 }
            if character == ")" { depth = max(0, depth - 1) }
            if character == separator && depth == 0 {
                pieces.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        pieces.append(current)
        return pieces.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    // MARK: Skills, speeds and resistances

    /// "Acrobatics +5, Warfare Lore +7 (+9 to recall)" into skills.
    public static func skills(_ text: String) -> [Skill] {
        list(text).compactMap { piece in
            let (main, details) = splitParenthetical(piece)
            guard let signIndex = main.lastIndex(where: { "+-−–".contains($0) }),
                  let modifier = integer(String(main[signIndex...])) else { return nil }
            let name = main[..<signIndex].trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : Skill(name: name, modifier: modifier, details: details)
        }
    }

    public static func format(_ skills: [Skill]) -> String {
        skills.map { skill in
            "\(skill.name) \(signedText(skill.modifier))" + (skill.details.isEmpty ? "" : " (\(skill.details))")
        }
        .joined(separator: ", ")
    }

    /// "25 feet, fly 40 feet, swim 20 feet" into speeds; the first speed without a type is the land Speed.
    public static func speeds(_ text: String) -> [Speed] {
        list(text).compactMap { piece in
            let words = piece.lowercased().split(separator: " ").map(String.init)
            guard let feet = words.compactMap({ Int($0) }).first else { return nil }
            let type = words.first { Int($0) == nil && $0 != "feet" && $0 != "ft." } ?? "land"
            return Speed(type: type, feet: feet)
        }
    }

    public static func format(_ speeds: [Speed]) -> String {
        speeds.map { ($0.type == "land" ? "" : "\($0.type) ") + "\($0.feet) feet" }.joined(separator: ", ")
    }

    /// "fire 5, physical 5 (except silver)" into resistances or weaknesses.
    public static func adjustments(_ text: String) -> [DamageAdjustment] {
        list(text).compactMap { piece in
            let (main, details) = splitParenthetical(piece)
            let words = main.split(separator: " ").map(String.init)
            guard let value = words.last.flatMap(integer) else { return nil }
            let type = words.dropLast().joined(separator: " ")
            let exceptions = details.lowercased().hasPrefix("except ")
                ? list(String(details.dropFirst("except ".count))) : []
            return type.isEmpty ? nil : DamageAdjustment(type: type, value: value, exceptions: exceptions)
        }
    }

    public static func format(_ adjustments: [DamageAdjustment]) -> String {
        adjustments.map { adjustment in
            "\(adjustment.type) \(adjustment.value)"
                + (adjustment.exceptions.isEmpty ? "" : " (except \(adjustment.exceptions.joined(separator: ", ")))")
        }
        .joined(separator: ", ")
    }

    // MARK: Damage

    /// "2d8+11 bludgeoning plus 1d6 fire" or "1d6 persistent bleed" into damage parts.
    public static func damage(_ text: String) -> [DamagePart] {
        text.components(separatedBy: " plus ").compactMap { piece in
            let trimmed = piece.trimmingCharacters(in: .whitespaces)
            guard let match = trimmed.firstMatch(of: /^(?<formula>\d+d\d+(?:\s*[+\-−–]\s*\d+)?|\d+)\s*(?<rest>.*)$/)
            else { return nil }
            let formula = String(match.output.formula).filter { !$0.isWhitespace }
                .replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "–", with: "-")
            var words = match.output.rest.split(separator: " ").map(String.init).filter { $0 != "damage" }
            let isPersistent = words.contains("persistent") || words.contains("bleed")
            words.removeAll { $0 == "persistent" }
            return DamagePart(formula: formula, type: words.joined(separator: " "), isPersistent: isPersistent)
        }
    }

    public static func format(_ parts: [DamagePart]) -> String {
        parts.map { part in
            let persistent = part.isPersistent && !part.type.contains("bleed") ? "persistent " : ""
            return [part.formula, persistent + part.type].filter { !$0.isEmpty }.joined(separator: " ")
        }
        .joined(separator: " plus ")
    }

    // MARK: Helpers

    /// "Warfare Lore +7 (+9 to recall)" into ("Warfare Lore +7", "+9 to recall").
    static func splitParenthetical(_ text: String) -> (String, String) {
        guard let open = text.firstIndex(of: "("), let close = text.lastIndex(of: ")"), open < close else {
            return (text.trimmingCharacters(in: .whitespaces), "")
        }
        let main = text[..<open].trimmingCharacters(in: .whitespaces)
        return (main, String(text[text.index(after: open)..<close]))
    }

    static func signedText(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "-\(abs(value))"
    }
}
