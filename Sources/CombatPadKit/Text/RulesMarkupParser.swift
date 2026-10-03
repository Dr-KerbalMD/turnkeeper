import Foundation

/// Splits one paragraph of `RulesText` markup into runs.
enum RulesMarkupParser {
    static func runs(in line: String) -> [RulesRun] {
        var runs: [RulesRun] = []
        var rest = Substring(line)
        while let open = rest.range(of: "{{"),
              let close = rest.range(of: "}}", range: open.upperBound..<rest.endIndex) {
            runs += emphasisRuns(in: rest[rest.startIndex..<open.lowerBound])
            let token = rest[open.upperBound..<close.lowerBound]
            runs.append(tokenRun(String(token)) ?? .text(String(token), .plain))
            rest = rest[close.upperBound...]
        }
        runs += emphasisRuns(in: rest)
        return runs
    }

    /// Writes a run back as markup. Used by the importer and by tests.
    static func markup(for run: RulesRun) -> String {
        switch run {
        case let .text(text, .plain): return text
        case let .text(text, .bold): return "**\(text)**"
        case let .text(text, .italic): return "*\(text)*"
        case let .check(check):
            let basic = check.isBasic ? ":basic" : ""
            return "{{check:\(check.statistic):\(check.difficultyClass)\(basic)}}"
        case let .damage(parts): return "{{damage:\(parts.map(damageMarkup).joined(separator: ";"))}}"
        case let .actions(cost): return "{{actions:\(actionsMarkup[cost] ?? "1")}}"
        }
    }

    private static let actionsMarkup: [ActionCost: String] = [
        .one: "1", .two: "2", .three: "3", .free: "free", .reaction: "reaction"
    ]

    private static func damageMarkup(_ part: DamagePart) -> String {
        ([part.formula, part.type] + (part.isPersistent ? ["persistent"] : [])).joined(separator: "|")
    }

    private static func tokenRun(_ token: String) -> RulesRun? {
        let fields = token.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 2 else { return nil }
        switch fields[0] {
        case "check":
            guard fields.count >= 3, let dc = Int(fields[2]) else { return nil }
            return .check(CheckReference(statistic: fields[1], difficultyClass: dc, isBasic: fields.count > 3))
        case "damage":
            let parts = fields[1].split(separator: ";").compactMap(damagePart)
            return parts.isEmpty ? nil : .damage(parts)
        case "actions":
            return actionsMarkup.first { $0.value == fields[1] }.map { .actions($0.key) }
        default:
            return nil
        }
    }

    private static func damagePart(_ text: Substring) -> DamagePart? {
        let fields = text.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard let formula = fields.first, !formula.isEmpty else { return nil }
        let type = fields.count > 1 ? fields[1] : ""
        return DamagePart(formula: formula, type: type, isPersistent: fields.contains("persistent"))
    }

    /// Splits text on `**` and `*` markers into plain, bold and italic runs.
    private static func emphasisRuns(in text: Substring) -> [RulesRun] {
        var runs: [RulesRun] = []
        var emphasis = TextEmphasis.plain
        var current = ""
        var index = text.startIndex
        while index < text.endIndex {
            let marker = text[index...].hasPrefix("**") ? "**" : (text[index] == "*" ? "*" : "")
            guard !marker.isEmpty else {
                current.append(text[index])
                index = text.index(after: index)
                continue
            }
            if !current.isEmpty { runs.append(.text(current, emphasis)) }
            current = ""
            let markerEmphasis: TextEmphasis = marker == "**" ? .bold : .italic
            emphasis = emphasis == markerEmphasis ? .plain : markerEmphasis
            index = text.index(index, offsetBy: marker.count)
        }
        if !current.isEmpty { runs.append(.text(current, emphasis)) }
        return runs
    }
}
