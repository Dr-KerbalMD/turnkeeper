import CombatPadKit
import Foundation

/// A sample campaign for trying the app and for screenshots, used with the `--demo` launch argument:
/// `--demo planner` opens the planner, `--demo setup` a fight in setup, `--demo board` a fight in round 1, and
/// `--demo starfinder` a Starfinder fight in round 1.
enum DemoLibrary {
    @MainActor
    static func model(mode: String, bestiary: BestiaryStore) -> AppModel {
        let model = AppModel(bestiary: bestiary)
        if mode == "starfinder" { return starfinder(model: model, bestiary: bestiary) }
        let campaign = model.addCampaign(name: "Demo: PFS Season 7", game: .pathfinder)
        let party = Party(campaignID: campaign.id, name: "Friday table", level: 3,
                          members: ["Valeros", "Ezren", "Kyra", "Merisiel"].map(PartyMember.init))
        model.library.save(party)
        model.addScenario(to: campaign.id, name: "#7-99: The Goblin Docks", labels: ["10–12 CP", "16–18 CP"])
        guard let scenario = model.library.scenarios(in: campaign.id).first else { return model }
        let encounter = encounter(in: scenario, bestiary: bestiary)
        model.library.save(encounter)
        guard mode != "planner" else {
            model.selection = .encounter(encounter.id)
            return model
        }
        model.startCombat(encounter: encounter, variantLabel: "16–18 CP", party: party)
        if mode == "board", var session = model.activeSession {
            session.state = startedFight(session.state, bestiary: bestiary)
            model.library.save(session)
        }
        return model
    }

    @MainActor
    private static func starfinder(model: AppModel, bestiary: BestiaryStore) -> AppModel {
        let campaign = model.addCampaign(name: "Demo: SFS Season 1", game: .starfinder)
        let party = Party(campaignID: campaign.id, name: "Crew", level: 7,
                          members: ["Navasi", "Obozaya", "Keskodai", "Iseph"].map(PartyMember.init))
        model.library.save(party)
        model.addScenario(to: campaign.id, name: "#1-99: Aeon Ambush", labels: VariantScheme.easierBaseHarder.labels)
        guard let scenario = model.library.scenarios(in: campaign.id).first else { return model }
        var encounter = Encounter(scenarioID: scenario.id, name: "A: Hangar Bay")
        var base = EncounterVariant(label: "Base")
        var troopers = EncounterSlot(creatureKey: key("Aeon Guard Trooper", bestiary))
        troopers.count = 2
        base.slots = [troopers, EncounterSlot(creatureKey: key("Aeon Guard Commander", bestiary)),
                      EncounterSlot(creatureKey: key("Akata", bestiary))]
        encounter.setVariant(base)
        model.library.save(encounter)
        model.startCombat(encounter: encounter, variantLabel: "Base", party: party)
        if var session = model.activeSession {
            session.state = startedFight(session.state, bestiary: bestiary)
            model.library.save(session)
        }
        return model
    }

    private static func encounter(in scenario: Scenario, bestiary: BestiaryStore) -> Encounter {
        var encounter = Encounter(scenarioID: scenario.id, name: "A: Ambush on the Docks")
        encounter.notes = "The goblins hide behind crates. The trapdoor by the pier is the drowning pit."
        var high = EncounterVariant(label: "16–18 CP")
        var warriors = EncounterSlot(creatureKey: key("Goblin Warrior", bestiary))
        warriors.count = 3
        var chanter = EncounterSlot(creatureKey: key("Goblin War Chanter", bestiary))
        chanter.template = .elite
        var dog = EncounterSlot(creatureKey: key("Goblin Dog", bestiary))
        dog.startsOnBench = true
        high.slots = [warriors, chanter, EncounterSlot(creatureKey: key("Drowning Pit", bestiary)), dog]
        var collapse = EncounterEvent(label: "Crates topple", trigger: .initiative(15), occurrence: .onlyRound(2),
                                      text: "DC 18 Reflex or take 2d6 bludgeoning.")
        collapse.bringsInSlotIDs = [dog.id]
        high.events = [collapse]
        encounter.setVariant(high)
        encounter.copyVariant(from: "16–18 CP", to: "10–12 CP")
        return encounter
    }

    private static func startedFight(_ state: CombatState, bestiary: BestiaryStore) -> CombatState {
        var state = state
        var generator = SeededGenerator(seed: 3)
        for combatant in state.combatants where combatant.place == .ladder {
            state.setInitiative(Double(Int.random(in: 5...24, using: &generator)), for: combatant.id)
        }
        state.beginCombat()
        if let goblin = state.combatants.first(where: { $0.name == "Goblin Warrior 2" }) {
            state.addCondition(AppliedCondition(slug: "frightened", value: 2), to: goblin.id)
            let bleed = DamagePart(formula: "1d6", type: "bleed", isPersistent: true)
            state.addCondition(.persistent(bleed), to: goblin.id)
            state.applyDamage(4, to: goblin.id)
        }
        if let kyra = state.combatants.first(where: { $0.name == "Kyra" }) {
            state.addCondition(AppliedCondition(slug: "slowed", value: 1), to: kyra.id)
        }
        return state
    }

    private static func key(_ name: String, _ bestiary: BestiaryStore) -> String {
        bestiary.index.entries.first { $0.name == name && $0.source.isRemastered }?.key
            ?? bestiary.index.entries.first { $0.name == name }?.key ?? ""
    }
}
