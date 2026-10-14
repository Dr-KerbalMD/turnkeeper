import Foundation

/// Turns speech transcripts into initiative numbers: "seventeen", "twenty-three", "17", "minus one",
/// "17 and a half". The last number heard wins, so "fourteen, no, sixteen" gives 16.
public enum SpokenNumberParser {
    /// The last number in the transcript, or nil when there is none.
    public static func initiative(from transcript: String) -> Double? {
        numbers(in: words(transcript)).last?.value
    }

    private static let units = [
        "zero": 0, "oh": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19
    ]
    private static let tens = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
    ]
    private static let negatives: Set<String> = ["minus", "negative"]

    private struct SpokenNumber {
        var value: Double
        /// The words the number used.
        var range: Range<Int>
    }

    private static func words(_ transcript: String) -> [String] {
        transcript.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".")).inverted)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .filter { !$0.isEmpty }
    }

    private static func numbers(in words: [String]) -> [SpokenNumber] {
        var found: [SpokenNumber] = []
        var index = 0
        while index < words.count {
            guard let (value, end) = number(at: index, in: words) else {
                index += 1
                continue
            }
            let isNegative = index > 0 && negatives.contains(words[index - 1])
            let (fraction, fractionEnd) = half(after: end, in: words)
            let start = isNegative ? index - 1 : index
            found.append(SpokenNumber(value: (isNegative ? -value : value) + fraction, range: start..<fractionEnd))
            index = fractionEnd
        }
        return found
    }

    /// A number starting at `index`: digits, a unit word, or a tens word optionally followed by a unit.
    private static func number(at index: Int, in words: [String]) -> (Double, Int)? {
        let word = words[index]
        if let value = Double(word) { return (value, index + 1) }
        if let value = units[word] { return (Double(value), index + 1) }
        guard let ten = tens[word] else { return nil }
        if index + 1 < words.count, let unit = units[words[index + 1]], unit < 10 {
            return (Double(ten + unit), index + 2)
        }
        return (Double(ten), index + 1)
    }

    /// "and a half" or "point five" after a number, used to break ties.
    private static func half(after index: Int, in words: [String]) -> (Double, Int) {
        let rest = Array(words[index...].prefix(3))
        if rest.starts(with: ["and", "a", "half"]) { return (0.5, index + 3) }
        if rest.starts(with: ["point", "five"]) || rest.starts(with: ["point", "5"]) { return (0.5, index + 2) }
        return (0, index)
    }
}
