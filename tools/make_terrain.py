#!/usr/bin/env python3
"""보드 바탕 지형과 꾸밈 그림을 만든다. (직접 그린 도트 그림, 외부 그림을 쓰지 않는다)

    python3 tools/make_terrain.py

assets/terrain/<테마>.png       : 이어 붙여도 티가 안 나는 128x128 바탕
assets/terrain/<테마>_deco.png  : 32x32 꾸밈 그림 4개가 가로로 붙은 시트(나무, 집, 바위 등)
테마 이름은 data/boards/*.json의 theme.terrain과 같다.
"""
import math
import os
import random
from PIL import Image, ImageDraw

SIZE = 128
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "terrain")


def hexc(text):
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def tile_noise(rng, cells):
    """가장자리가 이어지는 부드러운 무늬(0~1)."""
    grid = [[rng.random() for _ in range(cells)] for _ in range(cells)]
    out = [[0.0] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            fx, fy = x / SIZE * cells, y / SIZE * cells
            x0, y0 = int(fx), int(fy)
            tx, ty = fx - x0, fy - y0
            tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
            a = grid[y0 % cells][x0 % cells]
            b = grid[y0 % cells][(x0 + 1) % cells]
            c = grid[(y0 + 1) % cells][x0 % cells]
            d = grid[(y0 + 1) % cells][(x0 + 1) % cells]
            out[y][x] = (a + (b - a) * tx) * (1 - ty) + (c + (d - c) * tx) * ty
    return out


def layered(rng):
    big, mid, fine = tile_noise(rng, 3), tile_noise(rng, 7), tile_noise(rng, 16)
    return [[big[y][x] * 0.55 + mid[y][x] * 0.3 + fine[y][x] * 0.15 for x in range(SIZE)] for y in range(SIZE)]


def make_ground(theme, rng):
    """base: 어두운→밝은 바탕 색 띠, patch: 군데군데 다른 땅(흙·물·용암), speck: 점(꽃·자갈)."""
    base = [hexc(c) for c in theme["base"]]
    patch = [hexc(c) for c in theme["patch"]]
    field, spots = layered(rng), layered(rng)
    image = Image.new("RGB", (SIZE, SIZE))
    pixels = image.load()
    for y in range(SIZE):
        for x in range(SIZE):
            value = field[y][x]
            index = min(len(base) - 1, int(value * len(base) * 1.25 - 0.1 * len(base)))
            color = base[max(0, index)]
            spot = spots[y][x]
            if spot > theme["patch_at"]:
                edge = spot < theme["patch_at"] + 0.025
                color = patch[0] if edge else patch[1 + int((spot * 40 + x * 0.0) % (len(patch) - 1))] if len(patch) > 2 else patch[-1]
                if theme.get("waves") and not edge and (y + int(math.sin(x / 5.0) * 2)) % 7 == 0:
                    color = patch[0]
            pixels[x, y] = color
    for _ in range(theme.get("speck_count", 90)):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        if spots[y][x] > theme["patch_at"] - 0.02:
            continue
        color = hexc(rng.choice(theme["speck"]))
        pixels[x, y] = color
        if rng.random() < 0.4:
            pixels[(x + 1) % SIZE, y] = color
    if theme.get("cracks"):
        crack = hexc(theme["cracks"])
        for _ in range(26):
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            for _step in range(rng.randrange(6, 16)):
                pixels[x % SIZE, y % SIZE] = crack
                x += rng.choice([-1, 0, 1, 1])
                y += rng.choice([-1, 0, 1])
    return image


# ---------------------------------------------------------------- 꾸밈 그림 (32x32)

def blob(draw, box, dark, mid, light):
    x0, y0, x1, y1 = box
    draw.ellipse(box, fill=dark)
    draw.ellipse((x0 + 1, y0 + 1, x1 - 1, y1 - 2), fill=mid)
    draw.ellipse((x0 + 3, y0 + 2, x0 + (x1 - x0) // 2, y0 + (y1 - y0) // 2), fill=light)


def shadow(draw, cx=16, width=20):
    draw.ellipse((cx - width // 2, 26, cx + width // 2, 31), fill=(0, 0, 0, 70))


def tree(draw, leaf, trunk="6b4423"):
    dark, mid, light = [hexc(c) for c in leaf]
    shadow(draw)
    draw.rectangle((14, 20, 17, 28), fill=hexc(trunk))
    blob(draw, (4, 4, 27, 23), dark, mid, light)
    blob(draw, (9, 1, 22, 13), dark, mid, light)


def pine(draw, leaf, snow=None):
    dark, mid, light = [hexc(c) for c in leaf]
    shadow(draw, width=16)
    draw.rectangle((15, 24, 17, 29), fill=hexc("5a3a1e"))
    for top, half in ((2, 6), (9, 9), (16, 11)):
        draw.polygon([(16, top), (16 - half, top + 11), (16 + half, top + 11)], fill=dark)
        draw.polygon([(16, top + 1), (16 - half + 2, top + 10), (16 + half - 3, top + 10)], fill=mid)
        draw.line([(16, top + 2), (16 - half + 3, top + 9)], fill=light)
        if snow:
            draw.polygon([(16, top), (13, top + 4), (19, top + 4)], fill=hexc(snow))


def rock(draw, colors):
    dark, mid, light = [hexc(c) for c in colors]
    shadow(draw, width=22)
    draw.polygon([(5, 27), (8, 15), (15, 10), (23, 13), (27, 27)], fill=dark)
    draw.polygon([(7, 26), (9, 16), (15, 12), (21, 14), (24, 26)], fill=mid)
    draw.polygon([(10, 17), (15, 13), (18, 15), (12, 20)], fill=light)


def house(draw, roof, wall="e8d8b0"):
    dark, mid = hexc(roof[0]), hexc(roof[1])
    shadow(draw, width=24)
    draw.rectangle((7, 16, 24, 28), fill=hexc(wall))
    draw.rectangle((7, 16, 24, 17), fill=hexc("b8a880"))
    draw.polygon([(4, 17), (16, 5), (27, 17)], fill=dark)
    draw.polygon([(7, 16), (16, 7), (24, 16)], fill=mid)
    draw.rectangle((14, 21, 17, 28), fill=hexc("6b4423"))
    draw.rectangle((9, 20, 11, 22), fill=hexc("7fc8ff"))
    draw.rectangle((20, 20, 22, 22), fill=hexc("7fc8ff"))


def cactus(draw):
    shadow(draw, width=14)
    dark, mid = hexc("2f6b3a"), hexc("4f9a52")
    draw.rounded_rectangle((13, 6, 19, 29), 3, fill=dark)
    draw.rounded_rectangle((14, 7, 17, 28), 2, fill=mid)
    draw.rounded_rectangle((7, 12, 11, 20), 2, fill=dark)
    draw.rectangle((10, 17, 14, 20), fill=dark)
    draw.rounded_rectangle((21, 9, 25, 17), 2, fill=dark)
    draw.rectangle((18, 14, 22, 17), fill=dark)


def palm(draw):
    shadow(draw, width=16)
    draw.line([(16, 29), (15, 20), (17, 11)], fill=hexc("8a6a3a"), width=3)
    for dx, dy in ((-11, 3), (-7, -4), (0, -7), (8, -4), (11, 3)):
        draw.line([(17, 11), (17 + dx, 11 + dy)], fill=hexc("2f7a3a"), width=3)
        draw.line([(17, 10), (17 + dx, 10 + dy)], fill=hexc("58b060"), width=1)


def tent(draw, colors):
    dark, mid = hexc(colors[0]), hexc(colors[1])
    shadow(draw, width=24)
    draw.polygon([(4, 28), (16, 8), (28, 28)], fill=dark)
    draw.polygon([(7, 27), (16, 11), (20, 27)], fill=mid)
    draw.polygon([(14, 28), (16, 19), (18, 28)], fill=hexc("3a2a1a"))


def pillar(draw, broken=False):
    dark, mid, light = hexc("7d776a"), hexc("b5ad98"), hexc("d9d2bd")
    shadow(draw, width=18)
    top = 14 if broken else 5
    draw.rectangle((11, top, 21, 27), fill=dark)
    draw.rectangle((12, top, 18, 27), fill=mid)
    draw.rectangle((13, top + 1, 14, 26), fill=light)
    draw.rectangle((9, 26, 23, 29), fill=dark)
    if broken:
        draw.polygon([(11, 14), (14, 10), (17, 15), (21, 12), (21, 15), (11, 15)], fill=mid)
    else:
        draw.rectangle((9, 3, 23, 6), fill=mid)


def mushroom(draw, cap=("a8323e", "e05555")):
    shadow(draw, width=16)
    draw.rectangle((14, 17, 18, 28), fill=hexc("eadfc8"))
    draw.pieslice((6, 6, 26, 28), 180, 360, fill=hexc(cap[0]))
    draw.pieslice((8, 8, 24, 26), 180, 360, fill=hexc(cap[1]))
    for x, y in ((11, 13), (17, 10), (21, 14)):
        draw.rectangle((x, y, x + 1, y + 1), fill=(255, 255, 255))


def cloud(draw, tint="ffffff"):
    color = hexc(tint)
    shade = tuple(int(c * 0.82) for c in color)
    for box in ((3, 14, 17, 27), (11, 8, 25, 26), (18, 15, 30, 27)):
        draw.ellipse(box, fill=shade)
    for box in ((4, 13, 16, 24), (12, 7, 24, 23), (19, 14, 29, 24)):
        draw.ellipse(box, fill=color)


def pool(draw, colors):
    dark, mid, light = [hexc(c) for c in colors]
    draw.ellipse((3, 12, 29, 28), fill=dark)
    draw.ellipse((5, 13, 27, 26), fill=mid)
    draw.line([(9, 18), (15, 18)], fill=light)
    draw.line([(17, 22), (23, 22)], fill=light)


def dead_tree(draw):
    shadow(draw, width=14)
    color = hexc("3a2a22")
    draw.line([(16, 29), (16, 12)], fill=color, width=3)
    for end in ((8, 6), (23, 8), (11, 14), (22, 15)):
        draw.line([(16, 16), end], fill=color, width=2)


def snowman(draw):
    shadow(draw, width=18)
    draw.ellipse((8, 15, 24, 30), fill=hexc("c8d8e8"))
    draw.ellipse((9, 15, 23, 28), fill=(255, 255, 255))
    draw.ellipse((11, 6, 21, 17), fill=(255, 255, 255))
    draw.rectangle((14, 10, 14, 10), fill=(20, 20, 30))
    draw.rectangle((18, 10, 18, 10), fill=(20, 20, 30))
    draw.rectangle((16, 12, 18, 12), fill=hexc("e8890c"))
    draw.rectangle((11, 4, 21, 6), fill=hexc("b8323a"))


def reeds(draw):
    for x, height in ((9, 14), (13, 20), (17, 17), (21, 22), (24, 13)):
        draw.line([(x, 29), (x + 1, 29 - height)], fill=hexc("4f8a3a"), width=2)
        draw.rectangle((x, 27 - height, x + 2, 31 - height), fill=hexc("7a4a22"))


THEMES = {
    "grass": {
        "base": ["3f8a35", "4c9c3c", "5fb347", "74c654"], "patch": ["8a6a3a", "a8824a", "b8925a"], "patch_at": 0.66,
        "speck": ["ffe066", "ffffff", "f08aa8", "2f7a2c"],
        "deco": [lambda d: tree(d, ("1f5a24", "2f7a2c", "58b04a")), lambda d: house(d, ("8a2a22", "c2413a")),
                 lambda d: pine(d, ("17481f", "24682c", "3f9a44")), lambda d: rock(d, ("5a5a5a", "8a8a82", "b8b8ae"))],
    },
    "desert": {
        "base": ["c79a4a", "d8ad5c", "e6c074", "f0d08a"], "patch": ["a87a34", "b8873c", "c08f44"], "patch_at": 0.7,
        "speck": ["a87a34", "f8e0a8", "8a6a2a"],
        "deco": [cactus, palm, lambda d: rock(d, ("8a6a3a", "b8935a", "e0c088")), lambda d: tent(d, ("8a2a22", "e8d8b0"))],
    },
    "forest": {
        "base": ["1f4f26", "27602d", "327536", "3f8a40"], "patch": ["16381c", "1a4220", "1f4a24"], "patch_at": 0.62,
        "speck": ["9ad06a", "e8d060", "174018"],
        "deco": [lambda d: tree(d, ("123a18", "1f5a24", "3f8a40")), lambda d: pine(d, ("0f3016", "1a4a20", "2f7a34")),
                 mushroom, lambda d: tree(d, ("2a4a12", "4a7a1c", "7aa838"))],
    },
    "snow": {
        "base": ["c2d4e6", "d4e2f0", "e6eef8", "f6faff"], "patch": ["8fb8dc", "a8cce8", "b8d8f0"], "patch_at": 0.7,
        "speck": ["ffffff", "a8c0d8", "8fb0cc"],
        "deco": [lambda d: pine(d, ("1a4a3a", "2a6a52", "4a9a7a"), "ffffff"), snowman,
                 lambda d: rock(d, ("6f8fae", "a8c8e0", "e8f4ff")), lambda d: house(d, ("d8e4f0", "ffffff"), "c8a878")],
    },
    "river": {
        "base": ["3a8a5a", "479a66", "58ad74", "6cc084"], "patch": ["c8e8f0", "2f7fc0", "3a8fd0"], "patch_at": 0.6,
        "waves": True, "speck": ["ffe066", "ffffff", "2f7a4a"],
        "deco": [reeds, lambda d: tree(d, ("1f5a3a", "2f7a52", "58b07a")),
                 lambda d: rock(d, ("5a6a6a", "8a9a98", "b8c8c4")), lambda d: house(d, ("1f5a8a", "3a8fd0"))],
    },
    "ruins": {
        "base": ["6a6558", "787364", "878170", "969080"], "patch": ["4a5a3a", "55683f", "607548"], "patch_at": 0.7,
        "speck": ["a8a290", "5a5548", "7a9a50"], "cracks": "4a463c",
        "deco": [pillar, lambda d: pillar(d, True), lambda d: rock(d, ("5a5548", "8a8472", "b5ad98")),
                 lambda d: tree(d, ("2a4a22", "3f6a30", "6a9a4a"))],
    },
    "sky": {
        "base": ["4a78d0", "5a8ae0", "6c9cec", "80aef4"], "patch": ["d8e8ff", "f0f6ff", "ffffff"], "patch_at": 0.68,
        "speck": ["ffffff", "c8dcff"], "speck_count": 40,
        "deco": [cloud, lambda d: cloud(d, "e8f0ff"), lambda d: rock(d, ("5a6a9a", "8a9ad0", "c0ccf0")),
                 lambda d: tree(d, ("2a6a5a", "3f9a80", "7ad0b0"))],
    },
    "volcano": {
        "base": ["3a2420", "4a2e28", "5a3830", "6a4238"], "patch": ["ffd24a", "e8501c", "ff7a1c"], "patch_at": 0.72,
        "speck": ["2a1a16", "8a5a48", "ff9a3a"], "cracks": "1f1210",
        "deco": [dead_tree, lambda d: rock(d, ("2a1a16", "5a3a30", "8a5a48")),
                 lambda d: pool(d, ("8a2a0c", "e8501c", "ffd24a")), lambda d: rock(d, ("3a2420", "6a4238", "a87058"))],
    },
}


# ---------------------------------------------------------------- 칸 위의 적 그림 (32x32)

def monster_beast(d):
    shadow(d, width=22)
    dark, mid, light = hexc("5a3a1e"), hexc("8a5a2e"), hexc("b8834a")
    d.ellipse((5, 14, 25, 27), fill=dark)
    d.ellipse((6, 14, 24, 25), fill=mid)
    d.ellipse((15, 7, 28, 19), fill=dark)
    d.ellipse((16, 8, 27, 18), fill=mid)
    d.polygon([(17, 9), (18, 3), (21, 8)], fill=dark)
    d.polygon([(24, 8), (27, 3), (27, 10)], fill=dark)
    d.rectangle((20, 12, 21, 13), fill=(255, 230, 80))
    d.rectangle((25, 12, 26, 13), fill=(255, 230, 80))
    d.rectangle((22, 16, 26, 16), fill=(255, 255, 255))
    for x in (8, 12, 18, 22):
        d.rectangle((x, 25, x + 2, 29), fill=dark)
    d.line([(6, 18), (2, 12)], fill=dark, width=2)
    d.line([(9, 16), (20, 16)], fill=light)


def monster_soldier(d):
    shadow(d, width=18)
    armor, trim, skin = hexc("5a6a8a"), hexc("8a9ac0"), hexc("e0b890")
    d.rectangle((11, 14, 20, 26), fill=armor)
    d.rectangle((12, 15, 15, 24), fill=trim)
    d.rectangle((11, 26, 14, 29), fill=hexc("3a2a1e"))
    d.rectangle((17, 26, 20, 29), fill=hexc("3a2a1e"))
    d.ellipse((11, 5, 20, 14), fill=skin)
    d.pieslice((10, 3, 21, 14), 180, 360, fill=armor)
    d.rectangle((10, 8, 21, 9), fill=trim)
    d.rectangle((13, 10, 14, 11), fill=(20, 20, 30))
    d.rectangle((17, 10, 18, 11), fill=(20, 20, 30))
    d.line([(25, 3), (25, 29)], fill=hexc("7a4a22"), width=2)
    d.polygon([(25, 0), (22, 6), (28, 6)], fill=hexc("d8dce8"))
    d.ellipse((3, 14, 12, 25), fill=hexc("8a2a22"))
    d.ellipse((5, 16, 10, 23), fill=hexc("c2413a"))


def monster_golem(d):
    shadow(d, width=24)
    dark, mid, light = hexc("4a4a52"), hexc("7a7a84"), hexc("a8a8b4")
    d.rectangle((8, 11, 23, 26), fill=dark)
    d.rectangle((9, 12, 21, 24), fill=mid)
    d.rectangle((10, 13, 14, 16), fill=light)
    d.rectangle((11, 3, 20, 11), fill=dark)
    d.rectangle((12, 4, 19, 10), fill=mid)
    d.rectangle((13, 6, 14, 7), fill=(120, 255, 255))
    d.rectangle((17, 6, 18, 7), fill=(120, 255, 255))
    d.rectangle((3, 12, 8, 23), fill=dark)
    d.rectangle((23, 12, 28, 23), fill=dark)
    d.rectangle((4, 13, 6, 21), fill=mid)
    d.rectangle((24, 13, 26, 21), fill=mid)
    d.rectangle((9, 26, 14, 29), fill=dark)
    d.rectangle((17, 26, 22, 29), fill=dark)
    d.line([(15, 14), (17, 19), (14, 23)], fill=dark)


def monster_spirit(d):
    shadow(d, width=14)
    dark, mid, light = hexc("3a5ad0"), hexc("6a9aff"), hexc("c8e0ff")
    d.polygon([(16, 1), (25, 12), (26, 22), (22, 28), (19, 24), (16, 29), (13, 24), (10, 28), (6, 22), (7, 12)], fill=dark)
    d.polygon([(16, 4), (23, 13), (24, 21), (21, 25), (19, 21), (16, 25), (13, 21), (11, 25), (8, 21), (9, 13)], fill=mid)
    d.ellipse((11, 8, 17, 14), fill=light)
    d.rectangle((12, 14, 14, 17), fill=(20, 20, 60))
    d.rectangle((18, 14, 20, 17), fill=(20, 20, 60))
    d.rectangle((14, 20, 18, 21), fill=(20, 20, 60))


def monster_bird(d):
    shadow(d, width=18)
    dark, mid, light = hexc("7a2a8a"), hexc("b05ac8"), hexc("e0a8f0")
    d.polygon([(16, 10), (1, 4), (4, 16), (12, 20)], fill=dark)
    d.polygon([(16, 10), (31, 4), (28, 16), (20, 20)], fill=dark)
    d.polygon([(15, 11), (4, 7), (6, 14), (12, 18)], fill=mid)
    d.polygon([(17, 11), (28, 7), (26, 14), (20, 18)], fill=mid)
    d.ellipse((11, 9, 21, 25), fill=dark)
    d.ellipse((12, 10, 20, 23), fill=mid)
    d.ellipse((13, 11, 17, 16), fill=light)
    d.rectangle((13, 13, 14, 14), fill=(20, 20, 30))
    d.rectangle((18, 13, 19, 14), fill=(20, 20, 30))
    d.polygon([(15, 16), (17, 16), (16, 20)], fill=(255, 190, 40))
    d.line([(14, 25), (13, 29)], fill=(255, 190, 40))
    d.line([(18, 25), (19, 29)], fill=(255, 190, 40))


def monster_hazard(d):
    shadow(d, width=22)
    d.polygon([(16, 2), (30, 27), (2, 27)], fill=hexc("7a1a14"))
    d.polygon([(16, 6), (27, 25), (5, 25)], fill=hexc("e0342b"))
    d.rectangle((15, 11, 17, 19), fill=(255, 255, 255))
    d.rectangle((15, 21, 17, 23), fill=(255, 255, 255))


def monster_boss(d):
    shadow(d, width=26)
    dark, mid, light = hexc("4a1a5a"), hexc("8a3aa8"), hexc("c88ae0")
    d.polygon([(6, 12), (2, 1), (11, 8)], fill=hexc("e8d8b0"))
    d.polygon([(26, 12), (30, 1), (21, 8)], fill=hexc("e8d8b0"))
    d.ellipse((4, 6, 28, 28), fill=dark)
    d.ellipse((5, 7, 27, 26), fill=mid)
    d.ellipse((8, 9, 16, 15), fill=light)
    d.polygon([(8, 14), (14, 15), (9, 18)], fill=(255, 220, 60))
    d.polygon([(24, 14), (18, 15), (23, 18)], fill=(255, 220, 60))
    d.rectangle((10, 15, 11, 16), fill=(120, 0, 0))
    d.rectangle((21, 15, 22, 16), fill=(120, 0, 0))
    d.rectangle((10, 21, 22, 23), fill=(30, 10, 30))
    for x in (11, 14, 17, 20):
        d.polygon([(x, 21), (x + 2, 21), (x + 1, 24)], fill=(255, 255, 255))
    d.polygon([(11, 6), (13, 1), (15, 5), (16, 0), (17, 5), (19, 1), (21, 6)], fill=(255, 200, 40))


MONSTERS = [monster_beast, monster_soldier, monster_golem, monster_spirit, monster_bird, monster_hazard, monster_boss]


def make_monsters():
    """칸 위에 서 있는 적 그림 시트. 순서: 짐승, 병사, 골렘, 정령, 새, 위험물, 보스 (scripts/ui/board_view.gd의 MONSTER_KINDS와 같다)."""
    sheet = Image.new("RGBA", (32 * len(MONSTERS), 32), (0, 0, 0, 0))
    for slot, painter in enumerate(MONSTERS):
        cell = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        painter(ImageDraw.Draw(cell))
        sheet.paste(cell, (slot * 32, 0))
    sheet.save(os.path.join(OUT, "monsters.png"))
    print("만듦: monsters")


def main():
    make_monsters()
    os.makedirs(OUT, exist_ok=True)
    for index, (name, theme) in enumerate(THEMES.items()):
        rng = random.Random(1000 + index)
        make_ground(theme, rng).save(os.path.join(OUT, name + ".png"))
        sheet = Image.new("RGBA", (32 * len(theme["deco"]), 32), (0, 0, 0, 0))
        for slot, painter in enumerate(theme["deco"]):
            cell = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
            painter(ImageDraw.Draw(cell))
            sheet.paste(cell, (slot * 32, 0))
        sheet.save(os.path.join(OUT, name + "_deco.png"))
        print("만듦:", name)


if __name__ == "__main__":
    main()
