"""Uitbreiding "moeras" (Kruipmoeras): drassige tegels, wild en personages voor het moerasklimaat.

art_tiles.py laadt dit bestand vanzelf (tile_painters()); make_art.py pikt sheets() eruit.
Het palet is nat en gedempt: drijfmestgroen, blubberbruin, rietgeel en wilgengroen.
"""
import random

from artlib import *  # noqa: F401,F403
import art_chars as ch

# --- paletten ----------------------------------------------------------------------------------------------

GRAS, GRAS_D, GRAS_L = c("#5a6b34"), c("#48562a"), c("#75854a")
MODDER, MODDER_D, MODDER_L = c("#6b5636"), c("#54432a"), c("#8a7a58")
BAGGER, BAGGER_D, BAGGER_L = c("#3d4f38"), c("#2e3d2c"), c("#57704c")
KROOS = c("#6f8f4a")
RIET, RIET_D, PLUIM = c("#7a8a4a"), c("#5a6836"), c("#9a7a4a")
WILG, WILG_D, WILG_L, STAM = c("#4a6b2e"), c("#3a5424"), c("#64823c"), c("#5a4632")
VORS, VORS_D, VORS_L, VORS_BUIK = c("#7a8a3f"), c("#5a6830"), c("#9aa858"), c("#c8c49a")
SLANG, SLANG_D, SLANG_BUIK = c("#4a5a3a"), c("#38462c"), c("#8a9a6a")
SKIN, SKIN_D = c("#f6cfa6"), c("#dba57c")
OUTLINE = c("#1a1220")


# --- tegels (16x16) ----------------------------------------------------------------------------------------

def _gras_base(seed):
    img = blank()
    fill(img, GRAS)
    rnd = random.Random(seed)
    for _ in range(14):
        put(img, rnd.randrange(16), rnd.randrange(16), rnd.choice([GRAS_D, GRAS_L]))
    # natte veen: hier en daar een donkerder veegje
    for y in (4, 12):
        for x in range(3, 13):
            if (x + y) % 4 == 0:
                put(img, x, y, GRAS_D)
    return img


def tile_painters(ti):
    """Geeft {tegelnaam: tekenfunctie} voor de nieuwe tegels. `ti` is de module art_tiles."""

    def marsh_grass():
        return _gras_base(61)

    def marsh_tufts():
        img = _gras_base(62)
        rnd = random.Random(63)
        for _ in range(4):
            x, y = rnd.randrange(2, 14), rnd.randrange(5, 14)
            put(img, x, y, GRAS_D)
            put(img, x, y - 1, GRAS_L)
            put(img, x + 1, y - 2, GRAS)
            put(img, x, y - 3, GRAS)  # hoge polletjes
        return img

    def mud():
        img = blank()
        fill(img, MODDER)
        rnd = random.Random(64)
        for _ in range(4):  # blubberplasjes
            x, y = rnd.randrange(1, 11), rnd.randrange(1, 11)
            ellipse(img, (x, y, x + 3, y + 2), MODDER_D)
            put(img, x + 1, y, MODDER_L)  # natte glans
        for _ in range(6):
            put(img, rnd.randrange(16), rnd.randrange(16), MODDER_L)
        return img

    def bog_water():
        img = blank()
        fill(img, BAGGER)
        for y in (3, 8, 13):  # trage golvingen
            for x in range(1, 15):
                if (x + y) % 4 == 0:
                    put(img, x, y, BAGGER_L)
                elif (x + y) % 4 == 2:
                    put(img, x, y, BAGGER_D)
        rnd = random.Random(65)
        for _ in range(7):  # kroos dat op het water drijft
            x, y = rnd.randrange(1, 14), rnd.randrange(1, 14)
            put(img, x, y, KROOS)
            put(img, x + 1, y, KROOS)
        return img

    def reed():
        img = _gras_base(66)
        for x, h in ((3, 9), (6, 11), (9, 10), (12, 8), (14, 11)):  # riethalmen
            vline(img, x, 15 - h + 6, 15, RIET)
            vline(img, x, 15 - h + 6, 15 - h + 8, RIET_D)
            vline(img, x, 15 - h + 2, 15 - h + 5, PLUIM)  # rietpluim
        return img

    def willow():
        img = _gras_base(67)
        rect(img, 6, 10, 9, 15, STAM)  # knot
        rect(img, 6, 10, 9, 11, c("#6b5440"))
        ellipse(img, (2, 1, 13, 7), WILG)  # kruin
        for x in range(2, 14):  # hangende takken
            if x % 2 == 0:
                vline(img, x, 6, 12 + (x % 3), WILG_D if x % 4 else WILG_L)
        put(img, 7, 2, WILG_L)
        put(img, 10, 3, WILG_L)
        return img

    return {
        "marsh_grass": marsh_grass, "marsh_tufts": marsh_tufts, "mud": mud,
        "bog_water": bog_water, "reed": reed, "willow": willow,
    }


