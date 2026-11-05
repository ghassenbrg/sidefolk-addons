import Foundation

/// How words become a number, for everything that compares, adds or reads one: one reader, and a list of what it reads rather than a list of what it doesn't.
/// Words are a number only when they are one number and little else: optionally a label ending in a colon, one sign, and one currency or unit beside it. Nothing is picked from among
/// other words, because no list of them could say which change the number: `12 apples` is 12, but `5 dozen`, `minus 5` and `3 Millionen` aren't 5, 5 and 3.
/// Where the marks could mean two things it stops too: `1.500` and `1,500` are fifteen hundred or one and a half.
enum NumberWords {
    enum Reading: Equatable, Sendable {
        case number(Double)
        /// No digits at all.
        case none
        /// Digits, but not plainly one number.
        case unreadable
    }

    static func number(_ words: String) -> Double? {
        if case .number(let n) = read(words) { return n }
        return nil
    }

    static func read(_ words: String) -> Reading {
        let text = withPlainDigits(words).trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.utf8.contains(where: { (48...57).contains($0) }) else { return .none }
        if let n = machineNumber(text) { return n.isFinite ? .number(n) : .unreadable }
        guard let match = shape.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return .unreadable }
        func part(_ at: Int) -> String? { Range(match.range(at: at), in: text).map { String(text[$0]) } }
        let signs = [part(1), part(3)].compactMap { $0 }.filter { !$0.isEmpty }
        // One currency or unit, one sign: `$5 €` and `--5` aren't anything.
        guard signs.count <= 1, part(2) == nil || part(5) == nil, let digits = part(4), let plain = plain(digits), let value = Double(plain), value.isFinite else { return .unreadable }
        return .number(signs.first.map { $0 == "+" } == false ? -value : value)
    }

    /// As a machine writes one with an exponent: a sign or a point says it isn't an id like `5e3`.
    private static func machineNumber(_ text: String) -> Double? {
        guard text.range(of: #"^[+-]?([0-9]*\.[0-9]+[eE][+-]?[0-9]+|[0-9]+[eE][+-][0-9]+)$"#, options: .regularExpression) != nil else { return nil }
        return Double(text)
    }

    /// The digits and their marks as a machine reads them, if what the marks mean is plain.
    private static func plain(_ run: String) -> String? {
        func matches(_ pattern: String) -> Bool { run.range(of: pattern, options: .regularExpression) != nil }
        if matches(#"^[0-9]{1,15}$"#) { return run }
        // Marks every group of three and ends in a different one before cents: `1,299.00`, `1.299,00`. A million is plain with commas, but `192.168.100.200` isn't with points.
        if matches(#"^[1-9][0-9]{0,2}(,[0-9]{3})+\.[0-9]{2}$"#) { return run.replacingOccurrences(of: ",", with: "") }
        if matches(#"^[1-9][0-9]{0,2}(\.[0-9]{3})+,[0-9]{2}$"#) { return run.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") }
        if matches(#"^[1-9][0-9]{0,2}(,[0-9]{3}){2,}$"#) { return run.replacingOccurrences(of: ",", with: "") }
        // One mark. Up to three digits and then exactly three could be a thousand either way, unless it starts with a nought.
        if matches(#"^[1-9][0-9]{0,2}[.,][0-9]{3}$"#) { return nil }
        if matches(#"^[0-9]{0,15}\.[0-9]+$"#) { return run }
        if matches(#"^[0-9]{1,15},[0-9]{1,2}$"#) || matches(#"^0,[0-9]+$"#) { return run.replacingOccurrences(of: ",", with: ".") }
        return nil
    }

    private static let currency = #"\p{Sc}|USD|EUR|GBP|JPY|CHF|CAD|AUD|NZD|CNY|INR|BRL|MXN|SEK|NOK|DKK|PLN|CZK|HUF|TRY|RUB|KRW|SGD|HKD|ZAR|AED|SAR|ILS|TND|MAD|EGP|THB|IDR|MYR|PHP|VND|UAH"#
    /// Units that can't be taken for how much: not `M`, `K`, `B`, `T` or `m`, which could be a million as easily as anything else.
    private static let unit = #"[%‰٪％]|°[CF]?|ms|ns|µs|s|secs?|seconds?|mins?|minutes?|h|hrs?|hours?|days?|kB|KB|MB|GB|TB|KiB|MiB|GiB|TiB|mg|g|kg|mm|cm|km|ml|l|L"#
    /// Groups: a sign, a currency before, a sign after it, the digits and their marks, then a currency or unit after.
    private static let shape = try! NSRegularExpression(pattern: #"^(?:[\p{L}\p{M}][\p{L}\p{M} _/.-]{0,39}\s*[:=：]\s*)?([-−–+]?)(?:("# + currency + #")\s*)?([-−–+]?)([0-9][0-9.,]*|\.[0-9]+)(?:\s*("# + currency + "|" + unit + #"))?$"#)

    /// Every script's digits as a machine reads them, with the Arabic decimal and thousands marks and the wide minus.
    private static func withPlainDigits(_ text: String) -> String {
        if text.utf8.allSatisfy({ $0 < 128 }) { return text }
        var out = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if scalar.properties.numericType == .decimal, let value = scalar.properties.numericValue, let plain = Unicode.Scalar(UInt32(value) + 48) { out.append(plain) }
            else if scalar == "\u{FF0D}" { out.append("-") }
            else if scalar == "\u{066B}" { out.append(".") }
            else if scalar == "\u{066C}" { out.append(",") }
            else { out.append(scalar) }
        }
        return String(out)
    }
}

extension FlowBody {
    /// Steps that read a number from words rather than a number a tool or a form gave as one. Nothing's wrong yet, so this doesn't hold anything up, but the person hears before a real run that they stop if the words aren't plainly one number.
    @MainActor func readsNumbersFromWords(_ catalog: Catalog) -> Set<String> {
        let steps = allSteps
        func sides(_ condition: Condition) -> [String] { condition.checks.filter { $0.test == .more_than || $0.test == .less_than }.flatMap { [$0.value, $0.than] } }
        return Set(steps.filter { step in
            let looksAt: [String]
            switch step.kind {
            case .branch(let condition, _, _): looksAt = sides(condition)
            case .repeatUntil(let condition, _, _): looksAt = sides(condition)
            case .data(let data):
                let compares = data.op == .filter && (data.test == .more_than || data.test == .less_than)
                let eachField = data.field?.isEmpty == false
                looksAt = (compares ? [data.than ?? ""] : []) + ((data.op == .number || ((data.op == .sum || compares) && !eachField)) ? [data.from] : [])
            default: looksAt = []
            }
            return looksAt.contains { !Self.isPlainlyANumber($0, among: steps, catalog) }
        }.map(\.id))
    }

    /// Whether this is written as a number, or is nothing but a value that comes as one. A field no one has said the type of may well be one.
    @MainActor private static func isPlainlyANumber(_ side: String, among steps: [Step], _ catalog: Catalog) -> Bool {
        guard Values.isOneSlot(side), let slot = Values.slots(side).first else { return NumberWords.number(side) != nil }
        let field = slot.path.split(whereSeparator: { $0 == "." || $0 == "[" }).first.map(String.init)
        guard let source = steps.first(where: { $0.id == slot.name }) else { return field != nil }
        switch source.kind {
        case .action(let tool, _):
            guard let field else { return false }
            return catalog.tool(tool)?.outputTypes[field].map { $0 == "number" || $0 == "integer" } ?? true
        case .ai:
            guard let field else { return false }
            return source.fields?[field].map { $0 == "number" } ?? true
        case .form(let form):
            return form.fields.first { $0.name == field }?.kind == .number
        case .data(let data):
            return field != nil || data.op == .number || data.op == .sum || data.op == .count
        case .text(let text):
            return NumberWords.number(text) != nil
        default:
            return field != nil
        }
    }
}
