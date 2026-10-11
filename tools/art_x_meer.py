"""Uitbreiding "meer" (het Zilvermeer): nieuwe tegels, voorwerp-iconen, personages en kleine objecten.

make_art.py laadt dit bestand vanzelf (sheets()); art_tiles.py haalt er de tekeningen van de nieuwe tegels uit
(tile_painters()). Alle kleuren komen uit dezelfde paletten als de rest van het spel (zie art_tiles.py en art_chars.py).
"""
import random

from PIL import ImageDraw

import art_chars as ch
from artlib import *  # noqa: F401,F403

# --- paletten ----------------------------------------------------------------------------------------------

SAND, SAND_D, SAND_L = c("#ecdaa4"), c("#d6bf80"), c("#f8edc6")
WOOD, WOOD_L, WOOD_D, WOOD_DD = c("#b07a40"), c("#c99a60"), c("#7a4e24"), c("#3a2410")
REED, REED_L, REED_D = c("#6f9a3a"), c("#9cc24e"), c("#486d28")
CATTAIL, CATTAIL_D = c("#8a5530"), c("#4f2e14")
PAD, PAD_L, PAD_D = c("#3fa05a"), c("#74d27e"), c("#2a7a45")
WATER_L, WATER_D = c("#8cc4f7"), c("#2f6cb8")


# --- tegels (16x16) ----------------------------------------------------------------------------------------