# --- wild (16x16 per hokje, 4 hokjes: lopen 2x, vluchten 2x) --------------------------------------------------

def _toad(frame):
    """Moerasvors in zijaanzicht (kijkt naar rechts). frame 0-1: stappen, 2-3: vluchten."""
    img = blank()
    flee = frame >= 2
    step = frame % 2
    body_y = 11 if not flee else 10
    # lijf: laag en breed, met een lichte buik
    ellipse(img, (3, body_y - 3, 11, body_y + 2), VORS)
    ellipse(img, (4, body_y, 10, body_y + 2), VORS_BUIK)
    # kop met uitpuilende ogen bovenop
    ellipse(img, (9, body_y - 4, 13, body_y), VORS)
    put(img, 10, body_y - 5, c("#e8d05a"))
    put(img, 12, body_y - 5, c("#e8d05a"))
    put(img, 11, body_y - 4, OUTLINE)
    put(img, 14, body_y - 2, OUTLINE)  # neusgat
    # wratten
    put(img, 5, body_y - 3, VORS_D)
    put(img, 7, body_y - 4, VORS_D)
    put(img, 4, body_y - 1, VORS_L)
    # poten: achterpoot groot en gevouwen; bij de vlucht gestrekt
    if flee:
        line(img, (4, body_y + 2), (1, body_y + 5), VORS_D, 2)
        line(img, (10, body_y + 2), (13, body_y + 4), VORS_D)
    else:
        line(img, (4, body_y + 2), (2 if step else 4, body_y + 4), VORS_D, 2)
        line(img, (10, body_y + 2), (11 if step else 9, body_y + 4), VORS_D)
    return outline(img)


def _snake(frame):
    """Waterslang in zijaanzicht (glijdt naar rechts). frame 0-1: glijden, 2-3: vluchten."""
    img = blank()
    flee = frame >= 2
    phase = frame % 2
    base_y = 12
    # het lijf als een dikke S-bocht; bij de vlucht langer en strakker
    amp = 2 if not flee else 1
    points = []
    for x in range(1, 12):
        y = base_y + int(round(amp * ((x + (1 if phase else 0)) % 4 - 2) / 2.0))
        points.append((x, y))
    for i in range(len(points) - 1):
        line(img, points[i], points[i + 1], SLANG, 2)
    for x, y in points[::2]:  # lichte buikschubben
        put(img, x, y + 1, SLANG_BUIK)
    # kop, iets opgericht, met oog en tong
    head_y = base_y - 3 if not flee else base_y - 4
    ellipse(img, (11, head_y, 14, head_y + 2), SLANG_D)
    put(img, 13, head_y, c("#e8d05a"))
    if phase:  # de tong flikkert om en om
        put(img, 15, head_y + 1, c("#d05a4a"))
        if flee:
            put(img, 15, head_y, c("#d05a4a"))
    return outline(img)


# --- personages (16x16 per hokje, 2 hokjes) -------------------------------------------------------------------

def _head(img, dy=0):
    rect(img, 5, 5 + dy, 10, 7 + dy, SKIN)
    rect(img, 5, 7 + dy, 10, 7 + dy, SKIN_D)
    put(img, 6, 6 + dy, OUTLINE)
    put(img, 9, 6 + dy, OUTLINE)


