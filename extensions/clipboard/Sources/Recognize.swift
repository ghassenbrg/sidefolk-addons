import Foundation

/// What a copied text is, read from the text alone.
enum Recognize {
    static func kind(_ text: String) -> Entry.Kind {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.contains(where: \.isWhitespace), let url = URL(string: t), let scheme = url.scheme?.lowercased(),
           ["http", "https", "mailto", "ftp"].contains(scheme), url.host != nil || scheme == "mailto" {
            return .link
        }
        if t.range(of: #"^(#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?([0-9a-fA-F]{2})?|rgba?\([\d\s.,%]+\)|hsla?\([\d\s.,%deg]+\))$"#,
                   options: .regularExpression) != nil {
            return .color
        }
        return looksLikeCode(t) ? .code : .text
    }

    /// Two lines or more that read like a program: braces, semicolons, keywords, indented blocks.
    static func looksLikeCode(_ t: String) -> Bool {
        let lines = t.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count >= 2 else {
            return t.range(of: #"^\s*(\$ |sudo |git |npm |brew |swift |python3? |cd |ls |curl )"#, options: .regularExpression) != nil
        }
        var score = 0
        for line in lines.prefix(40) {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.hasSuffix("{") || l.hasSuffix("}") || l.hasSuffix(";") || l.hasSuffix(":") && l.hasPrefix("def ") { score += 1 }
            if l.range(of: #"^(func|def|class|struct|import|let|var|const|return|if|for|while|#include|public|private|SELECT|FROM)\b"#,
                       options: .regularExpression) != nil { score += 1 }
            if line.hasPrefix("    ") || line.hasPrefix("\t") { score += 1 }
        }
        return score * 3 >= lines.prefix(40).count * 2
    }

    /// A password, an API key, a token or a card number: kept masked, briefly. A guess on purpose: better to hide an
    /// ordinary word now and then than to keep someone's key in a list for a month.
    static func isSecret(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.contains("PRIVATE KEY-----") { return true }
        guard !t.contains(where: \.isWhitespace), (8...512).contains(t.count) else { return isCard(t) }
        let known = [#"^sk-[A-Za-z0-9_-]{16,}"#, #"^(ghp|gho|ghu|ghs|github_pat)_[A-Za-z0-9_]{20,}"#, #"^AKIA[0-9A-Z]{16}$"#,
                     #"^xox[abpr]-[A-Za-z0-9-]{10,}"#, #"^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$"#, #"^AIza[0-9A-Za-z_-]{35}$"#,
                     #"^glpat-[A-Za-z0-9_-]{20,}"#, #"^npm_[A-Za-z0-9]{36}$"#, #"^(sk|pk|rk)_(live|test)_[A-Za-z0-9]{16,}"#]
        if known.contains(where: { t.range(of: $0, options: .regularExpression) != nil }) { return true }
        if URL(string: t)?.scheme != nil || t.contains("@") || t.contains("/") { return false }
        // A long run of letters, digits and symbols with no words in it, mixing every kind: a generated key or password.
        let upper = t.contains(where: \.isUppercase), lower = t.contains(where: \.isLowercase), digit = t.contains(where: \.isNumber)
        let symbol = t.contains { !$0.isLetter && !$0.isNumber }
        let kinds = [upper, lower, digit, symbol].filter { $0 }.count
        return (t.count >= 20 && kinds >= 3 && digit) || (t.count >= 12 && kinds == 4)
    }

    /// 13 to 19 digits (spaces and dashes allowed) that pass the Luhn check.
    static func isCard(_ text: String) -> Bool {
        guard text.allSatisfy({ $0.isNumber || $0 == " " || $0 == "-" }) else { return false }
        let digits = text.compactMap(\.wholeNumberValue)
        guard (13...19).contains(digits.count) else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { total, pair in
            let d = pair.offset % 2 == 1 ? pair.element * 2 : pair.element
            return total + (d > 9 ? d - 9 : d)
        }
        return sum % 10 == 0
    }
}
