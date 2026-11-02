import Foundation
import SidefolkExtensionKit

/// Everything that changes anything, as tools: so Guard sees it, History has it, and a page or a sentence reach it by the same road. Read-only tools answer Ask's questions from one snapshot.
@MainActor
enum NoorTools {
    private static var model: NoorModel { .shared }

    /// A saved change goes to the host's plan as soon as the days it needs are here.
    private static func replan() { model.replan() }

    private static func prayerArg(_ text: String?) throws -> PrayerID {
        guard let text = text?.lowercased(), let prayer = PrayerID(rawValue: text) else { throw Problem(L("Which prayer: Fajr, Dhuhr, Asr, Maghrib or Isha?")) }
        return prayer
    }

    static func install(on ext: Extension) {
        reading(ext)
        names(ext)
        place(ext)
        sources(ext)
        reminders(ext)
        data(ext)
    }

    // MARK: Questions

    private static func reading(_ ext: Extension) {
        // One tool for what is only read, so one "Always" covers every question: a Noor with internet access asks before its first call of each.
        ext.tool("ask_noor", "Ask Noor", "Answers from what Noor already has: the next prayer or iqamah with its countdown and source (next), when one prayer starts with its iqamah separately (prayer), today's Hijri date (hijri), or the Qibla bearing clockwise from true north (qibla).",
                 input: Schema.object(["question": Schema.string("next, prayer, hijri or qibla", oneOf: ["next", "prayer", "hijri", "qibla"]), "prayer": Schema.string("For prayer: fajr, dhuhr, asr, maghrib or isha", oneOf: PrayerID.allCases.map(\.rawValue))], required: ["question"]), reply: { args in
            let s = model.snapshot()
            switch args.string("question") {
            case "prayer":
                let prayer = try prayerArg(args.string("prayer"))
                guard let day = s.today else { return noTimes(s) }
                let when = day.whenIs(prayer)
                let zone = day.zone
                var text = L("{prayer} starts at {time} on {date} ({zone}, {source}).", ["prayer": Words.prayer(prayer), "time": Words.time(when.start, zone: zone), "date": Words.date(when.date, weekday: false), "zone": when.zoneID, "source": Words.provenance(s)])
                if let iqamah = when.iqamah { text += " " + L("Iqamah is at {time}.", ["time": Words.time(iqamah, zone: zone)]) }
                return ToolReply(text).opening(page: "noor", state: ["tab": "prayer", "select": prayer.rawValue, "sheet": NSNull()])
            case "hijri":
                guard let day = s.calendar else { return ToolReply(L("Today's Hijri date isn't here yet. Try again in a moment.")).opening(page: "noor", state: ["tab": "calendar", "sheet": NSNull()]) }
                return ToolReply(L("{date}, by {method}. Local announcements may differ.", ["date": Words.hijri(day.hijri), "method": Words.calendarMethodName(day.method)])).opening(page: "noor", state: ["tab": "calendar", "sheet": NSNull()])
            case "qibla":
                guard let bearing = s.qibla, let place = s.place else { return ToolReply(L("Choose a place first: the bearing is from where you are.")).opening(page: "noor", state: ["tab": "qibla", "sheet": NSNull()]) }
                return ToolReply(L("From {place}, Qibla is {degrees}° clockwise from true north. This Mac can't sense which way you are facing.", ["place": place.label, "degrees": "\(bearing.rounded)"])).opening(page: "noor", state: ["tab": "qibla", "sheet": NSNull()])
            default:
                guard let focus = DialScene.focus(s) else { return noTimes(s) }
                let text = L("{title} at {time}, {countdown}. {source}.", ["title": focus.title, "time": focus.time, "countdown": focus.countdown.lowercased(), "source": Words.provenance(s)])
                return ToolReply(text).opening(page: "noor", state: ["tab": "overview", "sheet": NSNull()])
            }
        })
        ext.tool("convert_date", "Convert a date", "Converts a date between Gregorian and Hijri under the selected calendar method.",
                 input: Schema.object(["direction": Schema.string("g2h or h2g", oneOf: ["g2h", "h2g"]), "date": Schema.string("YYYY-MM-DD")], required: ["date"]), reply: { args in
            let m = model
            m.conversion = nil
            m.conversionProblem = nil
            let text = args.string("date") ?? ""
            let toHijri = (args.string("direction") ?? "g2h") == "g2h"
            let method = m.prefs.calendarMethod
            let outcome: Outcome<CalendarDay>
            if toHijri {
                guard let date = CivilDate(iso: text) else {
                    m.conversionProblem = L("“{date}” is not a valid date.", ["date": text])
                    return ToolReply(m.conversionProblem ?? "").opening(page: "noor", state: ["sheet": "convert", "direction": "g2h", "convert_date": text])
                }
                outcome = await m.provider.load(AlAdhan.gregorianToHijri(date, method: method), now: m.now)
            } else {
                let p = text.split(separator: "-").compactMap { Int($0) }
                guard p.count == 3, let date = HijriDate(year: p[0], month: p[1], day: p[2]) else {
                    m.conversionProblem = L("“{date}” is not a valid date.", ["date": text])
                    return ToolReply(m.conversionProblem ?? "").opening(page: "noor", state: ["sheet": "convert", "direction": "h2g", "convert_date": text])
                }
                outcome = await m.provider.load(AlAdhan.hijriToGregorian(date, method: method), now: m.now)
            }
            guard let day = outcome.value else {
                if case .unavailable(let why) = outcome { m.conversionProblem = Words.problem(why).isEmpty ? L("That date couldn't be converted.") : Words.problem(why) }
                return ToolReply(m.conversionProblem ?? "").opening(page: "noor", state: ["sheet": "convert", "direction": toHijri ? "g2h" : "h2g", "convert_date": text])
            }
            m.conversion = day
            let words = L("{hijri} is {gregorian}, by {method}.", ["hijri": Words.hijri(day.hijri), "gregorian": Words.date(day.gregorian), "method": Words.calendarMethodName(day.method)])
            return ToolReply(words).opening(page: "noor", state: ["sheet": "convert", "direction": toHijri ? "g2h" : "h2g", "convert_date": text])
        })
        ext.tool("open_noor", "Open Noor", "Opens one of Noor's places.", input: Schema.object(["what": Schema.string("overview, prayer, calendar, qibla, names, ramadan or preferences", oneOf: ["overview", "prayer", "calendar", "qibla", "names", "ramadan", "preferences"])], required: ["what"]), reply: { args in
            let what = args.string("what") ?? "overview"
            switch what {
            case "ramadan": return ToolReply(L("Here is the Ramadan planner. No reminder starts until you enable it.")).opening(page: "noor", state: ["sheet": "ramadan"])
            case "preferences": return ToolReply(L("Here are Noor's preferences.")).opening(page: "noor", state: ["sheet": "prefs", "section": "place"])
            default: return ToolReply(L("Here it is.")).opening(page: "noor", state: ["tab": what, "sheet": NSNull()])
            }
        })
        ext.tool("set_display", "Change Noor's display", "Changes how Noor shows times, occasions and the Name.",
                 input: Schema.object(["what": Schema.string("time, occasions or name"), "value": Schema.string("For time: system, hour24, hour12"), "on": Schema.boolean("For occasions and name")], required: ["what"])) { args in
            try model.save { p in
                switch args.string("what") {
                case "time": p.timeFormat = Preferences.TimeFormat(rawValue: args.string("value") ?? "") ?? p.timeFormat
                case "occasions": p.showOccasions = args.bool("on") ?? p.showOccasions
                case "name": p.showNameOfTheDay = args.bool("on") ?? p.showNameOfTheDay
                default: break
                }
            }
            replan()
            return L("Changed.")
        }
        ext.tool("set_calendar_method", "Change Noor's calendar method", "Changes the Hijri calendar method. The prayer method is separate.", input: Schema.object(["value": Schema.string("A method's id from the provider's list.")], required: ["value"])) { args in
            guard let method = CalendarMethod(rawValue: args.string("value") ?? "") else { throw Problem(L("That isn't a calendar method.")) }
            try model.save { $0.calendarMethod = method }
            model.freshen(refresh: false)
            replan()
            return L("Calendar method: {method}.", ["method": Words.calendarMethodName(method)])
        }
    }