def tile_painters(ti):
    """Geeft {tegelnaam: tekenfunctie} voor de nieuwe tegels. `ti` is de module art_tiles (voor water en gras)."""

    def sand():
        img = blank()
        fill(img, SAND)
        rnd = random.Random(41)
        for _ in range(18):
            put(img, rnd.randrange(16), rnd.randrange(16), rnd.choice([SAND_D, SAND_L]))
        # golfjes in het zand, zoals een laagje water ze achterlaat
        for x, y in [(2, 4), (3, 4), (4, 5), (5, 5), (6, 4)]:
            put(img, x, y, SAND_D)
        for x, y in [(9, 11), (10, 11), (11, 12), (12, 12), (13, 11)]:
            put(img, x, y, SAND_D)
        # een paar kiezels
        for x, y in [(12, 3), (3, 12)]:
            put(img, x, y, c("#b9a46a"))
            put(img, x + 1, y, c("#f4ecd0"))
        return img

    def reeds():
        img = ti.water_tile()
        # rimpelingen rond de stengels
        for x, y in [(1, 14), (2, 14), (5, 15), (6, 15), (9, 14), (10, 14), (12, 15), (13, 15)]:
            put(img, x, y, WATER_L)
        for x, y in [(3, 15), (4, 15), (11, 15), (14, 14)]:
            put(img, x, y, WATER_D)
        stalks = [(3, 7), (6, 3), (9, 5), (12, 8)]  # (x, bovenkant van de kolf)
        for x, top in stalks:
            vline(img, x, top + 3, 14, REED)
            vline(img, x + 1, top + 4, 14, REED_D)
            vline(img, x, top + 3, top + 6, REED_L)
        # bladeren buigen naar buiten
        for p0, p1 in [((3, 13), (1, 8)), ((6, 13), (8, 8)), ((9, 13), (6, 9)), ((12, 13), (14, 8)), ((6, 14), (3, 11)), ((9, 14), (12, 10))]:
            line(img, p0, p1, REED_L)
        for p0, p1 in [((4, 13), (2, 10)), ((11, 13), (13, 10))]:
            line(img, p0, p1, REED_D)
        # kolven
        for x, top in stalks:
            rect(img, x, top, x + 1, top + 3, CATTAIL)
            vline(img, x + 1, top, top + 3, CATTAIL_D)
            put(img, x, top, c("#b07a50"))
            put(img, x, top - 1, REED_D)
        return img

    def lily_water():
        img = ti.water_tile()
        pads = blank()
        for x0, y0, x1, y1 in [(1, 2, 8, 8), (8, 8, 14, 14), (10, 1, 14, 4)]:
            ellipse(pads, (x0, y0, x1, y1), PAD, PAD_D)
            put(pads, x0 + 2, y0 + 1, PAD_L)
            put(pads, x0 + 3, y0 + 1, PAD_L)
        # een inkeping in de twee grote bladeren: die pixels worden weer water
        for x, y in [(7, 5), (8, 5), (7, 4), (8, 11), (9, 11), (8, 10)]:
            pads.putpixel((x, y), (0, 0, 0, 0))
        img.alpha_composite(pads)
        # een waterlelie op het eerste blad
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            put(img, 4 + dx, 5 + dy, c("#ffffff"))
        put(img, 4, 5, c("#ffd83a"))
        put(img, 3, 4, c("#ff8fb0"))
        put(img, 5, 6, c("#ff8fb0"))
        return img

    def pier_post():
        img = ti.water_tile()
        # rimpels rond de paal
        for x, y in [(3, 13), (4, 14), (11, 13), (12, 14), (5, 15), (10, 15)]:
            put(img, x, y, WATER_L)
        for x, y in [(2, 14), (13, 14)]:
            put(img, x, y, WATER_D)
        rect(img, 5, 3, 10, 14, WOOD_DD)
        rect(img, 6, 3, 9, 14, WOOD)
        vline(img, 6, 3, 14, WOOD_L)
        vline(img, 9, 3, 14, WOOD_D)
        # bovenkant van de paal
        rect(img, 5, 2, 10, 4, WOOD_DD)
        rect(img, 6, 2, 9, 3, WOOD_L)
        hline(img, 6, 9, 3, c("#e6c088"))
        # touw
        for y in (7, 8):
            hline(img, 6, 9, y, c("#d8c8a0") if y == 7 else c("#a89870"))
        # waterlijn
        hline(img, 5, 10, 13, c("#245a9c"))
        return img

    def library_floor():
        img = blank()
        base, light, dark = c("#ad7640"), c("#bc8449"), c("#946032")
        fill(img, dark)
        # vlechtpatroon van 8x8 blokken: om en om horizontale en verticale planken
        for bx in (0, 8):
            for by in (0, 8):
                horizontal = (bx == by)
                for i in range(3):
                    if horizontal:
                        rect(img, bx, by + i * 3, bx + 6, by + i * 3 + 1, base)
                        hline(img, bx, bx + 6, by + i * 3, light)
                    else:
                        rect(img, bx + i * 3, by, bx + i * 3 + 1, by + 6, base)
                        vline(img, bx + i * 3, by, by + 6, light)
        return img

    def library_carpet():
        img = blank()
        base, light, dark, gold = c("#2f6e5c"), c("#4a9a80"), c("#1f4e42"), c("#e0b84a")
        fill(img, base)
        # ruitpatroon met een gouden stipje in het midden van elke ruit
        for cx, cy in [(4, 4), (12, 4), (4, 12), (12, 12), (8, 8)]:
            for d in range(0, 4):
                for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
                    x, y = cx + sx * d, cy + sy * (3 - d)
                    put(img, x, y, light)
            put(img, cx, cy, gold)
        for x, y in [(0, 0), (15, 15), (0, 15), (15, 0), (8, 0), (0, 8), (15, 8), (8, 15)]:
            put(img, x, y, dark)
        return img

    return {
        "meer_sand": sand, "meer_reeds": reeds, "meer_lelie": lily_water, "meer_paal": pier_post,
        "meer_bibvloer": library_floor, "meer_tapijt": library_carpet,
    }


# --- voorwerp-iconen (items_meer.png, een rij van 16x16) ---------------------------------------------------

