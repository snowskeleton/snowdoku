import SudokuCore

/// Where an unfinished game is kept: one per random-game tier, plus the daily, practice
/// puzzles, drills and the campaign. Starting a game replaces only the game in its own slot.
enum GameSlot: Hashable {
    case random(Difficulty)
    case daily, practice, drill, campaign

    var key: String {
        switch self {
        case .random(let d): "random.\(d.rawValue)"
        case .daily: "daily"
        case .practice: "practice"
        case .drill: "drill"
        case .campaign: "campaign"
        }
    }
}

extension GameSlot {
    init(campaign: Bool, drill: Bool, practice: Technique?, dailyKey: String?, difficulty: Difficulty) {
        if campaign { self = .campaign }
        else if drill { self = .drill }
        else if practice != nil { self = .practice }
        else if dailyKey != nil { self = .daily }
        else { self = .random(difficulty) }
    }
}

extension GameRecord {
    var slot: GameSlot {
        GameSlot(campaign: campaign != nil, drill: drill != nil, practice: practice, dailyKey: dailyKey, difficulty: difficulty)
    }
}

extension Game {
    var slot: GameSlot {
        GameSlot(campaign: campaign != nil, drill: drill != nil, practice: practice, dailyKey: dailyKey, difficulty: difficulty)
    }
}
