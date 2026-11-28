# TODO

## Game Center setup (needs your Apple account)

The app code is done (`App/Shared/GameCenter.swift`) and reports everything, but nothing shows up in Game Center until it's configured on Apple's side. Everything to enter is in `Design/achievements/GameCenter.json`, with badge art in `Design/achievements/badges/`. Identifiers must match exactly.

- [ ] **Xcode signing:** the team (`PK7HCG46US`) is in `project.yml`; check in Xcode that the Game Center capability (`Snowdoku.entitlements`) is accepted for iOS and macOS.
- [ ] **App Store Connect → Snowdoku → Game Center:** enable Game Center for the app version. Optionally create a group so iOS and macOS share achievements and leaderboards.
- [ ] **60 achievements, 728 points:** for each, enter the id, title, the before-earned and after-earned text, points, hidden flag and a 512×512 image from `badges/`. That's 7 parts, the whole campaign, 4 dailies, 7 first solves, every tier, 30 solve counts, 9 hidden digit runs and the drills one. Alternatively, create Xcode 26's Game Center configuration file (File → New → Game Center Configuration) and enter them there, then push it to App Store Connect from Xcode.
- [ ] **2 leaderboards:**
  - `snowdoku.chapters`: classic, high to low, integer score 0–29, suffix " chapters".
  - `snowdoku.daily`: recurring daily, starting 00:00 UTC, low to high, elapsed time in seconds.
- [ ] **iOS/macOS 26 challenge:** `snowdoku.challenge.daily` on the daily leaderboard.
- [ ] **iOS/macOS 26 activities:**
  - `snowdoku.activity.chapter`, with a `chapter` property set to a chapter id (e.g. `fullHouse`).
  - `snowdoku.activity.daily`.
