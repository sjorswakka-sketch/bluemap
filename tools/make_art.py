#!/usr/bin/env python3
"""Genereert alle pixel art van het spel in assets/ (16x16 per sprite).

Gebruik:  python3 tools/make_art.py      (Pillow nodig: pip install pillow)

Alles is zelfgemaakt voor dit project. Wil je andere art? Vervang gewoon de PNG's in assets/
door eigen bestanden met dezelfde indeling (zie README), de game-code hoeft dan niet te veranderen.
"""
import os
import random

from PIL import Image, ImageDraw, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets"))
T = 16


def c(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


OUTLINE = c("#1a1a2e")


# --- hulpfuncties -------------------------------------------------------------

def blank(w=T, h=T):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(img, x, y, col):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), col)


def rect(img, x0, y0, x1, y1, col):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, col)


def outline(img, col=OUTLINE):
    """Zet een rand van 1 pixel om alle gevulde pixels heen."""
    out = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < img.width and 0 <= ny < img.height and img.getpixel((nx, ny))[3] > 0:
                        out.putpixel((x, y), col)
                        break
    return out


def from_grid(rows, palette):
    h, w = len(rows), len(rows[0])
    img = blank(w, h)
    for y, row in enumerate(rows):
        assert len(row) == w, f"rij {y} heeft lengte {len(row)}, verwacht {w}: {row}"
        for x, ch in enumerate(row):
            if ch != ".":
                put(img, x, y, palette[ch])
    return img


def strip(frames, vertical=False):
    """Plakt losse frames aan elkaar tot een spritesheet."""
    w, h = frames[0].size
    sheet = blank(w, h * len(frames)) if vertical else blank(w * len(frames), h)
    for i, f in enumerate(frames):
        sheet.paste(f, (0, i * h) if vertical else (i * w, 0))
    return sheet


def grid_sheet(rows_of_frames):
    w, h = rows_of_frames[0][0].size
    sheet = blank(w * len(rows_of_frames[0]), h * len(rows_of_frames))
    for y, row in enumerate(rows_of_frames):
        for x, f in enumerate(row):
            sheet.paste(f, (x * w, y * h))
    return sheet


# --- tegels --------------------------------------------------------------------

GRASS, GRASS_D, GRASS_L = c("#5ca84a"), c("#468f3c"), c("#7cc65a")


def grass_tile(variant):
    img = blank()
    rect(img, 0, 0, 15, 15, GRASS)
    rnd = random.Random(100 + variant)
    for _ in range(8):
        put(img, rnd.randrange(16), rnd.randrange(16), GRASS_L if rnd.random() < 0.5 else GRASS_D)
    for _ in range(5 if variant == 2 else 3):
        x, y = rnd.randrange(2, 14), rnd.randrange(3, 15)
        put(img, x, y, GRASS_D)
        put(img, x - 1, y - 1, GRASS_D)
        put(img, x + 1, y - 1, GRASS_D)
    if variant == 1:  # bloemetjes
        for petal, (x, y) in zip(["#ffffff", "#ff8fb0", "#ffffff"], [(3, 4), (11, 9), (6, 13)]):
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                put(img, x + dx, y + dy, c(petal))
            put(img, x, y, c("#ffd83a"))
    return img


def tree_tile():
    img = grass_tile(0)
    d = ImageDraw.Draw(img)
    # stam
    rect(img, 6, 11, 9, 15, c("#6b4423"))
    rect(img, 9, 11, 9, 15, c("#4a2c12"))
    # kruin
    d.ellipse([1, 0, 14, 12], fill=c("#2f7d3f"), outline=c("#1b4d2a"))
    for x, y in [(4, 2), (5, 2), (3, 3), (4, 3), (6, 1), (7, 1), (4, 4)]:
        put(img, x, y, c("#52b05e"))
    for x, y in [(10, 8), (11, 7), (9, 9), (8, 10), (11, 9), (6, 9), (7, 10)]:
        put(img, x, y, c("#256a35"))
    for x, y in [(8, 4), (9, 3)]:
        put(img, x, y, c("#3d9a4d"))
    return img


