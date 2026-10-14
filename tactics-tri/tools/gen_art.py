#!/usr/bin/env python3
"""Generate every bitmap asset used by the game (all original, procedural).

Outputs (relative to the project root):
  assets/tiles/<terrain>_<h>.png   isometric blocks, diamond top + side faces
  assets/fx/*.png                  highlight / cursor / fire / frost overlays
  assets/units/<key>.png           chibi unit sprites with class weapon + badge
  assets/portraits/<key>.png       coloured bust silhouettes for dialogue
  assets/ui/*.png                  nine-patch button and panel skins
  assets/bg/*.png                  title / dialogue / battle backdrops
  icon.png, assets/icons/*.png     app icon and Android launcher icons
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TW, TH, HS, TOPPAD, BASE = 128, 64, 32, 48, 16
MAX_H = 8


def out(*parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


# ---------------------------------------------------------------- tiles

TERRAIN = {
    "grass": dict(top=(104, 168, 76), side=(128, 96, 64), speck=(140, 200, 100)),
    "forest": dict(top=(70, 128, 62), side=(110, 84, 58), speck=(96, 160, 80)),
    "water": dict(top=(72, 136, 206), side=(58, 104, 168), speck=(150, 200, 240)),
    "stone": dict(top=(176, 168, 150), side=(124, 116, 104), speck=(150, 142, 128)),
    "ruins": dict(top=(150, 142, 122), side=(112, 104, 92), speck=(110, 140, 90)),
    "wall": dict(top=(150, 146, 140), side=(118, 112, 106), speck=(170, 166, 160)),
    "ice": dict(top=(196, 228, 246), side=(150, 190, 220), speck=(255, 255, 255)),
}


def in_diamond(x, y, cx, cy, k=1.0):
    return abs(x - cx) / 64.0 + abs(y - cy) / 32.0 <= k


def draw_tree(d, x, y, rng):
    d.rectangle([x - 2, y - 10, x + 2, y], fill=(90, 60, 36, 255))
    dark, mid, light = (40, 92, 44, 255), (56, 120, 56, 255), (92, 156, 76, 255)
    d.ellipse([x - 13, y - 30, x + 13, y - 6], fill=dark)
    d.ellipse([x - 10, y - 38, x + 10, y - 16], fill=mid)
    d.ellipse([x - 6, y - 36, x + 2, y - 28], fill=light)


def tile_img(key, h):
    t = TERRAIN[key]
    rng = random.Random(f"{key}-{h}")
    depth = h * HS + BASE
    img = Image.new("RGBA", (TW, TOPPAD + TH + depth), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cy = TOPPAD + TH // 2
    top = [(64, cy - 32), (127, cy), (64, cy + 32), (0, cy)]
    left = [(0, cy), (64, cy + 32), (64, cy + 32 + depth), (0, cy + depth)]
    right = [(64, cy + 32), (127, cy), (127, cy + depth), (64, cy + 32 + depth)]
    d.polygon(left, fill=shade(t["side"], 1.0))
    d.polygon(right, fill=shade(t["side"], 0.72))
    # side speckles
    for _ in range(depth * 3):
        x = rng.randint(1, 126)
        base_y = cy + (x / 2 if x < 64 else (127 - x) / 2)
        y = int(base_y + rng.randint(2, max(3, depth - 2)))
        f = 0.85 if x < 64 else 0.62
        img.putpixel((x, min(y, img.height - 1)), shade(t["side"], f))
    if key == "wall":
        for r in range(6, depth, 12):
            d.line([(0, cy + r), (64, cy + 32 + r)], fill=shade(t["side"], 0.8), width=1)
            d.line([(64, cy + 32 + r), (127, cy + r)], fill=shade(t["side"], 0.55), width=1)
            off = 0 if (r // 12) % 2 == 0 else 10
            for x in range(4 + off, 64, 20):
                y0 = cy + r + x // 2
                d.line([(x, y0), (x, y0 + 12)], fill=shade(t["side"], 0.8))
            for x in range(70 + off, 127, 20):
                y0 = cy + r + (127 - x) // 2
                d.line([(x, y0), (x, y0 + 12)], fill=shade(t["side"], 0.55))
    else:
        for k in range(1, h + 1):
            y = cy + k * HS
            d.line([(0, y), (64, y + 32)], fill=shade(t["side"], 0.86), width=1)
            d.line([(64, y + 32), (127, y)], fill=shade(t["side"], 0.6), width=1)
    # soil / rim band under the top surface
    band = 6 if key not in ("water", "ice") else 4
    d.polygon([(0, cy), (64, cy + 32), (64, cy + 32 + band), (0, cy + band)], fill=shade(t["top"], 0.75))
    d.polygon([(64, cy + 32), (127, cy), (127, cy + band), (64, cy + 32 + band)], fill=shade(t["top"], 0.58))
    # top
    d.polygon(top, fill=t["top"] + (255,))
    for _ in range(140):
        x, y = rng.randint(2, 125), rng.randint(cy - 30, cy + 30)
        if in_diamond(x, y, 64, cy, 0.9):
            img.putpixel((x, y), t["speck"] + (255,))
            if key in ("grass", "forest") and y > 0:
                img.putpixel((x, y - 1), shade(t["speck"], 0.9))
    if key == "water":
        for i in range(5):
            x, y = rng.randint(28, 96), rng.randint(cy - 16, cy + 16)
            d.arc([x - 10, y - 3, x + 10, y + 3], 200, 340, fill=(200, 230, 255, 255), width=1)
    if key == "ice":
        for i in range(4):
            x, y = rng.randint(30, 96), rng.randint(cy - 14, cy + 14)
            d.line([(x - 12, y + 4), (x + 12, y - 4)], fill=(255, 255, 255, 255), width=2)
    if key == "stone":
        for gy in range(-24, 25, 12):
            d.line([(64 - 48 + abs(gy), cy + gy), (64 + 48 - abs(gy), cy + gy)], fill=shade(t["top"], 0.85))
    if key == "ruins":
        for i in range(3):
            x, y = rng.randint(30, 96), rng.randint(cy - 12, cy + 12)
            d.line([(x, y), (x + rng.randint(-10, 10), y + rng.randint(3, 8))], fill=shade(t["top"], 0.6), width=1)
        # broken pillar
        px, py = 46, cy + 4
        d.rectangle([px - 7, py - 30, px + 7, py], fill=(196, 188, 170, 255))
        d.rectangle([px + 1, py - 30, px + 7, py], fill=(160, 152, 136, 255))
        d.polygon([(px - 7, py - 30), (px - 2, py - 36), (px + 4, py - 31), (px + 7, py - 33), (px + 7, py - 30)],
                  fill=(210, 204, 188, 255))
        d.ellipse([px + 20, py - 4, px + 34, py + 4], fill=(170, 162, 146, 255))
    if key == "forest":
        for (tx, ty) in [(40, cy - 2), (88, cy + 2), (62, cy + 16), (64, cy - 12)]:
            draw_tree(d, tx, ty, rng)
    if key == "wall":
        d.line([(16, cy), (64, cy - 24), (112, cy)], fill=shade(t["top"], 0.85))
    d.line(top + [top[0]], fill=shade(t["top"], 0.62), width=1)
    return img


def gen_tiles():
    for key in TERRAIN:
        for h in range(MAX_H + 1):
            tile_img(key, h).save(out("assets", "tiles", f"{key}_{h}.png"))


# ---------------------------------------------------------------- fx overlays

def diamond(d, cy, fill, outline=None, width=2, inset=0):
    pts = [(64, cy - 32 + inset), (127 - inset * 2, cy), (64, cy + 32 - inset), (inset * 2, cy)]
    d.polygon(pts, fill=fill)
    if outline:
        d.line(pts + [pts[0]], fill=outline, width=width)


def gen_fx():
    img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    diamond(ImageDraw.Draw(img), 32, (255, 255, 255, 110), (255, 255, 255, 235), 3, 2)
    img.save(out("assets", "fx", "highlight.png"))

    img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    diamond(d, 32, (0, 0, 0, 0), (255, 255, 255, 255), 5, 2)
    img.save(out("assets", "fx", "cursor.png"))

    img = Image.new("RGBA", (TW, TH + TOPPAD), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cy = TOPPAD + 32
    diamond(d, cy, (255, 110, 30, 90))
    for fx, fh in [(40, 34), (64, 46), (88, 30), (60, 26)]:
        base = cy + (8 if fx == 60 else 0)
        d.polygon([(fx - 12, base), (fx, base - fh), (fx + 12, base)], fill=(230, 70, 20, 220))
        d.polygon([(fx - 7, base), (fx, base - fh * 0.65), (fx + 7, base)], fill=(255, 170, 40, 235))
        d.polygon([(fx - 3, base), (fx, base - fh * 0.35), (fx + 3, base)], fill=(255, 240, 150, 255))
    img.save(out("assets", "fx", "fire.png"))

    img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    diamond(d, 32, (180, 230, 255, 120), (230, 248, 255, 200), 2, 4)
    for sx, sy in [(44, 28), (82, 34), (64, 44), (64, 20)]:
        for a in range(3):
            ang = a * math.pi / 3
            dx, dy = math.cos(ang) * 7, math.sin(ang) * 4
            d.line([(sx - dx, sy - dy), (sx + dx, sy + dy)], fill=(255, 255, 255, 255), width=2)
    img.save(out("assets", "fx", "frost.png"))


# ---------------------------------------------------------------- units

UNITS = {
    # heroes
    "linyan": dict(cls="swordsman", body=(56, 88, 170), accent=(222, 186, 90), hair=(44, 34, 34), team=0),
    "qinlie": dict(cls="lancer", body=(156, 58, 48), accent=(210, 210, 220), hair=(86, 54, 32), team=0),
    "suqing": dict(cls="archer", body=(66, 140, 82), accent=(236, 220, 160), hair=(130, 72, 40), team=0),
    "shenmo": dict(cls="mage", body=(92, 62, 146), accent=(170, 140, 230), hair=(34, 32, 44), team=0),
    "wenlan": dict(cls="healer", body=(232, 230, 220), accent=(84, 168, 188), hair=(206, 164, 92), team=0),
    "ali": dict(cls="thief", body=(62, 62, 74), accent=(214, 146, 44), hair=(170, 64, 42), team=0),
    # enemies
    "bandit": dict(cls="swordsman", body=(58, 50, 58), accent=(176, 40, 40), hair=(30, 26, 26), team=1),
    "spear": dict(cls="lancer", body=(70, 56, 52), accent=(176, 40, 40), hair=(40, 30, 26), team=1),
    "crossbow": dict(cls="archer", body=(72, 64, 50), accent=(176, 40, 40), hair=(50, 38, 30), team=1),
    "shaman": dict(cls="mage", body=(46, 36, 52), accent=(200, 60, 60), hair=(20, 20, 24), team=1),
    "medic": dict(cls="healer", body=(110, 96, 86), accent=(176, 40, 40), hair=(60, 50, 40), team=1),
    "leader_a": dict(cls="swordsman", body=(40, 30, 34), accent=(210, 48, 40), hair=(20, 16, 16), team=1, leader=True),
    "leader_b": dict(cls="lancer", body=(52, 40, 40), accent=(214, 160, 50), hair=(26, 20, 20), team=1, leader=True),
}

SKIN = (246, 214, 180)


def draw_weapon(d, cls, accent):
    wood, steel, dark = (120, 80, 46, 255), (214, 220, 232, 255), (60, 50, 50, 255)
    if cls == "swordsman":
        d.line([(72, 88), (86, 36)], fill=steel, width=5)
        d.line([(66, 84), (80, 90)], fill=accent + (255,), width=4)
        d.line([(70, 88), (67, 98)], fill=dark, width=4)
    elif cls == "lancer":
        d.line([(76, 120), (84, 8)], fill=wood, width=4)
        d.polygon([(79, 14), (85, -2 + 4), (90, 14), (84, 24)], fill=steel)
        d.line([(78, 26), (90, 28)], fill=accent + (255,), width=3)
    elif cls == "archer":
        d.arc([60, 40, 92, 108], -80, 80, fill=wood, width=5)
        d.line([(79, 42), (79, 106)], fill=(240, 240, 230, 255), width=1)
    elif cls == "mage":
        d.line([(78, 118), (82, 34)], fill=(70, 50, 40, 255), width=4)
        d.ellipse([72, 20, 92, 40], fill=accent + (255,))
        d.ellipse([77, 24, 84, 31], fill=(255, 255, 255, 220))
    elif cls == "healer":
        d.line([(78, 118), (80, 36)], fill=(230, 210, 150, 255), width=4)
        d.rectangle([76, 18, 84, 42], fill=accent + (255,))
        d.rectangle([70, 25, 90, 33], fill=accent + (255,))
    elif cls == "thief":
        d.line([(70, 92), (84, 74)], fill=steel, width=4)
        d.line([(68, 88), (74, 94)], fill=dark, width=4)
        d.line([(22, 92), (12, 78)], fill=steel, width=3)


def draw_badge(d, cls, cx, cy, accent):
    d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=accent + (255,), outline=(30, 26, 30, 255))
    c = (30, 26, 30, 255)
    if cls == "swordsman":
        d.line([(cx - 4, cy + 4), (cx + 4, cy - 4)], fill=c, width=2)
    elif cls == "lancer":
        d.line([(cx, cy + 5), (cx, cy - 5)], fill=c, width=2)
        d.polygon([(cx - 3, cy - 2), (cx, cy - 6), (cx + 3, cy - 2)], fill=c)
    elif cls == "archer":
        d.arc([cx - 5, cy - 5, cx + 5, cy + 5], -90, 90, fill=c, width=2)
    elif cls == "mage":
        d.polygon([(cx - 5, cy + 4), (cx, cy - 6), (cx + 5, cy + 4)], outline=c)
    elif cls == "healer":
        d.line([(cx, cy - 5), (cx, cy + 5)], fill=c, width=2)
        d.line([(cx - 5, cy), (cx + 5, cy)], fill=c, width=2)
    elif cls == "thief":
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=c)


def outline(img, color=(24, 20, 26, 255), size=5):
    alpha = img.split()[3]
    grown = alpha.filter(ImageFilter.MaxFilter(size))
    base = Image.new("RGBA", img.size, color)
    res = Image.new("RGBA", img.size, (0, 0, 0, 0))
    res.paste(base, (0, 0), grown)
    res.alpha_composite(img)
    return res


def unit_img(key, u):
    img = Image.new("RGBA", (96, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body, accent, hair, cls = u["body"], u["accent"], u["hair"], u["cls"]
    big = u.get("leader", False)
    # legs and boots
    d.rectangle([36, 100, 45, 120], fill=shade(body, 0.55))
    d.rectangle([51, 100, 60, 120], fill=shade(body, 0.55))
    d.rectangle([34, 116, 46, 123], fill=(54, 40, 32, 255))
    d.rectangle([50, 116, 62, 123], fill=(54, 40, 32, 255))
    # cape / robe
    if cls in ("mage", "healer"):
        d.polygon([(28, 66), (68, 66), (74, 116), (22, 116)], fill=shade(body, 0.9))
        d.polygon([(48, 66), (68, 66), (74, 116), (48, 116)], fill=shade(body, 0.78))
    elif cls in ("swordsman",) or big:
        d.polygon([(26, 66), (34, 66), (30, 110), (18, 108)], fill=accent + (255,) if u["team"] == 0 else shade(accent, 0.7))
    # torso
    w = 22 if not big else 25
    d.rounded_rectangle([48 - w, 62, 48 + w - 4, 104], radius=10, fill=body + (255,))
    d.rounded_rectangle([48, 62, 48 + w - 4, 104], radius=10, fill=shade(body, 0.82))
    d.rectangle([48 - w + 2, 92, 48 + w - 6, 97], fill=shade(accent, 0.8))  # belt
    if cls == "lancer" or big:
        d.ellipse([18, 58, 38, 76], fill=shade((180, 180, 196), 1.0))  # pauldron
        d.ellipse([58, 58, 76, 76], fill=shade((150, 150, 166), 1.0))
    # arms / hands
    d.ellipse([18, 80, 30, 92], fill=SKIN + (255,))
    d.ellipse([64, 80, 76, 92], fill=SKIN + (255,))
    draw_badge(d, cls, 40, 78, accent)
    # head
    d.ellipse([22, 16, 72, 66], fill=SKIN + (255,))
    d.pieslice([20, 12, 74, 62], 180, 360, fill=hair + (255,))
    d.polygon([(20, 38), (30, 26), (34, 44)], fill=hair + (255,))
    d.polygon([(46, 22), (58, 34), (64, 26)], fill=hair + (255,))
    # eyes looking right
    d.rectangle([50, 40, 54, 48], fill=(30, 26, 34, 255))
    d.rectangle([62, 40, 66, 48], fill=(30, 26, 34, 255))
    d.point((51, 41), fill=(255, 255, 255, 255))
    d.point((63, 41), fill=(255, 255, 255, 255))
    if cls == "mage":
        d.polygon([(16, 30), (78, 30), (52, -4 + 6), (40, 2)], fill=shade(body, 0.9))
        d.rectangle([16, 26, 78, 32], fill=accent + (255,))
    elif cls == "healer":
        d.chord([18, 10, 76, 70], 160, 380, fill=shade(body, 0.96))
        d.ellipse([26, 24, 70, 66], fill=SKIN + (255,))
        d.rectangle([50, 40, 54, 48], fill=(30, 26, 34, 255))
        d.rectangle([62, 40, 66, 48], fill=(30, 26, 34, 255))
        d.rectangle([44, 14, 50, 26], fill=accent + (255,))
    elif cls == "thief":
        d.rectangle([34, 52, 72, 62], fill=accent + (255,))
        d.polygon([(26, 56), (14, 70), (22, 72), (32, 60)], fill=accent + (255,))
    elif cls == "archer":
        d.polygon([(20, 26), (66, 16), (74, 28), (30, 32)], fill=shade(body, 1.1))
        d.line([(70, 20), (84, 8)], fill=(240, 220, 120, 255), width=3)
    if u["team"] == 1 and not big:
        d.rectangle([22, 28, 72, 34], fill=accent + (255,))
        d.polygon([(22, 30), (10, 40), (16, 42), (24, 34)], fill=accent + (255,))
    if big:
        d.polygon([(26, 22), (14, 2), (34, 18)], fill=(230, 220, 200, 255))
        d.polygon([(66, 18), (82, 0), (72, 24)], fill=(230, 220, 200, 255))
        d.rectangle([22, 24, 72, 32], fill=shade(accent, 0.9))
    draw_weapon(d, cls, accent)
    return outline(img)


def gen_units():
    for key, u in UNITS.items():
        unit_img(key, u).save(out("assets", "units", f"{key}.png"))


# ---------------------------------------------------------------- portraits

def portrait_img(key, u):
    W, H = 420, 600
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = Image.new("L", (W, H), 0)
    m = ImageDraw.Draw(mask)
    m.ellipse([40, 360, 380, 760], fill=255)  # shoulders
    m.rectangle([160, 260, 260, 400], fill=255)  # neck
    m.ellipse([110, 90, 310, 320], fill=255)  # head
    cls = u["cls"]
    if cls == "mage":
        m.polygon([(80, 170), (340, 170), (230, 0), (190, 20)], fill=255)
    elif cls == "healer":
        m.ellipse([90, 70, 330, 360], fill=255)
    elif cls == "lancer":
        m.rectangle([350, 0, 366, 600], fill=255)
        m.polygon([(340, 40), (358, -10), (376, 40), (358, 70)], fill=255)
    elif cls == "archer":
        m.arc([280, 120, 420, 560], -80, 80, fill=255, width=16)
    elif cls == "thief":
        m.polygon([(110, 330), (40, 420), (80, 440), (150, 350)], fill=255)
    elif cls == "swordsman":
        m.polygon([(330, 600), (390, 230), (404, 236), (352, 600)], fill=255)
    if u.get("leader"):
        m.polygon([(130, 140), (90, 30), (170, 120)], fill=255)
        m.polygon([(290, 120), (330, 30), (250, 140)], fill=255)
    else:
        m.ellipse([100, 70, 320, 230], fill=255)  # hair volume
    grad = Image.new("RGBA", (W, H))
    gd = ImageDraw.Draw(grad)
    c1 = shade(u["body"], 1.25)
    c2 = shade(u["body"], 0.45)
    for y in range(H):
        gd.line([(0, y), (W, y)], fill=mix(c1, c2, y / H))
    img.paste(grad, (0, 0), mask)
    # rim light
    edge = mask.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(5))
    rim = Image.new("RGBA", (W, H), shade(u["accent"], 1.0)[:3] + (200,))
    img.paste(rim, (0, 0), edge)
    return img


def gen_portraits():
    for key, u in UNITS.items():
        if u["team"] == 0 or u.get("leader"):
            portrait_img(key, u).save(out("assets", "portraits", f"{key}.png"))


# ---------------------------------------------------------------- UI skins

def rounded_gradient(size, top, bottom, border, radius, bw):
    W, H = size
    grad = Image.new("RGBA", size)
    gd = ImageDraw.Draw(grad)
    for y in range(H):
        gd.line([(0, y), (W, y)], fill=mix(top, bottom, y / max(1, H - 1)))
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], radius=radius, fill=255)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    img.paste(grad, (0, 0), mask)
    ImageDraw.Draw(img).rounded_rectangle([1, 1, W - 2, H - 2], radius=radius, outline=border, width=bw)
    return img


def gen_ui():
    rounded_gradient((96, 96), (70, 84, 128), (36, 42, 70), (214, 180, 98, 255), 20, 4).save(out("assets", "ui", "button.png"))
    rounded_gradient((96, 96), (92, 108, 160), (50, 58, 96), (250, 220, 130, 255), 20, 4).save(out("assets", "ui", "button_hover.png"))
    rounded_gradient((96, 96), (30, 36, 60), (60, 72, 110), (250, 220, 130, 255), 20, 4).save(out("assets", "ui", "button_pressed.png"))
    rounded_gradient((96, 96), (70, 70, 74), (48, 48, 52), (110, 110, 110, 255), 20, 4).save(out("assets", "ui", "button_disabled.png"))
    p = rounded_gradient((64, 64), (28, 32, 50), (18, 20, 34), (186, 154, 86, 255), 14, 3)
    alpha = p.split()[3].point(lambda a: int(a * 0.9))
    p.putalpha(alpha)
    p.save(out("assets", "ui", "panel.png"))
    # facing arrow (points right)
    a = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    ImageDraw.Draw(a).polygon([(6, 22), (36, 22), (36, 8), (60, 32), (36, 56), (36, 42), (6, 42)],
                              fill=(255, 220, 90, 255), outline=(60, 40, 10, 255))
    a.save(out("assets", "ui", "arrow.png"))


# ---------------------------------------------------------------- backgrounds

def ridge(W, base, amp, seed, freq=1.0):
    rng = random.Random(seed)
    ph = [rng.random() * 6.28 for _ in range(4)]
    pts = []
    for x in range(0, W + 1, 8):
        t = x / W
        y = base - amp * (0.5 * math.sin(t * 6.0 * freq + ph[0]) + 0.3 * math.sin(t * 13.0 * freq + ph[1])
                          + 0.2 * math.sin(t * 29.0 * freq + ph[2]))
        pts.append((x, y))
    return pts


def sky(W, H, c1, c2):
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        d.line([(0, y), (W, y)], fill=mix(c1, c2, y / H))
    return img


def gen_backgrounds():
    W, H = 1920, 1080
    specs = {
        "title": ((24, 26, 62), (214, 128, 92), [(70, 52, 90), (48, 38, 70), (26, 22, 44)]),
        "camp": ((10, 14, 36), (52, 58, 96), [(36, 40, 70), (26, 30, 54), (16, 18, 34)]),
        "field": ((120, 170, 220), (226, 220, 190), [(120, 150, 130), (86, 124, 90), (60, 96, 60)]),
        "village": ((200, 120, 80), (250, 200, 140), [(150, 90, 70), (120, 70, 52), (80, 48, 40)]),
        "night": ((8, 10, 24), (40, 36, 70), [(30, 30, 50), (22, 22, 40), (14, 14, 26)]),
        "battle": ((26, 34, 56), (64, 86, 108), []),
    }
    for name, (c1, c2, layers) in specs.items():
        img = sky(W, H, c1, c2)
        d = ImageDraw.Draw(img)
        rng = random.Random(name)
        if name in ("camp", "night", "title"):
            for _ in range(160):
                x, y = rng.randint(0, W), rng.randint(0, int(H * 0.55))
                b = rng.randint(150, 255)
                d.point((x, y), fill=(b, b, b, 255))
            d.ellipse([1500, 120, 1620, 240], fill=(250, 240, 210, 255))
        for i, col in enumerate(layers):
            pts = ridge(W, H * (0.55 + i * 0.12), 90 - i * 18, f"{name}{i}", 1 + i * 0.4)
            d.polygon(pts + [(W, H), (0, H)], fill=col + (255,))
        if name == "camp":
            for tx in (420, 700, 1300):
                d.polygon([(tx - 110, 900), (tx, 740), (tx + 110, 900)], fill=(90, 70, 52, 255))
                d.polygon([(tx - 20, 900), (tx, 800), (tx + 20, 900)], fill=(40, 30, 24, 255))
            glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            ImageDraw.Draw(glow).ellipse([860, 760, 1100, 980], fill=(255, 150, 60, 110))
            img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(40)))
            d = ImageDraw.Draw(img)
            d.polygon([(950, 920), (980, 830), (1010, 920)], fill=(255, 180, 60, 255))
        if name == "village":
            for hx in (300, 560, 1350, 1600):
                d.rectangle([hx - 80, 820, hx + 80, 960], fill=(110, 80, 60, 255))
                d.polygon([(hx - 100, 830), (hx, 740), (hx + 100, 830)], fill=(70, 46, 40, 255))
                d.rectangle([hx - 20, 880, hx + 20, 960], fill=(40, 28, 24, 255))
        if name == "title":
            draw_scale(d, 960, 300, 300, (230, 196, 110, 255), 0.12)
        if name == "battle":
            for _ in range(60):
                x, y = rng.randint(0, W), rng.randint(0, H)
                d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(120, 140, 170, 255))
        img.convert("RGB").save(out("assets", "bg", f"{name}.png"))


def draw_scale(d, cx, cy, size, col, tilt):
    s = size / 300.0
    d.rectangle([cx - 8 * s, cy, cx + 8 * s, cy + 260 * s], fill=col)
    d.polygon([(cx - 70 * s, cy + 280 * s), (cx + 70 * s, cy + 280 * s), (cx + 30 * s, cy + 250 * s),
               (cx - 30 * s, cy + 250 * s)], fill=col)
    dx, dy = math.cos(tilt) * 200 * s, math.sin(tilt) * 200 * s
    d.line([(cx - dx, cy - dy), (cx + dx, cy + dy)], fill=col, width=max(3, int(10 * s)))
    d.ellipse([cx - 16 * s, cy - 16 * s, cx + 16 * s, cy + 16 * s], fill=col)
    for sx, sy in ((cx - dx, cy - dy), (cx + dx, cy + dy)):
        d.line([(sx, sy), (sx - 50 * s, sy + 110 * s)], fill=col, width=max(1, int(3 * s)))
        d.line([(sx, sy), (sx + 50 * s, sy + 110 * s)], fill=col, width=max(1, int(3 * s)))
        d.chord([sx - 70 * s, sy + 70 * s, sx + 70 * s, sy + 150 * s], 0, 180, fill=col)


# ---------------------------------------------------------------- icons

def icon_img(size, bg=True):
    S = 512
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg:
        g = rounded_gradient((S, S), (40, 52, 104), (16, 20, 44), (214, 180, 98, 255), 96, 14)
        img.alpha_composite(g)
    draw_scale(d, 256, 150, 300, (240, 204, 112, 255), 0.18)
    d.line([(256, 60), (256, 120)], fill=(220, 226, 240, 255), width=10)
    d.polygon([(240, 70), (256, 30), (272, 70)], fill=(220, 226, 240, 255))
    return img.resize((size, size), Image.LANCZOS)


def gen_icons():
    icon_img(512).save(out("icon.png"))
    icon_img(192).save(out("assets", "icons", "icon_192.png"))
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(icon_img(288, bg=False), (72, 72))
    fg.save(out("assets", "icons", "icon_fg_432.png"))
    sky(432, 432, (40, 52, 104), (16, 20, 44)).save(out("assets", "icons", "icon_bg_432.png"))


if __name__ == "__main__":
    gen_tiles()
    gen_fx()
    gen_units()
    gen_portraits()
    gen_ui()
    gen_backgrounds()
    gen_icons()
    print("assets generated in", ROOT)
