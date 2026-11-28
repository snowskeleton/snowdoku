/// The player's opening run of a single digit: the first digit placed, and whether every missing
/// copy of it went in before any other digit, note or hint (Game Center's hidden "first"
/// achievements, awarded as soon as the last copy goes in).
struct FirstDigitRun: Codable, Equatable {
    var digit: Int
    /// Another digit, a wrong copy, a note or a hint came before the run was done (a note or hint
    /// before any digit leaves `digit` 0).
    var broken = false
    /// Every copy of the digit is on the board.
    var done = false
}
