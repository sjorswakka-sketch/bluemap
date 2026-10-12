"""Original, deterministic 16px profession icons and resource sprites.

Automatically included by make_art.py; sheets() only creates the two new sheets.
"""
from artlib import blank, c, ellipse, hline, line, outline, polygon, put, rect, strip, vline

WOOD = c("a46f43")
LIGHT = c("e3b579")
GREEN = c("59aa6f")
LEAF = c("a0dd9a")
STONE = c("8997ae")
COPPER = c("d68a52")
IRON = c("b9d0dd")


def branch():
    im = blank()
    line(im, (3, 13), (12, 3), WOOD, 2)
    line(im, (8, 8), (4, 5), LIGHT, 2)
    line(im, (9, 7), (13, 7), WOOD, 2)
    return outline(im)


def rock(color=STONE, ore=False):
    im = blank()
    polygon(im, [(2, 11), (4, 5), (9, 3), (13, 7), (14, 12), (9, 14), (3, 13)], STONE)
    polygon(im, [(4, 5), (9, 3), (10, 8), (3, 10)], c("bac5d3"))
    if ore:
        polygon(im, [(6, 6), (9, 5), (10, 8), (7, 10)], color)
        rect(im, 10, 10, 12, 12, color)
        rect(im, 4, 10, 5, 12, color)
    return outline(im)


def herb():
    im = blank()
    line(im, (8, 14), (8, 3), GREEN, 2)
    for x, y, sign in [(7, 10, -1), (9, 8, 1), (7, 6, -1)]:
        polygon(im, [(x, y), (x + 4 * sign, y - 3), (x + 4 * sign, y), (x, y + 1)], LEAF)
    rect(im, 7, 2, 9, 3, c("e1fff0"))
    return outline(im)


def berry():
    im = blank()
    line(im, (8, 7), (9, 2), GREEN, 2)
    polygon(im, [(9, 3), (13, 2), (12, 5), (9, 5)], LEAF)
    for x, y in [(4, 7), (8, 6), (6, 11), (10, 10)]:
        ellipse(im, (x - 2, y - 2, x + 2, y + 2), c("6863b6"))
        rect(im, x - 1, y - 1, x, y - 1, c("b0b8ff"))
    return outline(im)


def log():
    im = blank()
    polygon(im, [(3, 6), (10, 3), (14, 8), (6, 13)], WOOD)
    line(im, (5, 7), (11, 4), LIGHT)
    line(im, (7, 10), (13, 7), c("704b32"))
    ellipse(im, (1, 6, 7, 13), LIGHT)
    ellipse(im, (3, 8, 5, 11), WOOD)
    return outline(im)


def ingot(color):
    im = blank()
    polygon(im, [(2, 9), (5, 5), (12, 5), (14, 10), (11, 13), (2, 13)], color)
    polygon(im, [(2, 9), (5, 5), (12, 5), (10, 9)], tuple(min(255, v + 35) for v in color[:3]) + (255,))
    line(im, (10, 9), (11, 13), c("66544e"))
    return outline(im)


def tool(color, pick=False):
    im = blank()
    line(im, (4, 13), (11, 4), WOOD, 2)
    line(im, (5, 13), (12, 4), LIGHT)
    if pick:
        polygon(im, [(3, 4), (5, 2), (9, 2), (13, 6), (14, 10), (10, 6), (6, 4)], color)
    else:
        polygon(im, [(8, 3), (12, 3), (13, 7), (10, 9), (6, 7)], color)
    return outline(im)


def tonic():
    im = blank()
    rect(im, 6, 2, 9, 4, LIGHT)
    rect(im, 6, 5, 9, 7, c("d2e9ec"))
    ellipse(im, (3, 6, 12, 14), c("cfede3"))
    ellipse(im, (4, 8, 11, 13), c("61cf9c"))
    polygon(im, [(8, 8), (6, 11), (8, 11), (7, 14), (10, 10), (8, 10)], c("edffd2"))
    return outline(im)


def bowl(kind):
    im = blank()
    ellipse(im, (2, 7, 13, 13), c("885032"))
    ellipse(im, (2, 5, 13, 10), LIGHT)
    ellipse(im, (3, 6, 12, 9), c("6f406c") if kind == "berries" else c("d5a958"))
    if kind == "fish":
        polygon(im, [(4, 7), (6, 5), (10, 6), (12, 4), (12, 9), (10, 7), (6, 9)], c("d2bc82"))
        rect(im, 5, 6, 5, 6, c("202d44"))
    else:
        for x, y in [(5, 7), (9, 8), (8, 6)]:
            rect(im, x, y, x + 1, y + 1, c("a5a6ed") if kind == "berries" else LEAF)
    return outline(im)


