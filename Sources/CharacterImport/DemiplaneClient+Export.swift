import Foundation

/// Exporting the sheet PDF, which Demiplane does for anyone with a shared character's link.
extension DemiplaneClient {
    /// Asks Demiplane to export the sheet PDF, waiting while it is built. Comes back at once when the
    /// character hasn't changed since the last export. While it builds, Demiplane answers 202, or 200
    /// without the PDF link; both mean "ask again".
    public func exportSheet(id: String) async throws -> SheetExport {
        let operation = "Exporting the character sheet"
        let body: [String: Any] = [
            "functionName": "GENERATE_CHARACTER_PDF_LAMBDA_NAME",
            "payload": ["id": id, "isPregen": false, "templateName": "default"]
        ]
        var request = URLRequest(url: Self.appURL.appendingPathComponent("/api/magic-missile"),
                                 cachePolicy: Self.uncached)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        for _ in 0..<maximumPolls {
            let (data, response) = try await transport.send(request)
            switch response.statusCode {
            case 202: try await sleep(pollInterval)
            case 200:
                if let export = Self.sheetExport(data) { return export }
                try await sleep(pollInterval)
            case 401, 403, 404: throw CharacterImportError.notShared(operation: operation)
            default: throw CharacterImportError.rejected(operation: operation, status: response.statusCode, message: "")
            }
        }
        throw CharacterImportError.timedOut(operation: operation)
    }

    /// The PDF link and revision in a finished export; nil while the PDF is still being built.
    static func sheetExport(_ data: Data) -> SheetExport? {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let result = json["result"] as? [String: Any] ?? [:]
        guard let link = result["url"] as? String, let url = URL(string: link) else { return nil }
        return SheetExport(url: url, revision: result["targetRevision"] as? String ?? "")
    }
}
