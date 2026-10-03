import SwiftUI

/// The app, shared by the iPad and Mac entry points.
public struct CombatPadApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