def water_tile():
    img = blank()
    rect(img, 0, 0, 15, 15, c("#3c82d6"))
    for x, y in [(2, 3), (3, 3), (4, 3), (9, 7), (10, 7), (11, 7), (4, 12), (5, 12), (6, 12)]:
        put(img, x, y, c("#8cc4f7"))
    for x, y in [(8, 3), (9, 3), (1, 8), (2, 8), (11, 13), (12, 13)]:
        put(img, x, y, c("#2f6cb8"))
    return img


def path_tile():
    img = blank()
    rect(img, 0, 0, 15, 15, c("#d9bb8a"))
    rnd = random.Random(7)
    for _ in range(14):
        put(img, rnd.randrange(16), rnd.randrange(16), rnd.choice([c("#c19e6c"), c("#ead0a5")]))
    for x, y in [(3, 4), (4, 4), (11, 10), (12, 10), (12, 11), (6, 13)]:
        put(img, x, y, c("#a98556"))
    return img


def stone_tile():
    img = blank()
    rect(img, 0, 0, 15, 15, c("#8f95aa"))
    mortar, light = c("#5d637a"), c("#aab0c4")
    for row, y in enumerate((0, 4, 8, 12)):
        rect(img, 0, y + 3, 15, y + 3, mortar)           # voeg onder de rij stenen
        rect(img, 0, y, 15, y, light)                    # lichte bovenrand
        for x in ((3, 11) if row % 2 else (7, 15)):      # voegen om en om, elke 8 pixels
            rect(img, x, y, x, y + 2, mortar)
    return img


# --- personages ----------------------------------------------------------------

HAIR, HAIR_D = c("#7a4a24"), c("#4f2e14")
SKIN, SKIN_D = c("#f6cfa6"), c("#dba57c")
TUN, TUN_D, TUN_L = c("#3f7fe0"), c("#2c58aa"), c("#86b9ff")
BELT, GOLD = c("#6b4423"), c("#ffd83a")
PANTS, BOOT = c("#3a3f66"), c("#5a3a1c")


def legs_front(img, step):
    left_up = step == 1
    right_up = step == 2
    rect(img, 5, 12, 6, 12 if left_up else 13, PANTS)
    rect(img, 9, 12, 10, 12 if right_up else 13, PANTS)
    rect(img, 5, 13 if left_up else 14, 6, 13 if left_up else 14, BOOT)
    rect(img, 9, 13 if right_up else 14, 10, 13 if right_up else 14, BOOT)


def body_front(img, buckle):
    rect(img, 4, 8, 11, 10, TUN)
    rect(img, 3, 8, 3, 9, TUN)
    rect(img, 12, 8, 12, 9, TUN)
    put(img, 3, 10, SKIN)
    put(img, 12, 10, SKIN)
    rect(img, 11, 8, 11, 10, TUN_D)
    rect(img, 12, 8, 12, 9, TUN_D)
    put(img, 5, 8, TUN_L)
    put(img, 6, 8, TUN_L)
    rect(img, 4, 11, 11, 11, BELT)
    if buckle:
        rect(img, 7, 11, 8, 11, GOLD)


def player(direction, step):
    img = blank()
    if direction == "down":
        rect(img, 4, 1, 11, 4, HAIR)
        rect(img, 5, 5, 10, 7, SKIN)
        rect(img, 4, 5, 4, 6, HAIR)
        rect(img, 11, 5, 11, 6, HAIR)
        rect(img, 5, 7, 10, 7, SKIN_D)
        put(img, 6, 6, OUTLINE)
        put(img, 9, 6, OUTLINE)
        put(img, 4, 4, HAIR_D)
        put(img, 11, 4, HAIR_D)
        put(img, 7, 2, c("#9a6334"))
        put(img, 8, 2, c("#9a6334"))
        body_front(img, buckle=True)
        legs_front(img, step)
    elif direction == "up":
        rect(img, 4, 1, 11, 6, HAIR)
        rect(img, 4, 5, 11, 6, HAIR_D)
        rect(img, 6, 7, 9, 7, SKIN_D)
        put(img, 7, 2, c("#9a6334"))
        put(img, 8, 2, c("#9a6334"))
        body_front(img, buckle=False)
        legs_front(img, step)
    else:  # rechts
        rect(img, 4, 1, 11, 3, HAIR)
        rect(img, 4, 4, 6, 6, HAIR)
        rect(img, 7, 4, 11, 7, SKIN)
        rect(img, 7, 7, 10, 7, SKIN_D)
        put(img, 9, 5, OUTLINE)
        put(img, 11, 6, SKIN_D)
        put(img, 5, 5, HAIR_D)
        put(img, 6, 2, c("#9a6334"))
        put(img, 7, 2, c("#9a6334"))
        rect(img, 5, 8, 10, 10, TUN)
        rect(img, 10, 8, 10, 10, TUN_D)
        rect(img, 7, 9, 8, 9, TUN_L)
        put(img, 8, 10, SKIN)
        rect(img, 5, 11, 10, 11, BELT)
        put(img, 9, 11, GOLD)
        if step == 0:
            back, front = (6, 7), (8, 9)
        elif step == 1:
            back, front = (5, 6), (9, 10)
        else:
            back, front = (7, 8), (7, 8)
        rect(img, back[0], 12, back[1], 13, PANTS)
        rect(img, front[0], 12, front[1], 13, PANTS)
        rect(img, back[0], 13 if step == 2 else 14, back[1], 13 if step == 2 else 14, BOOT)
        rect(img, front[0], 14, front[1], 14, BOOT)
    return outline(img)


