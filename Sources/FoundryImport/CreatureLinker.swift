import CombatPadKit
import Foundation

/// Links a creature's spells, items, Strike effects and traits to glossary entries.
struct CreatureLinker {
    let links: LinkResolver

    func table(for creature: Creature, items: [JSONValue]) -> LinkTable {
        var table = LinkTable()
        for spell in items where spell["type"].string == "spell" {
            add(.spell, SpellcastingParser.listedName(spell), target: target(of: spell, owner: creature), to: &table)
        }
        for item in StatisticsParser.inventoryItems(items) {
            add(.item, StatisticsParser.inventoryLabel(item), target: target(of: item, owner: creature), to: &table)
        }
        addEffects(items, creature: creature, to: &table)
        for slug in traitSlugs(of: creature) {
            add(.trait, slug, target: links.link(trait: slug, game: creature.game), to: &table)
        }
        return table
    }

    /// The compendium document the item was copied from, else the creature's own copy when it has text.
    private func target(of item: JSONValue, owner: Creature) -> String? {
        let source = item[path: "_stats.compendiumSource"].string
        let flagSource = item[path: "flags.core.sourceId"].string
        if let id = links.link(compendium: source.isEmpty ? flagSource : source) { return id }
        guard !item[path: "system.description.value"].string.isEmpty else { return nil }
        return links.link(embedded: item, owner: owner.key)
    }

    /// Effects such as "Tangle Spores" lead to the creature's own ability, others to the ability glossary.
    private func addEffects(_ items: [JSONValue], creature: Creature, to table: inout LinkTable) {
        let abilities = StrikeParser.abilitiesBySlug(items)
        let slugs = Set(items.filter { $0["type"].string == "melee" }
            .flatMap { $0[path: "system.attackEffects.value"].strings })
        for slug in slugs.sorted() {
            if let ability = abilities[slug] {
                add(.effect, ability["name"].string, target: links.link(embedded: ability, owner: creature.key),
                    to: &table)
            } else {
                let name = Words.label(slug)
                add(.effect, name, target: glossaryAbility(name, game: creature.game), to: &table)
            }
        }
    }

    private func glossaryAbility(_ name: String, game: Game) -> String? {
        let packs = ["\(game.rawValue).bestiary-ability-glossary-srd", "pf2e.bestiary-ability-glossary-srd"]
        return packs.lazy.compactMap { links.link(pack: $0, name: name) }.first
    }

    private func traitSlugs(of creature: Creature) -> [String] {
        let slugs = creature.traits.traits + creature.strikes.flatMap(\.traits) + creature.abilities.flatMap(\.traits)
        return Set(slugs).sorted()
    }

    private func add(_ kind: LinkTable.Kind, _ text: String, target: String?, to table: inout LinkTable) {
        if let target { table.add(kind, text, target: target) }
    }
}
