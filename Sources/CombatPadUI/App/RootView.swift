import CombatPadKit
import SwiftUI

/// The planner, or the combat board while a fight is open.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let session = model.activeSession {
                BoardView(sessionID: session.id)
            } else {
                PlannerView()
            }
        }
        .environment(\.padTheme, PadTheme.forGame(model.game))
        .alert("Combat Pad", isPresented: errorBinding) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .overlay(alignment: .bottom) { StatusToast() }
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
