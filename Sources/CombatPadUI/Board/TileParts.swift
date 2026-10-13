import BattleCards
import Bestiary
import CombatPadKit
import SwiftUI

/// Small round condition magnets with their values. Tap to open the condition palette.
struct ConditionChips: View {
    let combatant: Combatant
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            FlowLayout(spacing: 4) {
                ForEach(combatant.conditions) { condition in
                    Text(ConditionLabel.short(condition))
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ConditionLabel.color(condition).opacity(0.9), in: Capsule())
                        .overlay { Capsule().strokeBorder(.white.opacity(0.5)) }
                }
                if combatant.conditions.isEmpty {
                    Image(systemName: "plus.circle").font(.caption).opacity(0.6)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Conditions")
    }
}

/// Long-press or right-click actions on a strip.
struct TileMenu: View {
    let controller: BoardController
    let combatant: Combatant
    @Binding var sheet: BoardSheet?

    var body: some View {
        Button("Conditions…", systemImage: "staroflife") { sheet = .conditions(combatant.id) }
        if combatant.tracksHitPoints {
            Button("Damage or Heal…", systemImage: "heart") { sheet = .hitPoints(combatant.id) }
        }
        Button("Initiative…", systemImage: "number") { sheet = .initiative(combatant.id) }
        if combatant.kind == .creature || combatant.kind == .hazard {
            Picker("Template", selection: templateBinding) {
                Text("Weak").tag(CreatureTemplate.weak)
                Text("Normal").tag(CreatureTemplate.normal)
                Text("Elite").tag(CreatureTemplate.elite)
            }
        }
        Divider()
        if controller.state.phase == .active {
            if combatant.isDelaying {
                Button("Return from Delay", systemImage: "arrow.uturn.left") {
                    controller.change { $0.endDelay(combatant.id) }
                }
            } else {
                Button("Delay", systemImage: "hourglass") { controller.startDelay(combatant.id) }
            }
            Button("Knocked Out (Dying)", systemImage: "heart.slash") {
                controller.change { $0.knockOut(combatant.id) }
            }
        }
        Button("Move to Bench", systemImage: "chair.lounge") { controller.change { $0.moveToBench(combatant.id) } }
        Button("Remove", systemImage: "trash", role: .destructive) { controller.change { $0.remove(combatant.id) } }
    }

    private var templateBinding: Binding<CreatureTemplate> {
        Binding(get: { combatant.template },
                set: { template in controller.change { $0.setTemplate(template, for: combatant.id) } })
    }
}
