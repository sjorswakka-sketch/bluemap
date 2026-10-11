"""Uitbreiding "wereld": zon en maan voor in beeld, bekers voor de prestaties, een altaarspeldje en een lantaarnpaal.

  wereld_ui.png          rij van 16x16: zon, lage zon, maan, beker, beker (nog niet behaald), geheime beker, altaarspeldje
  wereld_lantaarn.png    3 vakjes van 16x32: uit (overdag), aan, aan (de vlam beweegt)
"""
from artlib import *  # noqa: F401,F403

SUN, SUN_L, SUN_D, SUN_EDGE = c("#ffd83a"), c("#fff3a6"), c("#f2a81c"), c("#9a5a0c")
RAY = c("#ffe680")


def _rays(img, cx, cy, near, far, col):
    """Acht korte stralen om een punt, op afstand near..far."""
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
        steps = range(near, far + 1) if dx == 0 or dy == 0 else range(near - 1, far)
        for s in steps:
            put(img, cx + dx * s, cy + dy * s, col)


def sun():
    img = blank()
    _rays(img, 8, 8, 5, 7, RAY)
    disk = blank()
    ellipse(disk, (4, 4, 11, 11), SUN)
    rect(disk, 5, 9, 10, 10, SUN_D)
    hline(disk, 6, 11, 10, SUN_D)
    for x, y in [(5, 5), (6, 5), (5, 6)]:
        put(disk, x, y, SUN_L)
    disk = outline(disk, SUN_EDGE)
    img.paste(disk, (0, 0), disk)
    return img


def low_sun():
    """Een zon die opkomt of ondergaat: halve schijf boven een horizon."""
    img = blank()
    orange, light, dark = c("#ff8a2a"), c("#ffc060"), c("#d9561a")
    _rays(img, 8, 10, 6, 8, c("#ffb060"))
    disk = blank()
    ellipse(disk, (3, 5, 12, 14), orange)
    for x, y in [(5, 7), (6, 7), (5, 8)]:
        put(disk, x, y, light)
    rect(disk, 4, 11, 11, 12, dark)
    disk = outline(disk, c("#7a2a0c"))
    img.paste(disk, (0, 0), disk)
    # De horizon en wat water of land ervoor.
    rect(img, 0, 12, 15, 15, c("#2f3a63"))
    hline(img, 0, 15, 12, c("#1a1a2e"))
    hline(img, 2, 13, 13, c("#ff8a2a"))
    hline(img, 4, 11, 14, c("#d9561a"))
    hline(img, 6, 9, 15, c("#ff8a2a"))
    return img


def moon():
    img = blank()
    body = blank()
    ellipse(body, (2, 3, 12, 13), c("#e8eeff"))
    cut = blank()
    ellipse(cut, (5, 0, 16, 10), c("#ff00ff"))
    for y in range(16):
        for x in range(16):
            if cut.getpixel((x, y))[3] > 0:
                body.putpixel((x, y), (0, 0, 0, 0))
    for x, y in [(3, 9), (3, 10), (4, 11), (5, 12), (6, 12), (4, 7)]:
        if body.getpixel((x, y))[3] > 0:
            put(body, x, y, c("#b8c4ec"))
    for x, y in [(3, 7), (4, 6), (5, 5)]:
        if body.getpixel((x, y))[3] > 0:
            put(body, x, y, c("#ffffff"))
    body = outline(body, c("#1a2a5a"))
    img.paste(body, (0, 0), body)
    for x, y in [(12, 4), (11, 4), (13, 4), (12, 3), (12, 5)]:
        put(img, x, y, c("#ffffff"))
    put(img, 14, 9, c("#cfe0ff"))
    put(img, 10, 12, c("#cfe0ff"))
    return img


