"""Art voor de arena: trofeeën en de Arenahelm, Arenameester Bruno, het publiek en de gong.

make_art.py roept sheets() aan en slaat elk plaatje op in assets/. De tegels van de arena staan in art_tiles.py.
"""
from artlib import *  # noqa: F401,F403
from art_chars import SKIN, SKIN_D, GOLD, BELT, _head, _legs

# --- trofeeën en helm (assets/items_arena.png, een rij van 16x16: brons, zilver, goud, helm) ----------

METALS = {
    # (hoofdkleur, licht, donker, rand)
    "bronze": (c("#c8803a"), c("#f0b068"), c("#8a4f1e"), c("#4a280e")),
    "silver": (c("#c8d0e0"), c("#f4f8ff"), c("#8a94ac"), c("#3a4258")),
    "gold": (c("#ffd83a"), c("#fff6a8"), c("#c98f12"), c("#7a4a0d")),
}


def trophy(metal):
    main, light, dark, edge = METALS[metal]
    img = blank()
    # oren aan de zijkanten
    ellipse(img, (1, 3, 5, 8), None, main)
    ellipse(img, (10, 3, 14, 8), None, main)
    # beker
    polygon(img, [(3, 2), (12, 2), (11, 8), (9, 10), (6, 10), (4, 8)], main)
    rect(img, 3, 2, 12, 3, light)
    vline(img, 4, 4, 7, light)
    vline(img, 5, 4, 6, light)
    rect(img, 10, 4, 11, 8, dark)
    put(img, 9, 9, dark)
    # steel en voet
    rect(img, 7, 10, 8, 12, dark)
    put(img, 7, 10, main)
    rect(img, 4, 12, 11, 14, main)
    rect(img, 4, 14, 11, 14, dark)
    rect(img, 4, 12, 11, 12, light)
    if metal == "gold":  # ster op de beker en een glinstering
        for x, y in [(7, 4), (8, 4), (7, 5), (8, 5), (6, 5), (9, 5), (7, 6), (8, 6)]:
            put(img, x, y, light)
        put(img, 7, 5, c("#ffffff"))
    else:
        rect(img, 7, 5, 8, 6, light)
    out = outline(img, edge)
    if metal == "gold":
        for x, y in [(14, 1), (13, 1), (15, 1), (14, 0), (14, 2)]:
            put(out, x, y, c("#ffffff"))
    return out


def helm():
    steel, steel_l, steel_d = c("#b8c0d4"), c("#f0f4ff"), c("#7a849c")
    img = blank()
    # rode pluim, als een waaier boven op de helm
    polygon(img, [(3, 6), (4, 2), (7, 0), (11, 1), (13, 3), (13, 6)], c("#e8334a"))
    polygon(img, [(4, 2), (7, 0), (9, 0), (6, 4)], c("#ff8a98"))
    rect(img, 11, 2, 13, 6, c("#a02030"))
    vline(img, 8, 1, 5, c("#c82840"))
    # koepel
    ellipse(img, (2, 4, 13, 14), steel)
    rect(img, 2, 9, 13, 14, steel)
    rect(img, 11, 6, 13, 14, steel_d)
    rect(img, 3, 6, 5, 8, steel_l)
    put(img, 4, 5, steel_l)
    # gouden rand, ooggleuf en neusstuk
    rect(img, 2, 12, 13, 13, c("#e0b84a"))
    hline(img, 2, 13, 13, c("#c98f12"))
    rect(img, 3, 8, 6, 9, c("#1a1a2e"))
    rect(img, 9, 8, 12, 9, c("#1a1a2e"))
    rect(img, 7, 7, 8, 13, steel_d)
    vline(img, 7, 7, 12, steel)
    rect(img, 4, 14, 5, 15, steel_d)
    rect(img, 10, 14, 11, 15, steel_d)
    return outline(img)


def item_icons():
    return strip([trophy("bronze"), trophy("silver"), trophy("gold"), helm()])


# --- Arenameester Bruno (npc_bruno.png, 2 vakjes) ---------------------------------------------------------

