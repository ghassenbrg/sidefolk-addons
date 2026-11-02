import SidefolkExtensionKit

// Letter tiles (LettersView). Not moved yet: its group fills this in from the panel's LettersKeysViews.swift. The keyboard is StageKeyboard.
extension BoardDrawing {
    func lettersPart(rows: [[LetterTile]], length: Int, tries: Int?, style: String, draft: Bool, flip: Int?, script: String) -> PartBlock { unmoved("letters") }
}
