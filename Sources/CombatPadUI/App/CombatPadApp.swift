import BattleCards
import Bestiary
import CombatPadKit
import SwiftUI

/// The app, shared by the iPad and Mac entry points.
public struct CombatPadApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(CombatPadAppDelegate.self) private var appDelegate
    #endif
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    public init() {
        let model = AppModel.live()
        Fonts.register(from: BestiaryStore.locateGeneratedDirectory())
        PlayerDisplay.shared.bestiary = model.bestiary
        PlayerDisplay.shared.artStore = model.artStore
        PlayerDisplay.shared.creatureArt = model.creatureArt
        _model = State(initialValue: model)
    }

    public var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { url in model.importLibraryFile(url) }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { model.saveNow() }
                }
        }
        .defaultSize(width: 1280, height: 860)
        #if os(macOS)
        Window("Players", id: PlayerWindow.id) {
            PlayerScreen()
                .onAppear { PlayerDisplay.shared.hasSecondScreen = true }
                .onDisappear { PlayerDisplay.shared.hasSecondScreen = false }
        }
        .defaultSize(width: 700, height: 1000)
        #endif
    }
}

enum PlayerWindow {
    static let id = "players"
}
