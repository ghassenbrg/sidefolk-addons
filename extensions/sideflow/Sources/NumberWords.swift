import Foundation

/// How words become a number, for everything that compares, adds, sorts or reads one: one reader, and it reads only a number written plainly: digits, a minus before them, at most one point.
/// Everything else stops, naming the words. Lists of what changes a number never ended (`5 dozen`, `1 GB`, `Ports: 80,81`, `Down: 5%`), so units, currencies and thousands marks wait for a language where a flow says how to read them.
/// A number a tool or a form gave as a number doesn't come here at all (`Condition.reading`).
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
        let text = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.utf8.contains(where: { (48...57).contains($0) }) else { return .none }
        // `1.500` and `3.142` could be thousands, and `007` is a name: a plain number isn't either.
        guard isPlain(text), text.range(of: #"^-?[1-9][0-9]{0,2}\.[0-9]{3}$"#, options: .regularExpression) == nil else { return .unreadable }
        return Double(text).flatMap { $0.isFinite ? .number($0) : nil } ?? .unreadable
    }

    /// What someone types into a number field: the same shape, and there `1.125` can't be written any other way. `1.500` could as easily be 1.5, typed plainly.
    static func typed(_ text: String) -> Double? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isPlain(text), text.range(of: #"^-?[1-9][0-9]{0,2}\.[0-9]{2}0$"#, options: .regularExpression) == nil else { return nil }
        return Double(text).flatMap { $0.isFinite ? $0 : nil }
    }

    private static func isPlain(_ text: String) -> Bool {
        // Fifteen digits is what a number can hold exactly: past that it wouldn't be what's written.
        text.range(of: #"^-?(0|[1-9][0-9]{0,14})(\.[0-9]{1,15})?$"#, options: .regularExpression) != nil && text.filter(\.isNumber).count <= 15
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