def trophy(gold=True, secret=False):
    img = blank()
    if gold:
        body, light, dark, base, base_d = c("#ffd83a"), c("#fff3a6"), c("#c98f12"), c("#a86a1c"), c("#6b4210")
        edge = c("#7a4a0d")
    else:
        body, light, dark, base, base_d = c("#7d849b"), c("#a3aac0"), c("#555b72"), c("#4a4f66"), c("#33384d")
        edge = c("#242840")
    # De handvatten, de beker, de steel en de voet.
    for x, y in [(2, 3), (3, 3), (2, 4), (2, 5), (3, 6), (4, 6), (13, 3), (12, 3), (13, 4), (13, 5), (12, 6), (11, 6)]:
        put(img, x, y, dark)
    polygon(img, [(4, 2), (11, 2), (11, 6), (9, 10), (6, 10), (4, 6)], body)
    rect(img, 4, 2, 11, 3, light)
    vline(img, 5, 3, 7, light)
    vline(img, 10, 4, 7, dark)
    rect(img, 9, 8, 9, 9, dark)
    rect(img, 7, 10, 8, 12, dark if not gold else body)
    rect(img, 5, 13, 10, 14, base)
    hline(img, 5, 10, 14, base_d)
    img = outline(img, edge)
    if secret:
        # Een vraagteken in de beker.
        q = c("#e6ebff")
        for x, y in [(7, 4), (8, 4), (9, 5), (9, 6), (8, 7), (7, 8)]:
            put(img, x, y, q)
        put(img, 7, 10, q)
        put(img, 7, 9, c("#555b72"))
    return img


def altar_pin():
    """Klein blauw kristal: markeert een ontdekt altaar in de lijst voor snel reizen."""
    img = blank()
    polygon(img, [(8, 1), (12, 6), (8, 14), (4, 6)], c("#4cc3ff"))
    polygon(img, [(8, 1), (12, 6), (8, 14)], c("#2d9be6"))
    polygon(img, [(8, 3), (10, 6), (8, 7), (6, 6)], c("#d8f6ff"))
    return outline(img, c("#14487a"))


def lantern(frame):
    """Lantaarnpaal van 16x32. frame 0: uit, 1 en 2: aan (de vlam beweegt)."""
    img = blank(16, 32)
    iron, iron_l, iron_d = c("#4a4f63"), c("#6a7088"), c("#2f3340")
    # Voet en paal.
    rect(img, 4, 29, 11, 31, c("#565c70"))
    hline(img, 4, 11, 29, c("#7a8099"))
    hline(img, 4, 11, 31, iron_d)
    rect(img, 6, 27, 9, 28, iron)
    rect(img, 7, 12, 8, 27, iron)
    vline(img, 7, 12, 27, iron_l)
    rect(img, 6, 11, 9, 12, iron_d)
    # De lamp: dakje, ijzeren frame en glas.
    polygon(img, [(3, 6), (8, 1), (12, 6)], iron_d)
    hline(img, 4, 11, 4, iron)
    put(img, 8, 0, iron_d)
    rect(img, 4, 6, 11, 10, iron_d)
    glass = c("#9fb4c8") if frame == 0 else c("#ffd45a")
    rect(img, 5, 7, 10, 9, glass)
    if frame == 0:
        put(img, 6, 7, c("#cfe0ee"))
        put(img, 7, 9, c("#5a4a3a"))
        put(img, 8, 9, c("#5a4a3a"))
    else:
        rect(img, 6, 7, 9, 9, c("#ffe58a"))
        lean = 1 if frame == 2 else 0
        rect(img, 7, 7, 8, 9, c("#fff6c0"))
        put(img, 7 + lean, 6, c("#ffe58a"))
        put(img, 8, 10, c("#ff9a2a"))
    hline(img, 4, 11, 11, iron_d)
    return outline(img)


def sheets():
    return {
        "wereld_ui": strip([sun(), low_sun(), moon(), trophy(True), trophy(False), trophy(False, True), altar_pin()]),
        "wereld_lantaarn": strip([lantern(0), lantern(1), lantern(2)]),
    }