def player_sheet():
    rows = []
    for direction in ("down", "up", "right"):
        rows.append([player(direction, s) for s in range(3)])
    rows.append([ImageOps.mirror(f) for f in rows[2]])  # links = gespiegeld rechts
    return grid_sheet(rows)


SL, SL_D, SL_L, SL_OUT = c("#5fd36b"), c("#3a9e4c"), c("#b9f7bf"), c("#1f6b34")


def slime(frame, angry):
    img = blank()
    x0, y0, x1, y1 = [(2, 6, 13, 14), (3, 4, 12, 14)][frame]
    ImageDraw.Draw(img).ellipse([x0, y0, x1, y1], fill=SL)
    for y in range(y1 - 2, y1 + 1):
        for x in range(img.width):
            if img.getpixel((x, y))[3] > 0:
                put(img, x, y, SL_D)
    for dx, dy in ((3, 2), (4, 2), (3, 3)):
        put(img, x0 + dx, y0 + dy, SL_L)
    ey = y0 + 5
    lx, rx = x0 + 3, x1 - 3
    for x in (lx, rx):
        put(img, x, ey, OUTLINE)
        put(img, x, ey + 1, OUTLINE)
    if angry:
        put(img, lx - 1, ey - 2, OUTLINE)
        put(img, lx, ey - 1, OUTLINE)
        put(img, rx + 1, ey - 2, OUTLINE)
        put(img, rx, ey - 1, OUTLINE)
    return outline(img, SL_OUT)


ROBE, ROBE_D = c("#6a3fb5"), c("#4b2a85")
HAT, HAT_D = c("#7b49c7"), c("#52308f")
BEARD, BEARD_D = c("#f2f2f7"), c("#c4c6d6")
CRY, CRY_D, CRY_L, CRY_OUT = c("#4cc3ff"), c("#2d9be6"), c("#a8e8ff"), c("#14487a")


def wizard():
    img = blank()
    rect(img, 7, 1, 8, 1, HAT)
    rect(img, 6, 2, 9, 2, HAT)
    rect(img, 5, 3, 10, 3, GOLD)
    rect(img, 3, 4, 12, 4, HAT_D)
    rect(img, 4, 4, 11, 4, HAT)
    put(img, 8, 2, GOLD)
    rect(img, 5, 5, 10, 7, SKIN)
    put(img, 6, 6, OUTLINE)
    put(img, 9, 6, OUTLINE)
    put(img, 7, 7, SKIN_D)
    put(img, 8, 7, SKIN_D)
    # mantel
    rect(img, 4, 8, 11, 11, ROBE)
    rect(img, 3, 12, 12, 14, ROBE)
    rect(img, 10, 8, 11, 11, ROBE_D)
    rect(img, 11, 12, 12, 14, ROBE_D)
    rect(img, 3, 12, 12, 12, ROBE_D)
    rect(img, 4, 11, 11, 11, GOLD)
    rect(img, 3, 9, 3, 10, ROBE_D)
    put(img, 3, 11, SKIN)
    # baard
    rect(img, 5, 8, 10, 9, BEARD)
    rect(img, 6, 10, 9, 10, BEARD)
    rect(img, 7, 11, 8, 11, BEARD)
    rect(img, 9, 8, 10, 10, BEARD_D)
    put(img, 10, 9, BEARD)
    # staf met kristal
    rect(img, 13, 4, 13, 14, BELT)
    put(img, 12, 10, ROBE_D)
    put(img, 12, 11, SKIN)
    rect(img, 13, 1, 13, 3, CRY)
    put(img, 13, 1, CRY_L)
    return outline(img)