def icon_rod():
    img = blank()
    line(img, (1, 14), (11, 3), c("#8a5a2c"), 2)
    line(img, (2, 13), (11, 2), c("#b07a40"), 1)
    ellipse(img, (3, 9, 6, 12), c("#aab0c4"), c("#5d637c"))
    put(img, 4, 10, c("#e8ecf8"))
    # lijn met dobber en haakje
    vline(img, 14, 3, 8, c("#e8ecf8"))
    line(img, (11, 2), (14, 3), c("#e8ecf8"))
    ellipse(img, (13, 8, 15, 10), c("#e8334a"))
    put(img, 14, 10, c("#ffffff"))
    put(img, 14, 11, c("#9aa0b4"))
    put(img, 13, 12, c("#9aa0b4"))
    return outline(img)


def icon_baars():
    """Gestreepte baars naar links, met rode vinnen."""
    img = blank()
    body, belly, stripe, fin = c("#8fa83a"), c("#e8e0a0"), c("#4f6a24"), c("#e8553a")
    ellipse(img, (1, 5, 12, 11), body)
    for x in range(2, 12):
        for y in (10, 11):
            if img.getpixel((x, y))[3] > 0:
                put(img, x, y, belly)
    for x in (5, 7, 9):  # donkere dwarsstrepen
        for y in range(6, 10):
            if img.getpixel((x, y))[3] > 0:
                put(img, x, y, stripe)
    polygon(img, [(11, 8), (15, 4), (15, 12)], fin)  # staart
    rect(img, 5, 4, 9, 4, fin)  # rugvin
    put(img, 4, 3, fin)
    put(img, 8, 3, fin)
    rect(img, 4, 12, 6, 12, fin)  # buikvin
    put(img, 3, 7, c("#ffffff"))
    put(img, 4, 7, OUTLINE)
    return outline(img)


def icon_snoek():
    img = blank()
    body, belly, dark, light = c("#7a9a50"), c("#dfe4b8"), c("#4a6a30"), c("#b6d070")
    # lang lijf met een eendenbek
    ellipse(img, (2, 6, 14, 10), body)
    polygon(img, [(0, 7), (4, 6), (4, 9), (0, 9)], body)
    hline(img, 0, 3, 9, belly)
    for x in range(3, 13):
        if img.getpixel((x, 10))[3] > 0:
            put(img, x, 10, belly)
        if img.getpixel((x, 9))[3] > 0 and x % 2 == 0:
            put(img, x, 9, belly)
    # vlekjes
    for x, y in [(6, 7), (8, 8), (10, 7), (12, 8), (7, 9)]:
        put(img, x, y, light)
    # staart en rugvin
    polygon(img, [(13, 8), (15, 5), (15, 11)], c("#c8d070"))
    polygon(img, [(10, 6), (12, 4), (13, 6)], dark)
    put(img, 3, 7, c("#ffffff"))
    put(img, 4, 7, OUTLINE)
    put(img, 1, 8, dark)
    return outline(img)


def icon_karper():
    img = blank()
    gold, gold_l, gold_d, fin = c("#ffd23a"), c("#fff0a0"), c("#d89a12"), c("#ff9a2a")
    ellipse(img, (1, 4, 11, 12), gold)
    polygon(img, [(10, 8), (14, 3), (15, 8), (14, 13)], fin)
    polygon(img, [(4, 4), (7, 1), (10, 4)], fin)
    polygon(img, [(5, 12), (7, 14), (9, 12)], fin)
    # schubben
    for x, y in [(5, 6), (7, 6), (9, 7), (6, 8), (8, 9), (5, 10), (7, 11)]:
        put(img, x, y, gold_d)
    for x, y in [(4, 7), (6, 7), (8, 8), (5, 9), (7, 10)]:
        put(img, x, y, gold_l)
    # buik
    for x in range(2, 11):
        if img.getpixel((x, 12))[3] > 0:
            put(img, x, 12, gold_d)
    # kop met snorharen
    put(img, 3, 7, c("#ffffff"))
    put(img, 4, 7, OUTLINE)
    put(img, 1, 9, gold_d)
    out = outline(img, c("#7a4a0d"))
    line(out, (0, 10), (-1, 12), c("#7a4a0d"))
    # glinsteringen
    for x, y in [(13, 1), (12, 1), (14, 1), (13, 0), (13, 2), (2, 1), (1, 1), (3, 1), (2, 0), (2, 2)]:
        put(out, x, y, c("#ffffff"))
    return out


