import SidefolkExtensionKit

// GitHub Issues: public repositories only, read only, no account. The internet, to api.github.com, nothing else.
let ext = Extension(name: "github-issues")

ext.tool("list_issues", "List a repository's issues",
         "A public GitHub repository's issues, newest changed first, 30 a page: number, title, state, labels, author, address. Pull requests are left out. "
         + "With max_pages it goes through that many pages in one call (up to 10) and gives them as one list; its fields say next_page when there's more. "
         + "When GitHub asks to wait before anything is read, rate_limited and retry_after_seconds say how long.",
         input: Schema.object([
             "repository": Schema.string("owner/name, like apple/swift.", maxLength: 150),
             "state": Schema.string("open, closed or all.", oneOf: ["open", "closed", "all"]),
             "page": Schema.integer("Which page to start from, from 1.", minimum: 1, maximum: 100),
             "max_pages": Schema.integer("How many pages to go through, 1 to 10. 1 if left out.", minimum: 1, maximum: 10),
         ], required: ["repository"]), reply: { args in
    try await Issues.list(try Issues.repository(try args.required("repository")), state: args.string("state") ?? "open", page: args.int("page") ?? 1, pages: args.int("max_pages") ?? 1)
})

await ext.serve()
