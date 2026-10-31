import Foundation
import SidefolkExtensionKit

/// Playtime's page in Home (D62, D74): how trivia is going against the companion, a button that opens the game (an
/// `ask` part, so it reaches the game's own sentence through Sidefolk), and the last ten games.
enum PlaytimePage {
    static func render(language: String?) -> Page {
        let w = Words.for(language)
        let r = TriviaRecords.load()
        let hero = r.played == 0
            ? Hero(w["page.title.none"], eyebrow: w["page.eyebrow"], detail: w["page.detail.none"], symbol: "questionmark.bubble.fill")
            : Hero(w("page.title", w.number(r.you), w.number(r.companion)), eyebrow: w["page.eyebrow"], detail: w("page.detail", w.number(r.played)),
                   symbol: "questionmark.bubble.fill",
                   facts: [(w["page.games"], w.number(r.played)), (w["page.best"], r.best["10"].map(w.number) ?? "–"),
                           (w["page.streak"], w.number(r.bestStreak))])
        var sections = [Section(nil, [.hero(hero), .ask(w["page.play"], "let's play trivia"), .note(w["page.how"], tone: .info)])]
        if !r.history.isEmpty {
            let dates = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(w.locale)
            let rows = r.history.map { g -> Row in
                let outcome = g.you > g.companion ? w["page.won"] : g.you < g.companion ? w["page.lost"] : w["page.drew"]
                return Row(w("page.row", w.number(g.you), w.number(g.companion)),
                           detail: [outcome, TriviaScreen.topic(g.topic, w), g.date.formatted(dates)].joined(separator: " · "),
                           symbol: g.you > g.companion ? "crown.fill" : g.you < g.companion ? "hand.thumbsup" : "equal.circle")
            }
            sections.append(Section(w["page.last"], [.list(nil, rows)]))
        }
        return Page(summary: Summary(r.played == 0 ? w["page.title.none"] : w("page.title", w.number(r.you), w.number(r.companion)),
                                     detail: w["page.eyebrow"], symbol: "gamecontroller.fill"),
                    sections: sections)
    }
}
