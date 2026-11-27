import Foundation
import SudokuCore

/// The campaign's puzzles, bundled with the app (`Resources/Campaign.json`, picked by
/// `sudokugen campaign-merge`). Each pool keeps the file's order: a step's own puzzle is at its
/// `canonicalIndex`, the rest are alternates for retries.
enum CampaignBank {
    struct PoolKey: Hashable {
        var chapter: String
        var kind: CampaignKind
        var member: Technique?
    }

    static let pools: [PoolKey: [CampaignPuzzle]] = {
        guard let url = Bundle.main.url(forResource: "Campaign", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([CampaignPuzzle].self, from: data) else { return [:] }
        return Dictionary(grouping: list) { PoolKey(chapter: $0.chapter, kind: $0.kind, member: $0.member) }
    }()

    static var isEmpty: Bool { pools.isEmpty }

    static func pool(_ ch: CampaignChapter, _ step: CampaignStep) -> [CampaignPuzzle] {
        guard let kind = step.kind else { return [] }
        return pools[PoolKey(chapter: ch.id, kind: kind, member: ch.member(for: step))] ?? []
    }
}
