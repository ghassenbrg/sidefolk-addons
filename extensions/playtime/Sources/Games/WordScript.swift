import Foundation

extension Games {
    /// How each language's words split into the pieces the word games guess, what a guess must match, and the keys of
    /// the on-screen keyboard. Decided per language (Content/Words/README in the report, and below):
    ///
    /// - English, French, Spanish, German, Italian, Portuguese: letters a–z. Accents are folded (é is guessed as e,
    ///   ç as c), as Wordle-likes in those languages do, except Spanish ñ and German ä ö ü, which are letters of their
    ///   own there and have keys. Words with ß, œ or æ are left out of the lists.
    /// - Japanese: hiragana (katakana typed is read as hiragana). Balloon Words folds dakuten and small kana (が is
    ///   guessed as か, ゃ as や) so its keyboard is the 46 base kana; Daily Word is exact, like the Japanese
    ///   Wordle-likes, with every kana a key.
    /// - Korean: jamo, as the Korean Wordle-likes do: each syllable splits into its letters, compound vowels and final
    ///   clusters into the keys typed for them (ㅘ is ㅗ ㅏ, ㄺ is ㄹ ㄱ); ㄲ ㄸ ㅃ ㅆ ㅉ stay single (shifted keys).
    ///   `group` is the syllable, so a half-guessed syllable can be drawn as one block.
    /// - Chinese: letters don't fit. Balloon Words guesses the word's pinyin (no tones, ü folded to u) and shows the
    ///   characters at the end; Daily Word is a four-character idiom guessed character by character (typed with the
    ///   input method, so there is no keyboard part).
    /// - Arabic: letters, without short-vowel marks and tatweel; أ إ آ ٱ fold to ا. Shaping (initial, medial, final
    ///   forms) is only drawing: the letters are the same code points in every form.
    enum WordScript {
        struct Unit: Codable, Equatable, Hashable, Sendable {
            /// As written (é, が, ㄱ, ü).
            let shown: String
            /// What a guess must match (e, か, ㄱ, u).
            let key: String
            /// The letter, syllable or character this unit belongs to, for drawing.
            let group: Int
        }

        enum Use: Sendable { case balloon, daily }

        /// Marks shown as they are and never guessed: a space, a hyphen, an apostrophe, Japanese ー (a long vowel, not a
        /// kana of its own). Their unit's key is empty.
        static let free: Set<String> = [" ", "-", "'", "’", "ー"]

        static func units(_ word: String, _ language: Language, for use: Use) -> [Unit] {
            letters(word, language, use).map { free.contains($0.shown) ? Unit(shown: $0.shown, key: "", group: $0.group) : $0 }
        }

        private static func letters(_ word: String, _ language: Language, _ use: Use) -> [Unit] {
            switch language {
            case .ko:
                return korean(word)
            case .zh where use == .daily:
                return word.enumerated().map { Unit(shown: String($1), key: String($1), group: $0) }
            case .zh:
                // Pinyin syllables are separated by spaces in the lists; each becomes a group.
                return word.split(separator: " ").enumerated().flatMap { group, syllable in
                    syllable.map { Unit(shown: String($0), key: latinKey($0, .zh), group: group) }
                }
            default:
                return clean(word, language).enumerated().map { i, c in Unit(shown: String(c), key: key(c, language, use), group: i) }
            }
        }

        /// The key for one typed character (a keyboard press), or nil when it isn't a letter of the game.
        static func key(typed: String, _ language: Language, for use: Use) -> String? {
            guard typed.count == 1, let c = typed.lowercased().first else { return nil }
            let k: String
            switch language {
            case .ko: k = korean(String(c)).first?.key ?? String(c)
            case .zh where use == .daily: k = String(c)
            default: k = key(c, language, use)
            }
            return isKey(k, language, use) ? k : nil
        }

