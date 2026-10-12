"""Uitbreiding 'vijanden': de Magiër, de Slijmspuwer en de arcane bol (zie scripts/data/ext/vijanden.gd).

  mage.png         4 vakjes van 16x16: rustig (2), aanloop met oplichtende handen, teleport-wolkje
  slime_spitter.png 5 vakjes: rustig (2), opblazen (aanloop), spuwen, hupje
  arcane_orb.png   4 vakjes: de bol van de Magiër, pulserend
"""
import math

from artlib import *  # noqa: F401,F403

# --- Magiër ----------------------------------------------------------------------------------------------

MAGE_PAL = {
    "H": c("#3b2a78"),  # kap, donker
    "h": c("#5f48b0"),  # kap, midden
    "L": c("#8f78e8"),  # kap, licht
    "F": c("#0f0a20"),  # het donkere gezicht onder de kap
    "E": c("#ff7aff"),  # gloeiende ogen
    "e": c("#b83fd0"),  # ogen, onderkant
    "R": c("#2c2063"),  # gewaad, donker
    "r": c("#473a9c"),  # gewaad, midden
    "S": c("#6a58c8"),  # mouwen en plooien
    "G": c("#ffd83a"),  # goud
    "g": c("#c98f12"),  # goud, donker
    "P": c("#d8d0ff"),  # bleke hand
    "W": c("#fff0ff"),  # oplichtende hand
    "w": c("#ff9cff"),  # gloed rond de hand
    "C": c("#4cc3ff"),  # kristalletje op de borst
    "c": c("#d8f6ff"),
}

# Elke rij is 16 tekens breed. De outline komt er automatisch omheen (dus de tekening blijft binnen 1..14).
MAGE_REST_A = [
    "................",
    ".......HH.......",
    "......HLhH......",
    ".....HLhhhH.....",
    "....HLhhhhhH....",
    "....HFFFFFFH....",
    "....HFEFFEFH....",
    "....HFeFFeFH....",
    "...HhhFFFFhhH...",
    "..HhhhhGGhhhhH..",
    "..HSrrrCcrrrSH..",
    "..PHrrrrrrrrHP..",
    "...RrrrrrrrrR...",
    "..RGgGgGgGgGgR..",
    "....RR.RR.RR....",
    "................",
]

MAGE_REST_B = [
    "................",
    "................",
    ".......HH.......",
    "......HLhH......",
    ".....HLhhhH.....",
    "....HLhhhhhH....",
    "....HFFFFFFH....",
    "....HFEFFEFH....",
    "...HhFeFFeFhH...",
    "..HhhhhGGhhhhH..",
    "..HSrrrCcrrrSH..",
    "..HHrrrrrrrrHH..",
    "..PRrrrrrrrrRP..",
    "..RgGgGgGgGgGR..",
    "...RR.RR.RR.R...",
    "................",
]

MAGE_CAST = [
    "................",
    ".wWW...HH...WWw.",
    ".WWW..HLhH..WWW.",
    "..SS.HLhhhH.SS..",
    "..SSHLhhhhhHSS..",
    "..SSHFFFFFFHSS..",
    "..SSHFEFFEFHSS..",
    "...SHFEFFEFHS...",
    "...HhhFFFFhhH...",
    "..HhhhhGGhhhhH..",
    "..HSrrrCcrrrSH..",
    "...HrrrrrrrrH...",
    "...RrrrrrrrrR...",
    "..RGgGgGgGgGgR..",
    "....RR.RR.RR....",
    "................",
]


def mage(frame):
    """0/1 = rustig, 2 = aanloop (handen omhoog en oplichtend), 3 = wolkje (teleport)."""
    if frame == 3:
        return mage_puff()
    grid = (MAGE_REST_A, MAGE_REST_B, MAGE_CAST)[frame]
    return outline(from_grid(grid, MAGE_PAL))


def mage_puff():
    """Een rookwolkje met een flits in het midden en vonkjes: de Magiër lost op of verschijnt."""
    smoke, smoke_d, smoke_l, edge = c("#cfc6f4"), c("#9d92d8"), c("#f2eeff"), c("#5f48b0")
    img = blank()
    # een kring rooklobben met een flits in het midden
    for i in range(8):
        angle = math.tau * i / 8 + 0.3
        cx, cy = 8 + math.cos(angle) * 4.9, 8 + math.sin(angle) * 4.6
        for y in range(img.height):
            for x in range(img.width):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= 2.15 ** 2:
                    put(img, x, y, smoke)
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3] == 0:
                continue
            if y >= 10 or x + y >= 21:
                put(img, x, y, smoke_d)
            elif y <= 5 or x + y <= 10:
                put(img, x, y, smoke_l)
    ellipse(img, (6, 6, 9, 9), MAGE_PAL["w"])
    rect(img, 7, 7, 8, 8, MAGE_PAL["W"])
    out = outline(img, edge)
    # vonkjes eromheen
    for x, y in ((1, 4), (13, 1), (14, 11), (2, 14), (8, 0), (0, 9)):
        put(out, x, y, MAGE_PAL["w"])
    for x, y in ((12, 0), (2, 1), (14, 7), (6, 15)):
        put(out, x, y, MAGE_PAL["W"])
    return out