    private static func noTimes(_ s: NoorSnapshot) -> ToolReply {
        ToolReply(s.validity == .noPlace || s.validity == .noSource ? L("Choose a place first.") : L("No valid time is available for that. Open Noor to check the source.")).opening(page: "noor", state: ["tab": "overview"])
    }

    // MARK: Names

    private static func names(_ ext: Extension) {
        ext.tool("save_name", "Save a Name", "Saves or removes one of the Names on this Mac.", input: Schema.object(["number": Schema.integer("1 to 99", minimum: 1, maximum: 99), "saved": Schema.boolean("Whether it should be saved")], required: ["number"])) { args in
            guard let number = args.int("number"), (1...99).contains(number) else { throw Problem(L("There are 99 Names.")) }
            let on = args.bool("saved") ?? true
            try model.setBookmark(number, on)
            return on ? L("Saved.") : L("Removed.")
        }
        ext.tool("show_name", "Show a Name", "Shows one of the Names by its number or transliteration.", input: Schema.object(["name": Schema.string("A transliteration, like Ar Rahmaan, or a number")], required: ["name"]), reply: { args in
            let text = (args.string("name") ?? "").lowercased()
            let flat = { (s: String) in s.lowercased().filter(\.isLetter) }
            guard let found = model.names.first(where: { "\($0.number)" == text || flat($0.transliteration) == flat(text) || $0.arabic == text }) else {
                return ToolReply(L("I couldn't find “{name}” among the Names.", ["name": text])).opening(page: "noor", state: ["tab": "names", "q": text, "sheet": NSNull(), "filter": NSNull(), "shelf": NSNull()])
            }
            return ToolReply("\(found.transliteration): \(found.meaning) (\(L("English meaning"))).").opening(page: "noor", state: ["tab": "names", "name": found.number, "sheet": "name", "q": NSNull(), "filter": NSNull(), "shelf": NSNull()], push: true)
        })
    }

