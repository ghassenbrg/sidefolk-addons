import Foundation
import SidefolkExtensionKit

/// The European Central Bank's reference rates first: the euro against 30 major currencies, published each working day
/// around 16:00 CET. Free, official, and nothing about the person is sent: the same file for everyone. For a currency it
/// doesn't list, Exchange Rate API's open daily table, free with no key and the same file for everyone too. Both ends
/// of a rate come from one table, every answer names its table and day, and a table days old is refused, never shown as today's.
@MainActor
enum Rates {
    static let address = URL(string: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")!
    static let worldAddress = URL(string: "https://open.er-api.com/v6/latest/EUR")!
    static var cache: String { Paths.data + "/ecb-rates.json" }
    static var worldCache: String { Paths.data + "/world-rates.json" }
    /// It updates daily, so this is a table that has stopped.
    nonisolated static let oldestWorld: TimeInterval = 3 * 86400

    struct Table {
        var day: String
        /// Units of each currency per euro; EUR itself is 1.
        var perEuro: [String: Double]
    }

    /// Words people use for the currencies the ECB lists.
    nonisolated static let names: [String: String] = [
        "dollar": "USD", "dollars": "USD", "us dollar": "USD", "us dollars": "USD", "$": "USD", "euro": "EUR", "euros": "EUR", "€": "EUR",
        "yen": "JPY", "¥": "JPY", "pound": "GBP", "pounds": "GBP", "sterling": "GBP", "£": "GBP", "yuan": "CNY", "renminbi": "CNY",
        "rmb": "CNY", "won": "KRW", "swiss franc": "CHF", "swiss francs": "CHF", "franc": "CHF", "francs": "CHF", "rupee": "INR",
        "rupees": "INR", "real": "BRL", "reais": "BRL", "canadian dollar": "CAD", "canadian dollars": "CAD", "australian dollar": "AUD",
        "australian dollars": "AUD", "new zealand dollar": "NZD", "hong kong dollar": "HKD", "singapore dollar": "SGD", "peso": "MXN",
        "pesos": "MXN", "mexican peso": "MXN", "rand": "ZAR", "lira": "TRY", "zloty": "PLN", "krona": "SEK", "kronor": "SEK",
        "krone": "NOK", "kroner": "NOK", "danish krone": "DKK", "forint": "HUF", "koruna": "CZK", "leu": "RON", "lev": "BGN",
        "tunisian dinar": "TND", "tunisian dinars": "TND", "moroccan dirham": "MAD", "algerian dinar": "DZD", "egyptian pound": "EGP",
        "emirati dirham": "AED", "saudi riyal": "SAR", "qatari riyal": "QAR", "kuwaiti dinar": "KWD",
        "naira": "NGN", "cedi": "GHS", "ruble": "RUB", "rouble": "RUB", "hryvnia": "UAH", "dong": "VND", "taka": "BDT",
        "pakistani rupee": "PKR", "argentine peso": "ARS", "chilean peso": "CLP", "colombian peso": "COP", "new taiwan dollar": "TWD",
        "shekel": "ILS", "shekels": "ILS", "baht": "THB", "ringgit": "MYR", "rupiah": "IDR", "philippine peso": "PHP", "krona iceland": "ISK",
    ]

    /// A code or a name as a code, whichever table it's in.
    nonisolated static func wanted(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespaces)
        return names[text.lowercased()] ?? text.uppercased()
    }

    static func code(_ raw: String, in table: Table) throws -> String {
        let code = wanted(raw)
        guard table.perEuro[code] != nil else {
            throw Problem(L("I don't have a rate for “{currency}”. Use a three-letter code like USD or TND.", ["currency": raw.trimmingCharacters(in: .whitespaces)]))
        }
        return code
    }

    /// The table a set of currencies can all be read from: the ECB's when it lists them, else the wider one.
    static func tableFor(_ currencies: [String], now: Date = Date()) async throws -> (table: Table, world: Bool) {
        let ecb = try? await table(now: now)
        if let ecb, currencies.allSatisfy({ ecb.perEuro[wanted($0)] != nil }) { return (ecb, false) }
        return (try await worldTable(now: now), true)
    }

    /// The wider table, from the cache when it was fetched in the last six hours.
    static func worldTable(now: Date = Date()) async throws -> Table {
        if let data = FileManager.default.contents(atPath: worldCache),
           let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let fetched = saved["fetched"] as? Double,
           now.timeIntervalSince1970 - fetched < 6 * 3600, let body = saved["body"] as? String, let table = try? parseWorld(body, now: now) {
            return table
        }
        let body = String(decoding: try await Web.data(worldAddress), as: UTF8.self)
        let table = try parseWorld(body, now: now)
        let saved: [String: Any] = ["fetched": now.timeIntervalSince1970, "body": body]
        if let data = try? JSONSerialization.data(withJSONObject: saved) { FileManager.default.createFile(atPath: worldCache, contents: data) }
        return table
    }

