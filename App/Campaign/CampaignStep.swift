import SudokuCore

/// One step of a campaign chapter, in play order. Spotlights, practice and mixed puzzles are
/// numbered within their kind.
enum CampaignStep: Hashable, Codable, Sendable {
    case spotlight(Int)
    case context(Int)
    case mixed(Int)
    case drills
    case boss
    case endless

    /// The kind of puzzle the step plays (nil for the drill round).
    var kind: CampaignKind? {
        switch self {
        case .spotlight: .spotlight
        case .context: .context
        case .mixed: .mixed
        case .drills: nil
        case .boss: .boss
        case .endless: .endless
        }
    }

    /// Stable key for saved progress.
    var key: String {
        switch self {
        case .spotlight(let i): "spotlight\(i)"
        case .context(let i): "context\(i)"
        case .mixed(let i): "mixed\(i)"
        case .drills: "drills"
        case .boss: "boss"
        case .endless: "endless"
        }
    }

    init?(key: String) {
        func index(after prefix: String) -> Int? { key.hasPrefix(prefix) ? Int(key.dropFirst(prefix.count)) : nil }
        if let i = index(after: "spotlight") { self = .spotlight(i) }
        else if let i = index(after: "context") { self = .context(i) }
        else if let i = index(after: "mixed") { self = .mixed(i) }
        else if key == "drills" { self = .drills }
        else if key == "boss" { self = .boss }
        else if key == "endless" { self = .endless }
        else { return nil }
    }
}

extension CampaignChapter {
    /// Practice and mixed puzzles per chapter.
    static let practiceCount = 2

    /// Every step, in play order: a spotlight per family member (two when the family has one),
    /// practice (not in the first chapter), mixed (when there's anything earlier to mix in), drills,
    /// boss, endless.
    var steps: [CampaignStep] {
        var s = (0..<max(2, family.count)).map(CampaignStep.spotlight)
        if hasPool(.context) { s += (0..<Self.practiceCount).map(CampaignStep.context) }
        if hasPool(.mixed) { s += (0..<Self.practiceCount).map(CampaignStep.mixed) }
        return s + [.drills, .boss, .endless]
    }

    /// Whether the chapter has puzzles of a kind (a kind the miner found nothing for is skipped).
    private func hasPool(_ kind: CampaignKind) -> Bool {
        kinds.contains(kind) && (CampaignBank.isEmpty || CampaignBank.pools[.init(chapter: id, kind: kind, member: nil)] != nil)
    }

    /// The family member a spotlight step is about, and which puzzle of its pool is the step's own.
    func member(for step: CampaignStep) -> Technique? {
        guard case .spotlight(let i) = step else { return nil }
        return family.count == 1 ? lead : family[min(i, family.count - 1)]
    }

    /// Index of the step's own puzzle in its pool (steps of one kind share a pool).
    func canonicalIndex(for step: CampaignStep) -> Int {
        switch step {
        case .spotlight(let i): family.count == 1 ? i : 0
        case .context(let i), .mixed(let i): i
        default: 0
        }
    }

    func title(for step: CampaignStep) -> String {
        switch step {
        case .spotlight(let i):
            family.count == 1 ? "Spotlight \(i + 1)" : "Spotlight: \(member(for: step)!.name)"
        case .context(let i): "Practice \(i + 1)"
        case .mixed(let i): "Mixed \(i + 1)"
        case .drills: "Drills"
        case .boss: "Boss"
        case .endless: "Endless"
        }
    }

    func subtitle(for step: CampaignStep) -> String {
        switch step {
        case .spotlight: "Just the technique, nothing else"
        case .context: "A real puzzle that needs it"
        case .mixed: "Mixed with what you've learned"
        case .drills: "Find it fast, \(CampaignProgress.drillsNeeded) times"
        case .boss: "Beat it without hints to finish the chapter"
        case .endless: "As many as you like"
        }
    }
}

/// What a campaign game is part of. Saved with the game.
struct CampaignContext: Codable, Hashable, Sendable {
    var chapter: String
    var step: CampaignStep
    /// The bundled puzzle's givens (before its random transform), so retries can avoid it.
    var puzzleID: String?

    var chapterInfo: CampaignChapter? { CampaignChapter.named(chapter) }

    /// The techniques this game is allowed to need, and the ones it's about.
    var allowed: Set<Technique> {
        guard let ch = chapterInfo else { return Set(Technique.allCases) }
        guard let kind = step.kind else { return ch.cumulative }
        return ch.allowed(kind, member: ch.member(for: step))
    }

    var focus: Set<Technique> {
        guard let ch = chapterInfo else { return [] }
        guard let kind = step.kind else { return ch.familySet }
        return ch.focusTechniques(kind, member: ch.member(for: step))
    }
}
