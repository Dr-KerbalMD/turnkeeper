import Foundation
import Testing
@testable import CombatPadKit

@Suite("Rules text markup")
struct RulesTextTests {
    @Test("Paragraphs, rules and emphasis")
    func paragraphs() {
        let text = RulesText("**Trigger** A foe *moves*.\n---\nPlain.")
        #expect(text.paragraphs == [
            .runs([.text("Trigger", .bold), .text(" A foe ", .plain), .text("moves", .italic), .text(".", .plain)]),
            .rule,
            .runs([.text("Plain.", .plain)])
        ])
    }

    @Test("Checks, damage and actions are structured")
    func tokens() {
        let text = RulesText(
            "{{actions:2}} DC {{check:reflex:34:basic}} for {{damage:2d6+4|fire;1d6|bleed|persistent}}"
        )
        #expect(text.paragraphs == [.runs([
            .actions(.two),
            .text(" DC ", .plain),
            .check(CheckReference(statistic: "reflex", difficultyClass: 34, isBasic: true)),
            .text(" for ", .plain),
            .damage([
                DamagePart(formula: "2d6+4", type: "fire"),
                DamagePart(formula: "1d6", type: "bleed", isPersistent: true)
            ])
        ])])
    }

    @Test("Runs write back to the same markup")
    func roundTrip() {
        let markup = "{{actions:reaction}} **Effect** {{check:will:20}} {{damage:1d8|cold}}"
        let runs = RulesText(markup).paragraphs.flatMap { paragraph -> [RulesRun] in
            if case let .runs(runs) = paragraph { return runs }
            return []
        }
        #expect(runs.map(\.markup).joined() == markup)
    }

    @Test("A malformed token stays as text")
    func malformedToken() {
        #expect(RulesText("{{check:will}}").paragraphs == [.runs([.text("check:will", .plain)])])
    }

    @Test("Rules text encodes as a plain string")
    func codable() throws {
        let data = try JSONEncoder().encode(["text": RulesText("Hi")])
        #expect(String(data: data, encoding: .utf8) == #"{"text":"Hi"}"#)
    }
}