def mage_sheet():
    return strip([mage(0), mage(1), mage(2), mage(3)])


# --- Slijmspuwer -----------------------------------------------------------------------------------------

SPIT_BODY, SPIT_DARK, SPIT_LIGHT, SPIT_EDGE = c("#a6e04a"), c("#6fae2a"), c("#e4ffa8"), c("#3a6a14")
MOUTH, TONGUE, TEETH, GOO = c("#24142c"), c("#e8607a"), c("#ffffff"), c("#d4ff8a")


def spitter(frame):
    """0/1 = rustig, 2 = opblazen (aanloop), 3 = spuwen, 4 = hupje (rekt zich uit)."""
    boxes = {0: (2, 5, 13, 14), 1: (3, 3, 12, 14), 2: (1, 2, 14, 14), 3: (1, 6, 14, 14), 4: (4, 1, 11, 13)}
    img = blank()
    x0, y0, x1, y1 = boxes[frame]
    ellipse(img, (x0, y0, x1, y1), SPIT_BODY)
    for y in range(y1 - 2, y1 + 1):
        for x in range(img.width):
            if img.getpixel((x, y))[3] > 0:
                put(img, x, y, SPIT_DARK)
    for dx, dy in ((3, 1), (4, 1), (3, 2)):
        put(img, x0 + dx, y0 + dy, SPIT_LIGHT)

    cx = (x0 + x1) // 2  # linkerhelft van het midden
    if frame == 4:  # grote ogen, mondje dicht ("oeh!")
        for x in (cx - 1, cx + 2):
            rect(img, x, y0 + 4, x, y0 + 6, OUTLINE)
        rect(img, cx, y0 + 8, cx + 1, y0 + 9, MOUTH)
        return outline(img, SPIT_EDGE)

    # De mond zit altijd onderaan: breed, met tanden bovenin en een tong. Hoe groter de aanloop, hoe wijder open.
    rows = {0: 3, 1: 3, 2: 5, 3: 4}[frame]
    half = {0: 4, 1: 4, 2: 6, 3: 6}[frame]
    bottom = y1 - 1
    top = bottom - rows + 1
    for i in range(rows):
        inset = 0 if i == 0 else min(i, 2) if rows <= 4 else min(i, 3) - (1 if i == 1 else 0)
        rect(img, cx + 1 - half + inset, top + i, cx + half - inset, top + i, MOUTH)
    for x in range(cx + 2 - half, cx + half, 2):
        put(img, x, top, TEETH)
    rect(img, cx - 1, bottom, cx + 2, bottom, TONGUE)
    if frame >= 2:  # de slijmbal wordt in de mond gevormd (opblazen) of komt eruit (spuwen)
        rect(img, cx - 1, top + 1, cx + 2, bottom - 1, GOO)
        put(img, cx, top + 1, TEETH)
    else:  # een druppeltje kwijl
        put(img, cx + half - 1, bottom + 1, GOO)

    # ogen: smalle streepjes boven de mond (bij het opblazen kijken ze boos)
    ey = top - 3
    for x in (cx - 3, cx + 4):
        put(img, x, ey, OUTLINE)
        put(img, x, ey + 1, OUTLINE)
    if frame == 2:
        for x in (cx - 4, cx - 2, cx + 3, cx + 5):
            put(img, x, ey - 1, OUTLINE)
    if frame == 3:  # spetters
        for x, y in ((cx - 5, top - 2), (cx + 6, top - 2), (cx - 6, top + 1), (cx + 7, top + 1)):
            put(img, x, y, GOO)
    return outline(img, SPIT_EDGE)


def spitter_sheet():
    return strip([spitter(i) for i in range(5)])


# --- Arcane bol ------------------------------------------------------------------------------------------

ORB_GLOW, ORB_MID, ORB_LIGHT, ORB_CORE, ORB_EDGE = c("#7a3fd0"), c("#b06cff"), c("#e8c8ff"), c("#ffffff"), c("#3a1f6b")


def orb(frame):
    """Een kleine bol van tovervuur. De vier vakjes pulseren en de vonkjes draaien rond."""
    radius = (3, 4, 4, 3)[frame]
    img = blank()
    ellipse(img, (8 - radius, 8 - radius, 7 + radius, 7 + radius), ORB_MID)
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3] > 0 and (x + y) > 15 + radius - 2:
                put(img, x, y, ORB_GLOW)  # schaduwkant rechtsonder
    inner = radius - 2
    ellipse(img, (8 - inner, 8 - inner, 7 + inner, 7 + inner), ORB_LIGHT)
    rect(img, 7, 7, 8, 8, ORB_CORE)
    out = outline(img, ORB_EDGE)
    spark = ((2, 7), (7, 2), (13, 8), (8, 13)) if frame % 2 == 0 else ((3, 3), (12, 3), (12, 12), (3, 12))
    for x, y in spark:
        put(out, x, y, ORB_MID if frame < 2 else ORB_LIGHT)
    return out


def orb_sheet():
    return strip([orb(i) for i in range(4)])


def sheets():
    return {"mage": mage_sheet(), "slime_spitter": spitter_sheet(), "arcane_orb": orb_sheet()}
