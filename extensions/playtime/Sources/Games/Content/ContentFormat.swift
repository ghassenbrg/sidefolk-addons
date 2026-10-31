import Foundation

extension Games {
    /// The games' bundled words are written in one small text format, kept in Swift string literals: Playtime ships as
    /// a single program (scripts/build.py packs the binary, its icon and licenses, no resource folder), and one big
    /// Swift array literal would take the type checker minutes where a string parses in milliseconds.
    ///
    ///     // a comment
    ///     # header words
    ///     en: English text
    ///     fr: le texte en français
    ///
    /// A block starts at `#`; each following line is `key: value`, keyed by `Language.key` (or `*` for text every
    /// language shares). A key may repeat inside a block (long word lists), and `values` keeps every line.
    struct Block: Sendable {
        let header: [String]
        let values: [String: [String]]
        /// The block's line in its file, for the content checks' messages.
        let line: Int

        /// The single line for `key`, or nil when it's missing or written twice.
        func one(_ key: String) -> String? {
            guard let lines = values[key], lines.count == 1 else { return nil }
            return lines[0]
        }

        /// The block's text in every language (missing ones stay out, for the checks to catch).
        var text: Text {
            Text(byKey: Dictionary(uniqueKeysWithValues: Language.allCases.compactMap { l in one(l.key).map { (l.key, $0) } }))
        }

        static func parse(_ source: String) -> [Block] {
            var blocks: [Block] = []
            var header: [String]?
            var values: [String: [String]] = [:]
            var start = 0
            func close() {
                if let header { blocks.append(Block(header: header, values: values, line: start)) }
            }
            for (number, raw) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.hasPrefix("//") { continue }
                if line.hasPrefix("#") {
                    close()
                    header = line.dropFirst().split(separator: " ").map(String.init)
                    values = [:]
                    start = number + 1
                } else if let colon = line.firstIndex(of: ":") {
                    let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                    let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    values[key, default: []].append(value)
                }
            }
            close()
            return blocks
        }
    }

    /// "a | b | c" → ["a", "b", "c"].
    static func fields(_ line: String) -> [String] {
        line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// "a, b, c" → ["a", "b", "c"], for word lists. Chinese lists may use 、 as well.
    static func items(_ line: String) -> [String] {
        line.split(whereSeparator: { $0 == "," || $0 == "、" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