    /// `{"result":"success","time_last_update_unix":…,"base_code":"EUR","rates":{"TND":3.36,…}}`.
    nonisolated static func parseWorld(_ body: String, now: Date) throws -> Table {
        guard let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any], json["result"] as? String == "success",
              json["base_code"] as? String == "EUR", let updated = json["time_last_update_unix"] as? Double,
              let raw = json["rates"] as? [String: Any] else { throw Problem(L("The wider rates source sent something I couldn't read.")) }
        guard now.timeIntervalSince1970 - updated < oldestWorld else { throw Problem(L("The wider rates source hasn't updated for days, so I won't quote it.")) }
        var rates: [String: Double] = ["EUR": 1]
        for (code, value) in raw where code.count == 3 {
            if let number = value as? Double, number > 0 { rates[code] = number }
        }
        guard rates.count > 1 else { throw Problem(L("The wider rates source sent something I couldn't read.")) }
        let read = ISO8601DateFormatter()
        read.formatOptions = [.withFullDate]
        return Table(day: read.string(from: Date(timeIntervalSince1970: updated)), perEuro: rates)
    }

    /// Today's table, from the cache when it was fetched in the last six hours.
    static func table(now: Date = Date()) async throws -> Table {
        if let data = FileManager.default.contents(atPath: cache),
           let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let fetched = saved["fetched"] as? Double,
           now.timeIntervalSince1970 - fetched < 6 * 3600, let day = saved["day"] as? String, let rates = saved["rates"] as? [String: Double] {
            return Table(day: day, perEuro: rates)
        }
        let table = try parse(String(decoding: try await Web.data(address), as: UTF8.self))
        let saved: [String: Any] = ["fetched": now.timeIntervalSince1970, "day": table.day, "rates": table.perEuro]
        if let data = try? JSONSerialization.data(withJSONObject: saved) { FileManager.default.createFile(atPath: cache, contents: data) }
        return table
    }

    /// `<Cube time='2026-10-27'>` then `<Cube currency='USD' rate='1.0812'/>` lines.
    nonisolated static func parse(_ xml: String) throws -> Table {
        guard let day = xml.firstMatch(of: /time=['"](\d{4}-\d{2}-\d{2})['"]/)?.1 else { throw Problem(L("The ECB's rates file had no date.")) }
        var rates = ["EUR": 1.0]
        for m in xml.matches(of: /currency=['"]([A-Z]{3})['"]\s+rate=['"]([0-9.]+)['"]/) { rates[String(m.1)] = Double(m.2) }
        guard rates.count > 1 else { throw Problem(L("The ECB's rates file had no rates.")) }
        return Table(day: String(day), perEuro: rates)
    }

    /// The ECB's day ("2026-10-27") as the person writes dates; English keeps the ECB's own way.
    nonisolated static func day(_ iso: String) -> String {
        let read = DateFormatter()
        read.locale = Locale(identifier: "en_US_POSIX")
        read.timeZone = TimeZone(identifier: "UTC")
        read.dateFormat = "yyyy-MM-dd"
        guard Language.code != "en", let date = read.date(from: iso) else { return iso }
        return Format.date(date, year: true, timeZone: TimeZone(identifier: "UTC")!)
    }

    nonisolated static func rate(_ from: String, _ to: String, in table: Table) -> Double {
        table.perEuro[to]! / table.perEuro[from]!
    }

    nonisolated static func money(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)).locale(Language.locale))
    }

    /// A rate keeps more digits than an amount: 1 USD = 0.8969 EUR.
    nonisolated static func rateText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(abs(value) >= 100 ? 0...2 : 2...4)).locale(Language.locale))
    }

    static func convert(_ amount: Double, from: String, to: [String]) async throws -> String {
        let (table, world) = try await tableFor([from] + to)
        let source = try code(from, in: table)
        var lines: [String] = []
        for target in to {
            let code = try code(target, in: table)
            let rate = rate(source, code, in: table)
            lines.append("\(money(amount)) \(source) = \(money(amount * rate)) \(code) (1 \(source) = \(rateText(rate)) \(code))")
        }
        return lines.joined(separator: "\n") + "\n" + credit(table, world: world)
    }

    /// Where a rate comes from and of which day. The wider source's terms ask for this credit and its site wherever its rates
    /// are used, so those words stay as they wrote them in every language.
    nonisolated static let attribution = "Rates By Exchange Rate API (www.exchangerate-api.com)."
    nonisolated static func credit(_ table: Table, world: Bool) -> String {
        world ? L("Daily rates of {day}, not the ECB's official ones.", ["day": day(table.day)]) + " " + attribution
            : L("ECB reference rates of {day}.", ["day": day(table.day)])
    }

    /// Tells once when the rate goes above (or below) a line, and again only after it came back.
    static func crosses(_ settings: Arguments, state: [String: Any]) async throws -> Check {
        let fromWord = try settings.required("from"), toWord = try settings.required("to")
        let (table, world) = try await tableFor([fromWord, toWord])
        let from = try code(fromWord, in: table), to = try code(toWord, in: table)
        let rate = rate(from, to, in: table)
        let line: Double, above: Bool
        if let a = settings.double("above") { (line, above) = (a, true) } else if let b = settings.double("below") { (line, above) = (b, false) } else {
            throw Problem(L("Give “above” or “below”: the rate to watch for."))
        }
        let source = world ? "world" : "ecb"
        let isPast = above ? rate > line : rate < line
        let (past, triggered) = crossing(isPast, source: source, state: state)
        let now = "1 \(from) = \(rateText(rate)) \(to) (" + (world ? L("Exchange Rate API, {day}", ["day": day(table.day)]) : L("ECB, {day}", ["day": day(table.day)])) + ")"
        let summary = !isPast ? now + "." : above ? L("{rate}, above {line}.", ["rate": now, "line": rateText(line)]) : L("{rate}, below {line}.", ["rate": now, "line": rateText(line)])
        return Check(triggered: triggered, state: ["past": past, "source": source], summary: summary + (world ? " " + attribution : ""))
    }

    /// Whether this check tells. The two tables differ a little, so a table swapped when the ECB's file fails says nothing
    /// about the rate having moved: a swap keeps what was known, and the next check on that table decides.
    nonisolated static func crossing(_ isPast: Bool, source: String, state: [String: Any]) -> (past: Bool, triggered: Bool) {
        let was = state["past"] as? Bool ?? false
        if let last = state["source"] as? String, last != source { return (was, false) }
        return (isPast, isPast && !was)
    }
}
