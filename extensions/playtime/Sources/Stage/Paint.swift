import SidefolkExtensionKit

/// The games' own colours, carried over from the Play panel's look v2 (D79 amended) as plain values and theme names, so a
/// board reads as one set of toys over its scene, by day and at night. A game's colour is identity, never a verdict (D78):
/// a win is the theme's green by the name `win`, a loss the calm tone `loss`, never a red.
enum Paint {
    static let card = Color.surfaceRaised
    static func card(_ alpha: Double) -> Color { Color.surfaceRaised.tuned(alpha: alpha) }
    /// The hairline around a card, a bubble or a tile: pale blue by day, a moonlit navy at night.
    static let edge = Color.adaptive(light: "#D5E1F0", dark: "#34476E")
    /// Under a raised tile or button, its thickness.
    static let lip = Color.adaptive(light: "#C6D5EA", dark: "#0B1322")
    /// Inside a card: the score bar's halves, a track.
    static let inset = Color.adaptive(light: "#EEF3FA", dark: "#111A2B")
    static let lostSoft = Color.adaptive(light: "#F3E4D6", dark: "#4A3A2F")
    static let lostEdge = Color.adaptive(light: "#B07A5299", dark: "#D9A98299")
    static let sun = Color.hex("#FFC93C")
    static let sunLip = Color.hex("#DBA610")
    static let coral = Color.hex("#FF7B6B")
    static let navy = Color.hex("#0F2D5B")
    static let white = Color.hex("#FFFFFF")
    /// Two players on one Mac (D96): who, never how it went: a calm blue and a warm violet.
    static let players = [Color.adaptive(light: "#3B7DD8", dark: "#7FB2FF"), Color.adaptive(light: "#8A55D6", dark: "#C09BFF")]
    /// The pads' colours and the balloons', soft clay, so red reads as a colour of the game, not an alarm.
    static let blue = Color.adaptive(light: "#5A8DF0", dark: "#6B9BFF")
    static let green = Color.adaptive(light: "#56B58A", dark: "#5FC496")
    static let yellow = Color.adaptive(light: "#F0B43C", dark: "#F5C255")
    static let red = Color.adaptive(light: "#F07A68", dark: "#F4897A")
    static let purple = Color.adaptive(light: "#9A7BE8", dark: "#A98BF2")
    /// The beds' palette, for a grid of choices or regions: never a red or the loss tone, which would read as a mistake.
    static let regionLight = ["FFD8D2", "FFE7B8", "FFF3B0", "DDF2C4", "C7EDDC", "C9E9F5", "D4DEFF", "E6D6FA", "F8D4EA", "EBDCC9", "D9E4D0", "E0E0E8"]
    static let regionDark = ["5A3934", "5A4628", "55502A", "3D5030", "2E5244", "2C4A57", "37406A", "4A3A64", "5A3550", "4D4134", "3E4A38", "44444F"]
    static func region(_ i: Int, alpha: String = "") -> Color {
        Color.adaptive(light: "#" + regionLight[i % 12] + alpha, dark: "#" + regionDark[i % 12] + alpha)
    }
    /// `#RRGGBB` with a see-through part, as the panel's `.opacity` was.
    static func clear(_ hex: String, _ alpha: Double) -> Color { Color.hex(hex + String(format: "%02X", Int((alpha * 255).rounded()))) }
    static let black15 = clear("#000000", 0.15)
    static let black8 = clear("#000000", 0.08)
}

/// What a result means for the person (`win`, `loss`, `draw`), and how every game draws it: the same meaning always the same
/// colour, with a symbol or a word beside it, never colour alone (D75, D78).
enum Verdict: String {
    case win, loss, draw

    init?(tile: TileState, locked: Bool) {
        switch tile {
        case .right: self = .win
        case .wrong: self = .loss
        case .picked where locked: self = .draw
        default: return nil
        }
    }

    init(tone: Tone) {
        switch tone {
        case .good: self = .win
        case .bad: self = .loss
        default: self = .draw
        }
    }

    var symbol: String {
        switch self {
        case .win: "checkmark.circle.fill"
        case .loss: "xmark.circle.fill"
        case .draw: "equal.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .win: .win
        case .loss: .loss
        case .draw: .inkMuted
        }
    }

    /// A tile's or a card's fill.
    var fill: Color {
        switch self {
        case .win: .win
        case .loss: Paint.lostSoft
        case .draw: .surfaceRaised
        }
    }

    /// The text on that fill.
    var ink: Color { self == .win ? Paint.white : .ink }
}
