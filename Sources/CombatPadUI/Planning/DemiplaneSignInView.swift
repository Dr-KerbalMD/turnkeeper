import CharacterImport
import SwiftUI
import WebKit

/// Demiplane's own sign-in page in a web view. It closes by itself once the session cookie appears; the
/// cookies stay in the default web data store for importing campaigns and exporting sheets.
struct DemiplaneSignInView: View {
    var onSignedIn: () -> Void
    @Environment(\.dismiss) private var dismiss

    private static let start = URL(string: "https://app.demiplane.com/nexus/pathfinder2e")!

    var body: some View {
        NavigationStack {
            DemiplaneWebView(url: Self.start) {
                onSignedIn()
                dismiss()
            }
            .navigationTitle("Sign In to Demiplane")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .frame(minWidth: 480, minHeight: 640)
    }
}

/// A web view that calls back once Demiplane's `access_token` cookie is set.
@MainActor
private struct DemiplaneWebView {
    let url: URL
    let onSignedIn: () -> Void

    func makeCoordinator() -> CookieWatcher {
        CookieWatcher(onSignedIn: onSignedIn)
    }

    private func makeWebView(coordinator: CookieWatcher) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.configuration.websiteDataStore.httpCookieStore.add(coordinator)
        webView.load(URLRequest(url: url))
        return webView
    }
}

#if os(iOS)
extension DemiplaneWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { makeWebView(coordinator: context.coordinator) }
    func updateUIView(_ webView: WKWebView, context: Context) {}
}
#else
extension DemiplaneWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { makeWebView(coordinator: context.coordinator) }
    func updateNSView(_ webView: WKWebView, context: Context) {}
}
#endif

/// Watches the web view's cookies for a signed-in Demiplane session, reporting it once.
@MainActor
final class CookieWatcher: NSObject, WKHTTPCookieStoreObserver {
    private let onSignedIn: () -> Void
    private var hasReported = false

    init(onSignedIn: @escaping () -> Void) {
        self.onSignedIn = onSignedIn
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self, !hasReported, DemiplaneSession(cookies: cookies) != nil else { return }
            hasReported = true
            onSignedIn()
        }
    }
}
