import CombatPadKit
import Foundation

/// Replaces Foundry text enrichers (`@UUID`, `@Check`, `@Damage`, `@Template`, `@Localize`, `[[/r …]]`)
/// with plain text or `RulesText` tokens. HTML is left in place for `HTMLFlattener`.
struct EnricherConverter {
    var localizer: Localizer
    /// Enricher names that could not be converted, for the import report.
    private(set) var unparsed: [String] = []

    init(localizer: Localizer) {
        self.localizer = localizer
    }

    mutating func convert(_ html: String) -> String {
        var text = expandLocalizations(html, depth: 0)
        text = replaceInlineRolls(in: text)
        return replaceEnrichers(in: text)
    }

    private func expandLocalizations(_ html: String, depth: Int) -> String {
        guard depth < 4, html.contains("@Localize[") else { return html }
        let expanded = EnricherScanner.replace(in: html) { match in
            guard match.name == "Localize" else { return nil }
            return localizer.text(for: match.argument) ?? ""
        }
        return expandLocalizations(expanded, depth: depth + 1)
    }

    private mutating func replaceEnrichers(in html: String) -> String {
        var unparsedNames: [String] = []
        let result = EnricherScanner.replace(in: html) { match in
            if let converted = Self.convert(match) { return converted }
            unparsedNames.append(match.name)
            return match.label ?? ""
        }
        unparsed += unparsedNames
        return result
    }

    private static func convert(_ match: EnricherMatch) -> String? {
        switch match.name {
        case "UUID": return uuidName(match.argument).isEmpty ? "" : (match.label ?? uuidName(match.argument))
        case "Check": return check(match).map { RulesRun.check($0).markup } ?? match.label ?? checkText(match.argument)
        case "Damage": return damage(match.argument).map { RulesRun.damage($0).markup } ?? match.label
        case "Template": return match.label ?? template(match.argument)
        case "Embed", "Compendium": return match.label ?? ""
        default: return nil
        }
    }

    /// The linked document's name. Links to Foundry effect items are dropped; they only automate rules.
    private static func uuidName(_ argument: String) -> String {
        let name = argument.split(separator: ".").last.map(String.init) ?? ""
        return name.hasPrefix("Effect:") ? "" : name
    }

    private static func check(_ match: EnricherMatch) -> CheckReference? {
        let fields = parameters(match.argument)
        guard let dc = fields["dc"].flatMap({ Int($0) }) else { return nil }
        let statistic = fields["type"] ?? fields[""] ?? ""
        guard !statistic.isEmpty else { return nil }
        return CheckReference(statistic: statistic, difficultyClass: dc, isBasic: fields["basic"] != nil)
    }

    private static let saves: Set<String> = ["fortitude", "reflex", "will"]

    /// Prose for a check without a fixed DC: "basic Reflex save" or "Athletics check against Fortitude DC".
    private static func checkText(_ argument: String) -> String {
        let fields = parameters(argument)
        let statistic = fields["type"] ?? fields[""] ?? ""
        let isSave = saves.contains(statistic)
        var text = (fields["basic"] != nil ? "basic " : "") + statistic.capitalized + (isSave ? " save" : " check")
        if let defense = fields["defense"] ?? fields["against"] {
            text += " against \(defense == "class" ? "class" : defense.capitalized) DC"
        }
        return text
    }

    private static func template(_ argument: String) -> String {
        let fields = parameters(argument)
        let shape = fields["type"] ?? fields[""] ?? "area"
        guard let distance = fields["distance"] else { return shape }
        return "\(distance)-foot \(shape)"
    }

    /// Parses `reflex|dc:20|basic` into `["": "reflex", "dc": "20", "basic": ""]`.
    static func parameters(_ argument: String) -> [String: String] {
        var result: [String: String] = [:]
        for (index, field) in argument.split(separator: "|").enumerated() {
            let pair = field.split(separator: ":", maxSplits: 1).map(String.init)
            if pair.count == 2 {
                result[pair[0]] = pair[1]
            } else if index == 0 {
                result[""] = pair[0]
            } else {
                result[pair[0]] = ""
            }
        }
        return result
    }

    static func damage(_ argument: String) -> [DamagePart]? {
        let formulaSpec = EnricherScanner.splitTopLevel(argument, separator: "|").first ?? ""
        let parts = EnricherScanner.splitTopLevel(formulaSpec, separator: ",").compactMap(DamageFormula.part)
        return parts.isEmpty ? nil : parts
    }

    /// `[[/r 1d4 #Recharge]]{1d4 rounds}` becomes "1d4 rounds", and `[[/act demoralize]]` "Demoralize".
    private func replaceInlineRolls(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\[\[/(\w+) ([^\]]*)\]\](?:\{([^}]*)\})?"#) else {
            return text
        }
        let source = text as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result += Self.inlineRollText(match, in: source)
            cursor = match.range.location + match.range.length
        }
        return result + source.substring(from: cursor)
    }

    private static func inlineRollText(_ match: NSTextCheckingResult, in source: NSString) -> String {
        if match.range(at: 3).location != NSNotFound { return source.substring(with: match.range(at: 3)) }
        let command = source.substring(with: match.range(at: 1))
        let body = source.substring(with: match.range(at: 2))
        let firstWord = body.split(separator: " ").first.map(String.init) ?? body
        if command == "act" { return firstWord.split(separator: "-").map(\.capitalized).joined(separator: " ") }
        return body.split(separator: "#").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? body
    }
}
