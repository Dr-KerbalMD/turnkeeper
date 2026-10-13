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

    /// The app's model, so the second screen finds creatures, art and handouts the way the GM's screen does.
    var model: AppModel?
    /// The fight on the board, for the player screen; nil when no board is open. Setting it replaces any handout.
    var fight: PlayerScreenFight? {
        didSet { if fight != nil { handout = nil } }
    }
    /// The GM's Player Screen toggle: whether the fight shows on the second screen.
    var isPlayerScreenOn = false
    /// The handout on show, as its name and image path.
    private(set) var handout: (name: String, imagePath: String)?
    var hasSecondScreen = false

    private init() {}

    func show(handout: Handout) {
        self.handout = (handout.name, handout.imagePath)
    }
}

/// The second screen's content: a handout, the fight while the player screen is on, or a dark screen.
struct PlayerScreen: View {
    @State private var display = PlayerDisplay.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let model = display.model {
                content.environment(model).battleCardEnvironment(model)
            }
        }
        .animation(.easeInOut, value: display.fight?.activeKey)
    }

    @ViewBuilder
    private var content: some View {
        if let handout = display.handout {
            HandoutPlayerView(name: handout.name, imagePath: handout.imagePath).transition(.opacity)
        } else if display.isPlayerScreenOn, let fight = display.fight {
            PlayerScreenLayout(fight: fight)
        }
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

/// The board's Player Screen toggle. On the Mac it opens and closes the Players window; on the iPad the fight goes
/// to an external display, or covers this screen, to be held up to the table, until tapped.
struct PlayerScreenToggle: View {
    @State private var display = PlayerDisplay.shared
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    #endif

    var body: some View {
        Toggle("Player Screen", systemImage: "tv", isOn: isOn)
            .toggleStyle(.button)
            .help("Show the players the initiative order, how hurt each enemy looks, and whoever is acting.")
            #if os(iOS)
            .fullScreenCover(isPresented: isCoveringThisScreen) {
                PlayerScreen()
                    .onTapGesture { display.isPlayerScreenOn = false }
                    .statusBarHidden()
                    .persistentSystemOverlays(.hidden)
            }
            #endif
    }

    private var isOn: Binding<Bool> {
        Binding(get: { display.isPlayerScreenOn }, set: { isOn in
            display.isPlayerScreenOn = isOn
            #if os(macOS)
            if isOn { openWindow(id: PlayerWindow.id) } else { dismissWindow(id: PlayerWindow.id) }
            #endif
        })
    }

    #if os(iOS)
    private var isCoveringThisScreen: Binding<Bool> {
        Binding(get: { display.isPlayerScreenOn && !display.hasSecondScreen },
                set: { if !$0 { display.isPlayerScreenOn = false } })
    }
    #endif
}

extension View {
    /// A handout takes the whole screen on the iPad, so it can be held up to the table. The Mac shows it as a
    /// sheet; the Players window is the full-size option there.
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
