import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// Working a value out: it can only compute, and a value's words are never part of the expression.
@Suite struct SideflowExpressionTests {
    private func values(_ set: [String: JSON] = [:]) -> Values {
        var v = Values()
        for (name, value) in set { v.named[name] = value }
        return v
    }

    private func work(_ written: String, _ set: [String: JSON] = [:]) throws -> JSON { try Expression.evaluate(written, values: values(set)) }

    @Test func itComputes() throws {
        #expect(try work("1 + 2 * 3") == .number(7))
        #expect(try work("(1 + 2) * 3") == .number(9))
        #expect(try work("-2 + 5 % 3") == .number(0))
        #expect(try work("round({{p}} * 1.2, 2)", ["p": .number(9.99)]) == .number(11.99))
        #expect(try work("if({{a}} > 2, \"big\", \"small\")", ["a": .number(3)]) == .string("big"))
        #expect(try work("{{a}} > 2 && {{a}} < 4", ["a": .number(3)]) == .bool(true))
        #expect(try work("upper(\"a\") + lower(\"B\")") == .string("Ab"))
        #expect(try work("join(split(\"a,b\", \",\"), \"-\")") == .string("a-b"))
        #expect(try work("sum({{l}})", ["l": .array([.number(1), .string("2")])]) == .number(3))
        #expect(try work("average({{l}})", ["l": .array([.number(1), .number(2)])]) == .number(1.5))
        #expect(try work("max(1, 5, 3)") == .number(5))
        #expect(try work("field({{r}}, \"a.b\")", ["r": .object(["a": .object(["b": .number(2)])])]) == .number(2))
        #expect(try work("default({{e}}, \"none\")", ["e": .string("")]) == .string("none"))
        #expect(try work("percent(\"12%\")") == .number(0.12))
    }

    @Test func aValuesWordsAreNeverPartOfIt() throws {
        let hostile = "1) + upper(\"x"
        #expect(try work("{{a}}", ["a": .string(hostile)]) == .string(hostile))
        #expect(try work("length({{a}})", ["a": .string("{{b}}")]) == .number(5), "not filled in again")
        #expect(throws: Problem.self) { try work("{{a}} + 1", ["a": .string("1 + 1")]) }
    }

    @Test func wordsAreANumberOnlyPlainlyOrAsStated() throws {
        #expect(try work("{{a}} * 2", ["a": .string("12.5")]) == .number(25), "a plain one")
        for words in ["1,299.00", "18 °C", "12%", "$5", "1.500"] {
            #expect(throws: Problem.self, "\(words)") { try work("{{a}} * 2", ["a": .string(words)]) }
            #expect(throws: Problem.self, "\(words)") { try work("number({{a}})", ["a": .string(words)]) }
        }
        #expect(try work("number({{a}}, \"1,234.56\")", ["a": .string("$1,299.50")]) == .number(1299.5))
        #expect(try work("number({{a}}, \"1.234,56\")", ["a": .string("1.299,50 €")]) == .number(1299.5))
        #expect(try work("number({{a}}, \"1 234,56\")", ["a": .string("1 299,5")]) == .number(1299.5))
        #expect(try work("number({{a}}, \"1,234.56\")", ["a": .string("-18 °C")]) == .number(-18))
        for words in ["1,50", "12,34,567", "1,299.50.2", "5 of 10", "Ports: 80,81", "many", "1,2345"] {
            #expect(throws: Problem.self, "\(words)") { try work("number({{a}}, \"1,234.56\")", ["a": .string(words)]) }
        }
        #expect(throws: Problem.self) { try work("number(\"1\", \"12.3\")") }
    }

    @Test func nothingPassesForAYesOrANo() {
        for written in ["if(1, 2, 3)", "!\"true\"", "1 && true"] { #expect(throws: Problem.self, "\(written)") { try work(written) } }
    }

    @Test func itCantReachAnything() {
        for written in ["read_file(\"/etc/passwd\")", "http(\"x\")", "now()", "exec(\"ls\")", "a", "{{a", "\"open", "1 +", "1 2", "()", "@", "1e3", "007", "1.2.3", "if(true)"] {
            #expect(throws: Problem.self, "\(written)") { try work(written) }
        }
    }

    @Test func itHasLimits() throws {
        #expect(throws: Problem.self, "too long") { try work(String(repeating: "1+", count: Expression.longest) + "1") }
        #expect(throws: Problem.self, "too deep") { try work(String(repeating: "(", count: 200) + "1" + String(repeating: ")", count: 200)) }
        #expect(throws: Problem.self, "too deep") { try work(String(repeating: "-", count: 200) + "1") }
        let big: JSON = .array((0..<30_000).map { .number(Double($0)) })
        #expect(throws: Problem.self, "too much") { try work("sum({{l}})", ["l": big]) }
        #expect(throws: Problem.self, "doubling words") {
            let grow = (0..<20).reduce("\"xxxxxxxxxxxxxxxxxxxx\"") { sofar, _ in "replace(\(sofar), \"x\", \"xx\")" }
            try work(grow)
        }
        #expect(throws: Problem.self, "too big") { try work("9000000000000000 * 9000000000000000") }
        #expect(throws: Problem.self, "zero") { try work("1 / 0") }
    }

    @Test func whatItNamesIsWhatsChecked() throws {
        #expect(Expression.slots(try Expression.parse("round({{a.b}}, 2) + if({{c}}, {{d}}, 1)")) .sorted() == ["a", "c", "d"])
        var body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "w", "data": ["op": "work_out", "from": "{{gone}} + 1"]]]])
        #expect(body.steps[0].usedTexts.flatMap(Values.references) == ["gone"], "a plan and the check read it like any other value")
        body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "w", "data": ["op": "work_out", "from": "nope(1)"]]]])
        #expect(body.step("w") != nil)
    }
}
