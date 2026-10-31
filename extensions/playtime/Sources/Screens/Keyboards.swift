import Foundation
import SidefolkExtensionKit

/// The on-screen keyboard for a word game in each script, laid out as people know it: QWERTY, AZERTY or QWERTZ with
/// the language's own letters (ñ, ä ö ü), Korean's two-set layout, the Arabic layout, kana in their gojūon order
/// (pages for voiced and small kana in Daily Word). Only keys the game takes (`WordScript.alphabet`), each once; any
/// letter of the alphabet a layout lacks goes on a last row, so every one can be typed.
enum Keyboards {
    struct Page {
        var label: String
        var rows: [[String]]
    }

    static func pages(_ language: Games.Language, for use: Games.WordScript.Use) -> [Page] {
        let alphabet = Games.WordScript.alphabet(language, for: use)
        guard !alphabet.isEmpty else { return [] }
        let layout: [Page] = switch language {
        case .fr: [Page(label: "", rows: ["azertyuiop", "qsdfghjklm", "wxcvbn"].map(letters))]
        case .de: [Page(label: "", rows: ["qwertzuiopü", "asdfghjklöä", "yxcvbnm"].map(letters))]
        case .es: [Page(label: "", rows: ["qwertyuiop", "asdfghjklñ", "zxcvbnm"].map(letters))]
        case .ko: [Page(label: "", rows: ["ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ", "ㅁㄴㅇㄹㅎㅗㅓㅏㅣ", "ㅋㅌㅊㅍㅠㅜㅡ", "ㅃㅉㄸㄲㅆㅒㅖ"].map(letters))]
        case .ar: [Page(label: "", rows: ["ضصثقفغعهخحج", "شسيبلاتنمكط", "ئءؤرىةوزظدذ"].map(letters))]
        case .ja:
            [Page(label: "あ", rows: ["あかさたなはまやらわ", "いきしちにひみり", "うくすつぬふむゆるん", "えけせてねへめれ", "おこそとのほもよろを"].map(letters)),
             Page(label: "が", rows: ["がざだばぱ", "ぎじぢびぴ", "ぐずづぶぷ", "げぜでべぺ", "ござどぼぽ"].map(letters)),
             Page(label: "ゃ", rows: ["ぁぃぅぇぉ", "っゃゅょ"].map(letters))]
        default: [Page(label: "", rows: ["qwertyuiop", "asdfghjkl", "zxcvbnm"].map(letters))]
        }
        let wanted = Set(alphabet)
        var seen = Set<String>()
        var pages = layout.map { page in
            Page(label: page.label, rows: page.rows.map { $0.filter { wanted.contains($0) && seen.insert($0).inserted } }.filter { !$0.isEmpty })
        }.filter { !$0.rows.isEmpty }
        let missing = alphabet.filter { !seen.contains($0) }
        if !missing.isEmpty, !pages.isEmpty { pages[pages.count - 1].rows.append(missing) }
        return pages
    }

    private static func letters(_ s: String) -> [String] { s.map(String.init) }

    static func script(_ language: Games.Language) -> String {
        switch language {
        case .ja: "kana"
        case .ko: "hangul"
        case .ar: "arabic"
        default: "latin"
        }
    }

    /// The pages as Sidefolk's keyboard part, each key with its mark.
    static func part(_ language: Games.Language, for use: Games.WordScript.Use, mode: String, length: Int? = nil, locked: Bool = false,
                     mark: (String) -> String) -> BoardPart? {
        let pages = pages(language, for: use)
        guard !pages.isEmpty else { return nil }
        return .play(.keys(pages: pages.map { p in KeyPage(p.label, rows: p.rows.map { $0.map { (key: $0, mark: mark($0)) } }) },
                           mode: mode, length: length, script: script(language), locked: locked))
    }
}