def icon_boot():
    img = blank()
    brown, brown_l, brown_d = c("#7a6a50"), c("#a08a68"), c("#4a3e2c")
    rect(img, 4, 2, 9, 10, brown)
    rect(img, 4, 2, 9, 3, brown_l)
    rect(img, 3, 9, 14, 13, brown)
    rect(img, 3, 12, 14, 13, brown_d)
    rect(img, 3, 9, 8, 10, brown_l)
    rect(img, 9, 9, 9, 10, brown)
    # een gat en wat waterplanten
    rect(img, 6, 6, 7, 7, c("#1a1a2e"))
    for x, y in [(11, 9), (12, 8), (13, 9), (12, 10)]:
        put(img, x, y, c("#3fa05a"))
    for x, y in [(5, 1), (4, 0), (6, 0)]:
        put(img, x, y, c("#3fa05a"))
    return outline(img)


def icon_cap():
    img = blank()
    navy, navy_l, navy_d = c("#2f4a7a"), c("#5a7ec0"), c("#1f3358")
    ellipse(img, (2, 3, 13, 11), navy)
    rect(img, 2, 8, 13, 11, navy)
    rect(img, 2, 9, 13, 10, c("#f4f4f8"))  # witte band
    hline(img, 2, 13, 11, navy_d)
    polygon(img, [(1, 11), (14, 11), (15, 13), (0, 13)], c("#1a2a48"))  # klep
    hline(img, 3, 12, 11, c("#3a5688"))
    for x, y in [(5, 4), (6, 4), (4, 5), (5, 5)]:
        put(img, x, y, navy_l)
    # gouden anker
    put(img, 7, 6, c("#ffd83a"))
    put(img, 8, 6, c("#ffd83a"))
    vline(img, 7, 6, 8, c("#ffd83a"))
    put(img, 6, 8, c("#ffd83a"))
    put(img, 8, 8, c("#ffd83a"))
    return outline(img)


def _book(cover, cover_d, mark, emblem):
    img = blank()
    rect(img, 3, 2, 12, 13, cover)
    rect(img, 3, 2, 4, 13, cover_d)  # rug
    rect(img, 12, 3, 12, 12, c("#f4ecd0"))  # paginarand
    hline(img, 3, 13, 13, cover_d)
    # embleem
    for x, y in emblem:
        put(img, x, y, mark)
    # leeslint
    vline(img, 10, 13, 15, c("#e8334a"))
    return outline(img)


def icon_book_island():
    return _book(c("#3a6fc9"), c("#27508f"), c("#cfe8ff"),
                 [(6, 5), (7, 6), (8, 5), (9, 6), (6, 8), (7, 9), (8, 8), (9, 9)])  # golfjes


def icon_book_hut():
    book = _book(c("#3f8f56"), c("#2a6a3c"), c("#d8f0c8"),
                 [(6, 6), (7, 5), (8, 5), (9, 6), (8, 7), (7, 7), (10, 6), (10, 5)])  # visje
    ImageDraw.Draw(book).ellipse([6, 8, 10, 12], outline=c("#6a4a30"))  # een koffiekring
    return book


def icon_book_sanne():
    return _book(c("#7a4aa8"), c("#54307a"), c("#ffd83a"),
                 [(8, 4), (7, 5), (8, 5), (9, 5), (6, 6), (7, 6), (8, 6), (9, 6), (10, 6), (7, 7), (8, 7), (9, 7), (7, 8), (9, 8)])  # ster


