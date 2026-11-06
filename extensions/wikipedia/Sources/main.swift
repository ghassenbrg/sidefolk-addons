import SidefolkExtensionKit

// Wikipedia: its search, read only. The internet, to wikipedia.org, nothing else.
let ext = Extension(name: "wikipedia")

ext.tool("search_wikipedia", "Search Wikipedia",
         "Searches Wikipedia in one language: titles, a line from each and their addresses, 10 a page. With max_pages it goes through that many pages in one call (up to 5) as one list; "
         + "its fields say next_page, where the next page starts, when there are more. When Wikipedia is busy before anything is read, rate_limited and retry_after_seconds say how long to wait.",
         input: Schema.object([
             "query": Schema.string("What to look for.", maxLength: 200),
             "language": Schema.string("The Wikipedia's language code, like en or fr. en if left out.", maxLength: 12),
             "from": Schema.integer("Where a page starts: 0, or a next_page it gave.", minimum: 0, maximum: 10_000),
             "max_pages": Schema.integer("How many pages to go through, 1 to 5. 1 if left out.", minimum: 1, maximum: 5),
         ], required: ["query"]), reply: { args in
    try await Search.find(try args.required("query"), language: try Search.language(args.string("language")), from: args.int("from") ?? 0, pages: args.int("max_pages") ?? 1)
})

await ext.serve()
