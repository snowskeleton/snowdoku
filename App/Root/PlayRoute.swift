import SudokuCore

/// Screens pushed in the Play tab. The board is a route too, so leaving it goes back to
/// whichever list it was started from (Free Play, a chapter, Home).
enum PlayRoute: Hashable {
    case campaign
    case chapter(String)
    case lesson(Technique)
    case freePlay
    case game
}
