import SidefolkExtensionKit

// Currency, an extension that ships with Sidefolk: the internet (two public files, the ECB's and a wider daily one), nothing else.
let ext = Extension(name: "currency")

ext.tool("convert_currency", "Convert money",
         "Converts an amount between currencies: the European Central Bank's reference rates for EUR and 30 major currencies, "
         + "published each working day, and a daily public table for about 160 others such as TND, AED, SAR, EGP, NGN and VND. The answer says which and of what day: keep that line, with its link, when you pass a rate on.",
         input: Schema.object([
             "amount": Schema.number("How much (1 for the rate itself)."),
             "from": Schema.string("The currency it is in: a code like USD or a name like yen.", maxLength: 30),
             "to": Schema.array(of: Schema.string("A currency code or name.", maxLength: 30), "The currencies wanted.", maxItems: 10),
         ], required: ["amount", "from", "to"])) { args in
    guard let amount = args.double("amount") else { throw Problem(L("“{key}” must be a number.", ["key": "amount"])) }
    return try await Rates.convert(amount, from: try args.required("from"), to: args.strings("to"))
}

ext.watcher("rate_crosses") { settings, state in
    try await Rates.crosses(settings, state: state)
}

await ext.serve()
