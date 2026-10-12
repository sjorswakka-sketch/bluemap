"""Uitbreiding "dorst" (Dorstvallei): woestijntegels en wilde dieren voor het hitteklimaat.

art_tiles.py laadt dit bestand vanzelf (tile_painters()); make_art.py pikt sheets() eruit.
Het palet is warm en dor: zandgeel, terracotta, cactusgroen en een frisse oase-tegenhanger.
"""
import random

from artlib import *  # noqa: F401,F403

# --- paletten ----------------------------------------------------------------------------------------------

SAND, SAND_D, SAND_L = c("#ecd193"), c("#d4ac66"), c("#f9e7b8")
TUFT, TUFT_D = c("#b3964f"), c("#8a6f36")
CACTUS, CACTUS_D, CACTUS_L = c("#4e9e4a"), c("#33702f"), c("#7cc464")
ROCK, ROCK_D, ROCK_L = c("#c08a54"), c("#96683c"), c("#dcb078")
OASIS, OASIS_D, OASIS_L = c("#67b34e"), c("#4a8a3a"), c("#9ad67e")
FOX, FOX_D, FOX_L = c("#d89a5a"), c("#a96f3a"), c("#f2d0a0")
HARE, HARE_D, HARE_L = c("#c9a874"), c("#96784c"), c("#ecdcc0")
FLOWER = c("#e87a9a")


# --- tegels (16x16) ----------------------------------------------------------------------------------------

def _sand_base(seed):
    img = blank()
    fill(img, SAND)
    rnd = random.Random(seed)
    for _ in range(12):
        put(img, rnd.randrange(16), rnd.randrange(16), rnd.choice([SAND_D, SAND_L]))
    # duinribbels: twee zachte golvingen
    for y in (5, 11):
        for x in range(2, 14):
            if (x + y) % 3 == 0:
                put(img, x, y, SAND_D)
    return img


def tile_painters(ti):
    """Geeft {tegelnaam: tekenfunctie} voor de nieuwe tegels. `ti` is de module art_tiles."""

    def dune_sand():
        return _sand_base(81)

    def dune_tufts():
        img = _sand_base(82)
        rnd = random.Random(83)
        for _ in range(4):
            x, y = rnd.randrange(2, 14), rnd.randrange(4, 14)
            put(img, x, y, TUFT_D)
            put(img, x, y - 1, TUFT)
            put(img, x + 1, y - 2, TUFT)
        return img

    def cactus():
        img = _sand_base(84)
        # een zuilcactus met twee armen
        rect(img, 7, 3, 9, 13, CACTUS)
        vline(img, 7, 3, 13, CACTUS_D)
        rect(img, 3, 6, 6, 7, CACTUS)
        vline(img, 3, 4, 7, CACTUS)
        rect(img, 3, 4, 4, 6, CACTUS)
        rect(img, 10, 8, 13, 9, CACTUS)
        vline(img, 13, 6, 9, CACTUS)
        rect(img, 12, 6, 13, 8, CACTUS)
        for y in (5, 8, 11):
            put(img, 8, y, CACTUS_L)
        put(img, 8, 2, FLOWER)  # een roze cactusbloem op de top
        put(img, 7, 1, FLOWER)
        put(img, 9, 1, FLOWER)
        rect(img, 5, 13, 11, 14, SAND_D)  # schaduw van het zand eromheen
        return img

    def sandstone():
        img = _sand_base(85)
        # een gestapelde zandsteenrots met lagen
        polygon(img, [(2, 13), (4, 6), (8, 3), (13, 6), (14, 13)], ROCK)
        hline(img, 3, 13, 9, ROCK_D)
        hline(img, 2, 14, 12, ROCK_D)
        polygon(img, [(4, 6), (8, 3), (10, 5), (5, 8)], ROCK_L)
        put(img, 6, 10, ROCK_D)
        put(img, 11, 10, ROCK_D)
        return img

    def oasis_grass():
        img = blank()
        fill(img, OASIS)
        rnd = random.Random(86)
        for _ in range(14):
            put(img, rnd.randrange(16), rnd.randrange(16), rnd.choice([OASIS_D, OASIS_L]))
        # grassprieten en een glinstering van water
        rnd2 = random.Random(87)
        for _ in range(5):
            x, y = rnd2.randrange(2, 14), rnd2.randrange(4, 14)
            put(img, x, y, OASIS_D)
            put(img, x, y - 1, OASIS_L)
        for x, y in [(4, 4), (12, 9)]:
            put(img, x, y, c("#bfeeff"))
        return img

    return {
        "dune_sand": dune_sand, "dune_tufts": dune_tufts, "cactus": cactus,
        "sandstone": sandstone, "oasis_grass": oasis_grass,
    }


