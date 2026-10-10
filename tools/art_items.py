"""Voorwerpen (iconen), objecten in de wereld, projectielen en het hartje."""
from artlib import *  # noqa: F401,F403

GOLD, GOLD_D = c("#ffd83a"), c("#c98f12")


# --- munt, hartje, kristal (bestaand) ----------------------------------------------------------------

def coin(width):
    img = blank()
    x0, x1 = 8 - width // 2, 8 + width // 2 - 1
    if width >= 4:
        ellipse(img, (x0, 4, x1, 11), GOLD, GOLD_D)
        put(img, x0 + 1, 5, c("#fff3a6"))
    else:
        rect(img, x0, 4, x1, 11, GOLD_D)
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
    padded = blank(grid.width + 2, grid.height + 2)
    padded.paste(grid, (1, 1), grid)
    return outline(padded, edge)


CRYSTAL_PALETTES = {
    "blue": (c("#4cc3ff"), c("#2d9be6"), c("#a8e8ff"), c("#14487a")),
    "bos": (c("#5ee8c0"), c("#2fb894"), c("#c0fff0"), c("#14604a")),
    "ruine": (c("#6aa0ff"), c("#3a6fd0"), c("#cfe0ff"), c("#1a3a80")),
    "grot": (c("#b48cff"), c("#8a5ad8"), c("#e6d4ff"), c("#4a2a80")),
}


def crystal(sparkle=False, palette="blue"):
    body, dark, light, edge = CRYSTAL_PALETTES[palette]
    img = blank()
    polygon(img, [(8, 1), (12, 6), (8, 14), (4, 6)], body)
    polygon(img, [(8, 1), (12, 6), (8, 14)], dark)
    polygon(img, [(8, 3), (10, 6), (8, 7), (6, 6)], light)
    out = outline(img, edge)
    if sparkle:
        for x, y in [(2, 3), (1, 3), (3, 3), (2, 2), (2, 4), (14, 9), (13, 9), (15, 9), (14, 8), (14, 10)]:
            put(out, x, y, c("#ffffff"))
    return out


# --- iconen voor de voorwerpen (volgorde = icon-nummer in scripts/data/items.gd) ---------------------

def icon_potion():
    img = blank()
    ellipse(img, (3, 6, 12, 14), c("#d8f0ff"))
    ellipse(img, (4, 8, 11, 14), c("#e8324a"))
    rect(img, 4, 7, 11, 7, c("#d8f0ff"))
    rect(img, 6, 3, 9, 6, c("#d8f0ff"))
    rect(img, 6, 1, 9, 3, c("#8a5a2c"))
    put(img, 5, 9, c("#ff9aa8"))
    put(img, 5, 10, c("#ff9aa8"))
    put(img, 6, 4, c("#ffffff"))
    return outline(img)


def icon_gel():
    img = blank()
    ellipse(img, (3, 6, 12, 14), c("#6fe07a"))
    polygon(img, [(6, 7), (8, 2), (10, 7)], c("#6fe07a"))
    for x, y in [(5, 9), (6, 9), (5, 10)]:
        put(img, x, y, c("#c8ffcc"))
    rect(img, 4, 12, 11, 13, c("#3a9e4c"))
    return outline(img, c("#1f6b34"))


def icon_shard():
    img = blank()
    polygon(img, [(9, 1), (12, 6), (8, 14), (4, 9)], c("#4cc3ff"))
    polygon(img, [(9, 1), (12, 6), (8, 14)], c("#2d9be6"))
    polygon(img, [(9, 3), (10, 6), (8, 8), (7, 6)], c("#d8f6ff"))
    return outline(img, c("#14487a"))


def icon_key():
    img = blank()
    bronze, rust = c("#c8963c"), c("#8a5a2a")
    ellipse(img, (2, 2, 8, 8), bronze)
    ellipse(img, (4, 4, 6, 6), None)
    put(img, 5, 5, c(0, 0) if False else (0, 0, 0, 0))
    line(img, (7, 7), (13, 13), bronze, 2)
    line(img, (11, 11), (13, 9), bronze, 1)
    line(img, (12, 12), (14, 10), bronze, 1)
    put(img, 3, 3, c("#ffe29a"))
    put(img, 9, 9, rust)
    put(img, 11, 12, rust)
    return outline(img)