def mushroom():
    im = blank()
    rect(im, 7, 8, 9, 14, c("eadabc"))
    ellipse(im, (2, 3, 13, 10), c("d8a44f"))
    rect(im, 3, 8, 12, 10, c("9f6e38"))
    rect(im, 5, 5, 6, 6, c("ffdf96"))
    rect(im, 10, 6, 11, 6, c("ffdf96"))
    return outline(im)


def bush():
    im = blank()
    for x, y in [(5, 9), (10, 9), (8, 5)]:
        ellipse(im, (x - 4, y - 3, x + 4, y + 3), GREEN)
    for x, y in [(4, 8), (8, 5), (11, 9), (7, 11)]:
        rect(im, x, y, x + 1, y + 1, c("9692df"))
    return outline(im)


def stump():
    im = blank()
    polygon(im, [(4, 5), (12, 5), (12, 11), (14, 14), (2, 14), (4, 11)], c("d3d5c2"))
    ellipse(im, (4, 3, 12, 8), LIGHT)
    ellipse(im, (6, 4, 10, 6), WOOD)
    rect(im, 4, 10, 6, 11, c("56616a"))
    rect(im, 10, 9, 12, 9, c("56616a"))
    return outline(im)


ICE = c("9fd8f0")
ICE_DARK = c("5ea8cc")
FROST = c("eaf7ff")
BERRY_RED = c("d96a7e")
PINE_WOOD = c("7a5c3d")
PINE_DARK = c("5c4229")


def iceflower():
    im = blank()
    line(im, (8, 14), (8, 6), c("6fae9a"), 1)
    for x, y in [(8, 2), (5, 4), (11, 4), (6, 7), (10, 7)]:
        polygon(im, [(x, y), (x + 1, y - 1), (x + 2, y), (x + 1, y + 1)], ICE)
    rect(im, 7, 4, 8, 5, FROST)
    rect(im, 7, 9, 8, 10, c("a5e8f2"))
    return outline(im)


def winterberry():
    im = blank()
    line(im, (8, 7), (9, 2), c("6fae9a"), 1)
    polygon(im, [(9, 3), (13, 2), (12, 5), (9, 5)], c("cfe8dd"))
    for x, y in [(4, 7), (8, 6), (6, 11), (10, 10)]:
        ellipse(im, (x - 2, y - 2, x + 2, y + 2), BERRY_RED)
        rect(im, x - 1, y - 2, x, y - 2, FROST)
    return outline(im)


def pinelog():
    im = blank()
    polygon(im, [(3, 6), (10, 3), (14, 8), (6, 13)], PINE_WOOD)
    line(im, (5, 7), (11, 4), c("a9835e"))
    line(im, (7, 10), (13, 7), PINE_DARK)
    ellipse(im, (1, 6, 7, 13), c("c9a06a"))
    ellipse(im, (3, 8, 5, 11), PINE_DARK)
    return outline(im)


def icecrystal():
    im = blank()
    polygon(im, [(7, 1), (10, 5), (9, 13), (6, 13), (5, 5)], ICE)
    polygon(im, [(7, 2), (8, 5), (8, 12), (7, 12)], FROST)
    polygon(im, [(11, 6), (13, 9), (12, 14), (10, 14), (10, 9)], ICE_DARK)
    polygon(im, [(2, 8), (5, 10), (5, 14), (3, 14), (2, 11)], ICE_DARK)
    return outline(im)


def frosttonic():
    im = blank()
    rect(im, 6, 2, 9, 4, c("b9c9d8"))
    rect(im, 6, 5, 9, 7, c("d2e9ec"))
    ellipse(im, (3, 6, 12, 14), c("dceffb"))
    ellipse(im, (4, 8, 11, 13), ICE)
    polygon(im, [(8, 8), (6, 11), (8, 11), (7, 14), (10, 10), (8, 10)], FROST)
    return outline(im)


