import Foundation

/// Turns Foundry description HTML into `RulesText` markup: paragraphs on new lines, `---` for rules,
/// `**bold**`, `*italic*` and action glyph tokens.
enum HTMLFlattener {
    static func markup(from html: String) -> String {
        var text = html
        for (pattern, replacement) in replacements {
            text = text.replacingOccurrences(
                of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive]
            )
        }
        text = decodeEntities(text)
        return text.split(separator: "\n")
            .map { normalizeSpaces(String($0)) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Applied in order. Action glyph spans first, then block tags, then emphasis, then any other tag.
    private static let replacements: [(String, String)] = [
        (#"<span[^>]*action-glyph[^>]*>\s*([123])\s*</span>"#, "{{actions:$1}}"),
        (#"<span[^>]*action-glyph[^>]*>\s*[aA]\s*</span>"#, "{{actions:1}}"),
        (#"<span[^>]*action-glyph[^>]*>\s*[dD]\s*</span>"#, "{{actions:2}}"),
        (#"<span[^>]*action-glyph[^>]*>\s*[tT]\s*</span>"#, "{{actions:3}}"),
        (#"<span[^>]*action-glyph[^>]*>\s*[fF]\s*</span>"#, "{{actions:free}}"),
        (#"<span[^>]*action-glyph[^>]*>\s*[rR]\s*</span>"#, "{{actions:reaction}}"),
        (#"<hr\s*/?>"#, "\n---\n"),
        (#"<li[^>]*>"#, "\n• "),
        (#"<br\s*/?>"#, "\n"),
        (#"</?(p|div|ul|ol|h[1-6]|table|tr|section|blockquote)[^>]*>"#, "\n"),
        (#"</t[dh]>"#, " "),
        (#"</?(strong|b)>"#, "**"),
        (#"</?(em|i)>"#, "*"),
        (#"<[^>]+>"#, "")
    ]

    private static let entities: [String: String] = [
        "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'",
        "&apos;": "'", "&ndash;": "–", "&mdash;": "—", "&hellip;": "…", "&times;": "×"
    ]

    private static func decodeEntities(_ text: String) -> String {
        entities.reduce(text) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    }

    /// Collapses runs of spaces and drops empty emphasis such as `****` left by adjacent tags.
    private static func normalizeSpaces(_ line: String) -> String {
        line.replacingOccurrences(of: "****", with: "")
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "** **", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
