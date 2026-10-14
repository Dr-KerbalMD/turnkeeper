import BattleCards
import TurnkeeperKit
import SwiftUI

/// The board: initiative on the left half, the battle card and notes on the right.
struct BoardView: View {
    let sessionID: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.boardTheme) private var theme
    @State private var controller: BoardController?

    var body: some View {
        Group {
            if let controller {
                BoardContent(controller: controller)
            } else {
                ProgressView()
            }
        }
        .task(id: sessionID) {
            self.controller = BoardController(sessionID: sessionID, model: model)
        }
    }
}

private struct BoardContent: View {
    @Bindable var controller: BoardController
    @Environment(\.boardTheme) private var theme
    @State private var sheet: BoardSheet?

    var body: some View {
        VStack(spacing: 0) {
            if controller.isFinished { FinishedBanner(controller: controller) }
            BoardTopBar(controller: controller, sheet: $sheet)
            Divider()
            GeometryReader { geometry in
                let isWide = geometry.size.width > 760
                HStack(spacing: 0) {
                    LadderView(controller: controller, sheet: $sheet)
                        .frame(width: isWide ? geometry.size.width * 0.48 : geometry.size.width)
                    if isWide {
                        Divider()
                        CardPanel(controller: controller)
                    }
                }
            }
        }
        .background(PadBackground())
        .overlay { ListeningOverlay(controller: controller) }
        .sheet(item: $sheet) { sheet in BoardSheetContent(sheet: sheet, controller: controller) }
        .sheet(isPresented: reminderBinding) { ReminderStack(controller: controller) }
        .delayedChoice(controller: controller)
        .sheet(isPresented: endBinding) {
            if controller.endingEvents.isEmpty {
                VictorySheet(controller: controller)
            } else {
                EndOfCombatSheet(controller: controller)
            }
        }
        .boardKeyboardShortcuts(controller: controller)
        .onChange(of: controller.playerScreen, initial: true) { PlayerDisplay.shared.fight = $1 }
        .onDisappear { PlayerDisplay.shared.fight = nil }
        .task { if controller.state.phase == .setup { await VoiceInitiative.shared.requestPermission() } }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(KeyEquivalent("i"), phases: [.down, .up]) { press in holdToSpeak(press) }
    }

    /// On the Mac, holding I works like the hold-to-talk button: it listens for the highlighted strip.
    private func holdToSpeak(_ press: KeyPress) -> KeyPress.Result {
        guard controller.state.phase == .setup, let id = controller.initiativeTargetID else { return .ignored }
        let voice = VoiceInitiative.shared
        if press.phase == .down, voice.listeningFor == nil {
            voice.listen(for: id)
        } else if press.phase == .up, voice.listeningFor == id {
            Task { _ = controller.recordSpokenInitiative(await voice.finish()) }
        }
        return .handled
    }

    private var reminderBinding: Binding<Bool> {
        Binding(get: { !controller.reminders.isEmpty }, set: { _ in })
    }

    private var endBinding: Binding<Bool> {
        Binding(get: { controller.showsEndSheet }, set: { _ in })
    }
}

/// The board's surface: parchment-brown for Pathfinder, a dark console for Starfinder.
private struct PadBackground: View {
    @Environment(\.boardTheme) private var theme

    var body: some View {
        if theme.isDark {
            Starfield().ignoresSafeArea()
        } else {
            LinearGradient(colors: [Color(hex: 0x3B2A1E), Color(hex: 0x2B1F17)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

/// Space or the right arrow for Next, ⌘Z and ⇧⌘Z for undo and redo.
private extension View {
    func boardKeyboardShortcuts(controller: BoardController) -> some View {
        background {
            Group {
                Button("Next Turn") { controller.next() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("Next Turn") { controller.next() }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Undo") { controller.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                Button("Redo") { controller.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
    }
}

/// Every enemy is down: end the fight, or keep going if some might get back up.
private struct VictorySheet: View {
    let controller: BoardController

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "trophy.fill").font(.system(size: 54)).foregroundStyle(.yellow)
            Text("Victory!").font(.largeTitle.bold())
            Text("Every enemy in the fight is at 0 HP.").foregroundStyle(.secondary)
            Button {
                controller.endCombat()
            } label: {
                Text("End Combat").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            Button("Keep Going") { controller.keepGoing() }
        }
        .padding(32)
        .frame(minWidth: 380)
        .interactiveDismissDisabled()
    }
}

/// The events planned for the end of the fight, read out before it closes.
private struct EndOfCombatSheet: View {
    let controller: BoardController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("At the End of Combat", systemImage: "flag.checkered").font(.title2.bold())
            ForEach(controller.endingEvents) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.label).font(.headline)
                    if !event.text.isEmpty { Text(event.text) }
                }
            }
            Button {
                controller.endCombat()
            } label: {
                Text("End Combat").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            Button("Back to the Fight") { controller.keepGoing() }
                .frame(maxWidth: .infinity)
        }
        .padding(32)
        .frame(minWidth: 380)
        .interactiveDismissDisabled()
    }
}

/// Shown on a finished fight, which can be looked at or taken up again.
private struct FinishedBanner: View {
    let controller: BoardController

    var body: some View {
        HStack {
            Label("This fight is over.", systemImage: "flag.checkered")
            Spacer()
            Button("Reopen Fight") { controller.reopen() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.85))
        .foregroundStyle(.white)
    }
}

/// While a microphone is held: who is being listened for, what is heard, and the creature's modifiers to
/// add to the die, large enough to read at arm's length.
private struct ListeningOverlay: View {
    let controller: BoardController
    @State private var voice = VoiceInitiative.shared

    var body: some View {
        if let id = voice.listeningFor, let combatant = controller.state[id] {
            VStack(alignment: .leading, spacing: 12) {
                Label("Listening for \(combatant.name)…", systemImage: "waveform").font(.title2.bold())
                Text(voice.transcript.isEmpty ? "Say the total" : voice.transcript)
                    .font(.largeTitle.monospacedDigit())
                InitiativeSkillsView(skills: controller.initiativeSkills(for: combatant), size: 22)
            }
            .padding(24)
            .frame(maxWidth: 460, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .shadow(radius: 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(32)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}

/// The modifiers a creature might roll for initiative; the one its stat block names is highlighted.
struct InitiativeSkillsView: View {
    let skills: [InitiativeSkill]
    var size: CGFloat = 17

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
            ForEach(skills) { skill in
                GridRow {
                    Text(skill.name).font(.system(size: size, weight: skill.isInitiative ? .bold : .regular))
                    Text(signed(skill.modifier)).font(.system(size: size, weight: .bold).monospacedDigit())
                    if skill.isInitiative {
                        Text("initiative").font(.system(size: size * 0.7)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