def winterbowl():
    im = blank()
    ellipse(im, (2, 7, 13, 13), c("885032"))
    ellipse(im, (2, 5, 13, 10), LIGHT)
    ellipse(im, (3, 6, 12, 9), BERRY_RED)
    for x, y in [(5, 7), (9, 8), (8, 6)]:
        rect(im, x, y, x + 1, y + 1, FROST)
    rect(im, 7, 3, 7, 3, c("f4fbff"))
    rect(im, 9, 2, 9, 2, c("f4fbff"))
    return outline(im)


def iceflower_bush():
    im = blank()
    ellipse(im, (2, 11, 13, 15), c("dfe9f2"))
    for x, y in [(4, 8), (8, 5), (11, 9), (7, 10)]:
        line(im, (x, 12), (x, y + 2), c("6fae9a"), 1)
        polygon(im, [(x, y), (x + 1, y - 1), (x + 2, y), (x + 1, y + 1)], ICE)
    rect(im, 8, 5, 9, 6, FROST)
    return outline(im)


def frostbush():
    im = blank()
    for x, y in [(5, 9), (10, 9), (8, 5)]:
        ellipse(im, (x - 4, y - 3, x + 4, y + 3), c("7fae9f"))
    for x, y in [(4, 8), (8, 5), (11, 9), (7, 11)]:
        rect(im, x, y, x + 1, y + 1, BERRY_RED)
    for x, y in [(3, 6), (9, 3), (12, 7)]:
        rect(im, x, y, x + 1, y, FROST)
    return outline(im)


def pinestump():
    im = blank()
    polygon(im, [(4, 5), (12, 5), (12, 11), (14, 14), (2, 14), (4, 11)], c("8a6a4a"))
    ellipse(im, (4, 3, 12, 8), c("c9a06a"))
    ellipse(im, (6, 4, 10, 6), PINE_DARK)
    rect(im, 4, 10, 6, 11, c("4a3b2c"))
    rect(im, 10, 9, 12, 9, c("4a3b2c"))
    rect(im, 5, 3, 11, 4, FROST)
    return outline(im)


def icevein():
    im = rock(ICE, True)
    rect(im, 3, 2, 4, 3, FROST)
    rect(im, 11, 3, 12, 4, FROST)
    return im


SAND = c("ecd193")
SAND_D = c("d4ac66")
CACTUS = c("4e9e4a")
CACTUS_D = c("33702f")
FIG = c("e87a9a")
FIG_D = c("c85a7a")
WORT = c("b3a04f")
WORT_D = c("8a6f36")
ROCKW = c("c08a54")
ROCKW_D = c("96683c")
ROCKW_L = c("dcb078")
MEAT = c("c94f4f")
MEAT_D = c("963838")
BONE = c("f2eadc")
HIDE = c("b98a5a")
HIDE_D = c("8a6238")


def cactusfig():
    im = blank()
    ellipse(im, (5, 3, 11, 12), FIG)
    ellipse(im, (6, 4, 10, 8), c("f4a5bc"))
    for x, y in [(4, 6), (12, 7), (5, 12), (11, 12)]:
        put(im, x, y, BONE)  # fijne stekeltjes
    rect(im, 7, 1, 9, 3, CACTUS_D)  # restje van het blad
    return outline(im)


def sandwort():
    im = blank()
    line(im, (8, 14), (8, 4), WORT_D, 2)
    for x, y, sign in [(7, 11, -1), (9, 9, 1), (7, 7, -1)]:
        polygon(im, [(x, y), (x + 4 * sign, y - 3), (x + 4 * sign, y), (x, y + 1)], WORT)
    rect(im, 7, 2, 9, 3, c("e8dba0"))
    return outline(im)


def sandstone_rock():
    im = blank()
    polygon(im, [(2, 11), (4, 5), (9, 3), (13, 7), (14, 12), (9, 14), (3, 13)], ROCKW)
    polygon(im, [(4, 5), (9, 3), (10, 8), (3, 10)], ROCKW_L)
    line(im, (3, 10), (13, 9), ROCKW_D)
    line(im, (4, 12), (12, 12), ROCKW_D)
    return outline(im)


def sandbalm():
    im = blank()
    rect(im, 5, 2, 10, 4, ROCKW_D)  # kurk
    ellipse(im, (3, 4, 12, 14), c("e8ddc0"))
    ellipse(im, (4, 7, 11, 13), c("d8c26a"))
    rect(im, 5, 5, 10, 6, c("fbf4dc"))
    polygon(im, [(7, 8), (9, 8), (8, 11)], CACTUS)  # kruidenteken op de pot
    return outline(im)