def icon_shell():
    """Een kammossel: een waaier met ribbels."""
    img = blank()
    shell, shell_l, shell_d = c("#f4b8c0"), c("#fff0e8"), c("#c8788a")
    polygon(img, [(8, 13), (1, 7), (3, 4), (6, 2), (10, 2), (13, 4), (15, 7)], shell)
    for x in (3, 5, 8, 11, 13):  # ribbels vanaf het scharnier
        line(img, (8, 12), (x, 4 if 4 <= x <= 12 else 5), shell_d)
    for x, y in [(6, 3), (7, 3), (5, 4)]:
        put(img, x, y, shell_l)
    rect(img, 6, 13, 10, 14, shell_d)
    return outline(img, c("#7a3a4a"))


def icons():
    return [
        icon_rod(), icon_baars(), icon_snoek(), icon_karper(), icon_boot(), icon_cap(),
        icon_book_island(), icon_book_hut(), icon_book_sanne(), icon_shell(),
    ]


# --- personages (npc_meer_*.png, 2 vakjes: rustig en een beetje bewegen) ---------------------------------

def joris(frame):  # Visser Joris: grommig maar lief, pet en snor, gele regenjas, hengel
    hy = 1 if frame else 0
    img = blank()
    navy, navy_d, navy_l = c("#2f4a7a"), c("#1f3358"), c("#5a7ec0")
    skin, skin_d = c("#e8b088"), c("#c98e66")
    coat, coat_d, coat_l = c("#e0b030"), c("#b08820"), c("#f4d060")
    stache, stache_d = c("#e4e4ec"), c("#a8a8b8")
    # pet
    rect(img, 5, 2 + hy, 10, 3 + hy, navy)
    rect(img, 4, 4 + hy, 11, 4 + hy, navy_d)
    put(img, 5, 2 + hy, navy_l)
    put(img, 6, 2 + hy, navy_l)
    put(img, 7, 3 + hy, c("#ffd83a"))
    put(img, 8, 3 + hy, c("#ffd83a"))
    # gezicht met wenkbrauwen die boos kijken
    rect(img, 5, 5 + hy, 10, 7 + hy, skin)
    rect(img, 5, 7 + hy, 10, 7 + hy, skin_d)
    put(img, 5, 5 + hy, c("#4a4a52"))
    put(img, 6, 5 + hy, c("#4a4a52"))
    put(img, 9, 5 + hy, c("#4a4a52"))
    put(img, 10, 5 + hy, c("#4a4a52"))
    put(img, 6, 6 + hy, OUTLINE)
    put(img, 9, 6 + hy, OUTLINE)
    # grote snor
    rect(img, 5, 7 + hy, 10, 7 + hy, stache)
    put(img, 5, 8 + hy, stache)
    put(img, 10, 8 + hy, stache)
    put(img, 7, 7 + hy, stache_d)
    put(img, 8, 7 + hy, stache_d)
    # jas
    rect(img, 4, 8, 11, 11, coat)
    rect(img, 11, 8, 11, 11, coat_d)
    rect(img, 3, 8, 3, 10, coat)
    rect(img, 12, 8, 12, 10, coat_d)
    put(img, 3, 11, skin)
    put(img, 12, 11, skin)
    rect(img, 4, 8, 6, 8, coat_l)
    put(img, 7, 10, c("#7a5a10"))
    put(img, 8, 10, c("#7a5a10"))
    rect(img, 4, 11, 11, 11, coat_d)
    # waterdichte broek en laarzen
    ch._legs(img, c("#3a5a44"), c("#2a2018"))
    # hengel met lijn en dobber
    rect(img, 13, 3, 13, 14, c("#8a5a2c"))
    put(img, 14, 2, c("#8a5a2c"))
    put(img, 15, 2, c("#8a5a2c"))
    vline(img, 15, 3, 6, c("#e8ecf8"))
    put(img, 15, 7, c("#e8334a"))
    return outline(img)


