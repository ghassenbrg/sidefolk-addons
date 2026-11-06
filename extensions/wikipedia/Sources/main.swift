import SidefolkExtensionKit

// Wikipedia: its search, read only. The internet, to wikipedia.org, nothing else.
let ext = Extension(name: "wikipedia")

ext.tool("search_wikipedia", "Search Wikipedia",
         "Searches Wikipedia in one language: titles, a line from each and their addresses, 10 a page. Its fields say next_page, where the next page starts, when there are more; "
         + "when Wikipedia is busy, rate_limited and retry_after_seconds say how long to wait, and nothing was read.",
         input: Schema.object([
             "query": Schema.string("What to look for.", maxLength: 200),
             "language": Schema.string("The Wikipedia's language code, like en or fr. en if left out.", maxLength: 12),
             "from": Schema.integer("Where a page starts: 0, or a next_page it gave.", minimum: 0, maximum: 10_000),
         ], required: ["query"]), reply: { args in
    try await Search.find(try args.required("query"), language: try Search.language(args.string("language")), from: args.int("from") ?? 0)
})

await ext.serve()
