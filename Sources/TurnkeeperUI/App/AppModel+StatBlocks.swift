import Bestiary
import TurnkeeperKit
import Foundation

extension AppModel {
    /// Reads stat blocks from pasted or dropped items and imports them; the result shows in
    /// `statBlockImport`.
    func importStatBlocks(from providers: [NSItemProvider], encounterID: UUID, currentLabel: String) {
        Task {
            let blocks = await StatBlockPasteboard.blocks(from: providers)
            guard !blocks.isEmpty else { return }
            statBlockImport = importStatBlocks(blocks, encounterID: encounterID, currentLabel: currentLabel)
        }
    }

    /// Adds copied stat blocks to an encounter as custom creatures, each in the variant for its subtier, else
    /// in `currentLabel`. Each variant's change asks first if it would reset a fight in progress.
    func importStatBlocks(_ blocks: [PluckStatBlock], encounterID: UUID, currentLabel: String) -> StatBlockImport? {
        guard let encounter = encounter(encounterID), let scenario = scenario(encounter.scenarioID),
              let campaign = library.campaigns.first(where: { $0.id == scenario.campaignID }) else { return nil }
        let plan = StatBlockImport(blocks: blocks, scenario: scenario, game: campaign.game,
                                   currentLabel: currentLabel)
        for label in Set(plan.items.map(\.variantLabel)) {
            let items = plan.items.filter { $0.variantLabel == label }
            changeVariant(encounterID: encounterID, variantLabel: label) { [self] in
                guard var edited = self.encounter(encounterID) else { return }
                var variant = edited.variant(label)
                for item in items {
                    library.save(item.custom)
                    variant.slots.append(EncounterSlot(creatureKey: item.custom.key))
                }
                edited.setVariant(variant)
                library.save(edited)
            }
        }
        return plan
    }

    /// The live encounters with a slot for the creature, in any variant.
    func encountersUsing(key: String) -> [Encounter] {
        library.encounters.filter { encounter in
            !encounter.isDeleted && encounter.variants.contains { $0.slots.contains { $0.creatureKey == key } }
        }
    }

    /// Deletes a custom creature and takes it out of every encounter.
    func deleteCustomCreature(key: String) {
        guard let custom = library.customCreature(key: key) else { return }
        for var encounter in encountersUsing(key: key) {
            for var variant in encounter.variants {
                variant.slots.removeAll { $0.creatureKey == key }
                encounter.setVariant(variant)
            }
            library.save(encounter)
        }
        library.deleteCustomCreature(custom.id)
    }
}