    // MARK: Place

    private static func placeFrom(_ args: Arguments, origin: Place.Origin = .manual) throws -> Place {
        guard let label = args.string("label"), let zone = args.string("zone"), let lat = args.double("latitude"), let lon = args.double("longitude") else { throw Problem(L("That place is missing something.")) }
        let id = "p" + String(format: "%.2f_%.2f", lat, lon).replacingOccurrences(of: "-", with: "m")
        do {
            return try Place(id: id, label: label, region: args.string("region"), country: args.string("country"), latitude: lat, longitude: lon, zoneID: zone, origin: origin)
        } catch {
            switch error {
            case .badLatitude, .badLongitude: throw Problem(L("Latitude runs from −90 to 90, longitude from −180 to 180."))
            case .badZone: throw Problem(L("That isn't a time zone like Asia/Tokyo."))
            default: throw Problem(L("That place can't be used."))
            }
        }
    }

    /// The source a place brings when calculated times are what is followed: same reminder choices, a new revision, so nothing is scheduled twice.
    private static func moving(to place: Place) throws {
        // One calculated source, the place's: another's would answer for a place that isn't this one.
        var next = model.sources.filter { $0.kind == .manual }
        let calculated = TimetableSource.calculated(for: place)
        next.append(calculated)
        let manual = model.source?.kind == .manual
        try model.commit(place: place, sourceID: manual ? model.prefs.sourceID : calculated.id, sources: next)
        model.placeResults = []
        model.placeProblem = nil
    }

