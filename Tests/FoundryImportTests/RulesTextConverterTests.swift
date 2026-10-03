import CombatPadKit
import Testing
@testable import FoundryImport

@Suite("Rules text conversion")
struct RulesTextConverterTests {
    private func convert(_ html: String) -> String {
        var converter = Fixtures.converter()
        return converter.convert(html).markup
    }

    @Test("Paragraphs, rules and emphasis become markup")
    func paragraphsAndEmphasis() {
        let html = "<p><strong>Trigger</strong> A goblin moves.</p>\n<hr />\n<p>It <em>Steps</em>.</p>"
        #expect(convert(html) == "**Trigger** A goblin moves.\n---\nIt *Steps*.")
    }

    @Test("A check keeps its statistic, DC and basic flag")
    func checkWithDC() {
        #expect(convert("@Check[reflex|dc:34|basic|options:area-effect]") == "{{check:reflex:34:basic}}")
        #expect(convert("@Check[type:will|dc:20]") == "{{check:will:20}}")
    }

    @Test("A check without a DC becomes prose")
    func checkWithoutDC() {
        #expect(convert("@Check[reflex|against:class|basic]") == "basic Reflex save against class DC")
        #expect(convert("@Check[athletics|defense:fortitude]") == "Athletics check against Fortitude DC")
        #expect(convert("@Check[thievery]{Disable it}") == "Disable it")
    }

    @Test("Damage with nested brackets, persistence and several parts")
    func damage() {
        #expect(convert("@Damage[(3d8+6)[piercing]]") == "{{damage:3d8+6|piercing}}")
        #expect(convert("@Damage[1d6[persistent,fire]]") == "{{damage:1d6|fire|persistent}}")
        #expect(convert("@Damage[2d6[bleed]|options:area-damage]") == "{{damage:2d6|bleed|persistent}}")
        #expect(convert("@Damage[2d6[fire],1d4[cold]]") == "{{damage:2d6|fire;1d4|cold}}")
    }

    @Test("Links, templates and inline rolls become words")
    func linksTemplatesAndRolls() {
        #expect(convert("@UUID[Compendium.pf2e.actionspf2e.Item.Step]{Steps}") == "Steps")
        #expect(convert("@UUID[Compendium.pf2e.conditionitems.Item.Frightened] 1") == "Frightened 1")
        #expect(convert("@UUID[Compendium.sf2e.bestiary-effects.Item.Effect: Lead the Charge]") == "")
        #expect(convert("@Template[cone|distance:40]") == "40-foot cone")
        #expect(convert("[[/gmr 1d4 #Recharge Breath]]{1d4 rounds}") == "1d4 rounds")
        #expect(convert("[[/act demoralize]]") == "Demoralize")
    }

    @Test("Localized glossary text is expanded and converted")
    func localization() {
        let html = "<p>@Localize[PF2E.NPC.Abilities.Glossary.ReactiveStrike]</p>"
        #expect(convert(html) == "**Trigger** A creature moves.")
    }

    @Test("Action glyph spans become action tokens")
    func actionGlyphs() {
        #expect(convert(#"<span class="action-glyph">2</span> Strike"#) == "{{actions:2}} Strike")
        #expect(convert(#"<span class="action-glyph">R</span>"#) == "{{actions:reaction}}")
    }

    @Test("Unknown enrichers keep their label and are reported")
    func unknownEnricher() {
        var converter = Fixtures.converter()
        #expect(converter.convert("@Mystery[thing]{the label}").markup == "the label")
        #expect(converter.unparsedEnrichers == ["Mystery"])
    }
}
