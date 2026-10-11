"""Uitbreiding "boog": iconen van de boog en de pijl, het doelwit en Tessa van de schietbaan."""
import art_chars as ch
from artlib import *  # noqa: F401,F403

WOOD, WOOD_L, WOOD_D = c("#b8793a"), c("#e0a868"), c("#7a4a24")
STRING = c("#eef0f8")
STEEL, STEEL_L, STEEL_D = c("#b8c0d4"), c("#f0f4ff"), c("#7a849c")
FEATHER, FEATHER_D = c("#e8334a"), c("#a81f36")


# --- voorwerp-iconen (items_boog.png: 0 = boog, 1 = pijl, 2 = vliegende pijl voor in de wereld) ---------------------

def _bezier(p0, p1, p2, steps=40):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        pts.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0],
                    (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]))
    return pts


def icon_bow():
    """Een boog rechtop: de bocht wijst naar rechts (daar vliegt de pijl heen), de pees is de rechte lijn links."""
    img = blank()
    outer = _bezier((4, 1), (18, 7.5), (4, 14))
    inner = _bezier((4, 3), (15, 7.5), (4, 12))
    polygon(img, [(round(x), round(y)) for x, y in outer + inner[::-1]], WOOD)
    # Lichte rand aan de buitenkant, donkere aan de binnenkant, zodat het hout rond lijkt.
    snap = img.copy()
    for y in range(16):
        for x in range(16):
            if snap.getpixel((x, y)) != WOOD:
                continue
            if x + 1 > 15 or snap.getpixel((x + 1, y))[3] == 0:
                put(img, x, y, WOOD_L)
            elif x - 1 < 0 or snap.getpixel((x - 1, y))[3] == 0:
                put(img, x, y, WOOD_D)
    vline(img, 4, 2, 13, STRING)  # de pees
    for y in (6, 7, 8, 9):  # omwikkeld handvat
        put(img, 9, y, c("#e0b84a"))
        put(img, 10, y, c("#c98f12"))
    put(img, 4, 1, c("#e0b84a"))
    put(img, 4, 14, c("#e0b84a"))
    return outline(img)


def icon_arrow():
    """De pijl schuin (punt rechtsboven), net als de zwaarden in items.png."""
    img = blank()
    for i in range(10):  # schacht, met een lichtere rand erlangs
        put(img, 3 + i, 12 - i, WOOD)
        put(img, 3 + i, 13 - i, WOOD_L)
    polygon(img, [(14, 1), (9, 3), (12, 6)], STEEL)
    put(img, 12, 4, STEEL_L)
    put(img, 13, 3, STEEL_L)
    put(img, 11, 5, STEEL_D)
    for k, reach in ((0, 2), (1, 2), (2, 1)):  # veren: een schuine band aan beide kanten van de schacht
        sx, sy = 3 + k, 12 - k
        for d in range(1, reach + 1):
            put(img, sx - d, sy - d, FEATHER)
            put(img, sx + d, sy + d, FEATHER_D if d == 1 else FEATHER)
    return outline(img)


def arrow_flying():
    """De pijl zoals hij door de lucht vliegt (wijst naar rechts): schacht, stalen punt en rode veren."""
    img = blank()
    y = 8
    hline(img, 3, 11, y, WOOD)
    polygon(img, [(11, y - 2), (14, y), (11, y + 2)], STEEL)
    hline(img, 12, 13, y, STEEL_L)
    for x, spread in ((2, 2), (3, 2), (4, 1)):  # veren: schuin naar buiten
        put(img, x, y - spread, FEATHER)
        put(img, x, y + spread, FEATHER)
    put(img, 3, y - 1, FEATHER_D)
    put(img, 3, y + 1, FEATHER_D)
    return outline(img)


# --- het doelwit (target.png: 0 = gewoon, 1 = geraakt en oplichtend) ---------------------------------------------

