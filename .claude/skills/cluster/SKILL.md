---
name: cluster
description: Run heavy sudokugen work (campaign mining, drills, bank generation) on the tc-00..tc-03 Linux VMs instead of the Mac. Covers hosts, paths, pushing and building the engine, starting jobs that survive a closed laptop, checking status, collecting results, and cleaning up.
---

# The tc cluster

Four Linux VMs reachable by plain `ssh tc-00` … `ssh tc-03` (user `snow`, keys already set up). Use them for anything slow: `sudokugen campaign`, `drills`, `mutate`, `generate`, `bank`. The user prefers the Mac to stay quiet (fan noise), so heavy work goes here.

**Ask first.** The user says when the VMs are free (e.g. "all night", "all day today"). These machines also run the user's other projects (containers, other repos in `~`), so:
- run jobs under `nice -n 10`;
- touch only `~/new` and `~/snowdoku`;
- never kill processes other than `sudokugen`.

| Host | Cores | RAM | Notes |
|---|---|---|---|
| tc-01 | 16 | 46 GB | The big one: give it the most chapters or the slowest ones. `~/pr1` holds an old PR benchmark; leave it. |
| tc-00 | 4 | 15 GB | |
| tc-02 | 4 | 7 GB | Low memory: avoid running several big processes at once. |
| tc-03 | 4 | 15 GB | |

## Layout on each VM

- `~/new/Engine`: the engine sources, synced from the Mac with rsync (not a git checkout). **Build here.**
  - The binary is `~/new/Engine/.build/release/sudokugen`, a symlink to `.build/out/Products/Release-linux-x86_64/`.
- `~/snowdoku`: the working directory for jobs. It holds `Puzzles.tsv` (a copy of `App/Resources/Puzzles.tsv`, used for `--bank`) and job outputs (`mined*.jsonl`, `mined*.log`).
  - `~/snowdoku/Engine` is an **old** copy of the engine; don't build or run it.
- Swift 6.4 via swiftly. `swift` is **not** on the PATH of a non-interactive ssh shell, so start every remote build with `export PATH=$HOME/.local/share/swiftly/bin:$PATH`.
- tmux, xz and rsync are installed.

## Pushing and building the engine

Always push the current engine before a run: the miner changes often, and a stale binary wastes hours. Run from the repo root on the Mac:

```bash
for h in tc-00 tc-01 tc-02 tc-03; do (
  ssh -n $h 'mkdir -p ~/new/Engine ~/snowdoku' &&
  rsync -az --delete --exclude .build Engine/ "${h}:new/Engine/" &&
  rsync -az App/Resources/Puzzles.tsv "${h}:snowdoku/" &&
  ssh -n $h 'export PATH=$HOME/.local/share/swiftly/bin:$PATH; cd ~/new && nice -n 10 swift build -c release --package-path Engine 2>&1 | grep -E "error:|Build complete" | tail -3'
) > "$SCRATCH/build-$h.log" 2>&1 & done; wait; tail -n 3 "$SCRATCH"/build-*.log
```

**Gotchas:**
- **zsh on the Mac:** write `"${h}:path"`, never `$h:path`. In zsh, `$h:s…` and `$h:l…` are history modifiers, so `$h:snowdoku/x` silently becomes a wrong path.
- **Linux is stricter about Sendable than the Mac build.** A capture of a `var` inside `DispatchQueue.concurrentPerform` fails only on Linux: copy it to a `let` first. Mark structs passed between threads `Sendable` and closures `@Sendable`. Fix the source on the Mac, re-sync, rebuild.
- **Output buffering:** use `fflush(nil)` for progress output, or the logs only show up when the process exits.
- An incremental rebuild takes about 1–3 minutes on the 4-core VMs; a clean build takes longer.

## Starting jobs (they must outlive the Mac)

The Mac may be closed while jobs run, so nothing may depend on it: no local waiters, no ssh sessions kept open. Run each job in a detached tmux session on the VM.

**`sudokugen campaign` prints its JSON only when it exits**, at `--minutes`. If you kill it early, you lose everything since it started. So for open-ended work ("until told to stop"), loop in chunks, each chunk writing its own numbered file:

```bash
B='~/new/Engine/.build/release/sudokugen'
start() {  # start <host> <session> <chapters> [extra args]
  ssh -n $1 "tmux kill-session -t $2 2>/dev/null; cd ~/snowdoku && mkdir -p $2 && tmux new-session -d -s $2 \
    'i=0; while [ ! -e ~/snowdoku/$2/STOP ]; do i=\$((i+1)); nice -n 10 $B campaign --chapter $3 --minutes 90 --iterations 300 --bank Puzzles.tsv $4 > $2/chunk\$i.jsonl 2> $2/chunk\$i.log; done'"
}
start tc-01 today xWing,swordfish,xChain
```

