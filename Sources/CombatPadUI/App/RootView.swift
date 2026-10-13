import BattleCards
import CombatPadKit
import SwiftUI

/// The planner, or the combat board while a fight is open.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let key = Self.demoCardBackKey {
                // `--demo back <key>`: one creature's player view, for checking card backs.
                if let entry = model.entry(key) { CardBackView(entry: entry) }
            } else if let session = model.activeSession {
                BoardView(sessionID: session.id)
            } else {
                PlannerView()
            }
        }
        .environment(\.padTheme, PadTheme.forGame(model.game))
        .battleCardEnvironment(model)
        .battleCardFullScreenHost()
        .alert("Combat Pad", isPresented: errorBinding) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .overlay(alignment: .bottom) { StatusToast() }
    }

    private static var demoCardBackKey: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--demo"), arguments.indices.contains(index + 2),
              arguments[index + 1] == "back" else { return nil }
        return arguments[index + 2]
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}

/// A passing message at the bottom of the window that fades after a few seconds.
private struct StatusToast: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let message = model.statusMessage {
            Text(message)
                .font(.callout)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 24)
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(5))
                    model.statusMessage = nil
                }
                .onTapGesture { model.statusMessage = nil }
        }
    }
}
