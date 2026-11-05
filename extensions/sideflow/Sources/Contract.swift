import Foundation
import SidefolkExtensionKit

/// What a flow says it takes and gives, so a flow that calls it finds out before anything goes wrong inside it.
struct FlowInput: Equatable, Sendable {
    var name: String
    var type: ValueType = .text
    var required = true
}

enum ValueType: String, Equatable, Sendable, CaseIterable {
    case text, number, yes_no, list, record

    /// What a person's told it wants.
    var word: String {
        switch self {
        case .text: L("words")
        case .number: L("a number")
        case .yes_no: L("a yes or no")
        case .list: L("a list")
        case .record: L("a record")
        }
    }

    /// It wants the thing itself, not the words a tool said along with it.
    var wantsItself: Bool { self == .list || self == .record }

    /// In the words a tool's own schema uses, which is what a field offering values goes by.
    var schemaWord: String {
        switch self {
        case .text: "string"
        case .number: "number"
        case .yes_no: "boolean"
        case .list: "array"
        case .record: "object"
        }
    }

    /// The value as this, when it plainly is this: the same reading a step's own fields give it. Otherwise nil.
    func fit(_ value: JSON) -> JSON? {
        switch (self, value) {
        case (.text, .string), (.number, .number), (.yes_no, .bool), (.list, .array), (.record, .object): return value
        case (.text, .number), (.text, .bool): return .string(Values.text(value))
        // "1.000" could be a thousand, and as a number it's on its way to a count as 1: a plain tool's number field reads it as a decimal, but this makes it what the flow goes on with.
        case (.number, .string(let words)): return words.trimmed.range(of: #"^[+-]?[0-9]{1,3}(\.000)+$"#, options: .regularExpression) != nil ? nil : Editing.number(words).map { .number($0) }
        case (.yes_no, .string(let words)): return Editing.yesOrNo(words).map { .bool($0) }
        case (.list, .string(let words)):
            if case .array(let items) = Values.structured(value) { return .array(items) }
            return words.trimmed.isEmpty ? nil : .array([.string(words)])
        case (.record, .string):
            if case .object(let fields) = Values.structured(value) { return .object(fields) }
            return nil
        default: return nil
        }
    }
}

enum Contract {
    static let mostInputs = 16

    /// Whether a version kept from before has an AI step or sets off a flow that what's allowed now doesn't have as it is. Sidefolk checks an action at each call,
    /// but nothing checks these two: what's stopped from going on in a run left behind by an edit mustn't come back through an old version.
    static func goesBeyond(_ held: FlowBody, _ allowed: FlowBody) -> Bool {
        held.allSteps.contains { step in
            switch step.kind {
            case .ai, .flow, .call: !allowed.allSteps.contains { $0.id == step.id && $0.kind == step.kind }
            default: false
            }
        }
    }

    /// Whether what's given is what it takes, as what it takes: a reason if not. Something it can do without left out is there as nothing.
    /// `written`: only what's written out, since a practice run hasn't got the real values to go by.
    static func check(_ given: inout [String: JSON], _ inputs: [FlowInput], flow: String, written: Set<String>? = nil) -> String? {
        for input in inputs {
            let value = given[input.name]
            let nothing = switch value { case nil, .null?: true; case .string(let words)?: words.trimmed.isEmpty; default: false }
            if nothing {
                if input.required, written?.contains(input.name) != false { return L("“{flow}” needs “{input}”, and this gives it nothing.", ["flow": flow, "input": input.name]) }
                if written?.contains(input.name) != false || value == nil { given[input.name] = .null }
                continue
            }
            guard let value else { continue }
            if let fitted = input.type.fit(value) {
                given[input.name] = fitted
            } else if written?.contains(input.name) != false {
                return L("“{flow}” wants {type} for “{input}”, and this gives it “{value}”.", ["flow": flow, "type": input.type.word, "input": input.name, "value": Values.text(value).clipped(80)])
            }
        }
        return nil
    }

    /// What's wrong with a call to this, going by what's written in the step.
    static func problems(of inputs: [String: String], to body: FlowBody, flow: String) -> [String] {
        guard !body.inputs.isEmpty else { return [] }
        var out: [String] = []
        for input in body.inputs where input.required && (inputs[input.name]?.trimmed ?? "").isEmpty {
            out.append(L("“{flow}” needs “{input}”: say what to give it.", ["flow": flow, "input": input.name]))
        }
        for input in body.inputs {
            guard let written = inputs[input.name]?.nonEmpty, Values.slots(written).isEmpty, input.type.fit(.string(written)) == nil else { continue }
            out.append(L("“{flow}” wants {type} for “{input}”.", ["flow": flow, "type": input.type.word, "input": input.name]))
        }
        for name in inputs.keys.sorted() where !body.inputs.contains(where: { $0.name == name }) {
            out.append(L("“{flow}” doesn't take “{input}”.", ["flow": flow, "input": name]))
        }
        return out
    }
}

extension Flow {
    /// What this version number ran: what's live now, or one kept from before.
    func body(version: Int) -> FlowBody? {
        version == self.version ? running : revisions.first { $0.version == version }?.body
    }

    /// What's on from now is one on. `keeping`: versions another flow's step is held to, kept beyond the usual number.
    mutating func keep(_ was: FlowBody, at date: Date, keeping pinned: Set<Int>) {
        revisions.append(Revision(at: date, body: was, version: version))
        version += 1
        while revisions.count > Self.keptRevisions, let oldest = revisions.firstIndex(where: { !pinned.contains($0.version) }) { revisions.remove(at: oldest) }
    }
}