def bruno(frame):
    hy = 1 if frame else 0
    img = blank()
    tan, tan_d, tan_l = c("#e0a070"), c("#b87a4a"), c("#f2c090")
    vest, vest_d = c("#7a4a24"), c("#4f2e14")
    red = c("#c8372d")
    # kale kop met rode hoofdband
    rect(img, 5, 3 + hy, 10, 4 + hy, tan)
    put(img, 6, 3 + hy, tan_l)
    put(img, 7, 3 + hy, tan_l)
    rect(img, 5, 4 + hy, 10, 4 + hy, red)
    put(img, 11, 4 + hy, red)
    put(img, 11, 5 + hy, c("#9a2a22"))
    _head(img, hy, tan, tan_d)
    hline(img, 6, 9, 7 + hy, c("#2a1a10"))  # grote snor
    put(img, 5, 7 + hy, c("#2a1a10"))
    put(img, 10, 7 + hy, c("#2a1a10"))
    put(img, 7, 8 + hy, c("#2a1a10"))
    put(img, 8, 8 + hy, c("#2a1a10"))
    # brede schouders met gouden schouderstukken, leren vest
    rect(img, 3, 8, 12, 11, vest)
    rect(img, 11, 8, 12, 11, vest_d)
    rect(img, 6, 9, 9, 9, tan)
    rect(img, 7, 10, 8, 10, tan)
    rect(img, 2, 8, 3, 9, GOLD)
    rect(img, 12, 8, 13, 9, GOLD)
    put(img, 2, 9, c("#c98f12"))
    put(img, 13, 9, c("#c98f12"))
    rect(img, 2, 10, 2, 11, tan)
    rect(img, 13, 10, 13, 11, tan_d)
    rect(img, 4, 11, 11, 11, c("#3a2410"))
    rect(img, 7, 11, 8, 11, GOLD)
    _legs(img, c("#8a2a30"), c("#2a2018"))
    # gongstok in zijn hand
    rect(img, 14, 6, 14, 12, BELT)
    rect(img, 13, 4, 15, 5, GOLD)
    put(img, 14, 4, c("#fff6a8"))
    put(img, 13, 11, tan_d)
    return outline(img)


def bruno_sheet():
    return strip([bruno(0), bruno(1)])


# --- het publiek (assets/arena_crowd.png): per kleurstelling 4 vakjes -----------------------------------
# kolom = kleurstelling * 4 + (2 als je ze van achteren ziet) + (1 als ze juichen)

CROWD_LOOKS = [
    # (haar, huid, huid-donker, shirt, shirt-donker)
    (c("#7a4a24"), SKIN, SKIN_D, c("#d84a4a"), c("#a02e38")),
    (c("#f2d36a"), c("#f0c8a0"), c("#d4a47c"), c("#3f7fe0"), c("#2c58aa")),
    (c("#2a2030"), c("#d9a074"), c("#b87c52"), c("#3a9e4c"), c("#2a7a38")),
    (c("#b5532a"), SKIN, SKIN_D, c("#8a4fc9"), c("#5a2d94")),
]


def spectator(look, back=False, cheer=False):
    hair, skin, skin_d, shirt, shirt_d = CROWD_LOOKS[look]
    img = blank()
    # lijf (de bank verbergt de benen)
    rect(img, 4, 8, 11, 13, shirt)
    rect(img, 10, 8, 11, 13, shirt_d)
    hline(img, 4, 11, 13, shirt_d)
    if cheer:  # armen omhoog
        for x in (2, 12):
            rect(img, x, 7, x + 1, 9, shirt)
            rect(img, x, 3, x + 1, 6, skin)
        rect(img, 12, 7, 13, 9, shirt_d)
    else:
        rect(img, 3, 9, 3, 12, shirt)
        rect(img, 12, 9, 12, 12, shirt_d)
        put(img, 3, 12, skin)
        put(img, 12, 12, skin_d)
    # hoofd
    if back:
        rect(img, 5, 2, 10, 7, hair)
        rect(img, 5, 6, 10, 7, hair)
        put(img, 5, 7, skin_d)
        put(img, 10, 7, skin_d)
    else:
        rect(img, 5, 2, 10, 3, hair)
        rect(img, 4, 3, 4, 5, hair)
        rect(img, 11, 3, 11, 5, hair)
        rect(img, 5, 4, 10, 7, skin)
        rect(img, 5, 7, 10, 7, skin_d)
        put(img, 6, 5, OUTLINE)
        put(img, 9, 5, OUTLINE)
        if cheer:
            rect(img, 7, 6, 8, 7, c("#8a1f2a"))
        else:
            put(img, 7, 6, skin_d)
            put(img, 8, 6, skin_d)
    return outline(img)


