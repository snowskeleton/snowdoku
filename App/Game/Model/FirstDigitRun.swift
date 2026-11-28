/// The player's opening run of a single digit: the first digit placed, and whether every missing
/// copy of it went in before any other digit (Game Center's hidden "first" achievements).
struct FirstDigitRun: Codable, Equatable {
    var digit: Int
    /// Another digit, or a wrong copy, came before the run was done.
    var broken = false
    /// Every copy of the digit is on the board.
    var done = false
}
