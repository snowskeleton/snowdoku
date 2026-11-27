#!/usr/bin/env python3
"""Draws the Game Center badge art and writes the Game Center configuration spec.

For every campaign chapter (from `sudokugen campaign-chapters`) a 512x512 badge: a medallion in its
part's color with a small board showing the technique's shape (the cells an X-Wing's rectangle or a
chain's path would use). Also badges for each part, the whole campaign, the hidden boss-skip
achievements, and the two leaderboards. SVGs are rasterized with headless Chrome, like the app icon.

Writes:
  Design/achievements/badges/*.png   the art (512x512, as App Store Connect wants)
  Design/achievements/GameCenter.json  every achievement and leaderboard: id, title, descriptions,
                                       points, image; the identifiers `App/Shared/GameCenter.swift` reports

Run: python3 Design/achievements/make_badges.py   (needs Engine/.build/release/sudokugen)
"""
import json, os, subprocess, sys, tempfile
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
OUT = os.path.join(HERE, "badges")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SUDOKUGEN = os.path.join(ROOT, "Engine", ".build", "release", "sudokugen")
FONT = "-apple-system, 'SF Pro Rounded', 'Helvetica Neue', sans-serif"

# One color per part: Singles … Extreme, getting deeper as the campaign goes on.
PART_COLORS = ["#3FA34D", "#2A9D8F", "#2563D4", "#5B4BD6", "#9C3FC4", "#C2367A", "#C8322B"]
GOLD = "#D4A12A"