    private static func place(_ ext: Extension) {
        ext.tool("search_places", "Find a place", "Looks up places by name. Only the words go to Sidefolk's place search.", input: Schema.object(["query": Schema.string("A city or place", maxLength: 80)], required: ["query"]), reply: { args in
            let query = args.string("query") ?? ""
            let found = await SharedPlace.search(query)
            model.placeProblem = found.problem.map { $0 == "busy" ? L("One moment between searches.") : $0 }
            model.placeResults = found.places.compactMap { p in
                guard let zone = p.timeZone else { return nil }
                return try? Place(id: "p" + String(format: "%.2f_%.2f", p.latitude, p.longitude).replacingOccurrences(of: "-", with: "m"), label: p.city, region: p.region, country: p.country, latitude: p.latitude, longitude: p.longitude, zoneID: zone)
            }
            if model.placeResults.isEmpty, model.placeProblem == nil { model.placeProblem = L("No place called “{query}”. Try another spelling, or enter coordinates.", ["query": query]) }
            let text = model.placeResults.prefix(5).map(PlaceParts.title).joined(separator: "; ")
            return model.isSetUp ? ToolReply(text).opening(page: "noor", state: ["sheet": "prefs", "section": "place", "place_q": query]) : ToolReply(text).opening(page: "noor", state: ["setup": "place", "place_q": query])
        })
        ext.tool("choose_place", "Use this place", "Saves the chosen place. Its coordinates then go to AlAdhan for times and the bearing.",
                 input: Schema.object(["label": Schema.string("Its name"), "region": Schema.string("Its region"), "country": Schema.string("Its country"), "latitude": Schema.number("Latitude"), "longitude": Schema.number("Longitude"), "zone": Schema.string("IANA time zone")], required: ["label", "latitude", "longitude", "zone"]), reply: { args in
            let place = try placeFrom(args)
            try moving(to: place)
            replan()
            let next: [String: Any] = model.prefs.convention == nil && model.source?.kind != .manual ? ["setup": "source", "place_pick": NSNull()] : ["setup": NSNull(), "place_pick": NSNull()]
            return ToolReply(L("Using {place}.", ["place": place.label])).row(L("Noor's place is now {place}", ["place": place.label])).opening(page: "noor", state: next)
        })
        ext.tool("follow_shared_place", "Follow Sidefolk's place", "Follows Sidefolk's own place, or stops and keeps it as a fixed one.", input: Schema.object(["on": Schema.boolean("Follow it, or keep what it is as a fixed place")], required: ["on"])) { args in
            let on = args.bool("on") ?? false
            if !on, let kept = model.prefs.place, kept.origin == .shared {
                try moving(to: try Place(id: kept.id, label: kept.label, region: kept.region, country: kept.country, latitude: kept.latitude, longitude: kept.longitude, zoneID: kept.zoneID))
                replan()
                return L("{place} stays as your place.", ["place": kept.label])
            }
            guard let shared = SharedPlace.current, let zone = shared.timeZone else { throw Problem(L("Sidefolk's place isn't available.")) }
            let place = try Place(id: "p" + String(format: "%.2f_%.2f", shared.latitude, shared.longitude).replacingOccurrences(of: "-", with: "m"), label: shared.city, region: shared.region, country: shared.country, latitude: shared.latitude, longitude: shared.longitude, zoneID: zone, origin: on ? .shared : .manual)
            try moving(to: place)
            replan()
            return on ? L("Following Sidefolk's place: {place}.", ["place": shared.city]) : L("{place} stays as your place.", ["place": shared.city])
        }
    }

    /// The person's own place moved, and they said to follow it: one reconciled plan, nothing else. If they took back their yes, the place they had stays, as a fixed one, and no more follows.
    static func placeMoved() {
        guard let kept = model.prefs.place, kept.origin == .shared else { return }
        guard SharedPlace.shared else {
            if let fixed = try? Place(id: kept.id, label: kept.label, region: kept.region, country: kept.country, latitude: kept.latitude, longitude: kept.longitude, zoneID: kept.zoneID) { try? moving(to: fixed) }
            return
        }
        guard let shared = SharedPlace.current, let zone = shared.timeZone,
              let place = try? Place(id: "p" + String(format: "%.2f_%.2f", shared.latitude, shared.longitude).replacingOccurrences(of: "-", with: "m"), label: shared.city, region: shared.region, country: shared.country, latitude: shared.latitude, longitude: shared.longitude, zoneID: zone, origin: .shared),
              place != kept else { return }
        try? moving(to: place)
        replan()
    }

    // MARK: Sources

