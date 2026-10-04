import CombatPadKit
import Observation
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// What the players are being shown, and whether there is a second screen to show it on: an external
/// display or AirPlay screen on the iPad, or the Players window on the Mac.
@Observable
@MainActor
final class PlayerDisplay {
    static let shared = PlayerDisplay()

    var entry: BestiaryIndexEntry?
    var hasSecondScreen = false
    /// The bestiary, so the second screen can load art without the app model.
    var bestiary = BestiaryStore()

    private init() {}
}

/// The second screen's content: the current card back, or a dark screen between creatures.
struct PlayerScreen: View {
    @State private var display = PlayerDisplay.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let entry = display.entry {
                CardBackView(entry: entry)
                    .environment(AppModel(bestiary: display.bestiary))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: display.entry?.key)
    }
}

#if os(iOS)
/// Routes an external display or AirPlay screen to the player screen; other scenes use SwiftUI's own.
final class CombatPadAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication, configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        guard session.role == .windowExternalDisplayNonInteractive else {
            return UISceneConfiguration(name: nil, sessionRole: session.role)
        }
        let configuration = UISceneConfiguration(name: "Players", sessionRole: session.role)
        configuration.delegateClass = ExternalDisplaySceneDelegate.self
        return configuration
    }
}

/// Shows the player screen on an external display while it is connected.
final class ExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: PlayerScreen())
        window.isHidden = false
        self.window = window
        MainActor.assumeIsolated { PlayerDisplay.shared.hasSecondScreen = true }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        MainActor.assumeIsolated { PlayerDisplay.shared.hasSecondScreen = false }
    }
}
#endif

/// "Show Players": puts the creature on the second screen when there is one, otherwise full screen here.
struct ShowPlayersButton: View {
    let entry: BestiaryIndexEntry?
    @State private var isPresentingHere = false
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        Menu {
            Button("Hide from Players", systemImage: "eye.slash") { PlayerDisplay.shared.entry = nil }
            #if os(macOS)
            Button("Open Players Window", systemImage: "macwindow") { openWindow(id: PlayerWindow.id) }
            #endif
        } label: {
            Label("Show Players", systemImage: "eye")
        } primaryAction: {
            show()
        }
        .disabled(entry == nil)
        .playerPresentation(isPresented: $isPresentingHere) {
            if let entry { PlayerViewSheet(entry: entry) }
        }
    }

    private func show() {
        PlayerDisplay.shared.entry = entry
        if !PlayerDisplay.shared.hasSecondScreen { isPresentingHere = true }
    }
}

extension View {
    /// The player view takes the whole screen on the iPad, so it can be held up to the table. The Mac shows it
    /// as a sheet; the Players window is the full-size option there.
    @ViewBuilder
    func playerPresentation<Content: View>(
        isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
}
