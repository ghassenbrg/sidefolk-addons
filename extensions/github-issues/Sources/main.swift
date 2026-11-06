import SidefolkExtensionKit

// GitHub Issues: public repositories only, read only, no account. The internet, to api.github.com, nothing else.
let ext = Extension(name: "github-issues")

ext.tool("list_issues", "List a repository's issues",
         "A public GitHub repository's issues, newest changed first, 30 a page: number, title, state, labels, author, address. Pull requests are left out. "
         + "Its fields say next_page when there's another; when GitHub asks to wait, rate_limited and retry_after_seconds say how long, and nothing was read.",
         input: Schema.object([
             "repository": Schema.string("owner/name, like apple/swift.", maxLength: 150),
             "state": Schema.string("open, closed or all.", oneOf: ["open", "closed", "all"]),
             "page": Schema.integer("Which page, from 1.", minimum: 1, maximum: 100),
         ], required: ["repository"]), reply: { args in
    try await Issues.list(try Issues.repository(try args.required("repository")), state: args.string("state") ?? "open", page: args.int("page") ?? 1)
})

await ext.serve()