    private static func sources(_ ext: Extension) {
        ext.tool("use_calculated", "Use calculated times", "Follows calculated times for the chosen place, with a method the person chose.", input: Schema.object(["method": Schema.integer("The provider's method id")]), reply: { args in
            guard let place = model.prefs.place else { throw Problem(L("Choose a place first.")) }
            let chosen = args.int("method").flatMap { $0 >= 0 ? $0 : nil } ?? model.prefs.convention?.method
            guard let chosen else { throw Problem(L("Choose a method first: there is no one right one.")) }
            let convention = try PrayerConvention(method: chosen, school: model.prefs.convention?.school ?? 0, latitudeAdjustment: model.prefs.convention?.latitudeAdjustment, tune: model.prefs.convention?.tune ?? [:])
            var next = model.sources.filter { $0.kind == .manual }
            let source = TimetableSource.calculated(for: place)
            next.append(source)
            try model.commit(place: place, sourceID: source.id, sources: next) { $0.convention = convention }
            replan()
            return ToolReply(L("Using calculated times.")).opening(page: "noor", state: ["setup": NSNull(), "tab": "overview", "sheet": NSNull()])
        })
        ext.tool("save_calculation", "Save calculation settings", "Saves the prayer calculation method, Asr method, high-latitude method and per-prayer minutes.",
                 input: Schema.object(["method": Schema.integer("Method id"), "school": Schema.integer("0 or 1"), "latitude": Schema.integer("0 for the provider's default, or 1 to 3"), "tune": ["type": "object", "additionalProperties": ["type": "integer"]] as [String: Any]], required: ["method"]), reply: { args in
            guard let method = args.int("method"), method >= 0 else { throw Problem(L("Choose a method first: there is no one right one.")) }
            let raw = args.values["tune"] as? [String: Any] ?? [:]
            var tune: [PrayerID: Int] = [:]
            for id in PrayerID.allCases { tune[id] = (raw[id.rawValue] as? NSNumber)?.intValue ?? 0 }
            let latitude = args.int("latitude") ?? 0
            let convention: PrayerConvention
            do {
                convention = try PrayerConvention(method: method, school: args.int("school") ?? 0, latitudeAdjustment: latitude == 0 ? nil : latitude, tune: tune)
            } catch {
                throw Problem(L("Minutes must be from −30 to +30."))
            }
            try model.save { $0.convention = convention }
            replan()
            return ToolReply(L("Saved. New times are on their way.")).opening(page: "noor", state: ["d_method": NSNull(), "d_school": NSNull(), "d_lat": NSNull()])
        })
        ext.tool("choose_source", "Use a saved timetable", "Follows one of the saved timetables.", input: Schema.object(["id": Schema.string("Its id")], required: ["id"]), reply: { args in
            guard let id = args.string("id"), model.sources.contains(where: { $0.id == id }) else { throw Problem(L("That timetable isn't saved.")) }
            try model.save { $0.sourceID = id }
            replan()
            return ToolReply(L("Using {name}.", ["name": model.source?.name ?? ""])).opening(page: "noor", state: ["compare": NSNull()])
        })
        ext.tool("remove_source", "Remove a timetable", "Removes a saved manual timetable and its times.", input: Schema.object(["id": Schema.string("Its id")], required: ["id"]), reply: { args in
            guard let id = args.string("id") else { throw Problem(L("That timetable isn't saved.")) }
            let next = model.sources.filter { $0.id != id }
            var chosen = model.prefs.sourceID
            if chosen == id { chosen = next.first { $0.kind == .calculated }?.id ?? model.prefs.place.map { TimetableSource.calculatedID(for: $0) } }
            var withCalculated = next
            if let place = model.prefs.place, !withCalculated.contains(where: { $0.id == TimetableSource.calculatedID(for: place) }) { withCalculated.append(.calculated(for: place)) }
            try model.commit(place: model.prefs.place, sourceID: chosen, sources: withCalculated)
            try model.store.deleteTimetable(sourceID: id)
            replan()
            return ToolReply(L("Removed."))
        })
        ext.tool("import_csv", "Read a timetable file", "Reads a CSV timetable the person chose and shows it for review. Nothing is saved yet.", input: Schema.object(["path": Schema.path("The file")], required: ["path"]), reply: { args in
            guard let path = args.string("path") else { throw Problem(L("Choose a file.")) }
            let url = URL(fileURLWithPath: path)
            let attributes = try? FileManager.default.attributesOfItem(atPath: path)
            if ((attributes?[.size] as? NSNumber)?.intValue ?? 0) > CSVImport.maximumBytes { throw Problem(L("The file is larger than 1 MB.")) }
            guard let data = try? Data(contentsOf: url) else { throw Problem(L("That file couldn't be read.")) }
            let name = url.deletingPathExtension().lastPathComponent
            let review = CSVImport.parse(data: data, name: name)
            // One program per named-folder call: the review has to outlive it, so it is kept where the main program can read it.
            try ImportHolding.keep(data: data, name: name)
            model.review = (name, review)
            return ToolReply(review.canSave ? L("{rows} rows read.", ["rows": "\(review.rows.count)"]) : L("That file needs fixing before it can be added.")).opening(page: "noor", state: ["sheet": "import", "import_name": name], push: true)
        })
        ext.tool("save_import", "Add the imported timetable", "Saves the timetable that was just reviewed, labelled Manual.", input: Schema.object(["name": Schema.string("Its name", maxLength: 80)]), reply: { args in
            ImportHolding.restore(into: model)
            guard let pending = model.review, pending.review.canSave else { throw Problem(L("There's nothing ready to add.")) }
            let name = args.string("name") ?? pending.name
            let review = ImportReview(name: name, rows: pending.review.rows)
            let id = "manual." + UUID().uuidString.prefix(8).lowercased()
            guard let table = review.timetable(id: id, attribution: name, revision: 1) else { throw Problem(L("That file needs fixing before it can be added.")) }
            try model.commit(place: model.prefs.place, sourceID: table.source.id, sources: model.sources + [table.source], timetable: table)
            model.review = nil
            ImportHolding.clear()
            replan()
            return ToolReply(L("Added {name}. It is labelled Manual.", ["name": name])).row(L("Added the timetable {name}", ["name": name])).opening(page: "noor", state: ["sheet": NSNull(), "tab": "prayer"])
        })
        ext.tool("discard_import", "Discard the import", "Forgets the file being reviewed. No source is added.", reply: { _ in
            model.review = nil
            ImportHolding.clear()
            return ToolReply(L("Nothing was added.")).opening(page: "noor", state: ["sheet": "prefs", "section": "sources"])
        })
        ext.tool("save_manual", "Save a timetable", "Saves a fixed timetable the person entered, for the date range they gave. It is labelled Manual.",
                 input: Schema.object(["name": Schema.string("Its name"), "zone": Schema.string("IANA time zone"), "from": Schema.string("YYYY-MM-DD"), "to": Schema.string("YYYY-MM-DD"), "starts": ["type": "object"] as [String: Any], "iqamah": ["type": "object"] as [String: Any]], required: ["name", "zone", "from", "to", "starts"]), reply: { args in
            let starts = args.values["starts"] as? [String: String] ?? [:], iqamah = args.values["iqamah"] as? [String: String] ?? [:]
            let name = args.string("name") ?? ""
            guard let review = SourcePage.manualReview(name: name, zone: args.string("zone") ?? "", from: args.string("from") ?? "", to: args.string("to") ?? "", starts: starts, iqamah: iqamah), review.canSave,
                  let table = review.timetable(id: "manual." + UUID().uuidString.prefix(8).lowercased(), attribution: name, revision: 1) else { throw Problem(L("Fill in a name, a real time zone, both dates and all five starts, as HH:mm.")) }
            try model.commit(place: model.prefs.place, sourceID: table.source.id, sources: model.sources + [table.source], timetable: table)
            replan()
            return ToolReply(L("Added {name}. It is labelled Manual.", ["name": name])).opening(page: "noor", state: ["sheet": NSNull(), "tab": "prayer"])
        })
    }