def crowd_sheet():
    frames = []
    for look in range(len(CROWD_LOOKS)):
        for back in (False, True):
            for cheer in (False, True):
                frames.append(spectator(look, back, cheer))
    return strip(frames)


# --- de gong en versiering (assets/arena_props.png): gong, gong die galmt, wapenrek, vaandel ---------------

def gong(hit):
    img = blank()
    wood, wood_d = c("#8a5a2c"), c("#5a3a1c")
    bronze, bronze_l, bronze_d = c("#d8a040"), c("#ffe08a"), c("#8a5a12")
    rect(img, 1, 1, 14, 2, wood)  # dwarsbalk
    rect(img, 1, 1, 14, 1, c("#a8743c"))
    rect(img, 1, 1, 2, 15, wood)  # poten
    rect(img, 13, 1, 14, 15, wood)
    vline(img, 1, 1, 15, c("#a8743c"))
    rect(img, 1, 14, 3, 15, wood_d)
    rect(img, 12, 14, 14, 15, wood_d)
    line(img, (8, 2), (8, 4), c("#d8d0c0"))  # touwtje
    dx = 1 if hit else 0
    ellipse(img, (4 + dx, 4, 11 + dx, 12), bronze)
    ellipse(img, (6 + dx, 6, 9 + dx, 10), bronze_d)
    ellipse(img, (7 + dx, 7, 8 + dx, 8), bronze_l)
    put(img, 5 + dx, 6, bronze_l)
    put(img, 5 + dx, 7, bronze_l)
    out = outline(img)
    if hit:  # trillende streepjes
        for x, y in [(2, 5), (2, 8), (2, 11), (15, 6), (15, 9)]:
            put(out, x, y, c("#fff6c0"))
    return out


def weapon_rack():
    img = blank()
    wood, wood_d = c("#8a5a2c"), c("#5a3a1c")
    rect(img, 1, 6, 14, 7, wood)
    rect(img, 1, 12, 14, 13, wood)
    rect(img, 1, 6, 2, 15, wood_d)
    rect(img, 13, 6, 14, 15, wood_d)
    steel, steel_l = c("#b8c0d4"), c("#f0f4ff")
    for x, top in [(4, 1), (7, 3), (10, 1)]:  # zwaarden en een speer
        rect(img, x, top, x, 11, steel)
        vline(img, x, top, 10, steel_l)
        rect(img, x - 1, 10, x + 1, 10, c("#e0b84a"))
        rect(img, x, 11, x, 12, c("#6b4423"))
    polygon(img, [(7, 3), (8, 0), (9, 3)], steel_l)
    return outline(img)


def banner():
    img = blank()
    red, red_d, red_l = c("#c8372d"), c("#8a2a22"), c("#e8584a")
    rect(img, 2, 0, 13, 1, c("#8a5a2c"))
    rect(img, 3, 2, 12, 12, red)
    polygon(img, [(3, 12), (12, 12), (12, 15), (8, 13), (3, 15)], red)
    rect(img, 11, 2, 12, 13, red_d)
    rect(img, 3, 2, 4, 12, red_l)
    # gouden zwaard op het vaandel
    vline(img, 7, 4, 9, GOLD)
    vline(img, 8, 4, 9, c("#c98f12"))
    hline(img, 5, 10, 10, GOLD)
    put(img, 7, 3, c("#fff6a8"))
    put(img, 7, 11, c("#c98f12"))
    put(img, 8, 11, c("#c98f12"))
    return outline(img)


def props_sheet():
    return strip([gong(False), gong(True), weapon_rack(), banner()])


def sheets():
    return {
        "items_arena": item_icons(),
        "npc_bruno": bruno_sheet(),
        "arena_crowd": crowd_sheet(),
        "arena_props": props_sheet(),
    }