- A chunk of 60–120 minutes is a good trade: you lose at most one chunk on a stop. Climbing restarts each chunk, but `--seeds a.jsonl,b.jsonl` preloads each target's best earlier puzzles as elites, so it continues from the best so far.
- For focus mining (raising use counts), `~/snowdoku/focus.sh <job> <chapters> <kinds> <threads>` (a copy of `focus.sh` next to this skill; rsync it there first) is that loop: it seeds each chunk from `~/snowdoku/archive.jsonl` (the decompressed archive) plus the job's earlier chunks, and its first chunk is a 3-minute smoke test. Start it with `tmux new-session -d -s <job> 'sh ~/snowdoku/focus.sh …'`.
- One process per machine: it already uses every core (`--threads` defaults to all of them). Split chapters across machines by expected difficulty; the rare patterns (X-Chain, Finned Swordfish, Forcing Chains, WXYZ-Wing) are slowest.
- Useful `campaign` options:
  - `--kind spotlight,context,mixed,boss,endless`: limit the kinds mined.
  - `--enough N`: once a kind has N puzzles (3N for endless; default 60), its time goes to the targets still short.
  - `--iterations`: the length of each hill-climb.
  - `--seed`.
- `--chapter` takes the ids from `sudokugen campaign-chapters`.
- To chain a job after a running one: `while pgrep -x sudokugen >/dev/null; do sleep 20; done; …` inside the tmux command.
- For a fixed end time, compute minutes on the VM: `M=$(( (END_EPOCH - $(date +%s)) / 60 ))`.

## Checking status

```bash
for h in tc-00 tc-01 tc-02 tc-03; do echo "== $h: $(ssh -n -o ConnectTimeout=10 $h 'tmux ls 2>/dev/null | cut -d: -f1 | tr "\n" " "; ps -o etime=,pcpu= -C sudokugen | head -1')"; done
ssh -n tc-01 'ls -la ~/snowdoku/today; tail -5 ~/snowdoku/today/chunk*.log'
```

Each finished chunk's log ends with per-target lines (`xChain.boss: 60 found; uses max 3 median 1 min 1`) and a total line (`2503 puzzles from 349497 climbs in 17281s`). An empty log for the current chunk is normal while it's running.

## Stopping and cleaning up

- **Graceful stop** (finish the current chunk, start no more): `ssh -n tc-01 'touch ~/snowdoku/today/STOP'`.
- **Hard stop** (loses the running chunk): `ssh -n $h 'tmux kill-session -t today; pkill -x sudokugen'`.
- When the results are collected and merged, delete the job's folder on the VM (`rm -r ~/snowdoku/today`). Leave `Puzzles.tsv` and `~/new` in place for next time.

## Collecting and merging results

Fetch everything into the scratchpad, then merge on the Mac. The merge is quick; only mining is slow. Always merge against the **full archive**, so the new pools are picked from every puzzle ever mined:

```bash
D=$SCRATCH/mined; G=Engine/.build/release/sudokugen
for h in tc-00 tc-01 tc-02 tc-03; do mkdir -p $D/$h; rsync -az "${h}:snowdoku/today/" "$D/$h/"; done
swift build -c release --package-path Engine
xz -dc Engine/Data/campaign-mined.jsonl.xz > $D/archive.jsonl
$G campaign --chapter fullHouse --minutes 10 --bank App/Resources/Puzzles.tsv > $D/fullhouse.jsonl   # not in the archive
$G campaign-merge $D/archive.jsonl $D/fullhouse.jsonl $D/tc-0*/chunk*.jsonl > App/Resources/Campaign.json 2> $D/merge.log
cat $D/merge.log    # pool sizes and best use count per chapter and kind
```

Then:
1. `swift test -c release --package-path Engine` (`CampaignTests.bundledCampaignStillWorks`).
2. Build iOS and macOS (commands in CLAUDE.md).
3. Run the `CampaignTests` UI tests.
4. Refresh the archive: `cat $D/archive.jsonl $D/tc-0*/chunk*.jsonl | LC_ALL=C sort -u | xz -9e -T0 > Engine/Data/campaign-mined.jsonl.xz`. Leave out the local Full House dump, which is large and quick to re-mine.
5. Commit `Campaign.json` and the archive, then push.

The merge picks each kind's pool by the miner's score: focus, plus variety for mixed and boss. Bosses pick first and endless last, and it prefers a fresh solution grid per puzzle within a chapter. So adding puzzles with higher focus raises the bundled pools' focus.