    // MARK: Reminders

    private static func reminders(_ ext: Extension) {
        ext.tool("save_reminders", "Save reminders", "Saves prayer reminder choices.",
                 input: Schema.object(["master": Schema.boolean("On or off"), "companion": Schema.boolean("Through the companion"), "system": Schema.boolean("Also macOS"), "prayers": ["type": "object"] as [String: Any], "name": Schema.boolean("A Name each day")], required: ["master"]), reply: { args in
            let raw = args.values["prayers"] as? [String: [String: Any]] ?? [:]
            try model.save { p in
                p.reminders.master = args.bool("master") ?? false
                p.reminders.route = Reminders.Route(companion: args.bool("companion") ?? true, systemFallback: args.bool("system") ?? false)
                p.reminders.nameOfDay.enabled = args.bool("name") ?? p.reminders.nameOfDay.enabled
                for id in PrayerID.allCases {
                    guard let r = raw[id.rawValue] else { continue }
                    let before = (r["before"] as? NSNumber)?.intValue ?? -1, iq = (r["iqamah"] as? NSNumber)?.intValue ?? -1
                    p.reminders.prayers[id] = Reminders.Prayer(beforeMinutes: Reminders.beforeBounds.contains(before) ? before : nil, atStart: r["at"] as? Bool ?? false, iqamahMinutes: Reminders.iqamahBounds.contains(iq) ? iq : nil)
                }
            }
            model.freshen()
            replan()
            let clear = Dictionary(uniqueKeysWithValues: ["rm_master", "rm_companion", "rm_system", "rm_name"].map { ($0, NSNull() as Any) })
            return ToolReply(L("Reminders saved.")).opening(page: "noor", state: clear)
        })
        ext.tool("prepare_reminder", "Prepare a reminder", "Opens a prayer's reminder as a draft to look over. Nothing is saved or scheduled yet.",
                 input: Schema.object(["prayer": Schema.string("fajr, dhuhr, asr, maghrib or isha"), "minutes": Schema.integer("Minutes before its start", minimum: 1, maximum: 180)], required: ["prayer", "minutes"]), reply: { args in
            let prayer = try prayerArg(args.string("prayer"))
            let minutes = args.int("minutes") ?? 10
            return ToolReply(L("Here's a reminder {minutes} minutes before {prayer}. It isn't saved until you say so.", ["minutes": Format.integer(minutes), "prayer": Words.prayer(prayer)]))
                .opening(page: "noor", state: ["sheet": "prefs", "section": "reminders", "rm_master": true, "rm_\(prayer.rawValue)_before": "\(minutes)"], push: true)
        })
        ext.tool("pause_reminders", "Pause Noor's reminders", "Pauses reminders until the given moment, in the timetable's own zone.", input: Schema.object(["until": Schema.string("tomorrow, or an ISO 8601 time")]), reply: { args in
            let zone = model.source?.zone ?? model.prefs.place?.zone ?? .current
            guard model.prefs.reminders.master else { return ToolReply(L("Reminders are off, so there's nothing to pause.")) }
            let today = CivilDate(model.now, in: zone)
            let until: Date
            switch args.string("until") {
            case nil, "tomorrow": until = CivilClock.startOfDay(today.next, in: zone)
            case let text?:
                // A pause has an end people can see coming: within a month, and not already over.
                guard let parsed = ISO8601DateFormatter().date(from: text), parsed > model.now, parsed.timeIntervalSince(model.now) <= 31 * 86400 else { throw Problem(L("A pause ends within the next month. Say tomorrow, or a time like 2026-11-05T09:00:00+09:00.")) }
                until = parsed
            }
            try model.save { $0.reminders.pausedUntil = until }
            replan()
            return ToolReply(L("Paused until {when}.", ["when": "\(Words.date(CivilDate(until, in: zone), weekday: true, year: false)) \(Words.time(until, zone: zone))"]))
        })
        ext.tool("reminders_off", "Turn off Noor's reminders", "Turns off all of Noor's reminders. What was chosen is kept for when they are turned on again.") { _ in
            try model.save { p in
                p.reminders.master = false
                p.reminders.ramadan.enabled = false
                p.reminders.pausedUntil = nil
            }
            replan()
            return L("Noor's reminders are off.")
        }
        ext.tool("resume_reminders", "Resume Noor's reminders", "Ends a pause.") { _ in
            try model.save { $0.reminders.pausedUntil = nil }
            replan()
            return L("Reminders are back on.")
        }
        ext.tool("select_occasion", "Remind me of an occasion", "Selects or clears a listed occasion for a reminder.", input: Schema.object(["occasion": Schema.string("Its identity"), "on": Schema.boolean("On or off")], required: ["occasion"])) { args in
            guard let id = args.string("occasion") else { throw Problem(L("Which occasion?")) }
            let on = args.bool("on") ?? false
            try model.save { p in
                if on { p.reminders.occasions.selected.insert(id) } else { p.reminders.occasions.selected.remove(id) }
            }
            replan()
            return on ? L("Noted. It comes once reminders are on.") : L("Cleared.")
        }
        ext.tool("save_ramadan", "Save Ramadan reminders", "Saves the Ramadan planner's reminders.", input: Schema.object(["enabled": Schema.boolean("On or off"), "suhoor": Schema.integer("Minutes before Fajr, or -1 for none"), "iftar": Schema.boolean("At Maghrib"), "days": Schema.array(of: Schema.integer("A day of Ramadan"), "Which days", maxItems: 30)], required: ["enabled"]), reply: { args in
            let on = args.bool("enabled") ?? false
            let suhoor = args.int("suhoor") ?? -1
            let days = (args.values["days"] as? [NSNumber])?.map(\.intValue) ?? []
            if on, !Occurrences.allowed { return ToolReply(L("Sidefolk needs your yes first: choose Allow Noor's reminders in Preferences.")).opening(page: "noor", state: ["sheet": "prefs", "section": "reminders"], push: true) }
            try model.save { p in
                p.reminders.ramadan = on ? Reminders.Ramadan(enabled: true, days: Set(days), suhoorMinutesBeforeFajr: Reminders.suhoorBounds.contains(suhoor) ? suhoor : nil, iftar: args.bool("iftar") ?? false) : Reminders.Ramadan()
                if on, !p.reminders.route.companion, !p.reminders.route.systemFallback { p.reminders.route.companion = true }
            }
            replan()
            return ToolReply(on ? L("Ramadan reminders saved. They come within 35 days of their day.") : L("Ramadan reminders are off."))
        })
    }

