import Foundation

/// What a field is by its name, as Sidefolk decides for a flow's card (T53): somewhere a step goes, words people read, or something else. The words and the way a
/// name is taken apart are a copy of ExtensionPlanCoverage's in the app: change them together.
enum FieldNames {
    /// Its name says it's where something goes.
    static func isPlace(_ key: String) -> Bool { !Set(words(in: key)).isDisjoint(with: placeWords) }

    /// Words people read: a plain string (`plainText`, as far as Sideflow can tell: its catalog has no format or pattern, so the caller says it's a string the tool
    /// takes as text) named only with words for what people read, and nothing that runs. Anything else, an amount, a query, an id, a list, counts as a place: when in
    /// doubt, it's kept and shown as one.
    static func isFreeText(_ key: String, plainText: Bool) -> Bool {
        let lower = key.lowercased(), tokens = Set(words(in: key))
        guard plainText, tokens.isDisjoint(with: placeWords), tokens.isDisjoint(with: codeWords), !codeCompounds.contains(where: lower.contains), !hidesCode(lower) else { return false }
        let allowed = freeTextWords.union(neutralWords)
        func isAllowed(_ word: String) -> Bool { allowed.contains(word) || allowed.contains(String(word.dropLast())) || allowed.contains(String(word.dropLast(2))) }
        return !tokens.isDisjoint(with: freeTextWords) && rawWords(in: key).allSatisfy(isAllowed)
    }

    /// A name that runs something written as one lower-case word (`osascript`, `shellcommand`): a stem in it, unless every place the stem appears is inside a word
    /// that only holds the letters (`description`, `transcript`).
    private static func hidesCode(_ lower: String) -> Bool {
        let text = lower as NSString
        func found(_ word: String) -> [NSRange] {
            var out: [NSRange] = [], from = 0
            while from < text.length {
                let r = text.range(of: word, range: NSRange(location: from, length: text.length - from))
                guard r.location != NSNotFound else { break }
                out.append(r)
                from = r.location + 1
            }
            return out
        }
        let innocent = ["description", "transcript", "manuscript", "prescription", "subscription", "inscription"].flatMap(found)
        return ["script", "command", "shell"].flatMap(found).contains { stem in
            !innocent.contains { NSIntersectionRange($0, stem) == stem }
        }
    }

    /// A name in lower-case words: camel case, acronyms (`URLPath` is `url`, `path`), digits and plurals taken apart.
    static func words(in key: String) -> [String] {
        rawWords(in: key).flatMap { w -> [String] in
            guard w.count > 3, w.hasSuffix("s"), !w.hasSuffix("ss") else { return [w] }
            return w.hasSuffix("es") ? [w, String(w.dropLast()), String(w.dropLast(2))] : [w, String(w.dropLast())]
        }
    }

    /// The words of a name as written, each once.
    private static func rawWords(in key: String) -> [String] {
        let chars = Array(key)
        var words: [String] = [], word = ""
        func flush() { if !word.isEmpty { words.append(word.lowercased()); word = "" } }
        for (i, ch) in chars.enumerated() {
            guard ch.isLetter || ch.isNumber else { flush(); continue }
            if let last = word.last {
                let boundary = (last.isLowercase && ch.isUppercase) || (last.isNumber != ch.isNumber)
                    || (last.isUppercase && ch.isUppercase && i + 1 < chars.count && chars[i + 1].isLowercase)
                if boundary { flush() }
            }
            word.append(ch)
        }
        flush()
        return words
    }

    static let placeWords: Set<String> = [
        "url", "uri", "link", "href", "host", "hostname", "domain", "address", "endpoint", "path", "file", "filename", "filepath", "dir", "directory",
        "folder", "recipient", "email", "repo", "repository", "branch", "channel", "webhook", "target", "destination", "server", "origin", "redirect", "to",
        "cc", "bcc", "chat", "user", "phone", "number", "attendee", "invitee", "location", "workspace", "account", "device", "tv",
    ]
    static let codeWords: Set<String> = [
        "command", "cmd", "script", "code", "exec", "execute", "eval", "expression", "sql", "shell", "statement", "program", "snippet", "args", "argv",
        "regex", "js", "python", "bash", "zsh", "powershell", "applescript", "javascript",
        "arguments", "argument", "executable", "exe", "binary", "cmdline", "flags", "flag", "options", "option", "env", "environment", "prompt", "task", "run", "sh",
        "interpreter", "entrypoint", "macro",
    ]
    static let codeCompounds = ["applescript", "javascript", "typescript", "vbscript", "coffeescript", "powershell", "commandline", "shellscript", "bashscript"]
    static let freeTextWords: Set<String> = [
        "text", "message", "msg", "body", "content", "title", "subject", "summary", "note", "comment", "description", "caption", "reason", "detail", "remark",
    ]
    /// Words that may sit beside a free-text word without making it something else (`long_description`, `plain_text`).
    static let neutralWords: Set<String> = ["short", "long", "full", "plain", "rich", "first", "last", "new", "custom", "extra", "main", "issue"]
}