# Each chapter's motif: cells (row, col, 0-8) to highlight on a 9x9 board, and optional links
# (pairs of cells) drawn as lines. Rough shapes, meant to be recognizable rather than exact.
R = lambda r, c: (r, c)
MOTIFS = {
    "fullHouse": ([R(4, c) for c in range(9)], []),
    "hiddenSingleBox": ([R(r, c) for r in range(3, 6) for c in range(3, 6)], []),
    "nakedSingle": ([R(4, 4)], [(R(4, 4), R(4, 0)), (R(4, 4), R(4, 8)), (R(4, 4), R(0, 4)), (R(4, 4), R(8, 4))]),
    "hiddenSingleLine": ([R(2, c) for c in range(9)], []),
    "pointing": ([R(3, 3), R(3, 4), R(3, 6), R(3, 8)], []),
    "claiming": ([R(5, 0), R(5, 1), R(5, 2)], []),
    "nakedPair": ([R(1, 2), R(1, 6)], [(R(1, 2), R(1, 6))]),
    "hiddenPair": ([R(6, 1), R(6, 4)], [(R(6, 1), R(6, 4))]),
    "triples": ([R(4, 1), R(4, 4), R(4, 7)], [(R(4, 1), R(4, 4)), (R(4, 4), R(4, 7))]),
    "xWing": ([R(1, 1), R(1, 7), R(7, 1), R(7, 7)], [(R(1, 1), R(1, 7)), (R(7, 1), R(7, 7))]),
    "skyscraper": ([R(1, 2), R(7, 2), R(2, 6), R(7, 6)], [(R(1, 2), R(7, 2)), (R(2, 6), R(7, 6))]),
    "twoStringKite": ([R(1, 1), R(1, 7), R(2, 2), R(7, 2)], [(R(1, 1), R(1, 7)), (R(2, 2), R(7, 2))]),
    "turbotFish": ([R(0, 1), R(0, 6), R(4, 6), R(4, 3)], [(R(0, 1), R(0, 6)), (R(0, 6), R(4, 6)), (R(4, 6), R(4, 3))]),
    "finnedXWing": ([R(1, 1), R(1, 7), R(7, 1), R(7, 7), R(8, 8)], [(R(1, 1), R(1, 7)), (R(7, 1), R(7, 7))]),
    "remotePair": ([R(1, 1), R(1, 5), R(4, 5), R(4, 8)], [(R(1, 1), R(1, 5)), (R(1, 5), R(4, 5)), (R(4, 5), R(4, 8))]),
    "uniqueness": ([R(2, 1), R(2, 4), R(6, 1), R(6, 4)], [(R(2, 1), R(2, 4)), (R(2, 4), R(6, 4)), (R(6, 4), R(6, 1)), (R(6, 1), R(2, 1))]),
    "xyWing": ([R(2, 2), R(2, 6), R(6, 2)], [(R(2, 2), R(2, 6)), (R(2, 2), R(6, 2))]),
    "xyzWing": ([R(2, 2), R(2, 6), R(1, 1)], [(R(2, 2), R(2, 6)), (R(2, 2), R(1, 1))]),
    "wWing": ([R(1, 1), R(7, 6), R(1, 6)], [(R(1, 1), R(1, 6)), (R(1, 6), R(7, 6))]),
    "emptyRectangle": ([R(3, 4), R(4, 3), R(4, 4), R(4, 5), R(5, 4), R(4, 8), R(0, 4)], [(R(4, 5), R(4, 8))]),
    "swordfish": ([R(1, 1), R(1, 4), R(4, 4), R(4, 7), R(7, 1), R(7, 7)], [(R(1, 1), R(1, 4)), (R(4, 4), R(4, 7)), (R(7, 1), R(7, 7))]),
    "xChain": ([R(0, 1), R(0, 5), R(3, 5), R(3, 8), R(7, 8)], [(R(0, 1), R(0, 5)), (R(0, 5), R(3, 5)), (R(3, 5), R(3, 8)), (R(3, 8), R(7, 8))]),
    "xyChain": ([R(1, 0), R(1, 4), R(5, 4), R(5, 7), R(8, 7)], [(R(1, 0), R(1, 4)), (R(1, 4), R(5, 4)), (R(5, 4), R(5, 7)), (R(5, 7), R(8, 7))]),
    "wxyzWing": ([R(3, 3), R(3, 7), R(5, 4), R(1, 4)], [(R(3, 3), R(3, 7)), (R(3, 3), R(5, 4)), (R(3, 3), R(1, 4))]),
    "finnedSwordfish": ([R(1, 1), R(1, 4), R(4, 4), R(4, 7), R(7, 1), R(7, 7), R(8, 8)], [(R(1, 1), R(1, 4)), (R(4, 4), R(4, 7)), (R(7, 1), R(7, 7))]),
    "aic": ([R(1, 1), R(1, 6), R(4, 6), R(4, 2), R(7, 2), R(7, 7)], [(R(1, 1), R(1, 6)), (R(1, 6), R(4, 6)), (R(4, 6), R(4, 2)), (R(4, 2), R(7, 2)), (R(7, 2), R(7, 7))]),
    "als": ([R(3, 0), R(3, 1), R(3, 2), R(6, 5), R(7, 5)], [(R(3, 2), R(6, 5))]),
    "forcingChain": ([R(4, 4), R(1, 4), R(4, 1), R(7, 7)], [(R(4, 4), R(1, 4)), (R(4, 4), R(4, 1)), (R(1, 4), R(7, 7)), (R(4, 1), R(7, 7))]),
    "forcingNet": ([R(4, 4), R(1, 1), R(1, 7), R(7, 1), R(7, 7), R(4, 8)], [(R(4, 4), R(1, 1)), (R(4, 4), R(1, 7)), (R(4, 4), R(7, 1)), (R(4, 4), R(7, 7)), (R(1, 7), R(4, 8)), (R(7, 7), R(4, 8))]),
}


def medallion(color, inner, label=None, locked_ring=False):
    """A round medallion: colored rim, darker face, the inner art, and an optional label."""
    ring = f'<circle cx="256" cy="256" r="240" fill="{color}"/>'
    face = f'<circle cx="256" cy="256" r="206" fill="#14161C"/>'
    shine = '<path d="M60 220 A200 200 0 0 1 452 220" stroke="#FFFFFF" stroke-opacity="0.18" stroke-width="10" fill="none"/>'
    text = ""
    if label:
        size = 40 if len(label) <= 12 else 32 if len(label) <= 16 else 26
        text = (f'<text x="256" y="420" text-anchor="middle" font-family="{FONT}" font-weight="700" '
                f'font-size="{size}" fill="#FFFFFF">{escape(label)}</text>')
    dash = ' stroke-dasharray="18 12"' if locked_ring else ""
    rim = f'<circle cx="256" cy="256" r="222" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="4"{dash}/>'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">'
            f'{ring}{face}{rim}{shine}{inner}{text}</svg>')


