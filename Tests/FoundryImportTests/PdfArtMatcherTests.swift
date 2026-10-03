import CombatPadKit
import Testing
@testable import FoundryImport

@Suite("PDF art matching")
struct PdfArtMatcherTests {
    private func entry(
        _ name: String, kind: PdfArtEntry.Kind, era: String = "legacy", game: Game = .starfinder
    ) -> PdfArtEntry {
        PdfArtEntry(name: name, collection: "set-\(era)", game: game, era: era, kind: kind, path: "\(era)/\(name)")
    }

    private func creature(_ name: String, game: Game = .starfinder, remastered: Bool = true) -> Creature {
        var creature = Creature(key: "x.\(name)", name: name, game: game)
        creature.source = Source(pack: "p", title: "t", isRemastered: remastered)
        return creature
    }

    @Test("Comma names match in any word order")
    func commaReordering() {
        let matcher = PdfArtMatcher(entries: [entry("AGATHION, VICUNAL", kind: .pawn)])
        #expect(matcher.art(for: creature("Vicunal Agathion"))[.pawn]?.name == "AGATHION, VICUNAL")
    }

    @Test("A card title's family prefix is optional")
    func familyPrefix() {
        let matcher = PdfArtMatcher(entries: [entry("AEON, AXIOMITE", kind: .cardBack, game: .pathfinder)])
        #expect(matcher.art(for: creature("Axiomite", game: .pathfinder))[.cardBack] != nil)
    }

    @Test("Spellcaster and other parenthetical variants share the base art")
    func variants() {
        let matcher = PdfArtMatcher(entries: [
            entry("DRAGON, ADULT HOST", kind: .token), entry("THRESHER", kind: .pawn)
        ])
        #expect(matcher.art(for: creature("Host Dragon (Adult, Spellcaster)"))[.token] != nil)
        #expect(matcher.art(for: creature("Thresher (Lord)"))[.pawn] != nil)
    }

    @Test("Art only matches creatures of the same game")
    func sameGame() {
        let matcher = PdfArtMatcher(entries: [entry("TROLL", kind: .cardBack, game: .starfinder)])
        #expect(matcher.art(for: creature("Troll", game: .pathfinder)).isEmpty)
    }

    @Test("Remastered creatures prefer remaster card sets, legacy ones legacy sets")
    func eraPreference() {
        let matcher = PdfArtMatcher(entries: [
            entry("OWLBEAR", kind: .cardBack, era: "legacy", game: .pathfinder),
            entry("OWLBEAR", kind: .cardBack, era: "remaster", game: .pathfinder)
        ])
        #expect(matcher.art(for: creature("Owlbear", game: .pathfinder))[.cardBack]?.era == "remaster")
        #expect(matcher.art(for: creature("Owlbear", game: .pathfinder, remastered: false))[.cardBack]?.era == "legacy")
    }

    @Test("Overrides map a renamed creature to its art")
    func overrides() {
        let matcher = PdfArtMatcher(entries: [entry("SPACE GOBLIN", kind: .pawn)], overrides: ["Gobbo": "SPACE GOBLIN"])
        #expect(matcher.art(for: creature("Gobbo"))[.pawn] != nil)
    }

    @Test("Foundry art wins; PDF tokens and pawns fill the gaps")
    func combining() {
        let pdf: [PdfArtEntry.Kind: PdfArtEntry] = [
            .pawn: entry("A", kind: .pawn), .cardBack: entry("A", kind: .cardBack)
        ]
        let fromFoundry = ArtChooser.combine(ArtReference(portrait: "f/p", token: "f/t"), pdfArt: pdf)
        #expect(fromFoundry == ArtReference(portrait: "f/p", token: "f/t", cardBack: "legacy/A"))
        let fromPdf = ArtChooser.combine(.none, pdfArt: pdf)
        #expect(fromPdf == ArtReference(portrait: "legacy/A", token: "legacy/A", cardBack: "legacy/A"))
    }
}
