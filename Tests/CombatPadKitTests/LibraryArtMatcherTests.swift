import Foundation
import Testing
@testable import CombatPadKit

@Suite("Matching library art to creatures")
struct LibraryArtMatcherTests {
    private func art(
        _ name: String, game: Game = .starfinder, remastered: Bool = false, token: Bool = false,
        available: Bool = true, sources: [String] = ["Test Pawn Box"]
    ) -> LibraryArt {
        LibraryArt(id: UUID(), name: name, game: game, isRemastered: remastered, isToken: token,
                   isAvailable: available, sourceTitles: sources)
    }

    private func match(_ matcher: LibraryArtMatcher, _ name: String, game: Game = .starfinder,
                       remastered: Bool = true) -> MatchedArt {
        matcher.art(forCreatureNamed: name, game: game, isRemastered: remastered)
    }

    @Test("Comma names match in any word order")
    func commaReordering() {
        let vicunal = art("AGATHION, VICUNAL")
        #expect(match(LibraryArtMatcher(art: [vicunal]), "Vicunal Agathion").portrait == vicunal.id)
    }

    @Test("A card title's family prefix is optional")
    func familyPrefix() {
        let axiomite = art("Aeon, Axiomite", game: .pathfinder)
        #expect(match(LibraryArtMatcher(art: [axiomite]), "Axiomite", game: .pathfinder).portrait == axiomite.id)
    }

    @Test("Spellcaster and other parenthetical variants share the base art")
    func variants() {
        let matcher = LibraryArtMatcher(art: [art("Dragon, Adult Host"), art("Thresher")])
        #expect(match(matcher, "Host Dragon (Adult, Spellcaster)").portrait != nil)
        #expect(match(matcher, "Thresher (Lord)").portrait != nil)
    }

    @Test("Art only matches creatures of the same game")
    func sameGame() {
        #expect(match(LibraryArtMatcher(art: [art("Troll")]), "Troll", game: .pathfinder) == .none)
    }

    @Test("Remastered creatures prefer remastered products' art, legacy ones the others")
    func eraPreference() {
        let legacy = art("Owlbear", game: .pathfinder), remaster = art("Owlbear", game: .pathfinder, remastered: true)
        let matcher = LibraryArtMatcher(art: [legacy, remaster])
        #expect(match(matcher, "Owlbear", game: .pathfinder).portrait == remaster.id)
        #expect(match(matcher, "Owlbear", game: .pathfinder, remastered: false).portrait == legacy.id)
    }

    @Test("Overrides map a renamed creature to its art")
    func overrides() {
        let goblin = art("Space Goblin")
        #expect(match(LibraryArtMatcher(art: [goblin], overrides: ["Gobbo": "Space Goblin"]), "Gobbo").portrait
                    == goblin.id)
    }

    @Test("The portrait is a figure or pawn, the token a token, each standing in for the other")
    func portraitAndToken() {
        let pawn = art("Ksarik"), token = art("Ksarik", token: true)
        let both = match(LibraryArtMatcher(art: [token, pawn]), "Ksarik")
        #expect(both.portrait == pawn.id && both.token == token.id)
        let onlyToken = match(LibraryArtMatcher(art: [token]), "Ksarik")
        #expect(onlyToken.portrait == token.id && onlyToken.token == token.id)
        let onlyPawn = match(LibraryArtMatcher(art: [pawn]), "Ksarik")
        #expect(onlyPawn.token == pawn.id)
    }

    @Test("Art from missing PDFs is passed over, and named when it is all there is")
    func missingSources() {
        let missing = art("Owlbear", game: .pathfinder, available: false, sources: ["Bestiary Battle Cards"])
        let present = art("Owlbear", game: .pathfinder, remastered: true, sources: ["Monster Core Pawn Box"])
        #expect(match(LibraryArtMatcher(art: [missing, present]), "Owlbear", game: .pathfinder, remastered: false)
                    .portrait == present.id)
        let onlyMissing = match(LibraryArtMatcher(art: [missing]), "Owlbear", game: .pathfinder)
        #expect(onlyMissing.portrait == nil && onlyMissing.missingSources == ["Bestiary Battle Cards"])
    }

    @Test("Creatures without art match nothing")
    func noArt() {
        #expect(match(LibraryArtMatcher(), "Ksarik") == .none)
    }
}