def board(color, cells, links, top=120, size=216):
    """A 9x9 board with highlighted cells and link lines."""
    x0 = 256 - size / 2
    c = size / 9
    parts = [f'<rect x="{x0}" y="{top}" width="{size}" height="{size}" rx="10" fill="#1F232C"/>']
    for r, col in cells:
        parts.append(f'<rect x="{x0 + col * c + 2}" y="{top + r * c + 2}" width="{c - 4}" height="{c - 4}" rx="4" fill="{color}"/>')
    for i in range(1, 9):
        w = 3 if i % 3 == 0 else 1
        op = 0.55 if i % 3 == 0 else 0.22
        parts.append(f'<line x1="{x0 + i * c}" y1="{top}" x2="{x0 + i * c}" y2="{top + size}" stroke="#FFFFFF" stroke-opacity="{op}" stroke-width="{w}"/>')
        parts.append(f'<line x1="{x0}" y1="{top + i * c}" x2="{x0 + size}" y2="{top + i * c}" stroke="#FFFFFF" stroke-opacity="{op}" stroke-width="{w}"/>')
    parts.append(f'<rect x="{x0}" y="{top}" width="{size}" height="{size}" rx="10" fill="none" stroke="#FFFFFF" stroke-opacity="0.7" stroke-width="3"/>')
    for (r1, c1), (r2, c2) in links:
        parts.append(f'<line x1="{x0 + (c1 + 0.5) * c}" y1="{top + (r1 + 0.5) * c}" x2="{x0 + (c2 + 0.5) * c}" '
                     f'y2="{top + (r2 + 0.5) * c}" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/>')
    return "".join(parts)


def star(cx, cy, r, fill):
    import math
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append(f"{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}")
    return f'<polygon points="{" ".join(pts)}" fill="{fill}"/>'


def crown(fill):
    return (f'<path d="M150 300 L170 170 L215 230 L256 150 L297 230 L342 170 L362 300 Z" fill="{fill}"/>'
            f'<rect x="150" y="305" width="212" height="28" rx="8" fill="{fill}"/>')