def rawmeat():
    im = blank()
    ellipse(im, (3, 4, 12, 12), MEAT)
    ellipse(im, (5, 5, 10, 9), c("e88a7a"))
    rect(im, 6, 10, 9, 13, MEAT_D)
    ellipse(im, (6, 2, 9, 5), BONE)  # botje
    return outline(im)


def hide():
    im = blank()
    # een uitgespreide vacht: breder midden, pootpunten aan de hoeken
    polygon(im, [(4, 3), (12, 3), (14, 7), (13, 12), (3, 12), (2, 7)], HIDE)
    polygon(im, [(5, 4), (11, 4), (12, 8), (11, 11), (5, 11), (4, 8)], c("d4a878"))
    for x, y in [(3, 2), (13, 2), (2, 13), (14, 13)]:
        put(im, x, y, HIDE_D)
    return outline(im)


def roast():
    im = blank()
    ellipse(im, (1, 8, 14, 13), c("e8e4d4"))  # bord
    ellipse(im, (3, 5, 12, 11), c("a96f3a"))  # gebraden stuk
    ellipse(im, (4, 6, 9, 9), c("d89a5a"))
    line(im, (10, 5), (13, 2), BONE, 2)  # bot eruit
    put(im, 13, 1, BONE)
    put(im, 14, 2, BONE)
    put(im, 6, 4, WORT)  # snufje zandkruid
    return outline(im)


def cactusfig_bush():
    im = blank()
    ellipse(im, (2, 12, 13, 15), SAND_D)
    rect(im, 7, 4, 9, 13, CACTUS)
    vline(im, 7, 4, 13, CACTUS_D)
    rect(im, 4, 7, 6, 8, CACTUS)
    vline(im, 4, 5, 8, CACTUS)
    rect(im, 10, 8, 12, 9, CACTUS)
    vline(im, 12, 6, 9, CACTUS)
    for x, y in [(8, 3), (4, 5), (12, 6)]:
        ellipse(im, (x - 1, y - 1, x + 1, y + 1), FIG)
    return outline(im)


def sandwort_bush():
    im = blank()
    ellipse(im, (2, 12, 13, 15), SAND_D)
    for x0, x1, y in [(8, 8, 3), (6, 5, 5), (10, 11, 5), (5, 4, 8), (11, 12, 8)]:
        line(im, (x0, 12), (x1, y), WORT_D)
        put(im, x1, y - 1, WORT)
    for x, y in [(7, 6), (9, 7), (8, 10)]:
        put(im, x, y, c("e8dba0"))
    return outline(im)


# --- kleding (uiterlijk): pictogrammen op vaste plekken 31 t/m 42 -------------------------

CLOTH = c("b08a5a")   # neutrale stof; de verfkleur zie je pas als je het draagt
CLOTH_D = c("8a6a42")
CLOTH_L = c("d4b083")


def straw_hat():
    im = blank()
    ellipse(im, (4, 2, 11, 8), c("e8cc7a"))
    rect(im, 2, 8, 13, 10, c("dcc06a"))
    rect(im, 4, 7, 11, 8, c("c8a44e"))
    rect(im, 5, 4, 10, 5, c("f2dd96"))
    return outline(im)


def beret():
    im = blank()
    ellipse(im, (3, 4, 13, 11), c("a04a5a"))
    ellipse(im, (5, 5, 11, 8), c("bc6070"))
    rect(im, 7, 1, 8, 4, c("a04a5a"))
    return outline(im)


def beanie():
    im = blank()
    ellipse(im, (4, 3, 11, 10), c("5a7ab0"))
    rect(im, 3, 9, 12, 11, c("46608e"))
    for x in (5, 8, 11):
        vline(im, x, 4, 8, c("6e92c8"))
    ellipse(im, (7, 1, 9, 3), c("e8ecf4"))  # pompon
    return outline(im)


def cape():
    im = blank()
    polygon(im, [(8, 2), (4, 6), (3, 14), (13, 14), (12, 6)], c("7a4a8a"))
    polygon(im, [(8, 3), (6, 6), (5, 13), (7, 13)], c("9662a8"))
    put(im, 8, 3, c("ffd83a"))  # sluiting
    return outline(im)


