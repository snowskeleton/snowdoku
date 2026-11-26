#!/usr/bin/env python3
"""Builds Icon Composer (.icon) options for the board-snowflake logo.

Each option is split into transparent 1024x1024 layers (board, grid, tiles, digits) so Icon Composer can
give each its own Liquid Glass treatment. Layers are drawn as SVG, rasterized with headless Chrome
(Icon Composer's SVG renderer doesn't draw <text>), packaged with the compose-app-icon skill's
create_icon.py, and previewed with Xcode's ictool.

Run: python3 Design/logo/make_icons.py
"""
import json, os, shutil, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_logo import S, FONT, BOARDS, d4

# Digits come from the solution of a puzzle made by `sudokugen generate --difficulty medium`, shuffled within
# bands (which keeps it a valid sudoku) and chosen so the 7x7 snowflake has no runs, repeated diagonals or
# mirrored pairs. The 7x7 window starts at row 1, column 1, so its centre 3x3 is a real sudoku box.
SOURCE_PUZZLE = "16...3.9.2...1.....58....47....8...1...2.9.........9.5.9.....24.1..478.....6....."
# The same puzzle after that shuffle (still Medium, unique solution); its clues are the icon's givens.
PUZZLE = "16...39..2...1.....58...47....2.9..........59....8..1....6......1..47..8.9....24."
SOLUTION = "164873925279514863358926471531269784827431659946785312485692137612347598793158246"

def solved(r, c):
    return int(SOLUTION[(r + 1) * 9 + c + 1])

def is_given(r, c):
    return PUZZLE[(r + 1) * 9 + c + 1] != "."

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
ICONS = os.path.join(HERE, "icons")
# The option that ships: it lives in the app's synced folder, where Xcode builds it as the app icon.
CHOSEN = "3-glass-tiles"
APP_ICON = os.path.join(HERE, "..", "..", "App", "AppIcon.icon")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SKILL = os.path.expanduser("~/.claude/skills/compose-app-icon/scripts")
ICTOOL = os.path.join(os.path.dirname(subprocess.check_output(["xcode-select", "-p"], text=True).strip()),
                      "Applications/Icon Composer.app/Contents/Executables/ictool")

BLUE = "#2563D4"
NAVY = "#0E3A8C"
WHITE = "#FFFFFF"
INK = "#1C1C1E"   # iOS label color in light mode, what the game uses for givens

def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}" width="{S}" height="{S}">{body}</svg>'

def geometry(n, pad):
    return (S - 2 * pad) / n

def layer_board(pad, color=WHITE, radius=56):
    o = pad - 18
    return svg(f'<rect x="{o}" y="{o}" width="{S-2*o}" height="{S-2*o}" rx="{radius}" fill="{color}"/>')

def layer_grid(n, pad, color=NAVY, opacity=0.18):
    cell = geometry(n, pad)
    lines = []
    for i in range(1, n):
        x = pad + i * cell
        lines.append(f'<line x1="{x:.1f}" y1="{pad}" x2="{x:.1f}" y2="{S-pad}"/>')
        lines.append(f'<line x1="{pad}" y1="{x:.1f}" x2="{S-pad}" y2="{x:.1f}"/>')
    return svg(f'<g stroke="{color}" stroke-opacity="{opacity}" stroke-width="4">{"".join(lines)}</g>')

def layer_tiles(n, base, pad, color, gap=0, radius=0):
    cell = geometry(n, pad)
    rects = []
    for r, c in sorted(d4(base, n)):
        x, y = pad + c * cell + gap, pad + r * cell + gap
        rects.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{cell-2*gap:.1f}" height="{cell-2*gap:.1f}" rx="{radius}"/>')
    return svg(f'<g fill="{color}">{"".join(rects)}</g>')

def layer_digits(n, base, pad, color, given_color=None):
    """Digits for the snowflake cells. With given_color, the puzzle's clues get that color, as the game draws
    givens in the primary color and the player's entries in the accent color."""
    cell = geometry(n, pad)
    texts = []
    for r, c in sorted(d4(base, n)):
        x, y = pad + c * cell + cell / 2, pad + r * cell + cell / 2
        fill = given_color if given_color and is_given(r, c) else color
        texts.append(f'<text x="{x:.1f}" y="{y:.1f}" dy="0.36em" text-anchor="middle" fill="{fill}">{solved(r, c)}</text>')
    return svg(f'<g font-family="{FONT}" font-weight="700" font-size="{cell*0.6:.0f}">{"".join(texts)}</g>')

def rasterize(svg_text, png_path):
    html = png_path[:-4] + ".html"
    with open(html, "w") as f:
        f.write(f'<html><body style="margin:0;background:transparent">{svg_text}</body></html>')
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--default-background-color=00000000",
                    f"--window-size={S},{S}", f"--screenshot={png_path}", "file://" + html],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.remove(html)

