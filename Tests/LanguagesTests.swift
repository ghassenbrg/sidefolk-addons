import Foundation
import Testing
@testable import ext_clipboard
@testable import ext_keep_awake
@testable import ext_miraya
@testable import ext_system_vitals_plus
@testable import SidefolkExtensionKit

/// Sidefolk's own extensions answer in the person's language (Sidefolk D76): each with its own `strings/`, read the way
/// its program reads them, in a language of its own for this test only (`Language.with`), so tests beside it stay English.
/// Every key in every language is checked in Sidefolk (ExtensionLanguagesTests); here, what people see reads right.
@MainActor
struct LanguagesTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    static func strings(_ folder: String) -> String { root.appendingPathComponent("extensions/\(folder)/strings").path }

    static func texts(_ page: Page) -> String {
        String(decoding: (try? JSONSerialization.data(withJSONObject: page.json)) ?? Data(), as: UTF8.self)
    }

    /// Each value `L` fills in is isolated (FSI … PDI), so an Arabic sentence that begins with a name in Latin letters
    /// still reads right to left, and a name inside one keeps its own order (Sidefolk D76 amended).
    @Test func filledInValuesKeepTheirOwnDirection() throws {
        try Language.with("ar", strings: PlaytimeGameTests.strings) {
            let counting = L("{name} counts… {n} left.", ["name": "Mochi", "n": 1])
            #expect(counting.hasPrefix("\u{2068}Mochi\u{2069} ") && counting.contains("\u{2068}" + Format.integer(1) + "\u{2069}"), "\(counting)")
            #expect(counting.seen == "Mochi يعدّ… بقي \(Format.integer(1)).")
        }
        try Language.with("ar", strings: Self.strings("clipboard")) {
            let ignored = L("Copies from {app} aren't kept from now on.", ["app": "Safari"])
            #expect(ignored == "لن تُحفظ النسخ من \u{2068}Safari\u{2069} من الآن فصاعدًا.")
        }
        // Invisible in a sentence of the value's own direction, and the same in every language.
        #expect(L("{count} today", ["count": 3]).seen == "3 today" && L("{count} today", ["count": 3]) == "\u{2068}3\u{2069} today")
    }

    @Test func yourMacInGermanJapaneseAndArabic() {
        let s = SystemVitalsPlusTests.snapshot(load: 0.95, battery: SystemVitalsPlusTests.battery(15))
        Language.with("de", strings: Self.strings("system-vitals-plus")) {
            #expect(Words.summary(s).title == "Dein Mac arbeitet sehr hart")
            #expect(Words.glance(s).seen.hasPrefix("CPU 95\u{00A0}%"), "\(Words.glance(s))")
            #expect(Self.texts(MacPage.make(s)).contains("Gerade jetzt"))
            #expect(Answers.memory(s).contains("Speicherdruck"), "\(Answers.memory(s))")
        }
        Language.with("ja", strings: Self.strings("system-vitals-plus")) {
            #expect(Words.cores(s.specs).seen == "10コア（高性能 4、高効率 6）")
            #expect(Self.texts(MacPage.make(s)).contains("現在"))
        }
        Language.with("ar", strings: Self.strings("system-vitals-plus")) {
            #expect(Words.summary(s).title == "جهاز Mac يعمل بجهد كبير")
            #expect(Words.duration(3 * 86_400 + 4 * 3600) == "3 أيام و4 ساعات")
        }
    }

    @Test func keepAwakeAndClipboardInGerman() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("lang-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        Language.with("de", strings: Self.strings("keep-awake")) {
            let page = Self.texts(AwakePage.make(Keeper(folder: folder)))
            #expect(page.contains("Dein Mac schläft wie gewohnt") && page.contains("Nur am Netzteil"), "\(page.prefix(300))")
            #expect(Rules.left(Date(timeIntervalSince1970: 5400), now: Date(timeIntervalSince1970: 0)) == "1 Std., 30 Min.")
        }
        Language.with("ja", strings: Self.strings("clipboard")) {
            let page = Self.texts(ClipboardPage.make(History(folder: folder)))
            #expect(page.contains("コピーした内容の履歴を残す"), "\(page.prefix(300))")
        }
    }

    @Test func mirayaInArabic() {
        Language.with("ar", strings: Self.strings("miraya")) {
            let hero = MirayaPage.hero(MirayaTests.ready())
            #expect(hero.title.hasPrefix("مشاركة "), "\(hero.title)")
            #expect(MirayaPage.summary(MirayaPage.Now()).title == "لم يجد Miraya أي تلفاز")
            // A message from the Mac app's own sources, shown in the person's language.
            #expect(Said.shown("The pairing codes don't match. Nothing was shared.") == "رمزا الاقتران غير متطابقين. لم تتم مشاركة أي شيء.")
            #expect(Said.shown("Couldn't reach the TV: timed out. Check that Miraya is open on it and both are on the same network.").contains("timed out"))
        }
    }
}