    // MARK: Data

    private static func data(_ ext: Extension) {
        ext.tool("refresh", "Check for new times", "Asks the provider again for what is shown.", reply: { _ in
            model.freshen(refresh: true)
            return ToolReply(L("Checking…"))
        })
        ext.tool("clear_data", "Clear Noor's data", "Clears downloaded answers, or all of Noor's data, which cancels its reminders.", input: Schema.object(["scope": Schema.string("cache or all", oneOf: ["cache", "all"])], required: ["scope"]), reply: { args in
            let all = args.string("scope") == "all"
            try model.clear(all ? .all : .cache)
            if all {
                ImportHolding.clear()
                model.review = nil
                model.placeResults = []
            }
            // Everything is gone, so "nothing" is the whole truth; clearing downloads changes no reminder, and its plan waits for the days to come back.
            if all { Occurrences.replace(OccurrencePlan(revision: Occurrences.revision + 1, occurrences: [])) } else { replan() }
            return ToolReply(all ? L("Noor's data is gone, and its reminders are cancelled.") : L("Downloaded data cleared.")).opening(page: "noor", state: ["confirm_clear": NSNull(), "setup": NSNull(), "sheet": all ? NSNull() : "prefs"])
        })
    }
}

/// A file named for one call runs in a process of its own, which ends with the call, so what it read waits here for the main program. It holds a copy of what the person chose for as long as they are looking at it.
enum ImportHolding {
    private static var url: URL { URL(fileURLWithPath: Paths.data).appendingPathComponent("import-review.json") }

    private struct Held: Codable {
        let name: String
        let data: Data
    }

    static func keep(data: Data, name: String) throws {
        try JSONEncoder().encode(Held(name: name, data: data)).write(to: url, options: .atomic)
    }

    /// What was read last, as the file says: another process read it, so this one's memory is only good while the file is the same.
    @MainActor private static var seen: Data?

    @MainActor static func restore(into model: NoorModel) {
        guard let raw = try? Data(contentsOf: url), let held = try? JSONDecoder().decode(Held.self, from: raw) else {
            seen = nil
            model.review = nil
            return
        }
        guard raw != seen else { return }
        seen = raw
        model.review = (held.name, CSVImport.parse(data: held.data, name: held.name))
    }

    static func clear() { try? FileManager.default.removeItem(at: url) }
}
