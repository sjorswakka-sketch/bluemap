"""Original, deterministic 16px profession icons and resource sprites.

Automatically included by make_art.py; sheets() only creates the two new sheets.
"""
from artlib import blank, c, ellipse, line, outline, polygon, rect, strip

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


def sheets():
    icons = [branch(), rock(), herb(), berry(), log(), rock(COPPER, True), rock(IRON, True), ingot(COPPER), ingot(IRON), tool(STONE), tool(STONE, True), tool(COPPER, True), tool(IRON), tonic(), bowl("berries"), bowl("fish"), mushroom(), bowl("stew"), iceflower(), winterberry(), pinelog(), icecrystal(), frosttonic(), winterbowl()]
    resources = [branch(), rock(), herb(), bush(), mushroom(), stump(), rock(COPPER, True), rock(IRON, True), iceflower_bush(), frostbush(), pinestump(), icevein()]
    return {"items_beroepen": strip(icons), "resources_beroepen": strip(resources)}


if __name__ == "__main__":
    from pathlib import Path
    for name, image in sheets().items():
        image.save(Path(__file__).resolve().parent.parent / "assets" / (name + ".png"))
