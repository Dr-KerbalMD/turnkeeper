import Foundation

/// Why importing a character failed. Each case names the operation that failed.
public enum CharacterImportError: Error, LocalizedError {
    case unreadableImage(operation: String, underlying: Error)
    case notASheet(operation: String)
    /// Demiplane exported the sheet before working out its numbers: AC 10 and every modifier +0.
    case missingNumbers(operation: String, name: String)
    case notShared(operation: String)
    case rejected(operation: String, status: Int, message: String)
    case timedOut(operation: String)
    case unexpectedResponse(operation: String, detail: String)

    public var errorDescription: String? {
        switch self {
        case let .unreadableImage(operation, underlying):
            return "\(operation) failed: the image couldn't be read (\(underlying.localizedDescription))."
        case let .notASheet(operation):
            return "\(operation) failed: the file isn't a fillable Demiplane character sheet."
        case let .missingNumbers(operation, name):
            let sheet = name.isEmpty ? "the sheet" : "\(name)'s sheet"
            return "\(operation) failed: Demiplane sent \(sheet) without its numbers "
                + "(AC 10, every modifier +0), so the sheet you have is kept. Refresh again later; if it stays "
                + "blank, ask the player to open and save the character on Demiplane."
        case let .notShared(operation):
            return "\(operation) failed: the character isn't shared. Ask its player to share it by link on Demiplane."
        case let .rejected(operation, status, message):
            return "\(operation) failed: Demiplane answered \(status)\(message.isEmpty ? "" : " (\(message))")."
        case let .timedOut(operation):
            return "\(operation) failed: Demiplane took too long to export the sheet. Try again shortly."
        case let .unexpectedResponse(operation, detail):
            return "\(operation) failed: Demiplane sent something unexpected (\(detail))."
        }
    }
}
