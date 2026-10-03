import CombatPadKit
import SwiftUI

/// The combat board. Placeholder until the board is built.
struct BoardView: View {
    let sessionID: UUID
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack {
            Text("Board")
            Button("Close") { model.closeBoard() }
        }
    }
}
