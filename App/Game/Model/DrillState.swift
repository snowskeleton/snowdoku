/// Progress through a technique drill.
enum DrillState: String, Codable {
    /// Looking for the move.
    case searching
    /// The move was made; the drill's result card is showing.
    case found
    /// The player chose to keep solving after finding it.
    case dismissed
}
