# Snowdoku: working in this repo

A sudoku app with no ads and no gimmicks, built to *teach* solving techniques. One SwiftUI codebase for iOS 18+, iPadOS and native macOS 15+, on top of a pure-Swift engine.

## Layout

| Path | What |
|---|---|
| `Engine/` | Swift package `SudokuCore` (iOS 16 / macOS 13). Grid, brute-force solver, human-style solver, ~64 techniques, rater, generator, hints. Also the `sudokugen` CLI and the engine tests. |
| `Engine/Sources/SudokuCore/Techniques/` | One `Strategy` per technique |
| `App/` | SwiftUI app in feature folders: `Root/` (window root, per-window `GameStore`), `Game/` (model, board, pads, hint), `Home/`, `Techniques/`, `Statistics/` (shared `StatsStore`), `Settings/`, `Shared/`. One type per file. A **synced folder**, so new files show up in Xcode automatically. |
| `App/Resources/Drills.json` | The drill bank: for each technique, up to 20 mid-solve positions whose next move is that technique. Mined offline (see below); the app applies a random `GridTransform` to each drill it serves. |
| `App/Campaign/` | The campaign: `CampaignStep` (a chapter's steps), `CampaignBank` (loads `Campaign.json`), `CampaignProgress` (saved progress, unlocking, picking puzzles), and the path and chapter views. Chapters themselves are defined in the engine (`Engine/Sources/SudokuCore/Campaign.swift`). |
| `App/Resources/Campaign.json` | The campaign's puzzles: for each chapter, ~8 per spotlight member, practice, mixed and boss pools, and up to 150 endless. Mined on the cluster by `sudokugen campaign`, picked by `sudokugen campaign-merge` (see below). |
| `Engine/Data/campaign-mined.jsonl.xz` | Every puzzle the campaign miner found (JSON lines, `CampaignPuzzle`), for re-merging or other uses. |
| `App/Resources/Puzzles.tsv` | The puzzle bank: rated puzzles from Beginner 1 to Extreme (at least 500 per tier, 250 or more per level), one per line (`BankedPuzzle`: givens, hardest technique, total score, step count, technique counts, technique level). New games and dailies come from it with a random `GridTransform`; on-device generation is only the fallback. ~1.1 MB. |
| `Engine/Scripts/select_extremes.py` | Picks new Extreme bank lines from rated `mutate` output (see Topping up Extreme below). |
| `Engine/Data/extreme-puzzles.txt` | 718 puzzles that need forcing chains, found by `sudokugen mutate` (random generation essentially never reaches Extreme). Seeds the forcing drills; good seeds for more Extreme bank puzzles. |
| `App/AppIcon.icon` | The app icon, an Icon Composer package. Its look (`icon.json`) is tuned by hand in Icon Composer; its layer images are drawn by `Design/logo/make_icons.py`, which never overwrites `icon.json`. |
| `Design/logo/` | Logo concepts and the icon generator. |
| `Design/achievements/` | Game Center: `Achievements.tsv` is the achievement list (ids, titles, points, descriptions; designed with the user, so change titles and points only when asked). `make_badges.py` reads it, draws the badge art (`badges/`) and writes `GameCenter.json`, the achievements and leaderboards to configure in App Store Connect (identifiers must match `App/Shared/GameCenter.swift`). |
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
swift test  -c release --package-path Engine          # ~2 min; soundness tests and the bundled-bank checks are the important ones
Engine/.build/release/sudokugen techniques | solve <81 chars> | rate <puzzles> | stats --count 1000
Engine/.build/release/sudokugen generate --count 50 --difficulty expert   # or --level expert2, or --technique xWing
Engine/.build/release/sudokugen bank-stats    # puzzles per level and daily pool; per tier and technique: how many use it, and have it as hardest

# App (simulators: "iPhone 18 Pro", "iPad Pro 13-inch (M5)"; runtime iOS 27.2)
xcodebuild -project Snowdoku.xcodeproj -scheme Snowdoku -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath .build/xcode build
xcodebuild -project Snowdoku.xcodeproj -scheme Snowdoku -destination 'platform=macOS' -derivedDataPath .build/xcode build CODE_SIGN_IDENTITY=- CODE_SIGN_ENTITLEMENTS=   # ad-hoc signing can't carry the Game Center entitlement
xcodebuild test -project Snowdoku.xcodeproj -scheme Snowdoku -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath .build/xcode
```

Updating the drill bank when the solver's order changes (`DrillTests.bundledDrillsStillWork` fails when it does). `merge-drills` re-checks every drill: one whose next move is now a different technique becomes a drill for that technique. So first re-check the existing bank, then mine only the techniques it prints as short:

```bash
G=Engine/.build/release/sudokugen; T=$(mktemp -d)
$G merge-drills App/Resources/Drills.json > $T/rechecked.json           # prints per-technique counts
$G drills --per 20 --minutes 8 --technique xWing,skyscraper > $T/topup.json   # the short ones
$G merge-drills $T/rechecked.json $T/topup.json > App/Resources/Drills.json
```

Re-mining from scratch:

```bash
G=Engine/.build/release/sudokugen; T=$(mktemp -d)
$G drills --per 20 --minutes 8 > $T/random.json                         # everything random puzzles reach
$G drills --per 20 --from Engine/Data/extreme-puzzles.txt > $T/extreme.json   # forcing chains and nets
# more extremes: $G mutate --from Engine/Data/extreme-puzzles.txt --minutes 4 --count 400
$G merge-drills $T/random.json $T/extreme.json > App/Resources/Drills.json
```

Building the puzzle bank (`PuzzleBankTests.bundledRatingsStillMatch` fails when an engine change moves any stored rating):

```bash
G=Engine/.build/release/sudokugen; T=$(mktemp -d)
for d in beginner easy medium hard expert master; do $G generate --count 800 --difficulty $d > $T/$d.tsv; done
$G mutate --from Engine/Data/extreme-puzzles.txt --minutes 15 --count 2000 > $T/extreme.txt   # on the cluster
$G bank --per 500 $T/{beginner,easy,medium,hard,expert,master}.tsv $T/extreme.txt > App/Resources/Puzzles.tsv   # ~2 min; rating Extremes is slow
```

When only ratings drifted, **re-rate in place** instead: `$G bank App/Resources/Puzzles.tsv > $T/p.tsv && mv $T/p.tsv App/Resources/Puzzles.tsv`. `bank` keeps input order within a tier, and a daily picks one of its tier's levels evenly from the seed, then `pool[seed % count]` of that level (`Daily.pick`), drawing only from the first `Daily.poolSize` puzzles of each level (pinned in `Engine/Sources/SudokuCore/PuzzleBank.swift`). So keeping lines in order and only appending keeps past and future dailies the same. A puzzle that changes level, or a re-mined bank, changes dailies. Dailies never use Extreme (`DailySchedule.difficulty`).

Every tier must keep at least 500 puzzles, for the solve-count achievements, and every level some (`bundledRatingsStillMatch` checks both); aim for 250 per level. A re-rate can move puzzles between levels; check with `$G bank-stats`, then top up a short level: `$G generate --count 100 --level hard3` (seconds even for the rarest levels; `--difficulty hard` for a tier), rate it with `$G bank`, drop duplicates and `GridTransform`s of bank puzzles (the functions in `Engine/Scripts/select_extremes.py`), append the lines, and run `$G bank` over the file to regroup it by tier (order within a tier is kept).

Topping up Extreme (random generation essentially never reaches it): run `$G mutate --from <extreme-puzzles.txt plus the bank's Extreme lines> --minutes 15 --count 600` on the cluster, rate the output with `$G bank`, and append the Extreme lines `python3 Engine/Scripts/select_extremes.py App/Resources/Puzzles.tsv <how many> <rated files>` picks: no duplicates, nothing that is a `GridTransform` of any bank puzzle, and fresh solution grids first (mutate keeps the seed's grid). It takes a few minutes, so run it on the cluster too. Append their givens to `Engine/Data/extreme-puzzles.txt` too. With 500 Extremes, `bundledRatingsStillMatch` takes ~18 s, still shorter than the soundness tests it runs beside.

