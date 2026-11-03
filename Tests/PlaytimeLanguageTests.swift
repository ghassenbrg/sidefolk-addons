import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// Game language: a scene says its direction only when its words read the other way from the app's, so a copy of Sidefolk draws what it already would.
@MainActor
@Suite(.serialized) struct PlaytimeLanguageTests {
    private func stamped(app: String, playing: String) -> String? {
        defer { Language.use("en") }
        PlayLanguage.enter(app)
        Language.use(playing)
        return PlayLanguage.stamped(Scene(width: 400, height: 620)).extra["direction"] as? String
    }

    @Test func arabicOnAnEnglishAppReadsRightToLeft() {
        #expect(stamped(app: "en", playing: "ar") == "rtl")
    }

    @Test func englishOnAnArabicAppReadsLeftToRight() {
        #expect(stamped(app: "ar", playing: "en") == "ltr")
    }

    @Test func theSameDirectionSaysNothing() {
        #expect(stamped(app: "en", playing: "de") == nil)
        #expect(stamped(app: "ar", playing: "ar") == nil)
    }
}
