# Snowdoku

A sudoku app with no ads and no gimmicks, built to teach real solving techniques.

## Layout

| Path | What |
|---|---|
| `Engine/Sources/SudokuCore` | Pure-Swift engine (iOS 16+/macOS 13+): grid, brute-force solver, human-style solver, techniques, rater, generator, hints |
| `Engine/Sources/SudokuCore/Techniques` | One `Strategy` per technique (singles → forcing chains) |
| `Engine/Sources/sudokugen` | macOS CLI for solving, rating and bulk-generating puzzle banks |
| `Engine/Tests/SudokuCoreTests` | Swift Testing suite, including soundness checks for every technique |
| `App/` | SwiftUI app: one codebase for iOS 17+, iPadOS and native macOS 14+ |
| `project.yml` | XcodeGen spec that `Snowdoku.xcodeproj` is generated from (both committed) |

## Building the app

Open `Snowdoku.xcodeproj`. Source files under `App/` are a synced folder, so new files show up on their own. Project settings live in `project.yml`; after changing it, run `xcodegen generate`.

Debug-only demo hook for screenshots: launch with `-demo hard 3`, which starts a Hard game with notes filled in and the hint already at level 3.

## How it works

- **BruteForce**: bitmask backtracking. Checks for a unique solution, finds the solution, makes random full grids.
- **HumanSolver**: repeatedly applies the *easiest* applicable `Strategy` (ordered by `Technique.score`). Each deduction is a `Step` containing the technique, placements and eliminations, the houses involved, highlights, chain links and an explanation.
- **Rater**: a full human-style solve. The rating is the hardest technique used, and its `Difficulty` tier is the puzzle's level.
- **Generator**: random full grid → remove clues while the solution stays unique (optional symmetry) → rate. Hard and rare-technique puzzles are mined in bulk offline and shipped as a bank. `GridTransform` (digit relabeling, row/column/band shuffles, transpose) turns each stored puzzle into billions of lookalikes that need the exact same techniques. `Daily.seed` picks the daily puzzle deterministically, with no server.
- **HintEngine**: checks for wrong entries, then for wrongly removed pencil marks, and only then finds the next step from the player's own state. `Step.hintText(_:)` gives the progressive levels: nudge → technique → region → pattern → answer.

## CLI

```bash
swift build -c release --package-path Engine
Engine/.build/release/sudokugen techniques
Engine/.build/release/sudokugen solve <81-char puzzle>
Engine/.build/release/sudokugen generate --count 100 --difficulty expert
Engine/.build/release/sudokugen generate --count 10 --technique swordfish
Engine/.build/release/sudokugen stats --count 1000
```

## Techniques (scores are our own, tune in `Technique.swift`)

Singles: Full House, Hidden Single (box/line), Naked Single.
Intersections/subsets: Pointing, Claiming, Naked/Hidden Pair/Triple/Quad.
Fish: X-Wing, Swordfish, Jellyfish, finned and sashimi variants, Franken, Mutant and Kraken fish.
Single-digit: Skyscraper, 2-String Kite, Turbot Fish, Empty Rectangle, Simple Coloring, Multi-Coloring.
Wings: XY, XYZ, W, WXYZ.
Uniqueness: UR types 1–6, Hidden Rectangle, Avoidable Rectangle, BUG+1.
Chains: Remote Pair, X-Chain, XY-Chain, Continuous Nice Loop, AIC, Grouped AIC.
ALS: Sue de Coq, ALS-XZ, ALS-XY-Wing, ALS Chain, Death Blossom.
Forcing: Cell/Unit Forcing Chains, Forcing Contradiction, Forcing Nets (with locked candidates and pairs). Trial and Error is the last-resort fallback.

Not implemented: Exocet, MSLS and SK-loops. They show up almost only in puzzles hand-built by enthusiasts, and forcing nets cover those puzzles.