def _legs(img, color, dark):
    rect(img, 5, 12, 7, 14, color)
    rect(img, 8, 12, 10, 14, color)
    rect(img, 8, 12, 8, 14, dark)
    rect(img, 5, 15, 7, 15, dark)
    rect(img, 8, 15, 10, 15, dark)


def stien(frame):
    """Turfsteker: hoofddoek, ruige werkjurk, een bos turf onder de arm en haar spade."""
    hy = 1 if frame else 0
    img = blank()
    # hoofddoek
    rect(img, 4, 1 + hy, 11, 3 + hy, c("#7a8a9a"))
    rect(img, 4, 4 + hy, 4, 7 + hy, c("#7a8a9a"))
    rect(img, 11, 4 + hy, 11, 7 + hy, c("#5a6a7a"))
    _head(img, hy)
    # werkjurk
    rect(img, 4, 8, 11, 14, c("#8a5a3a"))
    rect(img, 11, 8, 11, 14, c("#64402a"))
    rect(img, 4, 10, 11, 10, c("#4a3020"))  # riem
    # turf onder de linkerarm
    rect(img, 1, 8, 3, 11, MODDER_D)
    put(img, 2, 8, MODDER)
    put(img, 2, 10, MODDER)
    # turfspade in de rechterhand
    rect(img, 13, 6, 13, 12, c("#8a5a2c"))
    rect(img, 12, 12, 14, 14, c("#9aa4ae"))
    _legs(img, c("#4a3a2a"), c("#2e2418"))
    return outline(img)


def mees(frame):
    """Rietvlechter: strohoedje, groen vest en een mand vol vers gesneden riet."""
    hy = 1 if frame else 0
    img = blank()
    # strohoedje
    rect(img, 3, 2 + hy, 12, 2 + hy, c("#d8bc6a"))
    rect(img, 5, 1 + hy, 10, 3 + hy, c("#c8a852"))
    _head(img, hy)
    # vest en hemd
    rect(img, 4, 8, 11, 13, c("#e8e0d0"))
    rect(img, 4, 8, 5, 13, c("#4a7a4e"))
    rect(img, 10, 8, 11, 13, c("#4a7a4e"))
    rect(img, 4, 12, 11, 12, c("#6a4a2a"))  # riem
    # mand met riet in de linkerhand
    rect(img, 1, 9, 3, 12, c("#a4763a"))
    vline(img, 1, 5, 8, RIET)
    vline(img, 2, 4, 8, RIET_D)
    vline(img, 3, 6, 8, PLUIM)
    _legs(img, c("#5a5a3a"), c("#3a3a26"))
    return outline(img)


def wouda(frame):
    """Oude Wouda: moerasziel en kruidenkenner, gehuld in een donkere cape met capuchon."""
    hy = 1 if frame else 0
    img = blank()
    # cape met capuchon
    rect(img, 4, 1 + hy, 11, 4 + hy, c("#2e4432"))
    rect(img, 4, 4 + hy, 4, 14, c("#2e4432"))
    rect(img, 11, 4 + hy, 11, 14, c("#22332a"))
    rect(img, 4, 8, 11, 14, c("#3a5440"))
    _head(img, hy)
    # kruidenbos in de hand
    put(img, 13, 9, c("#7ac86a"))
    put(img, 14, 8, c("#a8e8a0"))
    put(img, 13, 10, c("#5a9a4e"))
    # knots
    rect(img, 1, 5, 1, 14, c("#6b4a2e"))
    put(img, 1, 4, c("#8a6238"))
    _legs(img, c("#22332a"), c("#16211a"))
    return outline(img)


def sheets():
    return {
        "moerasvors": strip([_toad(0), _toad(1), _toad(2), _toad(3)]),
        "waterslang": strip([_snake(0), _snake(1), _snake(2), _snake(3)]),
        "npc_stien": ch.npc_sheet(stien),
        "npc_mees": ch.npc_sheet(mees),
        "npc_wouda": ch.npc_sheet(wouda),
    }
