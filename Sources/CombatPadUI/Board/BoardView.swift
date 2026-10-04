import CombatPadKit
import SwiftUI

/// The combat pad: initiative on the left half, the battle card and notes on the right, like the paper pad.
struct BoardView: View {
    let sessionID: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.padTheme) private var theme
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
            let controller = BoardController(sessionID: sessionID, model: model)
            if controller.state.phase == .setup { controller.rollCreatureInitiative() }
            self.controller = controller
        }
    }
}

private struct BoardContent: View {
    @Bindable var controller: BoardController
    @Environment(\.padTheme) private var theme
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
        .sheet(item: $sheet) { sheet in BoardSheetContent(sheet: sheet, controller: controller) }
        .sheet(isPresented: reminderBinding) { ReminderStack(controller: controller) }
        .sheet(isPresented: victoryBinding) { VictorySheet(controller: controller) }
        .boardKeyboardShortcuts(controller: controller)
        .task { if controller.state.phase == .setup { await VoiceInitiative.shared.requestPermission() } }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(KeyEquivalent("i"), phases: [.down, .up]) { press in holdToSpeak(press) }
    }

    /// On the Mac, holding I listens for the tapped strip's initiative during setup.
    private func holdToSpeak(_ press: KeyPress) -> KeyPress.Result {
        guard controller.state.phase == .setup, let id = controller.pinnedID else { return .ignored }
        let voice = VoiceInitiative.shared
        if press.phase == .down, voice.listeningFor == nil {
            voice.listen(for: id)
        } else if press.phase == .up, voice.listeningFor == id {
            Task {
                if let value = SpokenNumberParser.initiative(from: await voice.finish()) {
                    controller.change { $0.setInitiative(value, for: id) }
                }
            }
        }
        return .handled
    }

    private var reminderBinding: Binding<Bool> {
        Binding(get: { controller.isBlocked }, set: { _ in })
    }

    private var victoryBinding: Binding<Bool> {
        Binding(get: { controller.showsVictory }, set: { _ in })
    }
}

/// The pad's surface: parchment-brown for Pathfinder, a dark console for Starfinder.
private struct PadBackground: View {
    @Environment(\.padTheme) private var theme

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