# --- voorwerpen ----------------------------------------------------------------

def coin(width):
    img = blank()
    d = ImageDraw.Draw(img)
    x0, x1 = 8 - width // 2, 8 + width // 2 - 1
    if width >= 4:
        d.ellipse([x0, 4, x1, 11], fill=GOLD, outline=c("#c98f12"))
        put(img, x0 + 1, 5, c("#fff3a6"))
    else:
        rect(img, x0, 4, x1, 11, c("#c98f12"))
    return outline(img, c("#7a4a0d"))


HEART_PAL = {"r": c("#ff4d6a"), "R": c("#c21f45"), "p": c("#ffa3b5")}
HEART_ROWS = [
    "..rrr.rrr..",
    ".rpprrrrrR.",
    "rpprrrrrrrR",
    "rrrrrrrrrrR",
    "rrrrrrrrrrR",
    ".rrrrrrrrR.",
    "..rrrrrrR..",
    "...rrrrR...",
    "....rrR....",
    ".....R.....",
]
HEART_EMPTY = {"r": c("#4a4f66"), "R": c("#33384d"), "p": c("#5d637c")}


def heart(palette, edge):
    grid = from_grid(HEART_ROWS, palette)
    padded = blank(grid.width + 2, grid.height + 2)  # ruimte voor de rand
    padded.paste(grid, (1, 1), grid)
    return outline(padded, edge)


def crystal(sparkle):
    img = blank()
    d = ImageDraw.Draw(img)
    d.polygon([(8, 1), (12, 6), (8, 14), (4, 6)], fill=CRY)
    d.polygon([(8, 1), (12, 6), (8, 14)], fill=CRY_D)
    d.polygon([(8, 3), (10, 6), (8, 7), (6, 6)], fill=CRY_L)
    out = outline(img, CRY_OUT)
    if sparkle:
        for x, y in [(2, 3), (1, 3), (3, 3), (2, 2), (2, 4), (14, 9), (13, 9), (15, 9), (14, 8), (14, 10)]:
            put(out, x, y, c("#ffffff"))
    return out


def centered(img):
    out = blank()
    out.paste(img, ((T - img.width) // 2, (T - img.height) // 2), img)
    return out


# --- alles opslaan -------------------------------------------------------------

def main():
    os.makedirs(OUT, exist_ok=True)
    sheets = {
        # volgorde van tegels: zie enum Tile in scripts/main.gd
        "tiles": strip([grass_tile(0), tree_tile(), water_tile(), path_tile(), stone_tile(),
                        grass_tile(1), grass_tile(2)]),
        "player": player_sheet(),                       # 3 kolommen (stil, stap, stap) x 4 rijen (onder, boven, rechts, links)
        "slime": strip([slime(0, False), slime(1, False), slime(0, True), slime(1, True)]),
        "npc": wizard(),
        "coin": strip([coin(6), coin(4), coin(2), coin(4)]),
        "heart": centered(heart(HEART_PAL, c("#5a0f1f"))),
        "crystal": strip([crystal(False), crystal(True)]),
        "ui_heart": strip([heart(HEART_PAL, c("#5a0f1f")), heart(HEART_EMPTY, c("#1f2233"))]),
    }
    for name, img in sheets.items():
        img.save(os.path.join(OUT, name + ".png"))
        print(f"assets/{name}.png  {img.width}x{img.height}")

    # Voorbeeldplaatje om het resultaat snel te bekijken (niet in het spel gebruikt).
    if os.environ.get("PREVIEW"):
        names = list(sheets)
        scale = 8
        w = max(sheets[n].width for n in names) * scale
        h = sum(sheets[n].height * scale + 12 for n in names)
        sheet = Image.new("RGBA", (w, h), (70, 74, 90, 255))
        y = 0
        for n in names:
            big = sheets[n].resize((sheets[n].width * scale, sheets[n].height * scale), Image.NEAREST)
            sheet.paste(big, (0, y), big)
            y += big.height + 12
        sheet.save(os.environ["PREVIEW"])


if __name__ == "__main__":
    main()