def color(hexstr, a=1.0):
    r, g, b = (int(hexstr[i:i+2], 16) / 255 for i in (1, 3, 5))
    return f"srgb:{r:.5f},{g:.5f},{b:.5f},{a:.5f}"

def group(name, layers, glass=True, shadow=("neutral", 0.5), translucency=None, specular=True):
    g = {"name": name, "layers": [{"name": l, "image-name": f"{l}.png", "glass": glass} for l in layers],
         "shadow": {"kind": shadow[0], "opacity": shadow[1]}, "specular": specular}
    if translucency is not None:
        g["translucency"] = {"enabled": True, "value": translucency}
    return g

# Each option: board pattern, padding, layer drawings, and the icon.json groups (front to back).
def options():
    star, tips = BOARDS["c7-star"], BOARDS["c7-tips"]
    gradient = {"linear-gradient": [color("#2F7DE1"), color("#0E3A8C")],
                "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}}}
    out = []

    # 1. The flat concept, glassed: white board slab, blue snowflake cells, white digits on a blue gradient.
    def board_option(name, pattern):
        n, base = pattern
        pad = 140
        return name, {
            "digits": layer_digits(n, base, pad, WHITE),
            "tiles": layer_tiles(n, base, pad, BLUE),
            "grid": layer_grid(n, pad),
            "board": layer_board(pad),
        }, {"fill": gradient, "groups": [
            group("Digits", ["digits"], shadow=("none", 0)),
            group("Board", ["tiles", "grid", "board"], glass=False, shadow=("neutral", 0.6)),
        ]}
    out.append(board_option("1-board-star", star))
    out.append(board_option("2-board-tips", tips))

    # 3. Floating tiles: no board, the snowflake cells are separate glass tiles over a deep blue field.
    n, base = star
    pad = 120
    out.append(("3-glass-tiles", {
        "digits": layer_digits(n, base, pad, BLUE, given_color=INK),
        "tiles": layer_tiles(n, base, pad, WHITE, gap=7, radius=22),
    }, {"fill": gradient, "groups": [
        group("Digits", ["digits"], glass=False, shadow=("none", 0)),
        group("Tiles", ["tiles"], shadow=("layer-color", 0.5), translucency=0.25),
    ]}))

    # 4. Light: a white field with blue glass tiles and white digits; the system darkens it in dark mode.
    out.append(("4-light-tiles", {
        "digits": layer_digits(n, base, pad, WHITE),
        "tiles": layer_tiles(n, base, pad, BLUE, gap=7, radius=22),
    }, {"fill": "system-light", "groups": [
        group("Digits", ["digits"], shadow=("none", 0)),
        group("Tiles", ["tiles"], shadow=("layer-color", 0.6), translucency=0.15),
    ]}))
    return out

def render(icon_path, png_path, rendition):
    subprocess.run([ICTOOL, icon_path, "--export-image", "--output-file", png_path, "--platform", "iOS",
                    "--rendition", rendition, "--width", "512", "--height", "512", "--scale", "1"],
                   check=True, stdout=subprocess.DEVNULL)

if __name__ == "__main__":
    os.makedirs(BUILD, exist_ok=True)
    os.makedirs(ICONS, exist_ok=True)
    for name, layers, doc in options():
        doc["supported-platforms"] = {"squares": "shared"}  # iOS, iPadOS and macOS
        ldir = os.path.join(BUILD, name)
        os.makedirs(ldir, exist_ok=True)
        assets = []
        for lname, text in layers.items():
            png = os.path.join(ldir, f"{lname}.png")
            rasterize(text, png)
            assets += ["--asset", f"{lname}.png={png}"]
        doc_path = os.path.join(ldir, "icon.json")
        with open(doc_path, "w") as f:
            json.dump(doc, f, indent=2)
        icon = APP_ICON if name == CHOSEN else os.path.join(ICONS, f"Snowdoku-{name}.icon")
        if os.path.isdir(icon):
            # Once a package exists, its icon.json is tuned by hand in Icon Composer: only refresh the layers.
            for lname in layers:
                shutil.copyfile(os.path.join(ldir, f"{lname}.png"), os.path.join(icon, "Assets", f"{lname}.png"))
        else:
            subprocess.run(["uv", "run", "--project", SKILL, "python", os.path.join(SKILL, "create_icon.py"),
                            "--output", icon, "--icon", doc_path, *assets], check=True)
        subprocess.run(["uv", "run", "--project", SKILL, "python", os.path.join(SKILL, "validate_icon.py"), icon], check=True)
        for rendition in ["Default", "Dark", "TintedDark", "ClearLight"]:
            render(icon, os.path.join(BUILD, f"{name}-{rendition}.png"), rendition)
    print("done")
