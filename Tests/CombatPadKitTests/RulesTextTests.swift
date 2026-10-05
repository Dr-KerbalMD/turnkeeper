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

    @Test("Links keep their target, label and the emphasis around them")
    func links() {
        let text = RulesText("*{{link:pf2e.spells-srd.abc|detect magic}}* and {{link:trait.pf2e.fire|fire}}.")
        #expect(text.paragraphs == [.runs([
            .link("detect magic", target: "pf2e.spells-srd.abc", .italic),
            .text(" and ", .plain),
            .link("fire", target: "trait.pf2e.fire", .plain),
            .text(".", .plain)
        ])])
    }

    @Test("Links write back to the same markup")
    func linkRoundTrip() {
        let markup = "**{{link:a.b|Grab}}** then *{{link:c.d|Stunned 1}}*"
        let runs = RulesText(markup).paragraphs.flatMap { paragraph -> [RulesRun] in
            if case let .runs(runs) = paragraph { return runs }
            return []
        }
        #expect(runs.map(\.markup).joined() == markup)
    }

    @Test("A link without a target or label stays as text")
    func malformedLink() {
        #expect(RulesText("{{link:|Grab}}").paragraphs == [.runs([.text("link:|Grab", .plain)])])
        #expect(RulesText("{{link:a.b|}}").paragraphs == [.runs([.text("link:a.b|", .plain)])])
        #expect(RulesText("{{link:a.b}}").paragraphs == [.runs([.text("link:a.b", .plain)])])
    }

    @Test("Links read as their label in plain text")
    func linkPlainText() {
        #expect(StatBlockText.plainText(RulesText("Becomes *{{link:a.b|frightened 1}}*.")) == "Becomes *frightened 1*.")
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
