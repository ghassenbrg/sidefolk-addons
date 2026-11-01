import Foundation

extension String {
    /// The words as people see them: without the isolates the Kit's `L` puts around each value it fills in (invisible,
    /// Sidefolk D76), so a test can compare with the sentence it expects.
    var seen: String { filter { $0 != "\u{2068}" && $0 != "\u{2069}" } }
}
