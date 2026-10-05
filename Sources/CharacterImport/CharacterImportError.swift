import Foundation

/// Why importing a character failed. Each case names the operation that failed.
public enum CharacterImportError: Error, LocalizedError {
    case unreadableImage(operation: String, underlying: Error)
    case notASheet(operation: String)
    case notFound(operation: String, id: String)
    case notExported(operation: String)
    case signInNeeded(operation: String)
    case tokenExpired(operation: String)
    case rejected(operation: String, status: Int, message: String)
    case timedOut(operation: String)
    case unexpectedResponse(operation: String, detail: String)

    public var errorDescription: String? {
        switch self {
        case let .unreadableImage(operation, underlying):
            return "\(operation) failed: the image couldn't be read (\(underlying.localizedDescription))."
        case let .notASheet(operation):
            return "\(operation) failed: the file isn't a fillable Demiplane character sheet."
        case let .notFound(operation, id):
            return "\(operation) failed: Demiplane has no character \(id) that you can see."
        case let .notExported(operation):
            return "\(operation) failed: the sheet hasn't been exported. Sign in to Demiplane in Settings, "
                + "or press Export to PDF on the character sheet."
        case let .signInNeeded(operation):
            return "\(operation) failed: sign in to Demiplane in Settings first."
        case let .tokenExpired(operation):
            return "\(operation) failed: the Demiplane token has expired. Sign in again or paste a new token."
        case let .rejected(operation, status, message):
            return "\(operation) failed: Demiplane answered \(status)\(message.isEmpty ? "" : " (\(message))")."
        case let .timedOut(operation):
            return "\(operation) failed: Demiplane took too long to export the sheet. Try again shortly."
        case let .unexpectedResponse(operation, detail):
            return "\(operation) failed: Demiplane sent something unexpected (\(detail))."
        }
    }
}
