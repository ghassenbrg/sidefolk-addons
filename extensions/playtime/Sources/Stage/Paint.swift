import SidefolkExtensionKit

/// The games' own colours, carried over from the Play panel's look v2 (D79 amended) as plain values and theme names, so a
/// board reads as one set of toys over its scene, by day and at night. A game's colour is identity, never a verdict (D78):
/// a win is the theme's green by the name `win`, a loss the calm tone `loss`, never a red.
enum Paint {
    /// One palette for all of Playtime, by day and at night (the accepted redesign): warm cream and porcelain, navy words and actions, restrained lilac, apricot,
    /// butter and powder blue; ink and slate at night, with ivory actions. Playtime's own, whatever theme the app wears, so its games look the same everywhere;
    /// what a result means still comes from the theme by name (`win`, `loss`), and coral is the brand, never an error.
    static func both(_ light: String, _ dark: String) -> Color { .adaptive(light: light, dark: dark) }
    static let paper = both("#FCF1E6", "#18213C")
    static let card = both("#FFF9F0", "#27304F")
    /// The card, see-through: a tuned colour takes only a theme's token.
    static func card(_ alpha: Double) -> Color {
        let a = String(format: "%02X", Int((alpha * 255).rounded()))
        return both("#FFF9F0" + a, "#27304F" + a)
    }
    static let ink = both("#14275A", "#F8EFDF")
    static let inkSoft = both("#566181", "#BEC2D6")
    static let inkFaint = both("#A9AEC0", "#6C7290")
    /// The one thing to do: navy by day, ivory at night. Never a game's colour, never green.
    static let action = both("#14275A", "#F6EAD4")
    static let onAction = both("#FFF9F0", "#14275A")
    static let actionLip = both("#0B1A42", "#C9B99F")
    /// The hairline around a card, a bubble or a tile.
    static let edge = both("#EADBC9", "#3B4468")
    /// Under a raised tile or button, its thickness.
    static let lip = both("#E3D1BB", "#12182C")
    /// Inside a card: a well, a track.
    static let inset = both("#F4E8DA", "#1E2744")
    static let lilac = both("#E6DAF1", "#4A3F70")
    static let lilacDeep = both("#8E72B5", "#B9A2DE")
    static let apricot = both("#FBD9B8", "#6A4A3A")
    static let butter = both("#F8DE94", "#6B5A2C")
    static let rose = both("#F6CFCB", "#6A3F4A")
    static let powder = both("#BFDCF2", "#35506E")
    /// Words on the pack's cream props (a plaque, a ticket, a counter's cards), which stay cream at night.
    static let onCream = Color.hex("#14275A")
    static let cream = Color.hex("#FFF9F0")
    static let lilacFixed = Color.hex("#E6DAF1")
    static let lilacDeepFixed = Color.hex("#6F558F")
    /// A wrong ticket: the calm tone of a loss, on a prop that stays cream at night.
    static let lostCream = Color.hex("#EBD6C4")
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

    /// A plate on the arena.
    var tileFill: Color { self == .win ? .win : self == .loss ? Paint.lostSoft : Paint.card }

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
