import Foundation

/// What a flow reaches outside Sidefolk: another extension, or an MCP server the person added. Sidefolk holds these and decides every
/// call; this only says which of them each flow leans on and whether they're here now. No accounts, no keys: none of that passes here.
struct Connection: Equatable {
    var id: String
    var title: String
    var server: Bool
    /// What flows use of it that it doesn't offer now.
    var missing: [String]
    var flows: [String]
    var waiting: [String]

    var isHere: Bool { missing.isEmpty }
}

@MainActor enum Connections {
    /// How long a run waits for one to come back before it asks the person.
    static let longestWait: TimeInterval = 7 * 24 * 3600

    /// Which connection a tool belongs to; nil for Sidefolk's own.
    static func id(of tool: String) -> String? {
        guard tool.hasPrefix("ext.") else { return nil }
        let name = tool.dropFirst(4).prefix { $0 != "." }
        return name.isEmpty ? nil : String(name)
    }

    /// The name it goes by: its own while it's here, what it was called while it was, else made from its id.
    static func title(_ id: String, _ catalog: Catalog, _ store: FlowStore) -> String { catalog.connectionTitle(id) }

    /// A step's tool that isn't offered now. Only once the list has been read at all: at the start it just isn't known yet.
    static func isMissing(_ tool: String, _ catalog: Catalog) -> Bool {
        id(of: tool) != nil && catalog.loadedAt != nil && catalog.tool(tool) == nil
    }

    /// Who this flow leans on, in either what's written or what's on.
    private static func tools(_ flow: Flow) -> Set<String> {
        let bodies = [flow.draft] + (flow.live.map { [$0] } ?? [])
        return Set(bodies.flatMap(\.allSteps).compactMap { step in
            if case .action(let tool, _) = step.kind { tool } else { nil }
        })
    }

    /// What this flow needs that isn't here.
    static func missing(_ flow: Flow, _ catalog: Catalog, _ store: FlowStore) -> [String] {
        let ids = Set(tools(flow).filter { isMissing($0, catalog) }.compactMap(id(of:)))
        return ids.map { title($0, catalog, store) }.sorted()
    }

    /// Every connection a flow uses, the missing ones first.
    static func all(_ catalog: Catalog, _ store: FlowStore) -> [Connection] {
        var found: [String: Connection] = [:]
        for flow in store.flows() {
            for tool in tools(flow) {
                guard let id = id(of: tool) else { continue }
                var c = found[id] ?? Connection(id: id, title: title(id, catalog, store), server: server(id, catalog, store), missing: [], flows: [], waiting: [])
                if isMissing(tool, catalog) { c.missing.append(tool) }
                if !c.flows.contains(flow.name) { c.flows.append(flow.name) }
                found[id] = c
            }
        }
        for run in store.unfinished() {
            guard let tool = run.connection?.tool, let id = id(of: tool), found[id] != nil else { continue }
            found[id]?.waiting.append(run.id)
        }
        return found.values.map { c in
            var c = c
            c.missing.sort()
            c.flows.sort()
            return c
        }.sorted { ($0.isHere ? 1 : 0, $0.title) < ($1.isHere ? 1 : 0, $1.title) }
    }

    /// What's here that no flow uses yet.
    static func unused(_ catalog: Catalog, _ store: FlowStore) -> [(title: String, tools: Int)] {
        let used = Set(all(catalog, store).map(\.id))
        return Dictionary(grouping: catalog.tools.filter { $0.fromExtension != nil && !used.contains($0.fromExtension!) }, by: { $0.fromExtension! })
            .map { (title: $0.value.first?.fromTitle ?? $0.key, tools: $0.value.count) }
            .sorted { $0.title < $1.title }
    }

    private static func server(_ id: String, _ catalog: Catalog, _ store: FlowStore) -> Bool {
        catalog.tools.first { $0.fromExtension == id }?.fromServer ?? store.connectionServers.contains(id)
    }

    /// Keeps the names of what's here, because once it's gone nothing else can say what it was called.
    static func remember(_ catalog: Catalog, _ store: FlowStore) {
        var names = store.connectionNames, servers = store.connectionServers, tools = store.connectionTools
        for tool in catalog.tools {
            guard let id = tool.fromExtension, let title = tool.fromTitle else { continue }
            names[id] = title
            tools[tool.name] = tool.title
            if tool.fromServer { servers.insert(id) } else { servers.remove(id) }
        }
        store.keepConnections(names: names, servers: servers, tools: tools)
        (catalog.rememberedNames, catalog.rememberedTools) = (names, tools)
    }
}
