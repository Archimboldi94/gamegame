#!/usr/bin/env python3
"""Pixel props for Qingyadu exploration. Palette is sampled from assets/tiles.

Ground stays on the battle diamonds. These slices replace stacked-tile buildings,
the flat ferry polygon, and the inn's rectangle furniture.
"""
import json
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "tiles", "props")
BLUEPRINT = os.path.join(ROOT, "data", "wuxia", "qingyadu_blueprint_v1.3.json")
DRESSING = os.path.join(ROOT, "data", "wuxia", "explore_dressing.json")

# Colors taken from the battle tile set (wall, stone, bridge, grass, water).
WOOD = (144, 96, 64)
WOOD_DK = (96, 56, 32)
WOOD_LT = (176, 128, 80)
PLANTER = (112, 64, 32)
PLASTER = (196, 176, 148)
PLASTER_DK = (148, 124, 100)
STONE = (168, 152, 136)
STONE_DK = (96, 88, 72)
ROOF = (58, 78, 72)
ROOF_LT = (92, 114, 104)
ROOF_DK = (36, 48, 44)
INK = (28, 32, 30)
PAPER = (232, 214, 170)
GOLD = (196, 160, 80)
LEAF = (78, 112, 62)
LEAF_LT = (118, 148, 78)
LEAF_DK = (42, 68, 40)
BAMBOO = (86, 132, 72)
BAMBOO_DK = (48, 86, 46)
WATER_DK = (36, 72, 78)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(im, x, y, col, a=255):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), (*col, a))


def rect(im, x, y, w, h, col):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(im, xx, yy, col)


def hline(im, x, y, w, col):
    rect(im, x, y, w, 1, col)


def outline(im):
    src = im.copy()
    w, h = im.size
    px = src.load()
    out = im.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                continue
            hit = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                        hit = True
            if hit:
                out[x, y] = (*INK, 255)


def grain(col, x, y, amp=8):
    n = ((x * 17 + y * 11) ^ (x * 5 + y)) & 15
    d = (n - 8) * amp // 8
    return tuple(max(0, min(255, c + d)) for c in col)


