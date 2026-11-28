"""Cross-tabulates the bundled bank's tiers against HoDoKu's levels for the same puzzles.

usage: python3 -I hodoku-ratings.py BANK_TIERS HODOKU_VP_OUTPUT HODOKU_LEVELS_TSV

BANK_TIERS is `sudokugen bank-tiers Puzzles.tsv` (puzzle, tier); HODOKU_VP_OUTPUT is
`hodoku.jar /vp /bs givens.txt`; HODOKU_LEVELS_TSV maps each HoDoKu step name to its level. All
three are written by hodoku-compare.sh --ratings.
"""
import collections
import re
import sys

tiers_file, vp_file, levels_file = sys.argv[1:4]
tiers = ["Beginner", "Easy", "Medium", "Hard", "Expert", "Master", "Extreme"]
ours = dict(l.rstrip("\n").split("\t") for l in open(tiers_file) if l.strip())

step_level = {}
for l in open(levels_file):
    level, name = l.rstrip("\n").split("\t", 1)
    step_level[name] = level
levels = ["Easy", "Medium", "Hard", "Unfair", "Extreme"]
rank = {l: i for i, l in enumerate(levels)}

hd, cur = {}, None
for line in open(vp_file):
    m = re.match(r"^(\S{81}) #\d+ (\w+) \((\d+)\)", line)
    if m:
        cur = m.group(1)
        hd[cur] = {"level": m.group(2), "score": int(m.group(3)), "hardest": 0}
    elif cur and line.startswith("   ") and ":" in line:
        name = line.split(":")[0].strip()
        base = next((k for k in step_level if name == k or name.startswith(k)), None)
        if base:
            hd[cur]["hardest"] = max(hd[cur]["hardest"], rank[step_level[base]])

tab = collections.defaultdict(collections.Counter)
by_cause = collections.defaultdict(collections.Counter)
for p, tier in ours.items():
    if p not in hd:
        continue
    h = hd[p]
    tab[tier][h["level"]] += 1
    if rank[h["level"]] > h["hardest"]:
        by_cause[tier]["by score"] += 1

print("Our tier (rows) against HoDoKu's level (columns), %d puzzles" % sum(sum(c.values()) for c in tab.values()))
print("".ljust(10) + "".join(l.rjust(9) for l in levels) + "   rated up by score alone")
for t in tiers:
    print(t.ljust(10) + "".join(str(tab[t][l]).rjust(9) for l in levels) + str(by_cause[t]["by score"]).rjust(10))
