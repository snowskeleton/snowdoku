# Snowdoku: working in this repo

A sudoku app with no ads and no gimmicks, built to *teach* solving techniques. One SwiftUI codebase for iOS 18+, iPadOS and native macOS 15+, on top of a pure-Swift engine.

## Layout

| Path | What |
|---|---|
| `Engine/` | Swift package `SudokuCore` (iOS 16 / macOS 13). Grid, brute-force solver, human-style solver, ~59 techniques, rater, generator, hints. Also the `sudokugen` CLI and the engine tests. |
| `Engine/Sources/SudokuCore/Techniques/` | One `Strategy` per technique |
| `App/` | SwiftUI app in feature folders: `Root/` (window root, per-window `GameStore`), `Game/` (model, board, pads, hint), `Home/`, `Techniques/`, `Statistics/` (shared `StatsStore`), `Settings/`, `Shared/`. One type per file. A **synced folder**, so new files show up in Xcode automatically. |
| `App/Resources/Drills.json` | The drill bank: for each technique, up to 20 mid-solve positions whose next move is that technique. Mined offline (see below); the app applies a random `GridTransform` to each drill it serves. |
| `Engine/Data/extreme-puzzles.txt` | 404 puzzles that need forcing chains, found by `sudokugen mutate` (random generation essentially never reaches Extreme). Seeds the forcing drills and, later, Extreme in the puzzle bank. |
| `App/AppIcon.icon` | The app icon, an Icon Composer package. Its look (`icon.json`) is tuned by hand in Icon Composer; its layer images are drawn by `Design/logo/make_icons.py`, which never overwrites `icon.json`. |
| `Design/logo/` | Logo concepts and the icon generator. |
| `UITests/` | XCUITest target `SnowdokuUITests` (iOS simulator). Also a synced folder. |
| `project.yml` | XcodeGen spec. `Snowdoku.xcodeproj` is generated from it, and **both are committed**. |

## Ground rules from the user

- **Never hand the user setup steps.** Run tooling yourself. After editing `project.yml`, run `xcodegen generate` and commit the regenerated project. New files under `App/` or `UITests/` need no regeneration. **`project.yml` is the source of truth:** before regenerating, check `git diff Snowdoku.xcodeproj` for settings the user changed in Xcode (signing team, capabilities, build settings) and port them into `project.yml` first, or `xcodegen generate` will wipe them.
- **Always commit and push** (remote: `github.com/snowskeleton/snowdoku`, branch `main`). End commit messages with the `Co-Authored-By` trailer.
- **Prove UI fixes before claiming them.** A guessed fix once shipped broken. For interaction bugs, write or extend a UI test that reproduces the bug, check it fails on the old code, then fix it.
- **Overlays, not layout shifts.** Transient UI (hint panel, Finish pill) floats over the controls and never resizes the board. The user explicitly hated an inline banner.
- **Ask the user's taste, then commit to it.** v1 decisions are below; don't re-litigate them.

## Commands

```bash
# Engine
swift build -c release --package-path Engine
swift test  -c release --package-path Engine          # ~2 min; soundness tests are the important ones
Engine/.build/release/sudokugen techniques | solve <81 chars> | rate <puzzles> | stats --count 1000
Engine/.build/release/sudokugen generate --count 50 --difficulty expert   # or --technique xWing

# App (simulators: "iPhone 18 Pro", "iPad Pro 13-inch (M5)"; runtime iOS 27.2)
xcodebuild -project Snowdoku.xcodeproj -scheme Snowdoku -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath .build/xcode build
xcodebuild -project Snowdoku.xcodeproj -scheme Snowdoku -destination 'platform=macOS' -derivedDataPath .build/xcode build CODE_SIGN_IDENTITY=-
xcodebuild test -project Snowdoku.xcodeproj -scheme Snowdoku -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath .build/xcode
```