# --- wilde dieren (16x16 per hokje, 4 hokjes: lopen 2x, vluchten 2x) -----------------------------------------

def _fox(frame):
    """Woestijnvos in zijaanzicht (kijkt naar rechts). frame 0-1: stappen, 2-3: vluchten."""
    img = blank()
    flee = frame >= 2
    step = frame % 2
    body_y = 9 if not flee else 10
    # pluimstaart achteraan
    tail = [(2, body_y - 3), (5, body_y - 1), (5, body_y + 1), (2, body_y + 1)] if not flee \
        else [(1, body_y - 4), (5, body_y - 1), (5, body_y + 1), (1, body_y)]
    polygon(img, tail, FOX)
    put(img, tail[0][0], tail[0][1], FOX_L)
    # lijf en kop
    ellipse(img, (4, body_y - 2, 11, body_y + 2), FOX)
    ellipse(img, (9, body_y - 5, 13, body_y), FOX)  # kop
    put(img, 13, body_y - 3, FOX_L)  # snuit
    put(img, 14, body_y - 3, OUTLINE)  # neus
    # puntoren
    ear_y = body_y - 7 if not flee else body_y - 6
    polygon(img, [(10, ear_y + 2), (10, ear_y), (11, ear_y + 2)], FOX_D)
    polygon(img, [(12, ear_y + 2), (12, ear_y), (13, ear_y + 2)], FOX_D)
    put(img, 12, body_y - 4, OUTLINE)  # oog
    # poten: om en om, bij vluchten gestrekt
    if flee:
        line(img, (5, body_y + 2), (3, body_y + 5), FOX_D)
        line(img, (7, body_y + 2), (6, body_y + 5), FOX_D)
        line(img, (10, body_y + 2), (12, body_y + 5), FOX_D)
        line(img, (11, body_y + 2), (14, body_y + 4), FOX_D)
    else:
        line(img, (5, body_y + 2), (4 if step else 6, body_y + 5), FOX_D)
        line(img, (7, body_y + 2), (6 if step else 8, body_y + 5), FOX_D)
        line(img, (10, body_y + 2), (9 if step else 11, body_y + 5), FOX_D)
        line(img, (11, body_y + 2), (12 if step else 10, body_y + 5), FOX_D)
    return outline(img)


def _hare(frame):
    """Zandhaas in zijaanzicht (kijkt naar rechts). frame 0-1: huppelen, 2-3: vluchten."""
    img = blank()
    flee = frame >= 2
    step = frame % 2
    body_y = 10 if not flee else 11
    # lijf en kop
    ellipse(img, (4, body_y - 3, 10, body_y + 2), HARE)
    ellipse(img, (9, body_y - 5, 12, body_y - 1), HARE)
    put(img, 13, body_y - 3, HARE_L)  # neusje
    put(img, 11, body_y - 4, OUTLINE)  # oog
    put(img, 3, body_y - 1, HARE_L)  # staartpluimpje
    # lange oren: omhoog, bij vluchten naar achteren
    if flee:
        line(img, (10, body_y - 5), (7, body_y - 8), HARE_D, 1)
        line(img, (11, body_y - 5), (9, body_y - 8), HARE, 1)
    else:
        vline(img, 10, body_y - 9, body_y - 6, HARE_D)
        vline(img, 11, body_y - 9, body_y - 6, HARE)
        put(img, 10, body_y - 9, HARE_L)
        put(img, 11, body_y - 9, HARE_L)
    # pootjes: achterpoten groter, om en om bij huppelen
    line(img, (5, body_y + 2), (3 if (flee or step) else 5, body_y + 4), HARE_D, 2 if flee else 1)
    line(img, (9, body_y + 2), (12 if flee else (8 if step else 10), body_y + 4), HARE_D, 1)
    return outline(img)


def sheets():
    """Nieuwe plaatjes: de twee woestijndieren."""
    return {
        "woestijnvos": strip([_fox(0), _fox(1), _fox(2), _fox(3)]),
        "zandhaas": strip([_hare(0), _hare(1), _hare(2), _hare(3)]),
    }


if __name__ == "__main__":
    from pathlib import Path
    for name, painter in tile_painters(None).items():
        painter().save(Path(__file__).resolve().parent.parent / "assets" / ("tile_%s.png" % name))
    for name, image in sheets().items():
        image.save(Path(__file__).resolve().parent.parent / "assets" / (name + ".png"))
