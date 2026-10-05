import Foundation
import PDFKit

/// The filled-in values of a fillable PDF character sheet, by form field name.
struct SheetFields {
    private let values: [String: String]

    init(values: [String: String]) {
        self.values = values
    }

    /// PDFKit can deadlock loading form fields on several threads at once, so sheets are read one at a time.
    private static let pdfLock = NSLock()

    /// Reads every form field of the PDF. Throws when the data isn't a PDF with form fields.
    init(pdf data: Data) throws {
        Self.pdfLock.lock()
        defer { Self.pdfLock.unlock() }
        guard let document = PDFDocument(data: data) else {
            throw CharacterImportError.notASheet(operation: "Reading the character sheet")
        }
        var values: [String: String] = [:]
        for pageIndex in 0..<document.pageCount {
            for annotation in document.page(at: pageIndex)?.annotations ?? [] {
                guard let name = annotation.fieldName, let value = annotation.widgetStringValue else { continue }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { values[name] = trimmed }
            }
        }
        guard !values.isEmpty else { throw CharacterImportError.notASheet(operation: "Reading the character sheet") }
        self.values = values
    }

    /// Starfinder sheets have fields Pathfinder's lack: Computers, credits and UPB.
    var isStarfinder: Bool {
        ["computers", "credits", "upb"].contains { values[$0] != nil }
    }

    func string(_ name: String) -> String {
        values[name] ?? ""
    }

    /// The field as a whole number, such as "+19" or "19"; zero when empty or not a number.
    func int(_ name: String) -> Int {
        Int(string(name).replacingOccurrences(of: "+", with: "")) ?? 0
    }

    /// Whether a checkbox is ticked: "Yes" or "On".
    func isChecked(_ name: String) -> Bool {
        ["yes", "on"].contains(string(name).lowercased())
    }

    /// A comma-separated field as trimmed, non-empty parts.
    func list(_ name: String) -> [String] {
        string(name).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// The numbers N of filled fields named `<prefix>N<suffix>`, in numeric order.
    func numbers(prefix: String, suffix: String = "") -> [Int] {
        values.keys.compactMap { key -> Int? in
            guard key.hasPrefix(prefix), key.hasSuffix(suffix), key.count > prefix.count + suffix.count else {
                return nil
            }
            return Int(key.dropFirst(prefix.count).dropLast(suffix.count))
        }
        .sorted()
    }

    /// The values of `<prefix>N`, in numeric order, without repeats.
    func numbered(_ prefix: String) -> [String] {
        var seen = Set<String>()
        return numbers(prefix: prefix).map { string("\(prefix)\($0)") }.filter { seen.insert($0).inserted }
    }

    /// The highest proficiency rank ticked in `<prefix>_trained|expert|master|legendary`, 0 for untrained.
    func proficiency(_ prefix: String) -> Int {
        ["legendary", "master", "expert", "trained"].firstIndex { isChecked("\(prefix)_\($0)") }
            .map { 4 - $0 } ?? 0
    }
}
