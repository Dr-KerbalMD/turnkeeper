import Bestiary
import TurnkeeperKit
import SwiftUI

/// The custom creature form, in stat-block order. Lists are typed the way the books print them, such as
/// "Acrobatics +5, Stealth +7" or "2d8+11 bludgeoning plus 1d6 fire".
struct CreatureDraftForm: View {
    @Binding var draft: CreatureDraft

    var body: some View {
        Form {
            basics
            if draft.isHazard { HazardDraftSection(hazard: $draft.hazard) }
            statistics
            defenses
            Section("Speed") { TextField("Speed", text: $draft.speeds, prompt: Text("25 feet, fly 40 feet")) }
            StrikesSection(strikes: $draft.strikes)
            SpellcastingSection(entries: $draft.spellcasting)
            AbilitiesSection(abilities: $draft.abilities)
        }
        .formStyle(.grouped)
    }

    private var basics: some View {
        Section("Creature") {
            TextField("Name", text: $draft.name).nameEntry()
            Picker("Kind", selection: $draft.isHazard) {
                Text("Creature").tag(false)
                Text("Complex hazard").tag(true)
            }
            .pickerStyle(.segmented)
            NumberRow(title: "Level", value: $draft.level)
            Picker("Rarity", selection: $draft.rarity) {
                ForEach(["common", "uncommon", "rare", "unique"], id: \.self) { Text($0.capitalized).tag($0) }
            }
            Picker("Size", selection: $draft.size) {
                ForEach(["Tiny", "Small", "Medium", "Large", "Huge", "Gargantuan"], id: \.self) { Text($0).tag($0) }
            }
            TextField("Traits", text: $draft.traits, prompt: Text("goblin, humanoid"))
        }
    }

    @ViewBuilder
    private var statistics: some View {
        if !draft.isHazard {
            Section("Senses and statistics") {
                NumberRow(title: "Perception", value: $draft.perception, signed: true)
                TextField("Senses", text: $draft.senses, prompt: Text("darkvision, scent (imprecise) 30 feet"))
                TextField("Languages", text: $draft.languages, prompt: Text("Common, Goblin"))
                TextField("Skills", text: $draft.skills, prompt: Text("Acrobatics +5, Stealth +7"))
                AttributesRow(attributes: $draft.attributes)
                TextField("Items", text: $draft.items, prompt: Text("dogslicer, leather armor"))
            }
        }
    }

    private var defenses: some View {
        Section("Defenses") {
            NumberRow(title: "AC", value: $draft.armorClass)
            TextField("AC note", text: $draft.armorClassNote, prompt: Text("all-around vision"))
            HStack {
                NumberRow(title: "Fort", value: $draft.fortitude, signed: true)
                NumberRow(title: "Ref", value: $draft.reflex, signed: true)
                NumberRow(title: "Will", value: $draft.will, signed: true)
            }
            TextField("Save note", text: $draft.saveNote, prompt: Text("+1 status to all saves vs. magic"))
            NumberRow(title: "HP", value: $draft.hitPoints)
            TextField("HP note", text: $draft.hitPointNote, prompt: Text("regeneration 10 (deactivated by fire)"))
            NumberRow(title: "Hardness", value: $draft.hardness)
            TextField("Immunities", text: $draft.immunities, prompt: Text("fire, paralyzed"))
            TextField("Weaknesses", text: $draft.weaknesses, prompt: Text("cold iron 5"))
            TextField("Resistances", text: $draft.resistances, prompt: Text("physical 5 (except silver)"))
        }
    }
}

/// A labeled whole-number field, shown with a sign for modifiers.
struct NumberRow: View {
    let title: String
    @Binding var value: Int
    var signed = false

    var body: some View {
        LabeledContent(title) {
            TextField(title, value: $value, format: signed ? .number.sign(strategy: .always()) : .number)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 80)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
        }
    }
}

/// The six attribute modifiers in one row.
private struct AttributesRow: View {
    @Binding var attributes: AttributeModifiers

    var body: some View {
        HStack {
            NumberRow(title: "Str", value: $attributes.strength, signed: true)
            NumberRow(title: "Dex", value: $attributes.dexterity, signed: true)
            NumberRow(title: "Con", value: $attributes.constitution, signed: true)
        }
        HStack {
            NumberRow(title: "Int", value: $attributes.intelligence, signed: true)
            NumberRow(title: "Wis", value: $attributes.wisdom, signed: true)
            NumberRow(title: "Cha", value: $attributes.charisma, signed: true)
        }
    }
}

/// A complex hazard's Stealth and its printed text.
private struct HazardDraftSection: View {
    @Binding var hazard: HazardDraft

    var body: some View {
        Section("Hazard") {
            NumberRow(title: "Stealth", value: $hazard.stealth, signed: true)
            TextField("Stealth note", text: $hazard.stealthNote, prompt: Text("(trained)"))
            TextField("Description", text: $hazard.description, axis: .vertical).lineLimit(2...6)
            TextField("Disable", text: $hazard.disable, axis: .vertical).lineLimit(2...6)
            TextField("Routine", text: $hazard.routine, axis: .vertical).lineLimit(2...8)
            TextField("Reset", text: $hazard.reset, axis: .vertical).lineLimit(1...4)
        }
    }
}