Re-mining the drill bank (needed when the solver's order changes; `DrillTests.bundledDrillsStillWork` fails when it is):

```bash
G=Engine/.build/release/sudokugen; T=$(mktemp -d)
$G drills --per 20 --minutes 8 > $T/random.json                         # everything random puzzles reach
$G drills --per 20 --from Engine/Data/extreme-puzzles.txt > $T/extreme.json   # forcing chains and nets
# more extremes: $G mutate --from Engine/Data/extreme-puzzles.txt --minutes 4 --count 400
$G merge-drills $T/random.json $T/extreme.json > App/Resources/Drills.json
```

Some techniques never come up as the *next* move, because an easier technique always finds the same thing first (see the drill counts `merge-drills` prints). They have no drills, and their pages hide the drill button.

Build both iOS and macOS after app changes, since the code must stay platform-neutral. Use `#if os(iOS)` only for the rare platform-specific bit.

### Looking at the app

You can't tap the simulator directly. Use the DEBUG-only launch arguments (`GameStore.applyDebugArguments` in `App/Root/GameStore.swift`), then screenshot:

```bash
SIM="iPhone 18 Pro"; xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl install "$SIM" .build/xcode/Build/Products/Debug-iphonesimulator/Snowdoku.app
xcrun simctl terminate "$SIM" net.snowskeleton.snowdoku 2>/dev/null
xcrun simctl launch "$SIM" net.snowskeleton.snowdoku -demo hard 3     # see the arguments below
sleep 5; xcrun simctl io "$SIM" screenshot <scratchpad>/shot.png
```

- `-demo <difficulty> [hintLevel]`: generate a game, fill notes, select a cell, and optionally advance the hint (0 = nudge … 4 = answer)
- `-arm <digit>`: with `-demo`, arm a big digit (digit-first mode)
- `-puzzle <81 chars>`: start a specific puzzle (no generation wait; UI tests use this)
- `-prefill <n> [-wrong]`: with `-puzzle`, fill all but the last n empty cells from the solution, optionally with one wrong value
- `-technique <technique>`: open that technique's page
- `-drill <technique> [-hint level]`: start a drill from the bundled bank (raw technique name, e.g. `xWing`), optionally advancing the hint

UI tests find cells by accessibility label `Row r, column c, …` and big pad digits by a label that starts with `"<d>,"`.

## Engine architecture

- `BruteForce`: bitmask backtracking for uniqueness checks, solutions and random filled grids.
- `HumanSolver`: repeatedly applies the easiest `Strategy`, ordered by `Technique.score`. Each `Strategy` emits exactly one `Technique`. Strategies with `ranked == true` (chains) collect every step and present the simplest (`complexity`).
- `Step`: technique, placements, eliminations, houses, highlights (with roles), chain links, explanation. Hints, highlighting and explanations all come from it.
- `Rater`: the hardest technique in a full solve; its `Difficulty` tier is the puzzle's level.
- `Generator`: random grid → remove clues while the solution stays unique (optional `Symmetry`) → rate. `GridTransform` (relabel digits, shuffle rows/columns within bands, transpose) preserves the rating exactly. `Daily.seed` makes daily puzzles deterministic with no server.
- `HintEngine`: wrong values first, then removed-correct notes, then the next step from the player's own notes. `Step.hintText(level)` gives nudge → technique → region → pattern → answer.
- The engine is built with `-O` even in Debug (`Engine/Package.swift`) because generation is hot code.

### Adding a technique

1. Add a case to `Technique` with `name`, `score` (ordering and tier), `summary`, and `assumesUniqueness` if relevant.
2. Write a `Strategy` in `Techniques/` that emits only that technique. Explanations go in plain English, with eliminations via `describeEliminations`.
3. Register it in `HumanSolver.allStrategies`.
4. Run `swift test`. `SoundnessTests` check that every step (in find-all mode too) never removes a solution digit, which is how unsound logic gets caught. Then run `sudokugen stats` to see how often it fires.

Deliberately not implemented: Exocet, MSLS, SK-loops (rare; forcing nets cover them). The Easter Monster still ends with a trial-and-error step.

## App behavior (v1 decisions)

- Input: two pads, big (values) and small (notes), laid out as two 3×3 grids, or single rows when wide. With a cell selected, a digit enters it; entering a **big** digit then clears the selection, while notes keep it. With no selection, tapping a digit **arms** it, and tapping cells applies it; tap it again or press Esc to disarm.
- Tapping the selected cell deselects it. The board has a single tap handler that maps the location to a cell (don't go back to `.offset` + per-cell gestures, which broke hit-testing).
- Mac keyboard: number = value, Shift+number = note, arrows move, Option+arrow jumps a box, Command+arrow jumps to the edge, Delete erases, H = hint, Cmd+Z / Shift+Cmd+Z = undo/redo.
- Highlighting: the selected cell plus its peers, matching digits, and cells whose **notes** contain the highlighted digit (whole-cell tint, bold note).
- Technique pages: summary, a hand-written "How it works" guide, a worked example (the bank's first drill, drawn like an answer-level hint), and two practice buttons: a drill ("the next move is X") and a full puzzle that needs it.
- Drills start mid-solve with the solver's own candidates as notes (singles drills have no notes). The header says what to find, with no timer. Making any instance of the move shows a floating result card (Keep solving / Next drill). Drills don't count toward statistics.
- Hints are progressive, and the panel floats over the controls. Auto-complete ("Finish puzzle" pill) is offered only above Beginner, with no wrong entries, ≤ N empty cells (default 15), and singles finishing the rest.
- Random games run from Beginner to Master and are generated on device. Extreme isn't offered yet.
- Accessibility: basic labels and Dynamic Type only. A full VoiceOver mode was explicitly deferred.

## Roadmap / known gaps

- Bundled puzzle bank, mined offline with `sudokugen`: instant starts, Extreme puzzles, and stable daily puzzles across engine changes. (Today the daily puzzle depends on the generator code; changing the generator changes past and future dailies.) Daily days are UTC (`DailySchedule`), so everyone gets the same puzzle at the same moment.
- Technique training: a "how you could have spotted this" replay. (Drills and the long-form guides with a worked example exist: `Technique+Guide.swift`, `DrillBank`, `TechniqueExample`.)
- Draw chain links on the board (`Step.links` exists but isn't rendered).
- iPad and Mac layout polish, an accent color (no asset catalog yet), dark mode check.
- Puzzle import (paste or camera); `GameStore.start(puzzle:)` already exists.