def wall(im, x, y, w, h, col=PLASTER):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(im, xx, yy, grain(col if (xx + yy) % 7 else PLASTER_DK, xx, yy, 6))
    # timber posts
    for px in (x, x + w // 2, x + w - 3):
        rect(im, px, y, 3, h, WOOD_DK)
    hline(im, x, y + h // 2, w, WOOD_DK)


def roof(im, x, y, w, h, col=ROOF):
    """Hip roof: each row narrows toward the ridge."""
    for i in range(h):
        inset = int(i * (w * 0.18) / max(1, h))
        rw = w - inset * 2
        shade = ROOF_LT if i % 5 == 0 else (ROOF_DK if i % 5 == 4 else col)
        hline(im, x + inset, y + h - 1 - i, rw, shade)
    # ridge
    hline(im, x + w // 2 - 2, y, 4, GOLD)


def door(im, x, y, w, h):
    rect(im, x - 2, y, w + 4, h, GOLD)
    rect(im, x, y + 2, w, h - 2, WOOD_DK)
    rect(im, x + w // 2, y + 2, 1, h - 6, WOOD)
    put(im, x + w - 4, y + h // 2, GOLD)


def window(im, x, y, w, h):
    rect(im, x - 1, y - 1, w + 2, h + 2, WOOD_DK)
    rect(im, x, y, w, h, PAPER)
    hline(im, x, y + h // 2, w, WOOD_DK)
    for i in range(0, w, 3):
        put(im, x + i, y + 2, WOOD)


def building(w, h, roof_h, body_col=PLASTER, roof_col=ROOF, windows=2, sign=False):
    im = new(w, h)
    body_top = roof_h - 8
    body_h = h - body_top - 10
    wall(im, 16, body_top, w - 32, body_h, body_col)
    roof(im, 8, 8, w - 16, roof_h, roof_col)
    # stone step
    rect(im, w // 2 - 18, h - 12, 36, 6, STONE)
    door(im, w // 2 - 12, h - 12 - 36, 24, 36)
    gap = (w - 80) // (windows + 1)
    for i in range(windows):
        window(im, 28 + gap * (i + 1), body_top + 16, 16, 14)
    if sign:
        rect(im, w // 2 + 18, body_top + 8, 28, 16, WOOD)
        rect(im, w // 2 + 20, body_top + 10, 24, 12, PAPER)
        hline(im, w // 2 + 24, body_top + 15, 16, WOOD_DK)
    # lantern
    rect(im, 22, body_top + 6, 8, 10, GOLD)
    rect(im, 24, body_top + 16, 4, 6, WOOD_DK)
    outline(im)
    return im


def shrine():
    im = new(300, 230)
    # broken stone platform
    rect(im, 30, 180, 240, 18, STONE)
    rect(im, 40, 172, 220, 10, STONE_DK)
    # pillars
    for x in (70, 210):
        rect(im, x, 90, 16, 90, STONE)
        rect(im, x - 4, 82, 24, 10, STONE_DK)
        rect(im, x - 2, 176, 20, 8, STONE_DK)
    # tablet
    rect(im, 132, 110, 36, 62, (120, 116, 108))
    rect(im, 128, 104, 44, 8, STONE_DK)
    for i in range(4):
        hline(im, 138, 124 + i * 10, 24, STONE_DK)
    # damaged hip roof, shorter on the right
    roof(im, 24, 16, 230, 78, (88, 90, 86))
    # missing corner
    for y in range(16, 50):
        for x in range(210, 270):
            if im.getpixel((x, y))[3]:
                im.putpixel((x, y), (0, 0, 0, 0))
    rect(im, 200, 40, 28, 10, STONE_DK)
    # weeds
    for x in (48, 250, 160):
        rect(im, x, 190, 2, 12, LEAF)
        put(im, x - 3, 194, LEAF_LT)
        put(im, x + 3, 196, LEAF)
    outline(im)
    return im


def ferry():
    im = new(220, 120)
    # hull
    for y in range(50, 90):
        t = (y - 50) / 40
        inset = int(18 * (1 - t) + 8 * t)
        hline(im, 16 + inset // 2, y, 188 - inset, grain(WOOD if y % 4 else WOOD_DK, 0, y, 10))
    # bow point
    for i in range(16):
        hline(im, 8 + i, 62 + i // 2, 12, WOOD_LT)
    hline(im, 20, 88, 170, WOOD_DK)
    # cabin
    rect(im, 90, 28, 54, 32, PLASTER)
    roof(im, 82, 12, 70, 24, ROOF)
    window(im, 100, 36, 14, 10)
    window(im, 122, 36, 12, 10)
    # mast and furled sail
    rect(im, 70, 8, 3, 48, WOOD_DK)
    for i in range(5):
        hline(im, 73, 14 + i * 4, 22 - i, PAPER)
    # oar
    hline(im, 150, 70, 40, WOOD)
    rect(im, 186, 64, 10, 14, WOOD_DK)
    outline(im)
    return im


def crate():
    im = new(48, 40)
    rect(im, 6, 10, 36, 24, WOOD)
    hline(im, 6, 10, 36, WOOD_LT)
    hline(im, 6, 32, 36, WOOD_DK)
    rect(im, 6, 10, 3, 24, WOOD_DK)
    # braces
    for i in range(24):
        put(im, 8 + i, 12 + i // 2, PLANTER)
        put(im, 40 - i, 12 + i // 2, PLANTER)
    rect(im, 20, 14, 8, 6, GOLD)
    outline(im)
    return im


def bamboo():
    im = new(56, 120)
    stalks = [10, 20, 30, 40, 48]
    for i, x in enumerate(stalks):
        h = 100 - (i % 3) * 10
        col = BAMBOO if i % 2 == 0 else BAMBOO_DK
        rect(im, x, 120 - h, 4, h - 8, col)
        for s in range(8, h, 14):
            hline(im, x - 1, 120 - h + s, 6, LEAF_DK)
        # leaves
        for k in range(4):
            hline(im, x - 8 + k, 120 - h + k, 10, LEAF if k % 2 else LEAF_LT)
            hline(im, x + 2, 122 - h + k * 2, 12 - k, LEAF_DK)
    outline(im)
    return im


def lantern():
    im = new(24, 64)
    rect(im, 11, 8, 2, 40, WOOD_DK)
    rect(im, 6, 18, 12, 16, GOLD)
    rect(im, 8, 20, 8, 12, (232, 196, 110))
    hline(im, 6, 18, 12, WOOD_DK)
    hline(im, 6, 33, 12, WOOD_DK)
    put(im, 11, 48, GOLD)
    outline(im)
    return im


def post():
    im = new(20, 52)
    rect(im, 8, 6, 4, 40, WOOD)
    rect(im, 6, 4, 8, 6, WOOD_DK)
    hline(im, 12, 16, 6, (90, 78, 60))
    hline(im, 14, 20, 5, (90, 78, 60))
    outline(im)
    return im


def counter():
    im = new(150, 64)
    rect(im, 8, 28, 134, 22, WOOD)
    rect(im, 8, 22, 134, 8, WOOD_LT)
    rect(im, 12, 46, 8, 10, WOOD_DK)
    rect(im, 130, 46, 8, 10, WOOD_DK)
    # cloth
    rect(im, 20, 16, 40, 8, (120, 48, 44))
    # teapot
    rect(im, 90, 12, 12, 10, (70, 90, 86))
    rect(im, 102, 16, 6, 3, (70, 90, 86))
    rect(im, 110, 18, 8, 6, PAPER)
    outline(im)
    return im


def shelf():
    im = new(96, 88)
    rect(im, 8, 10, 80, 68, WOOD_DK)
    rect(im, 12, 14, 72, 60, (86, 62, 40))
    colors = [(140, 48, 44), (48, 78, 110), (90, 120, 70), PAPER, (90, 60, 40), (60, 60, 80)]
    for row in range(3):
        y = 18 + row * 18
        hline(im, 12, y + 14, 72, WOOD)
        for i, c in enumerate(colors):
            rect(im, 16 + i * 11, y, 8, 13, c)
    outline(im)
    return im


def rack():
    im = new(44, 96)
    rect(im, 6, 70, 32, 8, WOOD)
    rect(im, 8, 78, 4, 10, WOOD_DK)
    rect(im, 32, 78, 4, 10, WOOD_DK)
    rect(im, 18, 20, 4, 52, WOOD_DK)
    # sword
    rect(im, 20, 8, 3, 58, (180, 186, 190))
    rect(im, 16, 58, 12, 5, GOLD)
    rect(im, 20, 63, 3, 16, WOOD)
    outline(im)
    return im


def table():
    im = new(88, 52)
    # ellipse top
    for y in range(8, 28):
        t = (y - 18) / 10
        half = int(36 * (1 - t * t) ** 0.5)
        hline(im, 44 - half, y, half * 2, WOOD_LT if y < 16 else WOOD)
    rect(im, 40, 26, 8, 16, WOOD_DK)
    rect(im, 28, 38, 32, 4, WOOD)
    rect(im, 52, 14, 8, 6, PAPER)
    outline(im)
    return im


def save_all():
    os.makedirs(OUT, exist_ok=True)
    images = {
        "prop_inn.png": building(280, 210, 78, sign=True),
        "prop_shrine.png": shrine(),
        "prop_house.png": building(168, 140, 52, body_col=(186, 162, 130), roof_col=(110, 72, 48)),
        "prop_house_b.png": building(150, 128, 48, body_col=(210, 206, 196), roof_col=(72, 76, 80), windows=1),
        "prop_ferry.png": ferry(),
        "prop_crate.png": crate(),
        "prop_bamboo.png": bamboo(),
        "prop_lantern.png": lantern(),
        "prop_post.png": post(),
        "prop_counter.png": counter(),
        "prop_shelf.png": shelf(),
        "prop_rack.png": rack(),
        "prop_table.png": table(),
    }
    for name, im in images.items():
        im.save(os.path.join(OUT, name))
        print(name, im.size)


BLOCKED = set("#H~")
W, H = 48, 30


def blank(ch="."):
    return [[ch for _ in range(W)] for _ in range(H)]


def fill(g, x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H:
                g[y][x] = ch


def build_outdoor():
    g = blank(".")
    fill(g, 0, 0, W - 1, 0, "#")
    fill(g, 0, H - 1, W - 1, H - 1, "#")
    fill(g, 0, 0, 0, H - 1, "#")
    fill(g, W - 1, 0, W - 1, H - 1, "#")
    # Northwest bamboo grove, with a footpath out to the old road.
    fill(g, 1, 1, 14, 12, "#")
    fill(g, 8, 7, 16, 8, ",")
    fill(g, 10, 9, 11, 15, ",")
    # North forest belt. (22, 5) stays solid.
    fill(g, 19, 2, 29, 8, "#")
    fill(g, 21, 9, 24, 12, "#")
    # Shrine court (stone under the hall sprite). Door yard stays open.
    fill(g, 32, 3, 41, 7, "H")
    fill(g, 33, 8, 41, 10, "=")
    g[8][37] = "."
    # Inn courtyard and doorway. (5, 19) is wall/foundation.
    fill(g, 3, 17, 12, 20, "H")
    fill(g, 3, 21, 7, 21, "H")
    fill(g, 9, 21, 12, 21, "H")
    g[21][8] = "."
    # Village houses set back from the street.
    fill(g, 20, 17, 23, 20, "H")
    fill(g, 26, 17, 29, 20, "H")
    fill(g, 14, 14, 16, 16, "H")
    # Stone street, two tiles wide, from the inn to the ferry.
    fill(g, 2, 22, 36, 23, "=")
    fill(g, 8, 24, 18, 24, "=")
    # Lane up through the bamboo clearing.
    fill(g, 16, 9, 18, 21, "=")
    fill(g, 16, 7, 18, 8, ",")
    # Lane up to the shrine court.
    fill(g, 33, 11, 35, 21, "=")
    # Wooden pier (x >= 34 renders as bridge planks). (41, 23) is on it.
    fill(g, 37, 21, 43, 24, "=")
    # River, widening toward the south. Row 27 is water from column 42.
    for y in range(16, 29):
        shore = 45 if y < 21 else (44 if y < 25 else 42)
        for x in range(shore, 47):
            g[y][x] = "~"
    # Mud bank just inland of the water, where it does not erase the pier.
    for y in range(18, 28):
        shore = 45 if y < 21 else (44 if y < 25 else 42)
        for x in range(shore - 3, shore):
            if g[y][x] == ".":
                g[y][x] = "m"
    # South orchard and west windbreak.
    for x, y in ((3, 25), (4, 26), (6, 27), (12, 26), (13, 27), (22, 26), (23, 27), (28, 26), (2, 15), (2, 16)):
        g[y][x] = "#"
    fill(g, 1, 25, 2, 27, "#")
    # Grass variation off the roads.
    for y in range(1, 29):
        for x in range(1, 47):
            if g[y][x] == "." and (x * 3 + y * 5) % 7 == 0:
                g[y][x] = ","
    # Locked regression cells: (x, y).
    assert g[19][5] == "H"
    assert g[5][22] == "#"
    assert g[27][46] == "~"
    assert g[27][42] == "~"
    assert g[23][41] == "="
    return g


def build_inn():
    g = [["H"] * 14 for _ in range(10)]
    for y in range(1, 9):
        for x in range(1, 13):
            g[y][x] = "w"
    for y in range(1, 9):
        g[y][5] = "="
        g[y][6] = "="
        g[y][7] = "="
    # Side mats
    for x in range(2, 5):
        g[5][x] = ","
        g[6][x] = ","
    for x in range(9, 12):
        g[4][x] = ","
        g[5][x] = ","
    g[9][6] = "."
    assert g[5][0] == "H"
    assert all(len(row) == 14 for row in g)
    return g


def rows_of(g):
    return ["".join(row) for row in g]


def reachable(rows, start):
    seen = {start}
    q = [start]
    i = 0
    while i < len(q):
        x, y = q[i]
        i += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in seen:
                continue
            nx, ny = n
            if ny < 0 or ny >= len(rows) or nx < 0 or nx >= len(rows[0]):
                continue
            if rows[ny][nx] in BLOCKED:
                continue
            seen.add(n)
            q.append(n)
    return seen


def punch(rows, points, ch):
    out = [list(r) for r in rows]
    for x, y in points:
        if out[y][x] in BLOCKED:
            out[y][x] = ch
    return ["".join(r) for r in out]


def validate(outdoor, inn):
    o = punch(outdoor, [(8, 21), (37, 23), (16, 7), (37, 8), (8, 23)], ".")
    seen = reachable(o, (8, 23))
    for name, cell in {
        "inn": (8, 21), "ferry": (37, 23), "bamboo": (16, 7), "shrine": (37, 8)
    }.items():
        if cell not in seen:
            raise SystemExit("outdoor path broken: " + name)
    if o[27][46] != "~" or o[19][5] != "H" or o[5][22] != "#" or o[23][41] != "=":
        raise SystemExit("regression cell drifted")
    inn_pts = [(6, 9), (6, 3), (3, 3), (10, 3), (3, 6), (10, 6), (6, 8)]
    inn_rows = punch(inn, inn_pts, "w")
    seen_i = reachable(inn_rows, (6, 8))
    for cell in inn_pts:
        if cell not in seen_i:
            raise SystemExit("inn path broken " + str(cell))
    print("paths ok", "outdoor #", sum(r.count("#") for r in outdoor), "H", sum(r.count("H") for r in outdoor))


def dressing(outdoor):
    props = []
    for y, row in enumerate(outdoor):
        for x, ch in enumerate(row):
            if ch != "#":
                continue
            kind = "bamboo" if x <= 15 and 1 <= y <= 13 else "tree"
            props.append({"kind": kind, "cell": [x, y]})
    props.extend([
        {"kind": "inn", "cell": [8, 21]},
        {"kind": "shrine", "cell": [37, 8]},
        {"kind": "house", "cell": [22, 20]},
        {"kind": "house_b", "cell": [28, 20]},
        {"kind": "house", "cell": [15, 16]},
        {"kind": "ferry", "cell": [44, 22]},
        {"kind": "crate", "cell": [35, 21]},
        {"kind": "crate", "cell": [36, 24]},
        {"kind": "crate", "cell": [39, 21]},
        {"kind": "crate", "cell": [34, 24]},
        {"kind": "crate", "cell": [15, 24]},
        {"kind": "post", "cell": [38, 24]},
        {"kind": "post", "cell": [43, 21]},
        {"kind": "post", "cell": [43, 24]},
        {"kind": "lantern", "cell": [6, 22]},
        {"kind": "lantern", "cell": [14, 22]},
        {"kind": "lantern", "cell": [24, 22]},
        {"kind": "lantern", "cell": [32, 22]},
        {"kind": "lantern", "cell": [36, 10]},
    ])
    indoor = [
        {"kind": "counter", "cell": [6, 2]},
        {"kind": "shelf", "cell": [2, 5]},
        {"kind": "shelf", "cell": [2, 2]},
        {"kind": "rack", "cell": [11, 6]},
        {"kind": "table", "cell": [9, 5]},
        {"kind": "table", "cell": [4, 7]},
        {"kind": "lantern", "cell": [2, 1]},
        {"kind": "lantern", "cell": [11, 1]},
        {"kind": "lantern", "cell": [6, 1]},
        {"kind": "crate", "cell": [11, 7]},
        {"kind": "crate", "cell": [1, 7]},
    ]
    return {"outdoor": props, "inn": indoor}


def write_blueprint(outdoor, inn):
    with open(BLUEPRINT, encoding="utf-8") as f:
        data = json.load(f)
    data["scenes"]["outdoor"]["terrain_grid"] = rows_of(outdoor)
    data["scenes"]["inn"]["terrain_grid"] = rows_of(inn)
    with open(BLUEPRINT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def main():
    save_all()
    outdoor = build_outdoor()
    inn = build_inn()
    validate(rows_of(outdoor), rows_of(inn))
    write_blueprint(outdoor, inn)
    with open(DRESSING, "w", encoding="utf-8") as f:
        json.dump(dressing(outdoor), f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("wrote blueprint + dressing")


if __name__ == "__main__":
    main()
