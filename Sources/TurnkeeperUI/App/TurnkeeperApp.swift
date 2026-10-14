import AppNotices
import BattleCards
import Bestiary
import TurnkeeperKit
import SwiftUI

/// The app, shared by the iPad and Mac entry points.
public struct TurnkeeperApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(TurnkeeperAppDelegate.self) private var appDelegate
    #endif
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    public init() {
        let model = AppModel.live()
        Fonts.register(from: BestiaryStore.locateGeneratedDirectory())
        PlayerDisplay.shared.model = model
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
        .commands { AboutCommands(info: .turnkeeper) }
        #endif
        #if os(macOS)
        Window("Players", id: PlayerWindow.id) {
            PlayerScreen()
                // The window is the player screen: open is on, closed is off.
                .onAppear {
                    PlayerDisplay.shared.hasSecondScreen = true
                    PlayerDisplay.shared.isPlayerScreenOn = true
                }
                .onDisappear {
                    PlayerDisplay.shared.hasSecondScreen = false
                    PlayerDisplay.shared.isPlayerScreenOn = false
                }
        }
        .defaultSize(width: 1280, height: 720)
        #endif
    }
}

enum PlayerWindow {
    static let id = "players"
}