def target(hit):
    img = blank()
    # Houten pootjes en een steunbalk onder het bord.
    for x in (4, 10):
        rect(img, x, 11, x + 1, 15, WOOD)
        vline(img, x, 11, 15, WOOD_L)
        vline(img, x + 1, 11, 15, WOOD_D)
    rect(img, 3, 12, 12, 12, WOOD_D)
    rect(img, 5, 13, 10, 13, WOOD_D)
    # Het bord: ringen van buiten naar binnen.
    if hit:
        rings = [c("#fff6c0"), c("#ffd83a"), c("#fff6c0"), c("#ffb21f"), c("#ffffff")]
    else:
        rings = [c("#f4f0e0"), c("#d8433a"), c("#f4f0e0"), c("#d8433a"), c("#ffd83a")]
    ellipse(img, (1, 0, 14, 13), rings[0], c("#7a4a24"))
    ellipse(img, (2, 1, 13, 12), rings[1])
    ellipse(img, (4, 3, 11, 10), rings[2])
    ellipse(img, (5, 4, 10, 9), rings[3])
    ellipse(img, (6, 5, 9, 8), rings[4])
    if not hit:
        for x, y in ((4, 2), (5, 2), (3, 3)):  # lichte glans
            put(img, x, y, c("#ffffff"))
    else:
        # Een pijl in de roos en een paar vonken.
        line(img, (8, 6), (13, 1), WOOD, 1)
        put(img, 13, 0, FEATHER)
        put(img, 14, 1, FEATHER)
        put(img, 13, 2, FEATHER_D)
        put(img, 7, 7, STEEL_L)
    out = outline(img)
    if hit:
        for x, y in ((0, 1), (15, 8), (2, 14), (14, 13)):
            put(out, x, y, c("#ffffff"))
    return out


# --- Tessa, de schietbaanmeester (npc_tessa.png: 2 vakjes) ------------------------------------------------------

def tessa(frame):
    hy = 1 if frame else 0
    img = blank()
    hood, hood_d, hood_l = c("#3f9a54"), c("#2a6e3c"), c("#74cc82")
    hair = c("#b0521f")
    # Groene kap met een rode veer.
    rect(img, 4, 2 + hy, 11, 4 + hy, hood)
    rect(img, 5, 1 + hy, 10, 1 + hy, hood)
    rect(img, 5, 1 + hy, 8, 1 + hy, hood_l)
    rect(img, 4, 2 + hy, 6, 2 + hy, hood_l)
    put(img, 11, 1 + hy, FEATHER)
    put(img, 12, 0 + hy, FEATHER)
    put(img, 11, 0 + hy, FEATHER_D)
    ch._head(img, hy)
    rect(img, 4, 5 + hy, 4, 7 + hy, hood_d)
    rect(img, 11, 5 + hy, 11, 7 + hy, hood_d)
    rect(img, 5, 5 + hy, 10, 5 + hy, hood)
    put(img, 5, 5 + hy, hair)  # een plukje haar onder de kap
    put(img, 10, 5 + hy, hair)
    # Tuniek met een leren band en een pijlenkoker op de rug.
    ch._torso(img, c("#4aa05a"), c("#2f7040"), c("#3a8a4a"))
    rect(img, 4, 8, 11, 8, hood_l)
    line(img, (4, 8), (10, 11), c("#7a4a24"))
    rect(img, 4, 11, 11, 11, ch.BELT)
    rect(img, 7, 11, 8, 11, ch.GOLD)
    rect(img, 12, 4, 13, 9, WOOD_D)  # koker
    rect(img, 12, 4, 12, 9, WOOD)
    put(img, 12, 3, FEATHER)
    put(img, 13, 3, c("#f4f0e0"))
    put(img, 13, 2, FEATHER_D)
    ch._legs(img, c("#6b4a2a"), c("#3a2410"))
    return outline(img)


def sheets():
    return {
        "items_boog": strip([icon_bow(), icon_arrow(), arrow_flying()]),
        "target": strip([target(False), target(True)]),
        "npc_tessa": ch.npc_sheet(tessa),
    }
