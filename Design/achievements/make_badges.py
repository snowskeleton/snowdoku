#!/usr/bin/env python3
"""Draws the Game Center badge art and writes the Game Center configuration spec.

The achievements themselves (ids, titles, points, descriptions) live in `Achievements.tsv`, the
list designed with the user. Each gets a 512x512 medallion badge: the part's or tier's color, with a
number, calendar, digit or small board. Also badges for the two leaderboards. SVGs are rasterized
with headless Chrome, like the app icon.

Writes:
  Design/achievements/badges/*.png   the art (512x512, as App Store Connect wants)
  Design/achievements/GameCenter.json  every achievement and leaderboard: id, title, descriptions,
                                       points, image; the identifiers `App/Shared/GameCenter.swift` reports

Run: python3 Design/achievements/make_badges.py   (needs Google Chrome)
"""
import json, os, subprocess, tempfile
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "badges")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FONT = "-apple-system, 'SF Pro Rounded', 'Helvetica Neue', sans-serif"

# One color per part: Singles … Extreme, getting deeper as the campaign goes on.
PART_COLORS = ["#3FA34D", "#2A9D8F", "#2563D4", "#5B4BD6", "#9C3FC4", "#C2367A", "#C8322B"]
GOLD = "#D4A12A"

R = lambda r, c: (r, c)
TIERS = ["Beginner", "Easy", "Medium", "Hard", "Expert", "Master", "Extreme"]
PARTS = ["Singles", "Notes", "Patterns", "Wings & Fish", "Chains", "Master", "Extreme"]


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


def wide(badge, title, subtitle):
    """Challenge and activity art: 3840x2160, opaque, the badge beside a title."""
    inner = badge.split(">", 1)[1].rsplit("</svg>", 1)[0]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="3840" height="2160" viewBox="0 0 3840 2160">'
            f'<rect width="3840" height="2160" fill="#0E1015"/>'
            f'<g transform="translate(360 568) scale(2)">{inner}</g>'
            f'<text x="1640" y="1050" font-family="{FONT}" font-weight="800" font-size="180" fill="#FFFFFF">{escape(title)}</text>'
            f'<text x="1640" y="1230" font-family="{FONT}" font-weight="500" font-size="100" fill="#AEB4C0">{escape(subtitle)}</text>'
            f'</svg>')


def rasterize(svgs, size=512):
    """PNGs with transparency; at another size, opaque JPEGs (Game Center rejects alpha there)."""
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, svg in svgs.items():
            src = os.path.join(tmp, name + ".svg")
            png = os.path.join(OUT if size == 512 else tmp, name + ".png")
            with open(src, "w") as f:
                f.write(svg)
            w, h = (size, size) if size == 512 else size
            subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--default-background-color=00000000",
                            "--force-device-scale-factor=1", f"--window-size={w},{h}", f"--screenshot={png}", "file://" + src],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if size != 512:
                subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "90", png, "--out", os.path.join(OUT, name + ".jpg")],
                               check=True, stdout=subprocess.DEVNULL)


def big_text(text, color, size=150, y=300):
    return (f'<text x="256" y="{y}" text-anchor="middle" font-family="{FONT}" font-weight="800" font-size="{size}" '
            f'fill="{color}">{escape(text)}</text>')


def calendar(color, text):
    return (f'<rect x="146" y="130" width="220" height="210" rx="22" fill="#1F232C" stroke="{color}" stroke-width="10"/>'
            f'<rect x="146" y="130" width="220" height="52" rx="22" fill="{color}"/>'
            f'<rect x="146" y="160" width="220" height="22" fill="{color}"/>'
            f'<rect x="190" y="110" width="16" height="44" rx="8" fill="#FFFFFF"/>'
            f'<rect x="306" y="110" width="16" height="44" rx="8" fill="#FFFFFF"/>'
            + big_text(text, "#FFFFFF", 96 if len(text) <= 2 else 74, 300))


def art(kind, id, n):
    """The badge for one achievement: (image name, svg)."""
    tail = id.split(".")
    if kind == "part":
        color = PART_COLORS[n - 1]
        return f"part-{n}", medallion(color, big_text(str(n), color), PARTS[n - 1])
    if kind == "campaign":
        return "campaign-complete", medallion(GOLD, star(256, 250, 130, GOLD), "Campaign")
    if kind == "daily":
        days = "1" if tail[-1] == "first" else tail[-1].removeprefix("streak")
        return f"daily-{days}", medallion("#2563D4", calendar("#2563D4", days), "Daily" if days == "1" else f"{days} Days")
    if kind == "first":
        tier = tail[-1].capitalize()
        color = PART_COLORS[TIERS.index(tier)]
        return f"first-{tail[-1]}", medallion(color, big_text("1st", color, 120), tier)
    if kind == "everyTier":
        bars = "".join(f'<rect x="{150 + i * 30}" y="{320 - (i + 1) * 26}" width="24" height="{(i + 1) * 26}" rx="5" fill="{PART_COLORS[i]}"/>'
                       for i in range(6))
        return "every-tier", medallion(GOLD, bars, "Every Tier")
    if kind == "count":
        tier, count = tail[-2].capitalize(), tail[-1]
        color = PART_COLORS[TIERS.index(tier)]
        return f"solved-{tail[-2]}-{count}", medallion(color, big_text(count, color, 130 if len(count) <= 2 else 110), tier)
    if kind == "secret":
        return f"secret-{n}", medallion("#6B7280", big_text(str(n), "#E5E7EB", 190, 320), "Secret", locked_ring=True)
    if kind == "drills":
        cells = [R(1, 1), R(1, 7), R(7, 1), R(7, 7)]
        return "drills", medallion("#2A9D8F", board("#2A9D8F", cells, [(R(1, 1), R(1, 7)), (R(7, 1), R(7, 7))]), "Drills")
    raise ValueError(f"unknown kind {kind!r} for {id}")