def rasterize(svgs):
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, svg in svgs.items():
            src = os.path.join(tmp, name + ".svg")
            with open(src, "w") as f:
                f.write(svg)
            subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--default-background-color=00000000",
                            "--window-size=512,512", f"--screenshot={os.path.join(OUT, name + '.png')}", "file://" + src],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    chapters = json.loads(subprocess.check_output([SUDOKUGEN, "campaign-chapters"], text=True))
    parts = sorted({(c["part"], c["partName"]) for c in chapters})
    svgs, achievements = {}, []

    def achievement(id, title, before, after, points, image, hidden=False):
        achievements.append({"id": id, "title": title, "beforeEarned": before, "afterEarned": after,
                             "points": points, "hidden": hidden, "repeatable": False, "image": f"badges/{image}.png"})

    for i, ch in enumerate(chapters):
        color = PART_COLORS[ch["part"] - 1]
        cells, links = MOTIFS[ch["id"]]
        name = f"chapter-{i + 1:02d}-{ch['id']}"
        svgs[name] = medallion(color, board(color, cells, links), ch["title"])
        achievement(f"snowdoku.chapter.{ch['id']}", ch["title"], f"Finish chapter {i + 1} of the campaign: {ch['title']}.",
                    f"Finished chapter {i + 1}: {ch['title']}.", 15, name)

    for n, pname in parts:
        color = PART_COLORS[n - 1]
        inner = (f'<text x="256" y="300" text-anchor="middle" font-family="{FONT}" font-weight="800" font-size="150" '
                 f'fill="{color}">{n}</text>')
        name = f"part-{n}"
        svgs[name] = medallion(color, inner, pname)
        achievement(f"snowdoku.part.{n}", f"Part {n}: {pname}", f"Finish every chapter in part {n}, {pname}.",
                    f"Finished part {n}, {pname}.", 30, name)

    svgs["campaign-complete"] = medallion(GOLD, star(256, 250, 130, GOLD), "Campaign")
    achievement("snowdoku.campaign.complete", "Grandmaster", "Finish the whole campaign, from Full House to Forcing Nets.",
                "Finished the whole campaign, from Full House to Forcing Nets.", 100, "campaign-complete")

    for i, ch in enumerate(chapters):
        color = PART_COLORS[ch["part"] - 1]
        name = f"skip-{i + 1:02d}-{ch['id']}"
        svgs[name] = medallion(color, crown(color), ch["title"], locked_ring=True)
        achievement(f"snowdoku.boss.{ch['id']}.skip", f"Straight to the Boss: {ch['title']}",
                    "A hidden achievement.", f"Beat the {ch['title']} boss without hints before playing any other level of the chapter.",
                    5, name, hidden=True)

    svgs["leaderboard-chapters"] = medallion(GOLD, board(GOLD, [R(r, c) for r in range(9) for c in range(9) if (r + c) % 4 == 0], []), "Chapters")
    svgs["leaderboard-daily"] = medallion("#2563D4", (
        '<circle cx="256" cy="230" r="100" fill="none" stroke="#2563D4" stroke-width="18"/>'
        '<line x1="256" y1="230" x2="256" y2="160" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round"/>'
        '<line x1="256" y1="230" x2="306" y2="250" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round"/>'), "Daily")

    total = sum(a["points"] for a in achievements)
    assert total <= 1000, f"{total} achievement points; Game Center allows 1000"
    assert len(achievements) <= 100, f"{len(achievements)} achievements; Game Center allows 100"

    spec = {
        "note": "Game Center configuration for Snowdoku. Identifiers must match App/Shared/GameCenter.swift. "
                "Generated by Design/achievements/make_badges.py; enter it in Xcode's GameKit configuration "
                "(File > New > File > GameKit Bundle) or App Store Connect.",
        "totalPoints": total,
        "achievements": achievements,
        "leaderboards": [
            {"id": "snowdoku.chapters", "title": "Chapters Completed", "type": "classic", "sort": "high-to-low",
             "format": "integer", "suffix": " chapters", "suffixSingular": " chapter", "scoreRange": [0, len(chapters)],
             "image": "badges/leaderboard-chapters.png"},
            {"id": "snowdoku.daily", "title": "Daily Puzzle", "type": "recurring", "recurrence": "daily, starting at 00:00 UTC",
             "sort": "low-to-high", "format": "elapsed time (seconds)", "note": "Only no-hint solves are reported.",
             "image": "badges/leaderboard-daily.png"},
        ],
        "challenges": [
            {"id": "snowdoku.challenge.daily", "title": "Race Today's Puzzle", "leaderboard": "snowdoku.daily",
             "note": "iOS/macOS 26: friends race the day's puzzle; needs no code beyond the daily score."},
        ],
        "activities": [
            {"id": "snowdoku.activity.chapter", "title": "Campaign Chapter", "properties": {"chapter": "fullHouse"},
             "note": "Opens a campaign chapter; set the property to the chapter id."},
            {"id": "snowdoku.activity.daily", "title": "Today's Puzzle", "note": "Starts the day's puzzle."},
        ],
    }
    with open(os.path.join(HERE, "GameCenter.json"), "w") as f:
        json.dump(spec, f, indent=2)
        f.write("\n")
    rasterize(svgs)
    print(f"{len(achievements)} achievements, {total} points, {len(svgs)} images in {OUT}")


if __name__ == "__main__":
    main()
