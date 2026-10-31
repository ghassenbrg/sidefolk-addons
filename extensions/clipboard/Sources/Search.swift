import Foundation

/// Finding copies as the person types, four ways (Maccy has the same): every word somewhere (the first way), the exact
/// phrase, fuzzy (the letters in order, as "gtst" finds "git status"; exact matches first), or a regular expression.
/// Each copy's text is folded once (case and accents) and kept while the program runs, so a keystroke over thousands of
/// copies compares strings and nothing else.
@MainActor
final class Searcher {
    /// How much of a long copy is searched: its start, which is what anyone remembers of it.
    static let reach = 20_000
    private var folded: [String: String] = [:]

    /// What is searched in a copy: its text (never a secret's), its files, its app and its kind.
    static func haystack(_ e: Entry) -> String {
        [e.secret ? "" : String((e.text ?? "").prefix(reach)), e.files?.joined(separator: " ") ?? "", e.source ?? "", e.kind.rawValue]
            .joined(separator: " ")
    }

    static func fold(_ s: String) -> String { s.lowercased().folding(options: .diacriticInsensitive, locale: nil) }

    private func hay(_ e: Entry) -> String {
        if let hit = folded[e.id] { return hit }
        let made = Self.fold(Self.haystack(e))
        folded[e.id] = made
        return made
    }

    /// A copy changed or went: its folded text is made again next time.
    func forget(_ id: String) { folded[id] = nil }
    func forgetAll() { folded = [:] }

    /// The copies that match, in the order given (fuzzy: closer matches first). Nil when a regular expression isn't
    /// one, so the palette can say so.
    func filter(_ entries: [Entry], _ query: String, mode: Options.Search) -> [Entry]? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return entries }
        switch mode {
        case .words:
            let words = Self.fold(q).split(separator: " ").map(String.init)
            return entries.filter { e in let h = hay(e); return words.allSatisfy(h.contains) }
        case .exact:
            let phrase = Self.fold(q)
            return entries.filter { hay($0).contains(phrase) }
        case .fuzzy:
            let wanted = Array(Self.fold(q).filter { !$0.isWhitespace })
            var close: [Entry] = [], loose: [Entry] = []
            let phrase = Self.fold(q)
            for e in entries {
                let h = hay(e)
                if h.contains(phrase) { close.append(e) } else if Self.inOrder(wanted, in: h) { loose.append(e) }
            }
            return close + loose
        case .regex:
            guard let pattern = try? NSRegularExpression(pattern: q, options: [.caseInsensitive]) else { return nil }
            return entries.filter { e in
                let h = Self.haystack(e)
                return pattern.firstMatch(in: h, range: NSRange(h.startIndex..., in: h)) != nil
            }
        }
    }

    /// Every character of `wanted`, in order, somewhere in `text`.
    static func inOrder(_ wanted: [Character], in text: String) -> Bool {
        guard !wanted.isEmpty else { return true }
        var i = wanted.startIndex
        for ch in text where ch == wanted[i] {
            i += 1
            if i == wanted.endIndex { return true }
        }
        return false
    }
}