def lena(frame):  # Lena de bibliothecaresse: bril, knotje, boek
    hy = 1 if frame else 0
    img = blank()
    hair, hair_d = c("#7a3a2a"), c("#52261c")
    dress, dress_d, dress_l = c("#2f7d5a"), c("#1f5a40"), c("#4aa07a")
    # haar met knotje
    rect(img, 7, 1 + hy, 8, 1 + hy, hair)
    rect(img, 5, 2 + hy, 10, 2 + hy, hair)
    rect(img, 4, 3 + hy, 11, 4 + hy, hair)
    put(img, 4, 4 + hy, hair_d)
    put(img, 11, 4 + hy, hair_d)
    put(img, 6, 1 + hy, hair_d)
    # gezicht
    ch._head(img, hy)
    rect(img, 4, 5 + hy, 4, 7 + hy, hair)
    rect(img, 11, 5 + hy, 11, 7 + hy, hair)
    # bril: twee lichtblauwe glazen onder de pony met een brugje ertussen
    for x in (5, 6, 9, 10):
        put(img, x, 5 + hy, c("#bfe4ff"))
        put(img, x, 6 + hy, c("#bfe4ff"))
    put(img, 5, 5 + hy, c("#ffffff"))
    put(img, 9, 5 + hy, c("#ffffff"))
    put(img, 7, 5 + hy, c("#5a2a20"))
    put(img, 8, 5 + hy, c("#5a2a20"))
    put(img, 6, 6 + hy, OUTLINE)
    put(img, 9, 6 + hy, OUTLINE)
    # jurk met witte kraag
    rect(img, 4, 8, 11, 11, dress)
    rect(img, 11, 8, 11, 11, dress_d)
    rect(img, 3, 8, 3, 10, dress)
    rect(img, 12, 8, 12, 10, dress_d)
    put(img, 3, 11, ch.SKIN)
    put(img, 12, 11, ch.SKIN)
    rect(img, 5, 8, 10, 8, c("#f4f4f8"))
    rect(img, 3, 12, 12, 14, dress)
    rect(img, 11, 12, 12, 14, dress_d)
    hline(img, 3, 12, 14, dress_d)
    put(img, 5, 12, dress_l)
    put(img, 6, 12, dress_l)
    # boek tegen de borst
    rect(img, 5, 9, 9, 12, c("#a8403a"))
    rect(img, 5, 9, 5, 12, c("#7a2a26"))
    rect(img, 6, 12, 9, 12, c("#f4ecd0"))
    put(img, 7, 10, c("#ffd83a"))
    put(img, 8, 10, c("#ffd83a"))
    return outline(img)


def sanne(frame):  # Sanne: kind met strohoed, staartjes en een hengel
    hy = 1 if frame else 0
    img = blank()
    hair, hair_d = c("#e89a3a"), c("#b87020")
    straw, straw_d = c("#f2d36a"), c("#c8aa40")
    dress, dress_d = c("#3fb0a8"), c("#2a8a84")
    # strohoed
    rect(img, 5, 3 + hy, 10, 4 + hy, straw)
    rect(img, 3, 5 + hy, 12, 5 + hy, straw_d)
    rect(img, 4, 5 + hy, 11, 5 + hy, straw)
    rect(img, 5, 4 + hy, 10, 4 + hy, c("#e8334a"))  # lint
    # gezicht en staartjes
    rect(img, 5, 6 + hy, 10, 9 + hy, ch.SKIN)
    rect(img, 5, 9 + hy, 10, 9 + hy, ch.SKIN_D)
    put(img, 6, 8 + hy, OUTLINE)
    put(img, 9, 8 + hy, OUTLINE)
    rect(img, 4, 6 + hy, 4, 9 + hy, hair)
    rect(img, 11, 6 + hy, 11, 9 + hy, hair)
    put(img, 3, 8 + hy, hair)
    put(img, 12, 8 + hy, hair)
    put(img, 3, 9 + hy, hair_d)
    put(img, 12, 9 + hy, hair_d)
    put(img, 4, 6 + hy, c("#e8334a"))
    put(img, 11, 6 + hy, c("#e8334a"))
    # jurkje
    rect(img, 5, 10, 10, 12, dress)
    rect(img, 10, 10, 10, 12, dress_d)
    put(img, 4, 11, dress)
    put(img, 4, 12, ch.SKIN)
    put(img, 11, 11, dress_d)
    put(img, 11, 12, ch.SKIN)
    for x, y in [(6, 11), (8, 12)]:
        put(img, x, y, c("#ffffff"))
    # beentjes: een laars en een blote voet (ze is er een kwijt)
    rect(img, 5, 13, 6, 13, ch.SKIN)
    rect(img, 9, 13, 10, 13, c("#6a5a3c"))
    rect(img, 5, 14, 6, 14, ch.SKIN_D)
    rect(img, 9, 14, 10, 14, ch.BOOT)
    # hengeltje
    line(img, (11, 12), (15, 3), c("#8a5a2c"))
    vline(img, 15, 4, 8, c("#e8ecf8"))
    put(img, 15, 9, c("#e8334a"))
    return outline(img)


