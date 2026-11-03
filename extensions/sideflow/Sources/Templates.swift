import Foundation
import SidefolkExtensionKit

/// Flows to start from. Each is plain data, and a tool it needs that isn't here shows as something to fix, never as a surprise.
@MainActor enum Templates {
    struct Template {
        var id: String
        var name: String
        var line: String
        var symbol: String
        var color: String
        var body: [String: Any]
    }

    static var all: [Template] {
        [
            Template(id: "morning", name: L("Morning brief"), line: L("Your day in three lines, every weekday morning."), symbol: "sun.max", color: "#F2B33D", body: [
                "trigger": ["type": "schedule", "days": ["mon", "tue", "wed", "thu", "fri"], "at": "08:30"],
                "steps": [
                    ["id": "agenda", "do": "agenda.today", "name": L("Get today's plan")],
                    ["id": "brief", "ai": "Write three short, friendly lines about this person's day, from their plan:\n{{agenda}}", "name": L("Write three lines with the AI")],
                    ["do": "notify.user", "with": ["title": L("Your morning"), "body": "{{brief}}"], "name": L("Tell me")],
                ],
            ]),
            Template(id: "changed", name: L("Tell me what changed"), line: L("When a page changes, the AI says what's new and saves a note."), symbol: "doc.text.magnifyingglass", color: "#5B8DEF", body: [
                "trigger": ["type": "watch", "kind": "url_change", "target": "https://example.com"],
                "steps": [
                    ["id": "page", "do": "web.fetch", "with": ["url": "https://example.com"], "name": L("Read the page")],
                    ["id": "what", "ai": "In two sentences, say what this page is about now:\n{{page}}", "name": L("Say what's new with the AI")],
                    ["do": "notes.save", "with": ["text": "Page changed: {{what}}"], "name": L("Save a note")],
                    ["do": "notify.user", "with": ["title": L("The page changed"), "body": "{{what}}"], "name": L("Tell me")],
                ],
            ]),
            Template(id: "shutdown", name: L("End of the day"), line: L("At six, what's still open, and whether you want a reminder for tomorrow."), symbol: "moon.stars", color: "#8E6CF0", body: [
                "trigger": ["type": "schedule", "days": ["mon", "tue", "wed", "thu", "fri"], "at": "18:00"],
                "steps": [
                    ["id": "open", "do": "agenda.today", "name": L("Get what's still open")],
                    ["id": "note", "ai": "In one short sentence, sum up what is still open:\n{{open}}", "name": L("Sum it up with the AI")],
                    ["id": "tomorrow", "ask": "{{note}} Remind you tomorrow?", "options": [L("Yes"), L("No")], "name": L("Ask me")],
                    ["if": ["value": "{{tomorrow}}", "test": "is", "than": L("Yes")], "then": [
                        ["do": "reminders.create", "with": ["title": "{{note}}", "when": "tomorrow at 9"], "name": L("Set a reminder")],
                    ], "else": []],
                ],
            ]),
            Template(id: "rain", name: L("Umbrella check"), line: L("Each morning, the forecast; a word from your companion if rain's coming."), symbol: "cloud.rain", color: "#1FA88A", body: [
                "trigger": ["type": "schedule", "days": ["mon", "tue", "wed", "thu", "fri", "sat", "sun"], "at": "07:30"],
                "steps": [
                    ["id": "forecast", "do": "ext.weather.forecast", "name": L("Get the forecast")],
                    ["if": ["value": "{{forecast}}", "test": "contains", "than": "rain"], "then": [
                        ["do": "notify.user", "with": ["title": L("Take an umbrella"), "body": "{{forecast}}"], "name": L("Tell me")],
                    ], "else": []],
                ],
            ]),
            Template(id: "tally", name: L("Weekly look back"), line: L("On Fridays, what got saved this week, written up as one note."), symbol: "text.book.closed", color: "#52C08A", body: [
                "trigger": ["type": "schedule", "days": ["fri"], "at": "16:00"],
                "steps": [
                    ["id": "notes", "do": "notes.list", "name": L("Get my recent notes")],
                    ["id": "week", "ai": "Write a short look back at this person's week, from their notes:\n{{notes}}", "name": L("Write the week up with the AI")],
                    ["do": "notes.save", "with": ["text": "Week in review\n{{week}}"], "name": L("Save a note")],
                ],
            ]),
            Template(id: "meeting", name: L("Before a meeting"), line: L("Five minutes before, what you noted about it, on your desktop."), symbol: "person.2.wave.2", color: "#1FA88A", body: [
                "trigger": ["type": "event", "event": "calendar.starting"],
                "steps": [
                    ["id": "found", "do": "notes.search", "with": ["query": "{{trigger}}"], "name": L("Find my notes on it")],
                    ["do": "notify.user", "with": ["title": "{{trigger}}", "body": "{{found}}"], "name": L("Tell me")],
                ],
            ]),
            Template(id: "focus", name: L("Focus hour"), line: L("An hour of Focus when you ask, and a word when it's over."), symbol: "circle.lefthalf.filled", color: "#8E6CF0", body: [
                "trigger": ["type": "manual"],
                "steps": [
                    ["do": "attention.set", "with": ["mode": "focus", "minutes": 60], "name": L("Focus for an hour")],
                    ["wait_minutes": 60],
                    ["do": "notify.user", "with": ["title": L("Focus is over"), "body": L("Time to look up.")], "name": L("Tell me")],
                ],
            ]),
            Template(id: "tidy", name: L("Let your companion tidy up"), line: L("On Fridays, your companion goes through the week's notes itself."), symbol: "wand.and.stars", color: "#C65CD6", body: [
                "trigger": ["type": "schedule", "days": ["fri"], "at": "16:00"],
                "steps": [
                    ["id": "tidied", "do": "companion.job", "with": ["job": "Look through the notes I saved this week. Tell me which ones still need something from me, in a short list."], "name": L("Let your companion do it")],
                    ["do": "notify.user", "with": ["title": L("Your week's notes"), "body": "{{tidied}}"], "name": L("Tell me")],
                ],
            ]),
        ]
    }

    static func template(_ id: String) -> Template? { all.first { $0.id == id } }
}
