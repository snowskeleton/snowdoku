import SudokuCore

/// The coaching card a spotlight question shows over the controls.
enum Coach: Equatable {
    /// What the question practices, before the first move.
    case intro(String)
    /// Why the move at `cell` wasn't the answer.
    case feedback(SpotlightFeedback, cell: Int)

    var text: String {
        switch self {
        case .intro(let s): s
        case .feedback(let f, _): f.message
        }
    }

    /// The cell whose digit makes the move break a rule, to point at.
    var clash: Int? {
        if case .feedback(.conflict(_, _, let seen), _) = self { return seen }
        return nil
    }

    /// The house the clash is in.
    var clashHouse: Int? {
        if case .feedback(.conflict(_, let h, _), _) = self { return h }
        return nil
    }

    var attempt: Int? {
        if case .feedback(_, let c) = self { return c }
        return nil
    }
}
