# TODO

## Game Center setup (needs your Apple account)

The app code is done (`App/Shared/GameCenter.swift`) and reports everything, but nothing shows up in Game Center until it's configured on Apple's side. Everything to enter is in `Design/achievements/GameCenter.json`, with badge art in `Design/achievements/badges/`. Identifiers must match exactly.

- [ ] **Xcode signing:** sign in to your Apple account in Xcode, pick the team for the Snowdoku target, and check that the Game Center capability (`Snowdoku.entitlements`) is accepted for iOS and macOS. Then port the team into `project.yml` (`DEVELOPMENT_TEAM`), or the next `xcodegen generate` wipes it.
- [ ] **App Store Connect → Snowdoku → Game Center:** enable Game Center for the app version. Optionally create a group so iOS and macOS share achievements and leaderboards.
- [ ] **66 achievements, 890 points:** for each, enter the id, title, the before-earned and after-earned text, points, hidden flag and a 512×512 image from `badges/`. That's 29 chapters, 7 parts, the whole campaign and 29 hidden boss skips. Alternatively, create Xcode 26's Game Center configuration file (File → New → Game Center Configuration) and enter them there, then push it to App Store Connect from Xcode.
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

Found with `Engine/Tools/hodoku-compare.sh` (Nov 2026). Each change moves ratings, so it means re-rating the bank (changes dailies), re-checking drills and re-mining parts of the campaign. Decide which to adopt first.

- [ ] **Solve order is separate from score in HoDoKu.** It solves in a hand-curated order and uses base scores only for rating; our `Technique.score` does both, and copied HoDoKu's *score* order. E.g. HoDoKu tries Finned X-Wing after every wing and uniqueness technique (score 130 but late in the order); we try it before plain X-Wing, so it's chosen 3× as often. HoDoKu also tries quads and basic fish (to Jellyfish) before Skyscraper, Kite and the wings.
- [ ] **HoDoKu leaves out Kraken Fish, Mutant fish, Franken Jellyfish and Death Blossom** by default (its solver goes from Franken Swordfish to forcing chains). Our solver picks Kraken Fish ~1,350 times in the Medium+ bank census, yet HoDoKu solves every bank puzzle whose hardest step for us is Kraken without any Extreme-level step: our gaps below (no doubly-linked ALS-XZ, size and length caps) push those puzzles into Kraken.
- [ ] **Uniqueness with missing candidates** (HoDoKu default: on). A rectangle still counts when a corner's digit was already eliminated, since the swapped grid would still be a second solution. Our detectors miss ~470 Hard+ positions' worth of UR1/UR3/UR4 for this. Harder for a player to see.
- [ ] **Doubly-linked ALS-XZ** (two restricted commons: both ALSs become locked sets). Not implemented; ~4,500 Hard+ positions where HoDoKu's ALS-XZ removes something none of our ALS techniques do.
- [ ] **Caps:** chains stop at 15 links (HoDoKu 20) and ALS-XY-Wing, Death Blossom and ALS Chain use ALSs of at most 5 cells. Long chains are poor teaching, so maybe keep, but the caps make the solver fall through to Kraken and forcing chains.
- [ ] **Sue de Coq:** HoDoKu finds extended forms (more cells in the line or box part) we don't; small (~150 positions).
- [ ] **Tier scale:** tiers match HoDoKu's exactly through our Medium. HoDoKu caps Unfair at a total of 1,800, so it calls 82% of our Master and a third of our Expert "Extreme", by score alone (never because a forcing chain was needed). Probably keep ours (Extreme = forcing chains is a v1 decision), but note the disagreement.
- [ ] **Patterns HoDoKu rejects:** HoDoKu never reports a finned or sashimi Jellyfish where we find thousands, and finds far fewer plain Jellyfish; ours likely accept degenerate fish (a smaller fish plus a spare line). Check, and if so require every base line to matter.

## Campaign puzzles

- [ ] **Finned Swordfish endless:** only 50 base puzzles; the target is ≥ 100. Its context and mixed puzzles also use the technique only about twice each. To top it up, mine on the cluster, then merge with the archive (see CLAUDE.md):

  ```bash
  G=Engine/.build/release/sudokugen
  $G campaign --chapter finnedSwordfish --kind endless,context,mixed --minutes 240 --bank App/Resources/Puzzles.tsv > more.jsonl
  xz -dc Engine/Data/campaign-mined.jsonl.xz > old.jsonl
  $G campaign-merge old.jsonl more.jsonl > App/Resources/Campaign.json
  ```

  The archive doesn't include the Full House puzzles (mined on the Mac). Add a quick `$G campaign --chapter fullHouse --minutes 10 --bank App/Resources/Puzzles.tsv > fh.jsonl` to the merge, or that chapter loses its pools. Run `swift test` afterwards to check.
- [ ] Forcing Chains endless is at 101 puzzles; the other chapters have 150.
