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
