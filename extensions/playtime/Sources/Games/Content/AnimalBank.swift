import Foundation

extension Games {
    /// Guess My Animal's starter tree (Content/AnimalTree.swift), in all ten languages. The animals come first, then
    /// the tree in pre-order: a question, its yes side, then its no side.
    ///
    ///     # animal cat 🐱
    ///     en: cat
    ///     …
    ///     # ask
    ///     en: Does it live in water?
    ///     …
    ///     # is dolphin
    enum AnimalBank {
        struct Animal: Equatable, Sendable {
            let id: String
            let emoji: String
            let name: Text
        }

        indirect enum Node: Equatable, Sendable {
            case animal(String)
            case question(Text, yes: Node, no: Node)
        }

        static let animals: [String: Animal] = Dictionary(
            Block.parse(source).filter { $0.header.first == "animal" && $0.header.count == 3 }
                .map { ($0.header[1], Animal(id: $0.header[1], emoji: $0.header[2], name: $0.text)) },
            uniquingKeysWith: { a, _ in a })

        static var ids: Set<String> { Set(animals.keys) }

        /// The bundled tree, or nil when the source doesn't make one whole tree (the content test says why).
        static let root: Node? = {
            var steps = Block.parse(source).filter { $0.header.first == "ask" || $0.header.first == "is" }[...]
            func read() -> Node? {
                guard let block = steps.popFirst() else { return nil }
                if block.header.first == "is" { return block.header.count == 2 ? .animal(block.header[1]) : nil }
                guard let yes = read(), let no = read() else { return nil }
                return .question(block.text, yes: yes, no: no)
            }
            let tree = read()
            return steps.isEmpty ? tree : nil
        }()

        /// The tree in one language, as the game walks it.
        static func tree(_ language: Language) -> GuessAnimal.Node {
            func resolve(_ node: Node) -> GuessAnimal.Node {
                switch node {
                case .animal(let id):
                    let animal = animals[id]
                    return .animal(id: id, name: animal?.name[language] ?? id, emoji: animal?.emoji ?? "")
                case .question(let text, let yes, let no):
                    return .question(text[language], yes: resolve(yes), no: resolve(no))
                }
            }
            return root.map(resolve) ?? .animal(id: "?", name: "?", emoji: "")
        }

        /// Everything wrong with the tree, for the content test.
        static func problems() -> [String] {
            guard let root else { return ["the tree doesn't parse into one whole tree"] }
            var found: [String] = []
            var leaves: [String] = []
            func walk(_ node: Node) {
                switch node {
                case .animal(let id): leaves.append(id)
                case .question(let text, let yes, let no):
                    if !text.missing.isEmpty { found.append("question \(text["en"]): missing \(text.missing.map(\.key))") }
                    walk(yes)
                    walk(no)
                }
            }
            walk(root)
            for id in leaves where animals[id] == nil { found.append("\(id): no such animal") }
            for (id, animal) in animals {
                if !animal.name.missing.isEmpty { found.append("\(id): missing \(animal.name.missing.map(\.key))") }
                let uses = leaves.filter { $0 == id }.count
                if uses != 1 { found.append("\(id): in the tree \(uses) times") }
            }
            return found
        }
    }
}

private extension Games.Text {
    subscript(key: String) -> String { byKey[key] ?? "" }
}
