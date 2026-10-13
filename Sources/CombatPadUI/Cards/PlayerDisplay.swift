import Bestiary
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

    /// The creature on show; setting it replaces any handout.
    var entry: BestiaryIndexEntry? {
        didSet { if entry != nil { handout = nil } }
    }
    /// The handout on show, as its name and image path.
    private(set) var handout: (name: String, imagePath: String)?
    var hasSecondScreen = false
    /// The app's model, so the second screen finds creatures, art and handouts the way the GM's screen does.
    var model: AppModel?

    private init() {}

    func show(handout: Handout) {
        entry = nil
        self.handout = (handout.name, handout.imagePath)
    }

    /// Clears the second screen.
    func hide() {
        entry = nil
        handout = nil
    }
}

/// The second screen's content: the current card back, or a dark screen between creatures.
struct PlayerScreen: View {
    @State private var display = PlayerDisplay.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let model = display.model {
                Group {
                    if let entry = display.entry {
                        CardBackView(entry: entry)
                    } else if let handout = display.handout {
                        HandoutPlayerView(name: handout.name, imagePath: handout.imagePath)
                    }
                }
                .environment(model)
                .battleCardEnvironment(model)
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