def scarf():
    im = blank()
    rect(im, 3, 4, 12, 6, c("c8543c"))
    rect(im, 3, 4, 12, 4, c("e06a50"))
    rect(im, 5, 6, 7, 13, c("c8543c"))
    rect(im, 5, 12, 7, 13, c("a04028"))
    for x in (9, 11):
        put(im, x, 5, c("8e3822"))
    return outline(im)


def tunic():
    im = blank()
    rect(im, 5, 3, 10, 11, c("4a7a4e"))
    rect(im, 3, 3, 4, 7, c("4a7a4e"))
    rect(im, 11, 3, 12, 7, c("4a7a4e"))
    rect(im, 5, 10, 10, 11, c("3a603e"))
    rect(im, 5, 7, 10, 8, CLOTH_D)  # ceintuur
    put(im, 7, 4, c("6a9a6e"))
    return outline(im)


def blouse():
    im = blank()
    rect(im, 5, 3, 10, 10, c("e8e0d0"))
    rect(im, 3, 3, 4, 6, c("e8e0d0"))
    rect(im, 11, 3, 12, 6, c("e8e0d0"))
    rect(im, 7, 3, 8, 10, c("d0c4ac"))
    for y in (4, 6, 8):
        put(im, 7, y, CLOTH_D)  # knoopjes
    rect(im, 5, 10, 10, 11, c("c8b89a"))
    return outline(im)


def shirt():
    im = blank()
    rect(im, 4, 3, 11, 11, c("4a6a9a"))
    rect(im, 4, 3, 11, 4, c("5e80b4"))
    rect(im, 7, 3, 8, 5, c("2e4464"))  # kraag
    rect(im, 4, 8, 11, 9, c("3a567e"))
    return outline(im)


def trousers():
    im = blank()
    rect(im, 4, 2, 11, 4, c("5a5a6e"))
    rect(im, 4, 4, 7, 13, c("5a5a6e"))
    rect(im, 8, 4, 11, 13, c("4c4c5e"))
    rect(im, 4, 12, 7, 13, c("3e3e4e"))
    rect(im, 8, 12, 11, 13, c("3e3e4e"))
    return outline(im)


def skirt():
    im = blank()
    rect(im, 5, 2, 10, 4, c("a04a6a"))
    polygon(im, [(5, 4), (10, 4), (13, 13), (2, 13)], c("a04a6a"))
    polygon(im, [(6, 4), (8, 4), (6, 13), (4, 13)], c("bc6080"))
    rect(im, 2, 12, 13, 13, c("7e3852"))
    return outline(im)


def shoes():
    im = blank()
    for x0 in (3, 9):
        rect(im, x0, 7, x0 + 4, 11, c("6e4a2e"))
        rect(im, x0, 10, x0 + 4, 12, c("4e341e"))
        rect(im, x0 + 1, 7, x0 + 2, 8, c("8a6238"))
    return outline(im)


def slippers():
    im = blank()
    for x0 in (3, 9):
        ellipse(im, (x0, 6, x0 + 4, 12), c("c85a7a"))
        ellipse(im, (x0 + 1, 7, x0 + 3, 9), c("e87a9a"))
        put(im, x0 + 2, 6, c("f4f0e8"))  # bontje
    return outline(im)


def sheets():
    icons = [branch(), rock(), herb(), berry(), log(), rock(COPPER, True), rock(IRON, True), ingot(COPPER), ingot(IRON), tool(STONE), tool(STONE, True), tool(COPPER, True), tool(IRON), tonic(), bowl("berries"), bowl("fish"), mushroom(), bowl("stew"), iceflower(), winterberry(), pinelog(), icecrystal(), frosttonic(), winterbowl(), cactusfig(), sandwort(), sandstone_rock(), sandbalm(), rawmeat(), hide(), roast(), straw_hat(), beret(), beanie(), cape(), scarf(), tunic(), blouse(), shirt(), trousers(), skirt(), shoes(), slippers()]
    resources = [branch(), rock(), herb(), bush(), mushroom(), stump(), rock(COPPER, True), rock(IRON, True), iceflower_bush(), frostbush(), pinestump(), icevein(), cactusfig_bush(), sandwort_bush(), sandstone_rock()]
    return {"items_beroepen": strip(icons), "resources_beroepen": strip(resources)}


if __name__ == "__main__":
    from pathlib import Path
    for name, image in sheets().items():
        image.save(Path(__file__).resolve().parent.parent / "assets" / (name + ".png"))
