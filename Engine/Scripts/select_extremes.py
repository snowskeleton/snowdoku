"""Pick new Extreme bank lines.

usage: select_extremes.py BANK.tsv NEED rated1.tsv [rated2.tsv ...]  > new-lines.tsv
Candidates are rated bank lines; Extreme ones are those whose level (last field) is extreme.
Rejects exact duplicates and GridTransforms (band/row/stack/column shuffles, transpose,
digit relabel) of any bank puzzle or already-picked candidate. Picks greedily for variety:
fewest picks sharing a solution grid, then largest Hamming distance to the picks so far.
"""
import sys, itertools, random

# Technique raw values with score >= 500 except bruteForce (`sudokugen techniques`).
EXTREME = "extreme"  # the level, the bank line's last field

def rows_of(p): return [p[r*9:r*9+9] for r in range(9)]
def transpose(p): return "".join(p[c*9+r] for r in range(9) for c in range(9))

def line_orders():
    out = []
    for bands in itertools.permutations(range(3)):
        for a in itertools.permutations(range(3)):
            for b in itertools.permutations(range(3)):
                for c in itertools.permutations(range(3)):
                    within = (a, b, c)
                    out.append([bands[i]*3 + within[i][j] for i in range(3) for j in range(3)])
    return out
ORDERS = line_orders()

def counts(p):
    rc = [sum(ch != '.' for ch in p[r*9:r*9+9]) for r in range(9)]
    cc = [sum(p[r*9+c] != '.' for r in range(9)) for c in range(9)]
    return rc, cc

def sig(lst):
    return tuple(sorted(tuple(sorted(lst[b*3:b*3+3])) for b in range(3)))

def fingerprint(p):
    rc, cc = counts(p)
    a, b = sig(rc), sig(cc)
    digits = tuple(sorted(p.count(str(d)) for d in range(1, 10)))
    return (min(a, b), max(a, b), digits)

def is_transform(a, b):
    """Is b some GridTransform of a?"""
    for src in (a, transpose(a)):
        rca, cca = counts(src)
        rcb, ccb = counts(b)
        rows = [o for o in ORDERS if [rca[i] for i in o] == rcb]
        cols = [o for o in ORDERS if [cca[i] for i in o] == ccb]
        for ro in rows:
            for co in cols:
                m, ok = {}, True
                for r in range(9):
                    for c in range(9):
                        x, y = src[ro[r]*9 + co[c]], b[r*9 + c]
                        if (x == '.') != (y == '.'): ok = False; break
                        if x != '.':
                            if m.setdefault(x, y) != y: ok = False; break
                    if not ok: break
                if ok and len(set(m.values())) == len(m): return True
    return False

def solve(p):
    g = [int(c) if c != '.' else 0 for c in p]
    def cands(i):
        r, c = divmod(i, 9); used = set()
        for k in range(9): used.add(g[r*9+k]); used.add(g[k*9+c])
        br, bc = r//3*3, c//3*3
        for dr in range(3):
            for dc in range(3): used.add(g[(br+dr)*9+bc+dc])
        return [d for d in range(1, 10) if d not in used]
    def go():
        best, bc = None, None
        for i in range(81):
            if g[i] == 0:
                cs = cands(i)
                if best is None or len(cs) < len(bc):
                    best, bc = i, cs
                    if len(cs) <= 1: break
        if best is None: return True
        for d in bc:
            g[best] = d
            if go(): return True
        g[best] = 0
        return False
    go()
    return "".join(map(str, g))

def main():
    bank_path, need, files = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
    bank_lines = [l.split('\t') for l in open(bank_path).read().split('\n') if l]
    bank = [l[0] for l in bank_lines]
    bank_extreme = [l[0] for l in bank_lines if l[-1] == EXTREME]
    seen = {}
    for p in bank: seen.setdefault(fingerprint(p), []).append(p)
    cands, exact = [], set(bank)
    for f in files:
        for l in open(f).read().split('\n'):
            if not l: continue
            parts = l.split('\t')
            if parts[-1] == EXTREME and parts[0] not in exact:
                exact.add(parts[0]); cands.append(l)
    print(f"{len(cands)} new Extreme candidates", file=sys.stderr)
    random.seed(7); random.shuffle(cands)
    sols = {l: solve(l.split('\t')[0]) for l in cands}
    grid_uses = {}
    for p in bank_extreme:
        s = solve(p); grid_uses[s] = grid_uses.get(s, 0) + 1
    picked, pickedp, rejected, by_grid = [], [], 0, {}
    for p in bank_extreme: by_grid.setdefault(solve(p), []).append(p)
    pool = list(cands)
    while len(picked) < need and pool:
        def score(l):
            p = l.split('\t')[0]
            d = min((sum(x != y for x, y in zip(p, q)) for q in by_grid.get(sols[l], [])), default=81)
            return (-grid_uses.get(sols[l], 0), d)
        pool.sort(key=score)
        l = pool.pop()
        p = l.split('\t')[0]
        fp = fingerprint(p)
        if any(is_transform(q, p) for q in seen.get(fp, [])):
            rejected += 1; continue
        seen.setdefault(fp, []).append(p)
        picked.append(l); pickedp.append(p)
        grid_uses[sols[l]] = grid_uses.get(sols[l], 0) + 1
        by_grid.setdefault(sols[l], []).append(p)
    print(f"picked {len(picked)}, rejected {rejected} as transforms, "
          f"{len(set(sols[l] for l in picked))} distinct solution grids", file=sys.stderr)
    for l in picked: print(l)

main()