def icon_medallion():
    img = blank()
    chain = c("#a8a8b8")
    line(img, (4, 1), (8, 6), chain)
    line(img, (12, 1), (8, 6), chain)
    ellipse(img, (3, 6, 12, 15), c("#cfd6e4"), c("#8a92a8"))
    ellipse(img, (5, 8, 10, 13), c("#a4adc4"))
    rect(img, 7, 9, 8, 12, c("#4cc3ff"))
    put(img, 7, 9, c("#d8f6ff"))
    return outline(img)


def icon_boots():
    img = blank()
    brown, brown_l, brown_d = c("#8a5530"), c("#b0743c"), c("#5a3418")
    rect(img, 4, 2, 8, 9, brown)
    rect(img, 4, 2, 8, 3, brown_l)
    rect(img, 3, 9, 13, 13, brown)
    rect(img, 3, 12, 13, 13, brown_d)
    rect(img, 3, 9, 8, 10, brown_l)
    polygon(img, [(9, 3), (14, 1), (13, 6), (9, 6)], c("#f4f8ff"))
    put(img, 12, 3, c("#c8d8f0"))
    put(img, 11, 4, c("#c8d8f0"))
    return outline(img)


def icon_heart_container():
    img = from_grid(HEART_ROWS, HEART_PAL)
    padded = blank(14, 14)
    padded.paste(img, (1, 2), img)
    out = outline(padded, c("#f2c94c"))
    out = outline(out, c("#8a5a12"))
    for x, y in [(1, 1), (0, 1), (2, 1), (1, 0), (1, 2)]:
        put(out, x, y, c("#ffffff"))
    return centered(out)


def icon_sword(blade, blade_l, blade_d):
    img = blank()
    polygon(img, [(14, 1), (14, 4), (6, 10), (5, 9), (11, 2)], blade)
    line(img, (13, 2), (6, 9), blade_l)
    line(img, (13, 4), (7, 10), blade_d)
    polygon(img, [(3, 8), (8, 13), (7, 14), (2, 9)], c("#e0b84a"))  # kruisstuk
    line(img, (4, 11), (2, 13), c("#6b4423"), 2)
    put(img, 1, 14, c("#e0b84a"))
    return outline(img)


def icons():
    return [
        coin(6), icon_potion(), icon_gel(), icon_shard(), icon_key(), icon_medallion(), icon_boots(),
        icon_heart_container(), crystal(False, "bos"), crystal(False, "ruine"), crystal(False, "grot"),
        icon_sword(c("#c89860"), c("#e8c890"), c("#8a5a2c")),
        icon_sword(c("#b8c0d4"), c("#f0f4ff"), c("#7a849c")),
        icon_sword(c("#4cc3ff"), c("#d8f6ff"), c("#2d9be6")),
    ]


# --- objecten in de wereld -------------------------------------------------------------------------

def chest(opened):
    img = blank()
    wood, wood_l, wood_d = c("#a86a30"), c("#c88a48"), c("#6a3e1a")
    band = c("#e0b040")
    rect(img, 2, 7, 13, 14, wood)
    rect(img, 2, 12, 13, 14, wood_d)
    if opened:
        rect(img, 3, 1, 12, 5, wood_d)
        rect(img, 4, 2, 11, 4, wood)
        rect(img, 3, 6, 12, 9, c("#ffe58a"))
        rect(img, 5, 7, 10, 8, c("#fff6c0"))
    else:
        rect(img, 2, 4, 13, 8, wood_l)
        hline(img, 2, 13, 4, c("#e0a868"))
        hline(img, 2, 13, 8, wood_d)
    vline(img, 6, 4, 14, band) if not opened else vline(img, 6, 10, 14, band)
    vline(img, 9, 4, 14, band) if not opened else vline(img, 9, 10, 14, band)
    rect(img, 7, 8, 8, 10, c("#c98f12"))
    put(img, 7, 9, c("#2a2030"))
    return outline(img)


