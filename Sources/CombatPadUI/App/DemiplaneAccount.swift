import CharacterImport
import CombatPadKit
import Foundation
import Observation
import WebKit

/// The GM's Demiplane access on this device: the GraphQL token in the Keychain, and the web session the
/// sign-in page leaves in the web view's cookie store. Neither is part of the library, so neither is synced
/// or exported.
@Observable
@MainActor
final class DemiplaneAccount {
    private(set) var token: String?
    private(set) var session: DemiplaneSession?
    @ObservationIgnored private let tokenStore: KeychainTokenStore

    init(tokenStore: KeychainTokenStore = KeychainTokenStore()) {
        self.tokenStore = tokenStore
        token = tokenStore.read()
    }

    var isSignedIn: Bool { session != nil }
    var tokenExpiry: Date? { token.flatMap(DemiplaneToken.expiry(of:)) }

    /// Reads the session from the web view's cookies, as after signing in.
    func loadSession() async {
        session = DemiplaneSession(cookies: await WKWebsiteDataStore.default().httpCookieStore.allCookies())
    }

    /// Keeps a pasted token, without any "Bearer " prefix. An empty one removes it.
    func saveToken(_ text: String) throws {
        let token = DemiplaneToken.normalized(text)
        if token.isEmpty {
            tokenStore.delete()
            self.token = nil
        } else {
            try tokenStore.save(token)
            self.token = token
        }
    }

    /// Forgets the token and the session's cookies.
    func signOut() async {
        tokenStore.delete()
        token = nil
        let store = WKWebsiteDataStore.default()
        let records = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                               for: records.filter { $0.displayName.contains("demiplane") })
        session = nil
    }

    /// A client with the current session and a usable token: a missing or expired token is renewed from
    /// the session when there is one.
    func client() async throws -> DemiplaneClient {
        await loadSession()
        var client = DemiplaneClient(transport: URLSession.shared, token: token, session: session)
        let isUsable = token.map { !DemiplaneToken.isExpired($0) } ?? false
        if !isUsable, session != nil {
            let renewed = try await client.graphQLToken()
            try saveToken(renewed)
            client.token = renewed
        }
        return client
    }
}
