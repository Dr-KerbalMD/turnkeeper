import CombatPadKit
import Foundation

/// One `@Name[argument]{label}` enricher found in text.
struct EnricherMatch {
    var name: String
    var argument: String
    var label: String?
}

/// Finds enrichers with nested brackets, such as `@Damage[(2d6+4)[fire]]`, and replaces them.
enum EnricherScanner {
    /// Replaces every enricher for which `transform` returns text, and leaves the others untouched.
    static func replace(in text: String, transform: (EnricherMatch) -> String?) -> String {
        var result = ""
        var index = text.startIndex
        while let at = text[index...].firstIndex(of: "@") {
            result += text[index..<at]
            guard let (match, end) = match(in: text, at: at), let replacement = transform(match) else {
                result.append("@")
                index = text.index(after: at)
                continue
            }
            result += replacement
            index = end
        }
        return result + text[index...]
    }

    /// Splits on `separator` where it is not inside brackets or parentheses.
    static func splitTopLevel(_ text: String, separator: Character) -> [String] {
        var parts: [String] = []
        var depth = 0
        var current = ""
        for character in text {
            if "[(".contains(character) { depth += 1 }
            if "])".contains(character) { depth -= 1 }
            if character == separator && depth == 0 {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        return parts.filter { !$0.isEmpty }
    }

    private static func match(in text: String, at start: String.Index) -> (EnricherMatch, String.Index)? {
        let nameStart = text.index(after: start)
        guard let open = text[nameStart...].firstIndex(where: { !$0.isLetter }), text[open] == "[",
              open > nameStart, let close = matchingBracket(in: text, open: open) else { return nil }
        let name = String(text[nameStart..<open])
        let argument = String(text[text.index(after: open)..<close])
        var end = text.index(after: close)
        var label: String?
        if end < text.endIndex, text[end] == "{", let labelEnd = text[end...].firstIndex(of: "}") {
            label = String(text[text.index(after: end)..<labelEnd])
            end = text.index(after: labelEnd)
        }
        return (EnricherMatch(name: name, argument: argument, label: label), end)
    }

    private static func matchingBracket(in text: String, open: String.Index) -> String.Index? {
        var depth = 0
        var index = open
        while index < text.endIndex {
            if text[index] == "[" { depth += 1 }
            if text[index] == "]" {
                depth -= 1
                if depth == 0 { return index }
            }
            index = text.index(after: index)
        }
        return nil
    }
}

/// Parses one damage part such as `(2d6+4)[persistent,fire]` or `1d6[bleed]`.
enum DamageFormula {
    static func part(_ text: String) -> DamagePart? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.hasSuffix("]"), let open = typeBracketStart(trimmed) else {
            return DamagePart(formula: cleanFormula(trimmed), type: "")
        }
        let formula = cleanFormula(String(trimmed[..<open]))
        let tags = trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)]
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let types = tags.filter { $0 != "persistent" }
        let isPersistent = tags.contains("persistent") || tags.contains("bleed")
        return DamagePart(formula: formula, type: types.joined(separator: " "), isPersistent: isPersistent)
    }

    /// The `[` that opens the trailing type list, skipping brackets nested inside the formula.
    private static func typeBracketStart(_ text: String) -> String.Index? {
        var depth = 0
        var index = text.index(before: text.endIndex)
        while index > text.startIndex {
            if text[index] == "]" { depth += 1 }
            if text[index] == "[" {
                depth -= 1
                if depth == 0 { return index }
            }
            index = text.index(before: index)
        }
        return nil
    }

    /// Removes the wrapping parentheses Foundry adds, so `(3d8+6)` reads `3d8+6`.
    private static func cleanFormula(_ formula: String) -> String {
        var result = formula.trimmingCharacters(in: .whitespaces)
        if result.hasPrefix("("), result.hasSuffix(")"), !result.dropFirst().contains("(") {
            result = String(result.dropFirst().dropLast())
        }
        return result.replacingOccurrences(of: " ", with: "")
    }
}