- [ ] **Sandbox test:** sign in with a sandbox Game Center account on a device or simulator, run a **Release** build, and check that sign-in, achievements and the leaderboards work. Debug builds stay quiet and skip Game Center under the DEBUG launch arguments.
- [ ] **Signed Mac build:** after the team is set, build macOS without `CODE_SIGN_ENTITLEMENTS=` (ad-hoc signing can't carry the Game Center entitlement).

## Ratings and detectors: what HoDoKu disagrees with

Found with `Engine/Tools/hodoku-compare.sh` (Nov 2026). Each change moves ratings, so it means re-rating the bank (changes dailies), re-checking drills and re-mining parts of the campaign: make the engine changes first, then re-rate and re-mine once.

Decided so far (Nov 27, 2026):
- **Avoid techniques of last resort in our puzzles** (Sudopedia's list: Forcing Net, Tabling, GEM, Bowman Bingo, Trial & Error, Nishio, Templating, Guessing). Today every Extreme puzzle needs a forcing chain or net (tabling) by definition, and 32 Master puzzles need Kraken Fish (a fish plus tabling).
- **Separate solving order from difficulty**, as HoDoKu does: a move can be worth looking for early, but a puzzle that can be solved without a technique is easier than one that needs it.
- **Keep the Extreme tier** (forcing chains and nets), but nothing else should expect those techniques to be used (campaign, drills, hints for lower tiers). When the solver improves and an Extreme puzzle no longer needs a forcing step, it moves down a tier: re-rating hands those puzzles to the lower tiers.
- **Keep the score bump as is:** a long solve with easy techniques stays easier (don't adopt HoDoKu's lower caps).
- **Close HoDoKu's detector gaps** (doubly-linked ALS-XZ, extended Sue de Coq, larger ALSs) and **lengthen chains**.
- **Missing-candidate URs:** try them as a separate, harder technique and test how they play.
- **Find out why** HoDoKu never reports our finned/sashimi Jellyfish.

- [ ] **Solve order is separate from score in HoDoKu.** It solves in a hand-curated order and uses base scores only for rating; our `Technique.score` does both, and copied HoDoKu's *score* order. E.g. HoDoKu tries Finned X-Wing after every wing and uniqueness technique (score 130 but late in the order); we try it before plain X-Wing, so it's chosen 3× as often. HoDoKu also tries quads and basic fish (to Jellyfish) before Skyscraper, Kite and the wings.
- [ ] **HoDoKu leaves out Kraken Fish, Mutant fish, Franken Jellyfish and Death Blossom** by default (its solver goes from Franken Swordfish to forcing chains). Our solver picks Kraken Fish ~1,350 times in the Medium+ bank census, yet HoDoKu solves every bank puzzle whose hardest step for us is Kraken without any Extreme-level step: our gaps below (no doubly-linked ALS-XZ, size and length caps) push those puzzles into Kraken.
- [ ] **Uniqueness with missing candidates** (HoDoKu default: on). A rectangle still counts when a corner's digit was already eliminated, since the swapped grid would still be a second solution. Our detectors miss ~470 Hard+ positions' worth of UR1/UR3/UR4 for this. Harder for a player to see.
- [ ] **Doubly-linked ALS-XZ** (two restricted commons: both ALSs become locked sets). Not implemented; ~4,500 Hard+ positions where HoDoKu's ALS-XZ removes something none of our ALS techniques do.
- [ ] **Caps:** chains stop at 15 links (HoDoKu 20) and ALS-XY-Wing, Death Blossom and ALS Chain use ALSs of at most 5 cells. Long chains are poor teaching, so maybe keep, but the caps make the solver fall through to Kraken and forcing chains.
- [ ] **Sue de Coq:** HoDoKu finds extended forms (more cells in the line or box part) we don't; small (~150 positions).
- [ ] **Tier scale:** tiers match HoDoKu's exactly through our Medium. HoDoKu caps Unfair at a total of 1,800, so it calls 82% of our Master and a third of our Expert "Extreme", by score alone (never because a forcing chain was needed). Probably keep ours (Extreme = forcing chains is a v1 decision), but note the disagreement.
- [ ] **Patterns HoDoKu rejects:** HoDoKu never reports a finned or sashimi Jellyfish where we find thousands, and finds far fewer plain Jellyfish; ours likely accept degenerate fish (a smaller fish plus a spare line). Check, and if so require every base line to matter.

## Difficulty levels (decided Nov 28, 2026; not built yet)

Easy to Medium added 19 techniques at once. Instead, each headline tier gets numbered levels, and each level adds **at most 3 techniques** to everything below it. Pure variants count as one: Finned = Sashimi, Locked = Naked, UR Type 5 = UR Type 2. Levels follow the order a player should learn techniques in. A puzzle's level is **the smallest technique set that solves it**, which goes with separating solve order from score (above). Build both together and re-rate everything once.

| Level | New techniques |
|---|---|
| Beginner 1 | Full House, Hidden Single (Box) |
| Beginner 2 | Naked Single, Hidden Single (Line) |
| Easy 1 | Pointing, Claiming |
| Easy 2 | Naked/Locked Pair, Hidden Pair |
| Easy 3 | Naked/Locked Triple, Hidden Triple |
| Medium 1 | X-Wing, Finned/Sashimi X-Wing |
| Medium 2 | Skyscraper, 2-String Kite, Turbot Fish |
| Medium 3 | UR Type 1, UR Type 2 (+5), BUG+1 |
| Medium 4 | UR Type 4, Naked Quad, Hidden Quad |
| Hard 1 | XY-Wing, XYZ-Wing, Remote Pair |
| Hard 2 | W-Wing, Empty Rectangle |
| Hard 3 | Swordfish, Jellyfish |
| Hard 4 | UR Type 3, UR Type 6, UR with a missing candidate |
| Expert 1 | Hidden Rectangle, Avoidable Rectangle 1 and 2 |
| Expert 2 | Simple Coloring Trap, Color Wrap, Multi-Coloring |
| Expert 3 | X-Chain, XY-Chain, WXYZ-Wing |
| Expert 4 | Finned/Sashimi Swordfish, Finned/Sashimi Jellyfish, Continuous Nice Loop |
| Master 1 | Discontinuous Nice Loop, AIC, Grouped AIC |
| Master 2 | ALS-XZ, ALS-XY-Wing, Sue de Coq |
| Master 3 | ALS Chain, Franken Fish, Death Blossom |
| Extreme | Mutant Fish, Kraken Fish, forcing chains and nets, trial and error (no levels) |

Also decided:
- **Free Play:** pick the headline tier first, then the level within it.
- **Achievements and dailies stay per headline tier.** A daily of a tier draws from that tier's highest level (a Medium daily is Medium 4). The 500-puzzle minimum is per headline tier; each level needs enough to play (~200), which means targeted mining for thin ones (Medium 4's quads, Expert 2's coloring, Expert 4, Master 3).
- Long chains (PR #8 makes very long chains Master) mean a level's chain techniques come with a length limit.
- Measure after re-rating; a level with too few puzzles that truly need its techniques may merge with a neighbor.

## Campaign puzzles

- [ ] **Campaign vs. the new levels: investigate the options, not decided.** The campaign skips techniques some levels need (UR Types 3 and 6, Avoidable Rectangles, quads, coloring, Sue de Coq, Franken Fish, Death Blossom), and Remote Pair moves from Medium to Hard. Options: add chapters, accept library-only techniques, or line campaign parts up with levels ("finish these chapters and you're ready for Medium 2").
- [ ] **Finned Swordfish endless:** only 50 base puzzles; the target is ≥ 100. Its context and mixed puzzles also use the technique only about twice each. To top it up, mine on the cluster, then merge with the archive (see CLAUDE.md):

  ```bash
  G=Engine/.build/release/sudokugen
  $G campaign --chapter finnedSwordfish --kind endless,context,mixed --minutes 240 --bank App/Resources/Puzzles.tsv > more.jsonl
  xz -dc Engine/Data/campaign-mined.jsonl.xz > old.jsonl
  $G campaign-merge old.jsonl more.jsonl > App/Resources/Campaign.json
  ```

  The archive doesn't include the Full House puzzles (mined on the Mac). Add a quick `$G campaign --chapter fullHouse --minutes 10 --bank App/Resources/Puzzles.tsv > fh.jsonl` to the merge, or that chapter loses its pools. Run `swift test` afterwards to check.
- [ ] Forcing Chains endless is at 101 puzzles; the other chapters have 150.
