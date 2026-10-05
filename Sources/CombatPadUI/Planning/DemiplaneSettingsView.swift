import CharacterImport
import SwiftUI

/// Demiplane access on this device: signing in (for campaigns, sheet export and renewing the token) and
/// the GraphQL token itself, which can also be pasted.
struct DemiplaneSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var pastedToken = ""
    @State private var isSigningIn = false

    private var account: DemiplaneAccount { model.demiplane }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Web session", value: account.isSignedIn ? "Signed in" : "Signed out")
                    Button(account.isSignedIn ? "Sign In Again…" : "Sign In…", systemImage: "person.badge.key") {
                        isSigningIn = true
                    }
                    if account.isSignedIn || account.token != nil {
                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            Task { await account.signOut() }
                        }
                    }
                } footer: {
                    Text("Signing in lets the app import campaigns, export character sheets so they're current, "
                         + "and renew the token when it expires.")
                }
                Section {
                    LabeledContent("Token", value: tokenStatus)
                    TextField("Paste a token", text: $pastedToken, axis: .vertical)
                        .lineLimit(1...3)
                        .autocorrectionDisabled()
                    HStack {
                        PasteButton(payloadType: String.self) { strings in
                            pastedToken = strings.first ?? ""
                        }
                        Button("Save Token") { save() }
                            .disabled(pastedToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("GraphQL Token")
                } footer: {
                    Text("The token is kept in this device's Keychain. It is never synced or exported.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Demiplane")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await account.loadSession() }
            .sheet(isPresented: $isSigningIn) {
                DemiplaneSignInView { Task { await refreshAfterSignIn() } }
            }
        }
        .frame(minWidth: 420, minHeight: 420)
    }

    private var tokenStatus: String {
        guard let token = account.token else { return "None" }
        guard let expiry = DemiplaneToken.expiry(of: token) else { return "Saved" }
        let relative = expiry.formatted(.relative(presentation: .named))
        return expiry < Date() ? "Expired \(relative)" : "Expires \(relative)"
    }

    private func save() {
        do {
            try account.saveToken(pastedToken)
            pastedToken = ""
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    /// A fresh sign-in also renews the token.
    private func refreshAfterSignIn() async {
        await account.loadSession()
        do {
            _ = try await account.client()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}
