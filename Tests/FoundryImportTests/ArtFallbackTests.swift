import CombatPadKit
@testable import FoundryImport
import Testing

@Suite("Borrowing art by name")
struct ArtFallbackTests {
    private func creature(_ name: String, pack: String, game: Game = .pathfinder, remastered: Bool = true,
                          art: ArtReference = ArtReference(portrait: "", token: "", cardBack: "")) -> Creature {
        var creature = Creature(key: "\(game.rawValue).\(pack).\(name)", name: name, game: game)
        creature.source = Source(pack: pack, title: pack, isRemastered: remastered)
        creature.art = art
        return creature
    }

    @Test("A creature without art borrows each missing kind from the best same-named one")
    func borrowing() {
        var creatures = [
            creature("Skeleton Guard", pack: "pfs-season-7"),
            creature("Skeleton Guard", pack: "pathfinder-bestiary", remastered: false,
                     art: ArtReference(portrait: "legacy.webp", token: "", cardBack: "")),
            creature("Skeleton Guard", pack: "pathfinder-monster-core",
                     art: ArtReference(portrait: "core.webp", token: "core-token.webp", cardBack: "")),
            creature("Skeleton Guard", pack: "sf-pack", game: .starfinder)
        ]
        let borrowed = ArtFallback.borrow(into: &creatures)
        #expect(creatures[0].art.portrait == "core.webp" && creatures[0].art.token == "core-token.webp")
        #expect(creatures[1].art.portrait == "legacy.webp" && creatures[1].art.token == "core-token.webp")
        #expect(!creatures[3].art.hasArt, "art is never lent across games")
        #expect(borrowed == ["Skeleton Guard (pfs-season-7) ← pathfinder-monster-core",
                             "Skeleton Guard (pathfinder-bestiary) ← pathfinder-monster-core"])
    }

    @Test("Ties go to the remastered creature, and complete art is left alone")
    func ties() {
        var creatures = [
            creature("Goblin", pack: "legacy", remastered: false,
                     art: ArtReference(portrait: "old.webp", token: "", cardBack: "")),
            creature("Goblin", pack: "remaster", art: ArtReference(portrait: "new.webp", token: "", cardBack: "")),
            creature("Goblin", pack: "scenario")
        ]
        _ = ArtFallback.borrow(into: &creatures)
        #expect(creatures[2].art.portrait == "new.webp" && creatures[0].art.portrait == "old.webp")
    }
}