        static func isKey(_ key: String, _ language: Language, _ use: Use) -> Bool {
            if language == .zh, use == .daily { return key.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) } }
            return alphabet(language, for: use).contains(key)
        }

        /// The on-screen keyboard's keys, in order (empty for Chinese Daily Word, typed with the input method).
        static func alphabet(_ language: Language, for use: Use) -> [String] {
            let latin = "abcdefghijklmnopqrstuvwxyz".map(String.init)
            switch language {
            case .en, .fr, .it, .pt, .zh: return language == .zh && use == .daily ? [] : latin
            case .es: return latin + ["ñ"]
            case .de: return latin + ["ä", "ö", "ü"]
            case .ja: return use == .balloon ? kanaBase : kanaBase + kanaVoiced + kanaSmall
            case .ko: return koreanKeys
            case .ar: return arabicLetters
            }
        }

        // MARK: Latin, Japanese and Arabic

        private static func clean(_ word: String, _ language: Language) -> [Character] {
            if language == .ar {
                // Short vowels and other marks (U+064B–U+065F, U+0670) and tatweel (U+0640) aren't letters.
                return Array(String(String.UnicodeScalarView(word.unicodeScalars.filter {
                    !(0x064B...0x065F).contains($0.value) && $0.value != 0x0670 && $0.value != 0x0640
                })))
            }
            // Shown as written (German nouns keep their capital); the key is lowercased.
            return Array(word)
        }

        private static func key(_ c: Character, _ language: Language, _ use: Use) -> String {
            switch language {
            case .ja: return kanaKey(c, fold: use == .balloon)
            case .ar: return "أإآٱ".contains(c) ? "ا" : String(c)
            default: return latinKey(c, language)
            }
        }

        private static func latinKey(_ c: Character, _ language: Language) -> String {
            let s = String(c).lowercased()
            if language == .es, s == "ñ" { return s }
            if language == .de, "äöü".contains(s) { return s }
            return s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        }

        private static func kanaKey(_ c: Character, fold: Bool) -> String {
            var scalars = String(c).unicodeScalars.map(\.value)
            // Katakana to hiragana: the two blocks are 0x60 apart.
            scalars = scalars.map { (0x30A1...0x30F6).contains($0) ? $0 - 0x60 : $0 }
            var s = String(String.UnicodeScalarView(scalars.compactMap(Unicode.Scalar.init)))
            guard fold else { return s }
            // Dakuten and handakuten come off in the canonical decomposition (が → か + ゛).
            s = String(String.UnicodeScalarView(s.decomposedStringWithCanonicalMapping.unicodeScalars.filter {
                $0.value != 0x3099 && $0.value != 0x309A
            }))
            let small: [String: String] = ["ぁ": "あ", "ぃ": "い", "ぅ": "う", "ぇ": "え", "ぉ": "お", "っ": "つ", "ゃ": "や", "ゅ": "ゆ", "ょ": "よ", "ゎ": "わ"]
            return small[s] ?? s
        }

        static let kanaBase = "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん".map(String.init)
        static let kanaVoiced = "がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽ".map(String.init)
        static let kanaSmall = "ぁぃぅぇぉっゃゅょ".map(String.init)
        static let arabicLetters = "ابتثجحخدذرزسشصضطظعغفقكلمنهويةىءؤئ".map(String.init)

        // MARK: Korean

        private static let leads = "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ".map(String.init)
        private static let vowels = ["ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅗㅏ", "ㅗㅐ", "ㅗㅣ", "ㅛ", "ㅜ", "ㅜㅓ", "ㅜㅔ", "ㅜㅣ", "ㅠ", "ㅡ", "ㅡㅣ", "ㅣ"]
        private static let tails = ["", "ㄱ", "ㄲ", "ㄱㅅ", "ㄴ", "ㄴㅈ", "ㄴㅎ", "ㄷ", "ㄹ", "ㄹㄱ", "ㄹㅁ", "ㄹㅂ", "ㄹㅅ", "ㄹㅌ", "ㄹㅍ", "ㄹㅎ",
                                    "ㅁ", "ㅂ", "ㅂㅅ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
        static let koreanKeys = leads + "ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅛㅜㅠㅡㅣ".map(String.init)
        /// Compound jamo typed on their own (ㅘ, ㄳ) split the same way as inside a syllable.
        private static let compound: [String: String] = [
            "ㅘ": "ㅗㅏ", "ㅙ": "ㅗㅐ", "ㅚ": "ㅗㅣ", "ㅝ": "ㅜㅓ", "ㅞ": "ㅜㅔ", "ㅟ": "ㅜㅣ", "ㅢ": "ㅡㅣ", "ㄳ": "ㄱㅅ", "ㄵ": "ㄴㅈ",
            "ㄶ": "ㄴㅎ", "ㄺ": "ㄹㄱ", "ㄻ": "ㄹㅁ", "ㄼ": "ㄹㅂ", "ㄽ": "ㄹㅅ", "ㄾ": "ㄹㅌ", "ㄿ": "ㄹㅍ", "ㅀ": "ㄹㅎ", "ㅄ": "ㅂㅅ",
        ]

        private static func korean(_ word: String) -> [Unit] {
            word.enumerated().flatMap { group, c -> [Unit] in
                let jamo: String
                if let v = c.unicodeScalars.first?.value, c.unicodeScalars.count == 1, (0xAC00...0xD7A3).contains(v) {
                    let i = Int(v - 0xAC00)
                    jamo = leads[i / 588] + vowels[(i % 588) / 28] + tails[i % 28]
                } else {
                    jamo = compound[String(c)] ?? String(c)
                }
                return jamo.map { Unit(shown: String($0), key: String($0), group: group) }
            }
        }
    }
}