def npc_sheet(fn):
    return strip([fn(0), fn(1)])


# --- kleine objecten (meer_objects.png) en beeldjes voor het visspel (meer_ui.png) -------------------------

def lectern(glint):
    img = blank()
    wood, wood_l, wood_d = c("#8a5a2c"), c("#b07a40"), c("#5a3a1c")
    # poot en voet
    rect(img, 7, 9, 8, 13, wood)
    vline(img, 8, 9, 13, wood_d)
    rect(img, 4, 13, 11, 14, wood_d)
    rect(img, 4, 13, 11, 13, wood)
    # schuin blad met open boek
    polygon(img, [(2, 5), (13, 5), (14, 9), (1, 9)], wood_l)
    hline(img, 1, 14, 9, wood_d)
    polygon(img, [(3, 3), (7, 4), (7, 8), (3, 8)], c("#f4ecd0"))
    polygon(img, [(8, 4), (12, 3), (12, 8), (8, 8)], c("#f4ecd0"))
    vline(img, 7, 4, 8, c("#c8b890"))
    for y in (4, 6):
        hline(img, 4, 6, y, c("#9a8a68"))
        hline(img, 9, 11, y, c("#9a8a68"))
    hline(img, 3, 12, 8, c("#c8b890"))
    vline(img, 7, 8, 9, c("#e8334a"))  # leeslint
    out = outline(img)
    if glint:
        for x, y in [(12, 1), (11, 1), (13, 1), (12, 0), (12, 2), (2, 2), (1, 2), (3, 2), (2, 1), (2, 3)]:
            put(out, x, y, c("#fff6c0"))
    return out


def bobber(dipped):
    img = blank()
    if dipped:
        ellipse(img, (6, 9, 9, 12), c("#e8334a"))
        put(img, 7, 10, c("#ffa0a0"))
        for x, y in [(4, 12), (5, 13), (10, 12), (11, 13)]:
            put(img, x, y, WATER_L)
        return outline(img)
    ellipse(img, (6, 5, 9, 8), c("#e8334a"))
    put(img, 7, 6, c("#ffa0a0"))
    rect(img, 6, 9, 9, 10, c("#f4f4f8"))
    hline(img, 6, 9, 10, c("#c8c8d8"))
    for x, y in [(4, 11), (5, 12), (10, 11), (11, 12)]:
        put(img, x, y, WATER_L)
    return outline(img)


def bubble():
    """Een uitroepteken in een tekstballon: de vis bijt!"""
    img = blank()
    rect(img, 3, 1, 12, 10, c("#fff6c0"))
    polygon(img, [(6, 11), (9, 11), (7, 14)], c("#fff6c0"))
    rect(img, 7, 2, 8, 6, c("#e8334a"))
    rect(img, 7, 8, 8, 9, c("#e8334a"))
    return outline(img, c("#7a4a0d"))


def sheets():
    return {
        "items_meer": strip(icons()),
        "npc_meer_joris": npc_sheet(joris),
        "npc_meer_lena": npc_sheet(lena),
        "npc_meer_sanne": npc_sheet(sanne),
        "meer_objects": strip([lectern(False), lectern(True)]),
        "meer_ui": strip([bobber(False), bobber(True), bubble()]),
    }
