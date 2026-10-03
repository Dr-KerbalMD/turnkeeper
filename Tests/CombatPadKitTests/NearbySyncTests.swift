import Foundation
import Network
import Testing
@testable import CombatPadKit

@Suite("Nearby sync")
struct NearbySyncTests {
    private func package(_ campaign: String) -> LibraryPackage {
        var library = Library()
        library.save(Campaign(name: campaign, game: .pathfinder))
        return LibraryPackage(library: library, bestiaryRevision: "r")
    }

    @Test("Messages survive framing, even when they arrive in pieces")
    func framing() throws {
        let data = try NearbyFraming.frame(.refused(reason: "nope"))
        var buffer = Data(data.prefix(3))
        #expect(try NearbyFraming.nextMessage(from: &buffer) == nil)
        buffer.append(data.dropFirst(3))
        guard case let .refused(reason) = try NearbyFraming.nextMessage(from: &buffer) else {
            Issue.record("Expected a refusal")
            return
        }
        #expect(reason == "nope")
        #expect(buffer.isEmpty)
    }

    @Test("Oversized frames are refused")
    func oversized() {
        var buffer = Data([0xFF, 0xFF, 0xFF, 0xFF])
        #expect(throws: NearbyError.self) { try NearbyFraming.nextMessage(from: &buffer) }
    }

    @Test("Pairing codes have four digits and ignore spaces when entered")
    func codes() {
        var generator = SystemRandomNumberGenerator()
        let code = PairingCode.make(using: &generator)
        #expect(code.count == 4 && code.allSatisfy(\.isNumber))
        #expect(PairingCode.matches("12 34", "1234"))
        #expect(!PairingCode.matches("1235", "1234"))
    }

    @Test("Joining with the right code exchanges libraries over a real connection")
    func exchange() async throws {
        let received = Received()
        let host = try NearbyHost(name: nil, code: "4321") { incoming in
            await received.set(incoming)
            return package("Host campaign")
        }
        let port = try await host.start()
        defer { host.stop() }
        let reply = try await NearbyClient.sync(with: .hostPort(host: "127.0.0.1", port: port), code: "4321",
                                                package: package("Joining campaign"))
        #expect(reply.library.campaigns.map(\.name) == ["Host campaign"])
        #expect(await received.package?.library.campaigns.map(\.name) == ["Joining campaign"])
    }

    @Test("A wrong code is refused")
    func wrongCode() async throws {
        let host = try NearbyHost(name: nil, code: "4321") { _ in
            LibraryPackage(library: Library(), bestiaryRevision: "")
        }
        let port = try await host.start()
        defer { host.stop() }
        await #expect(throws: NearbyError.self) {
            _ = try await NearbyClient.sync(with: .hostPort(host: "127.0.0.1", port: port), code: "0000",
                                            package: package("Joining campaign"))
        }
    }
}

private actor Received {
    var package: LibraryPackage?

    func set(_ package: LibraryPackage) {
        self.package = package
    }
}
