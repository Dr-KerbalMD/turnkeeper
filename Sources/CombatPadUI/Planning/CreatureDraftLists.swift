import Bestiary
import CombatPadKit
import SwiftUI

/// Strikes in the custom creature form.
struct StrikesSection: View {
    @Binding var strikes: [StrikeDraft]

    var body: some View {
        Section("Strikes") {
            ForEach($strikes) { $strike in
                VStack(alignment: .leading) {
                    HStack {
                        Picker("Kind", selection: $strike.isRanged) {
                            Text("Melee").tag(false)
                            Text("Ranged").tag(true)
                        }
                        .labelsHidden()
                        .fixedSize()
                        TextField("Weapon", text: $strike.name, prompt: Text("jaws"))
                        NumberRow(title: "Attack", value: $strike.attackBonus, signed: true)
                    }
                    TextField("Traits", text: $strike.traits, prompt: Text("agile, finesse, range increment 30 feet"))
                    TextField("Damage", text: $strike.damage, prompt: Text("2d8+11 bludgeoning plus 1d6 fire"))
                    TextField("Effects", text: $strike.effects, prompt: Text("Grab"))
                }
            }
            .onDelete { strikes.remove(atOffsets: $0) }
            Button("Add Strike", systemImage: "plus") { strikes.append(StrikeDraft()) }
        }
    }
}

/// Spellcasting entries in the custom creature form; each entry's spells are typed as one printed line.
struct SpellcastingSection: View {
    @Binding var entries: [SpellcastingDraft]

    var body: some View {
        Section("Spellcasting") {
            ForEach($entries) { $entry in
                VStack(alignment: .leading) {
                    TextField("Entry", text: $entry.name, prompt: Text("Divine Innate Spells"))
                    HStack {
                        NumberRow(title: "DC", value: $entry.difficultyClass)
                        NumberRow(title: "Attack", value: $entry.attack, signed: true)
                    }
                    TextField("Spells", text: $entry.ranks,
                              prompt: Text("4th dispel magic; Cantrips (2nd) light, shield"), axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .onDelete { entries.remove(atOffsets: $0) }
            Button("Add Spellcasting", systemImage: "plus") { entries.append(SpellcastingDraft()) }
        }
    }
}

/// Abilities in the custom creature form. Text recognizes "DC 22 basic Reflex", "2d6 fire" and ◆ symbols.
struct AbilitiesSection: View {
    @Binding var abilities: [AbilityDraft]

    var body: some View {
        Section {
            ForEach($abilities) { $ability in
                VStack(alignment: .leading) {
                    HStack {
                        TextField("Name", text: $ability.name, prompt: Text("Breath Weapon")).titleEntry()
                        Picker("Actions", selection: $ability.cost) {
                            ForEach(Self.costs, id: \.0) { Text($0.1).tag($0.0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    HStack {
                        Picker("Placed", selection: $ability.section) {
                            Text("Top").tag(AbilitySection.interaction)
                            Text("Defenses").tag(AbilitySection.defensive)
                            Text("Offense").tag(AbilitySection.offensive)
                        }
                        .fixedSize()
                        TextField("Frequency", text: $ability.frequency, prompt: Text("1/day"))
                    }
                    TextField("Traits", text: $ability.traits, prompt: Text("arcane, fire"))
                    TextField("Text", text: $ability.text,
                              prompt: Text("**Trigger** … **Effect** … DC 22 basic Reflex"), axis: .vertical)
                        .lineLimit(2...10)
                }
            }
            .onDelete { abilities.remove(atOffsets: $0) }
            Button("Add Ability", systemImage: "plus") { abilities.append(AbilityDraft()) }
        } header: {
            Text("Abilities")
        } footer: {
            Text("**bold** and *italic* work. DCs such as \"DC 22 basic Reflex\" and damage such as \"2d6 fire\" "
                 + "adjust with templates and conditions.")
        }
    }

    private static let costs: [(ActionCost, String)] = [
        (.none, "—"), (.one, "◆"), (.two, "◆◆"), (.three, "◆◆◆"), (.free, "◇ free"), (.reaction, "⤾ reaction")
    ]
}