Building the campaign (`CampaignTests.bundledCampaignStillWorks` fails when an engine change moves a stored use count or makes a puzzle stop needing its technique). Mining is slow (hours per chapter for the rare patterns), so run it on many cores, one process per machine, each with a share of the chapters:

```bash
G=Engine/.build/release/sudokugen; T=$(mktemp -d)
$G campaign --chapter xWing,swordfish --minutes 100 --iterations 300 --bank App/Resources/Puzzles.tsv > $T/a.jsonl   # all kinds; --kind boss,endless for some
xz -dc Engine/Data/campaign-mined.jsonl.xz > $T/old.jsonl
$G campaign-merge $T/*.jsonl > App/Resources/Campaign.json             # prints each chapter's pool sizes and best use counts
```

`campaign-merge` drops puzzles over 28 clues (except the Full House chapter, which can't be solved with fewer), prefers a fresh solution grid for each puzzle in a chapter (unless a reused grid gives a higher use count), and lets endless reuse a chapter's practice and boss puzzles. A kind with no puzzles is simply skipped in the app.

Checking how often techniques come up, and whether our detectors miss instances:

```bash
Engine/.build/release/sudokugen census --min hard App/Resources/Puzzles.tsv   # ~2 min
Engine/Tools/hodoku-compare.sh [--min hard] [--limit N] [--examples N]       # ~15 min for Hard+
Engine/Tools/hodoku-compare.sh --ratings                                    # bank tiers vs HoDoKu's levels, ~1 min
```

`census` walks the solver's path and, at each position whose next move isn't a single, counts per technique whether it applies (avail), removes something no easier technique does (novel), and is picked (chosen). Available but never novel means fully covered by easier techniques (Hidden Quad, the Jellyfish family): rare by structure, not by ranking. Novel but rarely chosen means the order starves it.

`hodoku-compare.sh` fetches HoDoKu 2.2.0 into `.build/hodoku` (checksum-pinned; run as a separate program, so the GPL doesn't reach us), exports the same positions in HoDoKu's library format, runs its Find All Steps, and compares removals per technique. The **MISSED** column is the one that matters: HoDoKu removes a candidate that no technique of ours in the same family does (families absorb naming differences such as Skyscraper vs Turbot Fish, Locked vs Naked Pair). The soundness tests catch wrong eliminations; this catches missed ones. Known, deliberate gaps: ALS Chains stop at 5 sets (HoDoKu goes to 7); chains have no length limit (long ones cost extra in the total score, `Step.score`, and count at a higher level, `Step.level`); HoDoKu has no WXYZ-Wing, and its Find All Steps never reports Kraken Fish. Treat HoDoKu as the more experienced opinion, not just an oracle: where it differs by design (its defaults, order, what it leaves out), weigh changing ours. Open findings are in `TODO.md`.

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
- `-technique <technique>`: open that technique's page; `-techniquesTab` / `-statsTab`: open the library or Statistics tab
- `-drill <technique> [-hint level]`: start a drill from the bundled bank (raw technique name, e.g. `xWing`), optionally advancing the hint
- `-campaign <chapterId> <stepKey>`: start a campaign step (`lesson0`, `spotlight0`, `context1`, `mixed0`, `drills`, `boss`, `endless`); works with `-prefill`
- `-campaignDone <n>`: the first n chapters finished; `-resetCampaign` clears progress; `-resetGames` clears saved games and what Continue resumes

UI tests find cells by accessibility label `Row r, column c, …` (spotlit cells end with `, in focus`) and big pad digits by a label that starts with `"<d>,"`.

## Releasing (TestFlight and App Store)

The version is `MARKETING_VERSION` (e.g. `0.1`) and the build number is `CURRENT_PROJECT_VERSION`, both in `project.yml`. App Store Connect calls the version a "TestFlight version" (pre-release version) and files each build under the one matching its `MARKETING_VERSION`.

- **Build numbers** go up by one for every build uploaded, are never reused and **never reset**, not even for a new version. Bump them without asking. They're bumped by hand, as part of an upload, not by a build script, so only builds worth testing get numbers.
- **Versions**: **always ask the user before changing `MARKETING_VERSION`**, for TestFlight or for an App Store release.
- **Tags**: every uploaded build gets an annotated tag `build-<N>` (e.g. `build-4`) on the commit it was built from. The build that ships to the App Store also gets `v<version>` (e.g. `v1.0`) on the same commit. Push tags right after creating them.

Each TestFlight build goes through **GitHub Actions** (`.github/workflows/testflight.yml`):

1. Start from a clean, pushed `main`. Bump `CURRENT_PROJECT_VERSION` in `project.yml` to one more than the highest build in App Store Connect (`asc GET '/v1/builds?filter[app]=<app id>&sort=-version&limit=1'`, see the app-store-connect skill), run `xcodegen generate`, and commit and push the bump.
2. Write the **What to Test** notes for testers. Gather what changed since the previous build: `git log build-<N-1>..HEAD --no-merges` and the PRs merged since then (`gh pr list --state merged --search "merged:>=<date of build-<N-1>>"`). Write two short lists, "New since build <N-1>" (what was added or changed, in player terms) and "Please test" (what to try). Leave out engine, tooling and data work players can't see, and keep each line short and plain. Then run the text through the **humanizer** skill (embedded mode), and keep it under 4000 characters. If the build has no player-visible changes, say so in one line.
3. Tag `build-<N>` on the bump commit with the notes as the tag message: subject `TestFlight build <N> (<version>)`, a blank line, then the notes (`git tag -a build-<N> -F <file>`). Push the tag. That starts the workflow (`gh run list --workflow testflight.yml -L 1` for its link). Tags can't be moved, so get the notes right first. To fix notes on a build already uploaded, run `.github/scripts/whats-new.sh <build id> <file>` with the API key variables (see the script).
4. The workflow checks the tag (on `main`, N equals `CURRENT_PROJECT_VERSION`), archives for iOS on the `xcode-27` runner, uploads, waits for processing, sets What to Test from the tag message's body (`whats-new.sh`), adds the external group and submits for beta review (`.github/scripts/testflight.sh`). Watch it with `gh run watch <id> --exit-status` in the background and report how it ended.

How it's locked down: the Admin API key (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`) exists only as secrets of the `app-store` environment, which accepts deployments only from `build-*` tags. It has no approval step: the user dropped it on purpose, as the only writer to the repo, and isn't worried about the key. The ruleset "Shipped build tags" keeps `build-*` and `v*` tags from being moved or deleted, so a mistaken build gets the next number, never a re-tag. The workflow has a read-only token and pins its actions by commit SHA. Don't loosen any of this, or add another workflow that uses the environment, without asking.

**Fallback without CI** (the runner can't build, or Xcode needs a version the runner lacks), from step 2 on:

1. Archive **for iOS** (`-destination 'generic/platform=iOS'`; Xcode archives for whatever destination is selected, and a Mac archive lands in TestFlight's macOS section, not the iOS list), then export and upload with `ExportOptions.plist`. The archive can authenticate with the App Store Connect API key (flags in the app-store-connect skill; keep the key IDs out of this public repo), but the **export must not**: distribution uses a cloud-managed certificate, which the App Manager key may not use ("Cloud signing permission error"). Without the key flags, xcodebuild signs and uploads with the Apple ID signed in to Xcode, which works:
   ```bash
   xcodebuild archive -project Snowdoku.xcodeproj -scheme Snowdoku -destination 'generic/platform=iOS' -archivePath .build/release/Snowdoku-iOS.xcarchive -allowProvisioningUpdates
   xcodebuild -exportArchive -archivePath .build/release/Snowdoku-iOS.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath .build/release/export -allowProvisioningUpdates
   ```
2. Write the notes and tag `build-<N>` as in steps 2 and 3 above, and push the tag. That also starts the workflow: cancel its run (`gh run cancel <id>`) so it can't upload the same build again.
3. Wait for processing (`processingState` `VALID`). It usually takes only a minute or two, so check back every so often (a background loop polling every 30 s or so) and carry on as soon as it's done. The build joins the TestFlight version matching `MARKETING_VERSION` on its own, or a new one if that version is new (only after the user agreed to the new version). The internal group "All Users" gets every build automatically. Set What to Test with `.github/scripts/whats-new.sh`. For external testers, add the build to "All Users - External" (`POST /v1/builds/<id>/relationships/betaGroups`), then submit it for beta app review (`POST /v1/betaAppReviewSubmissions` with the build). Adding it to the group alone doesn't submit it. A version that has already passed review is approved at once (`externalBuildState` goes to `IN_BETA_TESTING`). The user approved both steps as part of this process.

An App Store release follows the same steps for its build, adds the `v<version>` tag, and asks the user before submitting for review or releasing (see the app-store-connect skill).

## Engine architecture

- `BruteForce`: bitmask backtracking for uniqueness checks, solutions and random filled grids.
- `Level` (`Level.swift`): 21 numbered levels inside the tiers (Beginner 1–2, Easy 1–3, Medium 1–4, Hard 1–4, Expert 1–4, Master 1–3) plus Extreme, each adding at most three techniques (variants count as one) to everything below. `Technique.level` places a technique; `Technique.rank` (Comparable) is teaching order, used for "easiest first" everywhere. `Technique.score` only feeds the total score.
- `HumanSolver`: starts at Beginner 1 and moves up a level only when stuck, to the easiest level with a move (`nextStep(_:level:limit:)`; `solve` keeps the level reached). Within the levels reached, it tries strategies in its own solve order (`allStrategies`, after HoDoKu's: quads and basic fish before the single-digit patterns, finned fish after the wings and uniqueness). So a solve uses the smallest technique set that solves the puzzle. Each `Strategy` emits exactly one `Technique`. Strategies with `ranked == true` (chains) collect every step and present the simplest (`complexity`) that fits the level: a chain counts at its own `Step.level` (Master 1 once its `Step.score`, the technique's score plus 10 per link beyond 9, reaches 300; Master 3 at 400).
- `Step`: technique, placements, eliminations, houses, highlights (with roles), chain links, explanation. Hints, highlighting and explanations all come from it.
- `Rater`: a puzzle's technique level (`Rating.techniqueLevel`, stored in bank lines) is the highest `Step.level` of the solve, which is the smallest level that solves it. The total is the sum of `Step.score`; a solve whose total is over its tier's `Difficulty.maxScore` (≈ 98th percentile) goes up one tier, as in HoDoKu, to that tier's first level (`Rating.level`, `isBumped`). Master is never bumped to Extreme. `rate(_:solution:ifIn:)` takes a tier or a level and stops early on puzzles that overshoot.
- Forcing chains and nets use **tabling** (`Techniques/Tabling.swift`, HoDoKu's method): an `ImplicationTable` per assumed literal records every consequence with its premises, so steps show their chains (`Step.links`, "r1c1=5 → r1c3≠5 → …"). Chain mode follows only the position's strong/weak links; net mode allows multi-premise steps (a cell emptied by several chains). The old locked-candidates-and-pairs net is kept as a final fallback.
- `Generator`: random grid → remove clues while the solution stays unique (optional `Symmetry`) → rate. `GridTransform` (relabel digits, shuffle rows/columns within bands, transpose) preserves the rating exactly. `Daily.seed` + `Daily.pick` choose the day's bank puzzle and transform deterministically with no server.
- `BankedPuzzle` (`PuzzleBank.swift`): one bank line, parsed without re-rating; `generated(transform)` solves it for play.
- `HintEngine`: wrong values first, then removed-correct notes, then the next step from the player's own notes. `Step.hintText(level)` gives nudge → technique → region → pattern → answer.
- The engine is built with `-O` even in Debug (`Engine/Package.swift`) because generation is hot code.

### Adding a technique

1. Add a case to `Technique` with `name`, `score` (what a use adds to the total), `summary`, and `assumesUniqueness` if relevant, and put it in a level's `Level.newTechniques`.
2. Write a `Strategy` in `Techniques/` that emits only that technique. Explanations go in plain English, with eliminations via `describeEliminations`.
3. Register it in `HumanSolver.allStrategies`, at its place in the solve order.
4. Run `swift test`. `SoundnessTests` check that every step (in find-all mode too) never removes a solution digit, which is how unsound logic gets caught. Then run `sudokugen stats` to see how often it fires.

HoDoKu (GPL, Java) is a design reference only: read it for ideas, but never translate its code, or the app would have to be GPL. Deliberately not implemented: Exocet, MSLS, SK-loops (rare; forcing nets cover them), templates, Whale/Leviathan fish, and HoDoKu's "dual" kite/empty rectangle (two ordinary steps in one; the solver always finds the first half alone). The Easter Monster still ends with a trial-and-error step.

## App behavior (v1 decisions)

- Input: two pads, big (values) and small (notes), laid out as two 3×3 grids, or single rows when wide. Settings → Number pad offers instead one pad with a Digits / Notes / Center switch beside it (`PadLayout`, `Game.padMode`; N steps through it on a keyboard). Center notes are drawn centered in the cell: each cell has one set of notes, drawn the way its last-added note was entered (`NoteKind`: grid, center or auto; `Game.centeredNotes` / `autoNotes`, saved and undoable). Settings → Note style (Manual / Auto) sets the kind for the two-pad notes pad, Shift and Fill: Manual is the grid; Auto centers a cell's notes while it has three or fewer and uses the grid from four. With a cell selected, a digit enters it; entering a **big** digit then clears the selection, while notes keep it. With no selection, tapping a digit **arms** it, and tapping cells applies it; tap it again or press Esc to disarm.
- Tapping the selected cell deselects it. The board has a single tap handler that maps the location to a cell (don't go back to `.offset` + per-cell gestures, which broke hit-testing).
- Mac keyboard: number = value, Shift+number = note, arrows move, Option+arrow jumps a box, Command+arrow jumps to the edge, Delete erases, H = hint, Cmd+Z / Shift+Cmd+Z = undo/redo.
- Pointer (iPad and Mac, each a Settings toggle): with a digit armed, Shift-click toggles it as a note even when the big digit is armed, and right-click removes that note. Board taps go through `BoardClick` (a UIKit recognizer on iOS, for modifier flags and the secondary button); the Mac reads Shift from `NSEvent` and has right-click only on macOS 26+, where AppKit recognizers can attach to SwiftUI views.
- Highlighting: the selected cell plus its peers, matching digits, and cells whose **notes** contain the highlighted digit (whole-cell tint, bold note).
- Technique library: a segmented control switches between grouping by difficulty (one section per level, "Hard 2") and by category (`TechniqueCategory`, HoDoKu's families; each row shows its level). The choice is remembered.
- Technique pages: summary, a hand-written "How it works" guide, a worked example (the bank's first drill, drawn like an answer-level hint), and two practice buttons: a drill ("the next move is X") and a full puzzle that needs it.
- Drills start mid-solve with the solver's own candidates as notes (singles drills have no notes). **Singles drills are spotlit** (`Spotlight` in the engine, `Game.spotlight`): an opening position has many valid singles, so a singles drill names one area (a house, or a naked single's box) and only moves there count. Cells outside are grayed and take no input; a move inside that isn't the answer bounces back (the board is unchanged) with a coach card (`CoachPanel`) naming the clash ("There's already a 5 in row 3"), or saying it's right but a different single or not forced yet. Only wrong digits count as mistakes. The header says what to find, with no timer. Making any instance of the move shows a floating result card (Keep solving / Next drill). Drills don't count toward statistics.
- Controls (Undo, Erase, Fill, Hint) sit above the pads, in wide layouts too; never in the toolbar. The one-pad layout has no controls row: Undo, Fill and Hint are its last column of keys (`ActionKey`), and it has no Erase (tapping a cell's digit again clears it; Delete still works).
- Hints are progressive, and the panel floats over the controls. Auto-complete ("Finish puzzle" pill) is offered only above Beginner, with no wrong entries, ≤ N empty cells (default 15), and singles finishing the rest.
- Random games run from Beginner 1 to Extreme and come from the bundled bank (`App/Root/PuzzleBank.swift`), so they start instantly. Free Play picks a tier, then a level or "All <tier>" (every level equally likely; `FreePlayLevelsView`; Extreme has no levels and starts at once); each tier keeps one unfinished game. A level with no bank puzzles falls back to on-device generation; Extreme is offered only when the bank has some. Hints work at the puzzle's technique level. Statistics and achievements stay per tier. Dailies come from the bank too, from all of a tier's levels evenly. Daily days are UTC (`DailySchedule`), so everyone gets the same puzzle at the same moment.
- **Game Center** (`App/Shared/GameCenter.swift`): signs in quietly at launch (skipped under the DEBUG launch arguments), re-reports everything from local progress after sign-in. Achievements (60, 728 points): one per campaign part and the whole campaign; the first daily and 7/30/365-day streaks; a first solve at every tier, every tier from Beginner to Master, and 10/50/100/250/500 solves per tier from Easy up (Free Play and dailies, from `Stats.completed`); a drill of every technique with drills (`Stats.drilled`); and nine hidden ones for placing every missing copy of one digit before any other digit, note or hint, awarded the moment the last copy goes in (`FirstDigitRun`, `Stats.digitsFirst`; Free Play and dailies). Progress achievements report a percentage, so Game Center shows their progress bars. Leaderboards: chapters completed, and a recurring daily time (no-hint solves only). On iOS/macOS 26, Game Center activities open a chapter or today's daily (`GameActivityListener`); the daily challenge needs no code. The access point shows on the Play home. Nothing depends on it.
- Accessibility: basic labels and Dynamic Type only. A full VoiceOver mode was explicitly deferred.

- **Play tab:** Continue (resumes the unfinished campaign level or free-play game, or starts the next campaign step / another game of the last level), Daily, Campaign, Free Play (tiers, then levels). `LastActivity` remembers which. Navigation is a `NavigationStack` path of `PlayRoute`s.
- **Campaign:** 30 chapters (`CampaignChapter.all`), singles to forcing nets; coloring and exotics stay library-only. The four singles chapters open with two **lesson rounds** for players who have never played (`CampaignStep.lesson`, `CampaignChapter.lessonLevels`): short untimed questions, each a drill position with a spotlight that fades from exact ("Where does the 5 go in this box?" with the 5 armed, or "Which digit fits in this cell?" with the cell selected, plus a one-line intro card) through one area and one digit to the whole board. Their drill round uses area spotlights. Each chapter: a lesson (the technique page), a spotlight per family member (at least 2, solvable with only singles plus that technique), practice ×2, mixed ×2 (needs two earlier techniques), a drill round (5 clean drills: no hint, no mistake, within a time limit by tier), a boss, and endless. Steps open in order; a puzzle counts only if solved without hints, otherwise the player gets another from the same pool. The boss is open from the start and beating it finishes the chapter (the skip). Hints and the use counter in campaign games use the step's allowed techniques only. Campaign games don't count toward statistics.

## Roadmap / known gaps

Open setup work and data gaps (Game Center configuration, thin campaign pools) are tracked in `TODO.md`.

- Technique training: a "how you could have spotted this" replay. (Drills and the long-form guides with a worked example exist: `Technique+Guide.swift`, `DrillBank`, `TechniqueExample`.)
- Draw chain links on the board (`Step.links` exists but isn't rendered).
- iPad and Mac layout polish, an accent color (no asset catalog yet), dark mode check.
- Puzzle import (paste or camera); `GameStore.start(puzzle:)` already exists.