def sign():
    img = blank()
    rect(img, 7, 9, 8, 14, c("#6a4220"))
    rect(img, 1, 2, 14, 9, c("#c89860"))
    rect(img, 1, 2, 14, 3, c("#e0b878"))
    rect(img, 1, 8, 14, 9, c("#8a5a2c"))
    for y in (5, 7):
        hline(img, 3, 12, y, c("#5a3a1c"))
    return outline(img)


def gate():
    img = blank()
    iron, iron_l, iron_d = c("#5a5f6e"), c("#9aa0b4"), c("#2f3340")
    for x in (1, 5, 9, 13):
        rect(img, x, 0, x + 1, 15, iron)
        vline(img, x, 0, 15, iron_l)
        put(img, x, 0, c("#c0c8e0"))
    rect(img, 0, 3, 15, 4, iron_d)
    rect(img, 0, 11, 15, 12, iron_d)
    hline(img, 0, 15, 3, iron)
    hline(img, 0, 15, 11, iron)
    return outline(img)


def altar(frame):
    img = blank()
    rect(img, 3, 9, 12, 14, c("#9aa0b4"))
    rect(img, 2, 8, 13, 10, c("#c0c8e0"))
    rect(img, 3, 12, 12, 14, c("#7a809a"))
    for x in (5, 8, 11):
        vline(img, x, 11, 14, c("#7a809a"))
    cy = 0 if frame == 0 else 1
    polygon(img, [(8, 1 + cy), (11, 5 + cy), (8, 9 + cy), (5, 5 + cy)], c("#4cc3ff"))
    polygon(img, [(8, 1 + cy), (11, 5 + cy), (8, 9 + cy)], c("#2d9be6"))
    polygon(img, [(8, 2 + cy), (9, 5 + cy), (8, 6 + cy), (7, 5 + cy)], c("#d8f6ff"))
    out = outline(img)
    if frame == 1:
        for x, y in [(3, 3), (13, 6), (4, 7)]:
            put(out, x, y, c("#d8f6ff"))
    return out


def torch(frame):
    img = blank()
    rect(img, 7, 8, 8, 14, c("#7a4a24"))
    rect(img, 6, 7, 9, 8, c("#5a3418"))
    lean = 1 if frame else 0
    polygon(img, [(8 + lean, 1), (11, 5), (8, 8), (5, 5)], c("#ff8a2a"))
    polygon(img, [(8 + lean, 3), (10, 6), (8, 8), (6, 6)], c("#ffd83a"))
    put(img, 8, 6, c("#fff6c0"))
    return outline(img)


def projectile_arrow():
    img = blank()
    hline(img, 3, 12, 8, c("#d8c8a0"))
    polygon(img, [(11, 6), (15, 8), (11, 10)], c("#c0c8d8"))
    put(img, 2, 7, c("#ffffff"))
    put(img, 3, 6, c("#ffffff"))
    put(img, 2, 9, c("#ffffff"))
    put(img, 3, 10, c("#ffffff"))
    return outline(img)


def projectile_rock():
    img = blank()
    polygon(img, [(4, 6), (8, 3), (12, 6), (12, 10), (8, 13), (4, 10)], c("#8a8e9c"))
    for x, y in [(6, 5), (7, 5), (6, 6)]:
        put(img, x, y, c("#b8bcc8"))
    rect(img, 9, 10, 11, 11, c("#5a5e6c"))
    return outline(img)


def projectile_slimeball():
    img = blank()
    ellipse(img, (4, 4, 11, 11), c("#5fd36b"))
    rect(img, 5, 5, 6, 6, c("#c8ffcc"))
    rect(img, 4, 10, 11, 11, c("#3a9e4c"))
    return outline(img, c("#1f6b34"))
