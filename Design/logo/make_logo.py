#!/usr/bin/env python3
"""Generates Snowdoku logo concepts as SVG. Run: python3 Design/logo/make_logo.py"""
import os

OUT = os.path.dirname(os.path.abspath(__file__))
S = 1024
FONT = "ui-rounded, 'SF Pro Rounded', system-ui, sans-serif"

# A valid solved sudoku grid, so every digit shown is consistent with a real solution.
def solved(r, c):
    return (r * 3 + r // 3 + c) % 9 + 1

def d4(cells, n):
    """Close a set of (row, col) cells under the 8 symmetries of an n x n square."""
    out = set()
    m = n - 1
    for r, c in cells:
        for a, b in [(r, c), (c, r)]:
            out |= {(a, b), (a, m - b), (m - a, b), (m - a, m - b)}
    return out

def background(defs_id="bg"):
    return f'''<defs>
  <linearGradient id="{defs_id}" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#2F7DE1"/><stop offset="1" stop-color="#0E3A8C"/>
  </linearGradient>
</defs>
<rect width="{S}" height="{S}" fill="url(#{defs_id})"/>'''

def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}" width="{S}" height="{S}">\n{body}\n</svg>\n'

# ---- Concept A: the givens of a 9x9 puzzle form a snowflake ----
def concept_givens():
    n, pad = 9, 96
    cell = (S - 2 * pad) / n
    flake = d4({(0, 4), (1, 4), (2, 4), (3, 4), (4, 4), (0, 0), (1, 1), (2, 2), (3, 3), (1, 3)}, n)
    parts = [background()]
    # faint grid
    for i in range(n + 1):
        w = 6 if i % 3 == 0 else 2
        o = 0.35 if i % 3 == 0 else 0.15
        x = pad + i * cell
        parts.append(f'<line x1="{x}" y1="{pad}" x2="{x}" y2="{S-pad}" stroke="#fff" stroke-opacity="{o}" stroke-width="{w}"/>')
        parts.append(f'<line x1="{pad}" y1="{x}" x2="{S-pad}" y2="{x}" stroke="#fff" stroke-opacity="{o}" stroke-width="{w}"/>')
    g = 5
    for r, c in sorted(flake):
        x, y = pad + c * cell + g, pad + r * cell + g
        parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{cell-2*g:.1f}" height="{cell-2*g:.1f}" rx="10" fill="#fff"/>')
        parts.append(f'<text x="{x + (cell-2*g)/2:.1f}" y="{y + (cell-2*g)/2:.1f}" dy="0.36em" text-anchor="middle" '
                     f'font-family="{FONT}" font-weight="700" font-size="{cell*0.62:.0f}" fill="#1550B8">{solved(r, c)}</text>')
    return svg("\n".join(parts))

# ---- Concept B: bold six-armed snowflake with squared-off (right-angle) branches, 3x3 digits at its heart ----
def concept_bold():
    cx = cy = S / 2
    w = 58            # stroke width
    arm = 430         # center to tip
    parts = [background()]
    flake = []
    for k in range(6):
        t = f'rotate({k*60} {cx} {cy})'
        flake.append(f'<rect x="{cx-w/2}" y="{cy-arm}" width="{w}" height="{arm}" transform="{t}"/>')
        # branch: a crossbar whose ends turn outward at a right angle (a squared-off V)
        for dist, span, rise in [(300, 92, 92)]:
            y = cy - dist
            flake.append(f'<rect x="{cx-span-w/2}" y="{y-w/2}" width="{2*span+w}" height="{w}" transform="{t}"/>')
            for sx in (-1, 1):
                bx = cx + sx * span - w / 2
                flake.append(f'<rect x="{bx}" y="{y-rise-w/2}" width="{w}" height="{rise+w/2}" transform="{t}"/>')
    parts.append('<g fill="#fff">' + "".join(flake) + '</g>')
    b = 300
    parts.append(f'<rect x="{cx-b/2}" y="{cy-b/2}" width="{b}" height="{b}" rx="34" fill="#fff"/>')
    inner = b - 44
    c3 = inner / 3
    ox, oy = cx - inner / 2, cy - inner / 2
    for i in (1, 2):
        parts.append(f'<line x1="{ox+i*c3}" y1="{oy}" x2="{ox+i*c3}" y2="{oy+inner}" stroke="#1550B8" stroke-opacity="0.3" stroke-width="4"/>')
        parts.append(f'<line x1="{ox}" y1="{oy+i*c3}" x2="{ox+inner}" y2="{oy+i*c3}" stroke="#1550B8" stroke-opacity="0.3" stroke-width="4"/>')
    for k, d in enumerate([5, 3, 9, 1, 7, 4, 8, 2, 6]):
        r, c = divmod(k, 3)
        parts.append(f'<text x="{ox+c*c3+c3/2}" y="{oy+r*c3+c3/2}" dy="0.36em" text-anchor="middle" font-family="{FONT}" '
                     f'font-weight="700" font-size="{c3*0.7:.0f}" fill="#1550B8">{d}</text>')
    return svg("\n".join(parts))

# ---- Concept C: a white board where the highlighted cells form the snowflake ----
# Digits come from a solved 9x9 grid, so no row or column repeats a digit even on the smaller boards.
BOARDS = {
    "c-board":  (9, {(0, 4), (1, 4), (2, 4), (3, 4), (4, 4), (0, 0), (1, 1), (2, 2), (3, 3), (1, 3)}),
    "c5-star":  (5, {(0, 2), (1, 2), (2, 2), (0, 0), (1, 1)}),
    "c7-star":  (7, {(0, 3), (1, 3), (2, 3), (3, 3), (0, 0), (1, 1), (2, 2)}),
    "c7-tips":  (7, {(0, 3), (1, 3), (2, 3), (3, 3), (0, 2), (2, 2), (1, 1)}),
}

def concept_board(n, base):
    pad = 112
    cell = (S - 2 * pad) / n
    flake = d4(base, n)
    parts = [background()]
    parts.append(f'<rect x="{pad-14}" y="{pad-14}" width="{S-2*pad+28}" height="{S-2*pad+28}" rx="40" fill="#fff"/>')
    for r, c in sorted(flake):
        x, y = pad + c * cell, pad + r * cell
        parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{cell:.1f}" height="{cell:.1f}" fill="#2563D4"/>')
        parts.append(f'<text x="{x+cell/2:.1f}" y="{y+cell/2:.1f}" dy="0.36em" text-anchor="middle" font-family="{FONT}" '
                     f'font-weight="700" font-size="{cell*0.6:.0f}" fill="#fff">{solved(r, c)}</text>')
    for i in range(1, n):
        if n == 9 and i % 3:
            continue
        w, o = (5, 0.35) if n == 9 else (3, 0.18)
        x = pad + i * cell
        parts.append(f'<line x1="{x:.1f}" y1="{pad}" x2="{x:.1f}" y2="{S-pad}" stroke="#0E3A8C" stroke-opacity="{o}" stroke-width="{w}"/>')
        parts.append(f'<line x1="{pad}" y1="{x:.1f}" x2="{S-pad}" y2="{x:.1f}" stroke="#0E3A8C" stroke-opacity="{o}" stroke-width="{w}"/>')
    return svg("\n".join(parts))

if __name__ == "__main__":
    concepts = {"a-givens": concept_givens(), "b-bold": concept_bold()}
    concepts |= {name: concept_board(n, base) for name, (n, base) in BOARDS.items()}
    for name, text in concepts.items():
        with open(os.path.join(OUT, f"concept-{name}.svg"), "w") as f:
            f.write(text)
    print("ok")