def main():
    with open(os.path.join(HERE, "Achievements.tsv")) as f:
        rows = [dict(zip(header, line.rstrip("\n").split("\t"))) for header in [f.readline().rstrip("\n").split("\t")] for line in f if line.strip()]
    svgs, achievements = {}, []
    for r in rows:
        last = r["id"].split(".")[-1]
        name, svg = art(r["kind"], r["id"], int(last) if last.isdigit() else 0)
        svgs[name] = svg
        achievements.append({"id": r["id"], "title": r["title"], "beforeEarned": r["before"], "afterEarned": r["after"],
                             "points": int(r["points"]), "hidden": r["hidden"] == "yes", "repeatable": False,
                             "image": f"badges/{name}.png"})

    svgs["leaderboard-streak"] = medallion("#E8590C", (
        '<path d="M256 110 C300 170 352 200 352 270 C352 330 308 360 256 360 C204 360 160 330 160 270 '
        'C160 220 196 196 214 160 C224 196 240 212 256 216 C262 180 256 146 256 110 Z" fill="#E8590C"/>'
        '<path d="M256 236 C282 270 304 286 304 316 C304 342 282 356 256 356 C230 356 208 342 208 316 '
        'C208 292 230 280 256 236 Z" fill="#FFD43B"/>'), "Streak")
    svgs["leaderboard-daily"] = medallion("#2563D4", (
        '<circle cx="256" cy="230" r="100" fill="none" stroke="#2563D4" stroke-width="18"/>'
        '<line x1="256" y1="230" x2="256" y2="160" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round"/>'
        '<line x1="256" y1="230" x2="306" y2="250" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round"/>'), "Daily")

    ids = [a["id"] for a in achievements]
    assert len(ids) == len(set(ids)), "duplicate achievement ids"
    total = sum(a["points"] for a in achievements)
    assert total <= 1000, f"{total} achievement points; Game Center allows 1000"
    assert len(achievements) <= 100, f"{len(achievements)} achievements; Game Center allows 100"

    spec = {
        "note": "Game Center configuration for Snowdoku. Identifiers must match App/Shared/GameCenter.swift. "
                "Generated by Design/achievements/make_badges.py from Achievements.tsv; enter it in Xcode's Game Center "
                "configuration (File > New > File > Game Center Configuration) or App Store Connect.",
        "totalPoints": total,
        "achievements": achievements,
        "leaderboards": [
            {"id": "snowdoku.daily", "title": "Daily Puzzle", "type": "recurring", "recurrence": "daily, starting at 00:00 UTC",
             "sort": "low-to-high", "format": "elapsed time (seconds)", "note": "Only no-hint solves are reported.",
             "image": "badges/leaderboard-daily.png"},
            {"id": "snowdoku.streak", "title": "Longest Daily Streak", "type": "classic", "sort": "high-to-low",
             "format": "integer", "suffix": " days", "suffixSingular": " day", "scoreRange": [1, 100000],
             "note": "The current streak is reported after each daily; Game Center keeps each player's best.",
             "image": "badges/leaderboard-streak.png"},
        ],
        "challenges": [
            {"id": "snowdoku.challenge.daily", "title": "Race Today's Puzzle", "leaderboard": "snowdoku.daily",
             "description": "Who can solve today's daily the fastest, without hints?", "image": "badges/challenge-daily.jpg",
             "note": "iOS/macOS 26: friends race the day's puzzle; needs no code beyond the daily score."},
        ],
        "activities": [
            {"id": "snowdoku.activity.chapter", "title": "Campaign Chapter", "properties": {"chapter": "fullHouse"},
             "description": "Play a chapter of the campaign.", "image": "badges/activity-chapter.jpg",
             "note": "Opens a campaign chapter; set the property to the chapter id."},
            {"id": "snowdoku.activity.daily", "title": "Today's Puzzle", "description": "Solve today's daily puzzle.",
             "image": "badges/activity-daily.jpg", "note": "Starts the day's puzzle."},
        ],
    }
    with open(os.path.join(HERE, "GameCenter.json"), "w") as f:
        json.dump(spec, f, indent=2)
        f.write("\n")
    for old in os.listdir(OUT) if os.path.isdir(OUT) else []:
        if old.endswith((".png", ".jpg")):
            os.remove(os.path.join(OUT, old))
    rasterize(svgs)
    rasterize({
        "challenge-daily": wide(svgs["leaderboard-daily"], "Race Today's Puzzle", "Fastest daily solve, no hints"),
        "activity-daily": wide(svgs["daily-1"], "Today's Puzzle", "Solve the daily puzzle"),
        "activity-chapter": wide(svgs["campaign-complete"], "Campaign Chapter", "Learn a technique, then beat the boss"),
    }, size=(3840, 2160))
    print(f"{len(achievements)} achievements, {total} points, {len(svgs) + 3} images in {OUT}")


if __name__ == "__main__":
    main()
