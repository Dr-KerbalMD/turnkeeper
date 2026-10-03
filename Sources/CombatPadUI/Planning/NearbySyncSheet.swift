import CombatPadKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Syncs the whole library with another device on the same network. One device shows a code; the other picks
/// it from the list and types the code. Both end up with every change from either side.
struct NearbySyncSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var role = Role.host
    @State private var host: NearbyHost?
    @State private var browser: NearbyBrowser?
    @State private var peers: [NearbyPeer] = []
    @State private var selectedPeer: NearbyPeer?
    @State private var enteredCode = ""
    @State private var status = ""
    @State private var isSyncing = false

    enum Role: String, CaseIterable {
        case host = "Show a code"
        case join = "Join another device"
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("This device", selection: $role) {
                    ForEach(Role.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if role == .host { hostSection } else { joinSection }
                if !status.isEmpty { Section { Text(status) } }
            }
            .formStyle(.grouped)
            .navigationTitle("Sync with Nearby Device")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: role) { await start(role) }
            .onDisappear(perform: stopAll)
        }
        .frame(minWidth: 460, minHeight: 380)
    }

    private var hostSection: some View {
        Section {
            if let host {
                Text(host.code).font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .frame(maxWidth: .infinity)
                Text("On the other device, choose Join, pick \(Self.deviceName), and enter this code.")
                    .foregroundStyle(.secondary)
            } else {
                ProgressView("Starting…")
            }
        }
    }

    private var joinSection: some View {
        Section("Nearby devices") {
            if peers.isEmpty { ProgressView("Looking for devices showing a code…") }
            Picker("Device", selection: $selectedPeer) {
                ForEach(peers) { Text($0.name).tag(NearbyPeer?.some($0)) }
            }
            TextField("Code", text: $enteredCode)
            Button("Sync", systemImage: "arrow.triangle.2.circlepath") { Task { await join() } }
                .disabled(selectedPeer == nil || enteredCode.count < 4 || isSyncing)
        }
    }

    // MARK: Actions

    private func start(_ role: Role) async {
        stopAll()
        status = ""
        if role == .host {
            await startHost()
        } else {
            let browser = NearbyBrowser()
            browser.start { found in Task { @MainActor in peers = found } }
            self.browser = browser
        }
    }

    private func startHost() async {
        var generator = SystemRandomNumberGenerator()
        let code = PairingCode.make(using: &generator)
        do {
            let host = try NearbyHost(name: Self.deviceName, code: code) { incoming in
                await MainActor.run {
                    let reply = LibraryPackage(library: model.library,
                                               bestiaryRevision: model.bestiary.index.sourceRevision)
                    model.importPackage(incoming)
                    status = model.statusMessage ?? "Synced."
                    return reply
                }
            }
            _ = try await host.start()
            self.host = host
        } catch {
            status = error.localizedDescription
        }
    }

    private func join() async {
        guard let peer = selectedPeer else { return }
        isSyncing = true
        defer { isSyncing = false }
        let package = LibraryPackage(library: model.library, bestiaryRevision: model.bestiary.index.sourceRevision)
        do {
            let reply = try await NearbyClient.sync(with: peer.endpoint, code: enteredCode, package: package)
            model.importPackage(reply)
            status = model.statusMessage ?? "Synced."
        } catch {
            status = error.localizedDescription
        }
    }

    private func stopAll() {
        host?.stop()
        host = nil
        browser?.stop()
        browser = nil
        peers = []
    }

    private static var deviceName: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return UIDevice.current.name
        #endif
    }
}
