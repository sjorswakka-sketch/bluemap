"""De Diepte (spoor diepte): voorwerp-iconen, objecten, de pilaren, het zegel en De Vergeten Wachter.

  items_diepte.png    16x16 per vakje: 0 = Sterrenzwaard, 1 = Kristalsleutel
  depths_objects.png  16x16 per vakje: 0-1 kristallamp, 2 poort, 3-4 scherf (projectiel)
  depths_pillar.png   16x32 per vakje: 0 = pilaar rustig, 1 = pilaar laadt op
  depths_seal.png     32x32 per vakje: 0-1 zegel (pulseert), 2 = gebarsten
  guardian.png        48x48 per vakje: 0-1 rustig, 2 aanloop storm, 3 storm, 4 klap omhoog, 5 klap omlaag,
                      6 uitgeput, 7 brul (fasewissel)
  golem_void.png      32x32: dezelfde vakjes als golem.png, maar paars (de kristalgolem van de Diepte)
"""
import math

from artlib import *  # noqa: F401,F403
import art_chars as ch

# Paletten van de Diepte (zelfde als de tegels in art_tiles.py)
STONE, STONE_D, STONE_L, STONE_X = c("#4a4482"), c("#2d2859"), c("#6e66b8"), c("#1b1740")
CR, CR_D, CR_L, CR_EDGE = c("#b46bff"), c("#7f3fd6"), c("#ecd4ff"), c("#2a0f5e")
GLOW, GLOW_L = c("#9ee8ff"), c("#ffffff")
DEEP = c("#120f2a")


# --- voorwerp-iconen ----------------------------------------------------------------------------------

def icon_star_sword():
    img = blank()
    blade, blade_l, blade_d = c("#cfe6ff"), c("#ffffff"), c("#7fa8e8")
    polygon(img, [(14, 1), (14, 4), (6, 10), (5, 9), (11, 2)], blade)
    line(img, (13, 2), (6, 9), blade_l)
    line(img, (13, 4), (7, 10), blade_d)
    polygon(img, [(3, 8), (8, 13), (7, 14), (2, 9)], c("#ffd83a"))  # kruisstuk
    line(img, (3, 9), (7, 13), c("#c98f12"))
    line(img, (4, 11), (2, 13), c("#4a4482"), 2)
    put(img, 1, 14, CR)  # edelsteen in de knop
    put(img, 0, 14, CR_D)
    out = outline(img)
    for x, y in [(11, 0), (12, 1), (12, 0), (13, 0)]:  # sterretje bij de punt
        put(out, x, y, c("#ffffff"))
    for x, y in [(15, 0), (15, 5), (10, 1)]:
        put(out, x, y, c("#a8e8ff"))
    return out


def icon_depths_key():
    img = blank()
    silver, silver_d, silver_l = c("#b8c0dc"), c("#7a82a8"), c("#eef2ff")
    polygon(img, [(4, 1), (7, 3), (7, 7), (4, 9), (1, 7), (1, 3)], CR)  # kristalkop
    polygon(img, [(4, 1), (7, 3), (7, 7), (4, 9)], CR_D)
    polygon(img, [(4, 3), (5, 4), (4, 6), (3, 4)], CR_L)
    line(img, (6, 8), (13, 14), silver, 2)
    rect(img, 12, 12, 14, 14, silver)  # baard van de sleutel
    rect(img, 13, 10, 14, 12, silver)
    rect(img, 10, 12, 11, 14, silver)
    put(img, 14, 10, silver_l)
    put(img, 7, 8, silver_l)
    put(img, 12, 13, silver_d)
    return outline(img, CR_EDGE)


def items_sheet():
    return strip([icon_star_sword(), icon_depths_key()])


# --- objecten --------------------------------------------------------------------------------------------

def lamp(frame):
    """Een kristal dat boven een stenen voetstuk zweeft en licht geeft."""
    img = blank()
    rect(img, 5, 12, 10, 14, STONE)
    rect(img, 4, 14, 11, 15, STONE_D)
    hline(img, 5, 10, 12, STONE_L)
    bob = 1 if frame else 0
    cx, top = 8, 1 + bob
    polygon(img, [(cx, top), (cx + 3, top + 4), (cx, top + 9), (cx - 3, top + 4)], CR)
    polygon(img, [(cx, top), (cx + 3, top + 4), (cx, top + 9)], CR_D)
    polygon(img, [(cx, top + 2), (cx + 1, top + 4), (cx, top + 5), (cx - 1, top + 4)], CR_L)
    out = outline(img, DEEP)
    if frame:
        for x, y in [(3, 3), (13, 6), (12, 2)]:
            put(out, x, y, GLOW)
    else:
        for x, y in [(4, 7), (12, 3)]:
            put(out, x, y, GLOW)
    return out


def crystal_gate():
    """Een poort van gloeiende kristalstaven tussen twee donkere stenen pijlers."""
    img = blank()
    for x in (0, 1, 14, 15):
        vline(img, x, 0, 15, STONE)
    vline(img, 0, 0, 15, STONE_L)
    vline(img, 15, 0, 15, STONE_D)
    for x in (3, 6, 9, 12):
        rect(img, x, 0, x + 1, 15, CR_D)
        vline(img, x, 0, 15, CR)
        put(img, x, 0, CR_L)
        put(img, x, 5, CR_L)
        put(img, x, 11, CR_L)
    rect(img, 0, 3, 15, 4, STONE_D)
    rect(img, 0, 11, 15, 12, STONE_D)
    hline(img, 0, 15, 3, STONE)
    hline(img, 0, 15, 11, STONE)
    # slot in het midden
    rect(img, 6, 7, 9, 8, c("#ffd83a"))
    put(img, 7, 7, c("#fff3a6"))
    return outline(img, DEEP)


def shard(frame):
    """Een kristalscherf die naar rechts wijst (wordt in het spel gedraaid)."""
    img = blank()
    polygon(img, [(1, 8), (6, 5), (14, 8), (6, 11)], CR)
    polygon(img, [(1, 8), (6, 8), (14, 8), (6, 11)], CR_D)
    polygon(img, [(4, 7), (8, 6), (11, 8), (6, 8)], CR_L)
    out = outline(img, CR_EDGE)
    if frame:
        for x, y in [(2, 6), (3, 5)]:
            put(out, x, y, GLOW)
    else:
        put(out, 3, 10, GLOW)
        put(out, 2, 10, GLOW)
    return out


def objects_sheet():
    return strip([lamp(0), lamp(1), crystal_gate(), shard(0), shard(1)])


# --- pilaar (16x32) -------------------------------------------------------------------------------------

def pillar(charged):
    img = blank(16, 32)
    # voet en schacht
    rect(img, 3, 26, 12, 30, STONE_D)
    rect(img, 2, 28, 13, 30, STONE)
    rect(img, 5, 10, 10, 27, STONE)
    rect(img, 5, 10, 6, 27, STONE_L)
    rect(img, 9, 10, 10, 27, STONE_D)
    for y in (14, 19, 24):
        hline(img, 5, 10, y, STONE_X)
    rune = GLOW if charged else c("#6a58d8")
    put(img, 7, 16, rune)
    put(img, 8, 16, rune)
    put(img, 7, 17, rune)
    put(img, 8, 21, rune)
    put(img, 7, 22, rune)
    put(img, 8, 22, rune)
    # kristal bovenop
    cr = CR if not charged else c("#ff8ad8")
    cr_d = CR_D if not charged else c("#d83aa8")
    polygon(img, [(8, 0), (12, 5), (8, 11), (4, 5)], cr)
    polygon(img, [(8, 0), (12, 5), (8, 11)], cr_d)
    polygon(img, [(8, 2), (9, 5), (8, 7), (7, 5)], CR_L)
    polygon(img, [(3, 9), (5, 6), (6, 11)], cr_d)
    polygon(img, [(13, 9), (11, 6), (10, 11)], cr_d)
    out = outline(img, DEEP)
    if charged:
        for x, y in [(2, 3), (14, 4), (1, 8), (15, 9)]:
            put(out, x, y, c("#ffe4f4"))
    return out


def pillar_sheet():
    return strip([pillar(False), pillar(True)])


# --- zegel (32x32) --------------------------------------------------------------------------------------

def seal(frame):
    """Een stenen plaat met een grote ster, die de trap in de tempel afsluit. 0-1 pulserend, 2 gebarsten."""
    img = blank(32, 32)
    rect(img, 1, 1, 30, 30, STONE)
    rect(img, 1, 1, 30, 3, STONE_L)
    rect(img, 1, 27, 30, 30, STONE_D)
    vline(img, 1, 1, 30, STONE_L)
    vline(img, 30, 1, 30, STONE_D)
    rect(img, 3, 5, 28, 26, STONE_D)  # verdiept vlak met een rand
    rect(img, 4, 6, 27, 25, c("#3a3470"))
    for x in (4, 27):  # klinknagels
        for y in (4, 27):
            put(img, x, y, c("#8c7cf0"))
            put(img, x + (1 if x == 4 else -1), y, c("#2d2859"))
    glow = [c("#8c7cf0"), c("#cfc4ff"), c("#ffffff")][frame]
    ring = c("#6a58d8") if frame != 1 else c("#9a8cf0")
    ellipse(img, (6, 7, 25, 24), None, ring)
    ellipse(img, (8, 9, 23, 22), None, c("#4a4390"))
    # een ster met acht punten
    star = [(16, 8), (18, 13), (23, 15), (18, 17), (16, 23), (14, 17), (9, 15), (14, 13)]
    polygon(img, star, glow)
    polygon(img, [(16, 11), (17, 14), (20, 15), (17, 16), (16, 20), (15, 16), (12, 15), (15, 14)], c("#ffffff") if frame else c("#cfc4ff"))
    put(img, 15, 15, c("#ffffff"))
    put(img, 16, 15, c("#ffffff"))
    for x, y in [(6, 15), (7, 15), (24, 15), (25, 15), (15, 6), (16, 6), (15, 25), (16, 25), (8, 10), (23, 10), (8, 21), (23, 21)]:
        put(img, x, y, ring)
    if frame == 2:
        for p0, p1 in [((14, 1), (16, 14)), ((16, 14), (10, 31)), ((16, 14), (28, 20)), ((28, 20), (31, 26)), ((6, 3), (11, 12)),
                       ((16, 14), (4, 18)), ((22, 5), (17, 13))]:
            line(img, p0, p1, STONE_X)
        for p in [(15, 14), (16, 15), (17, 14), (16, 13)]:
            put(img, p[0], p[1], c("#ffffff"))
    return outline(img, DEEP)


def seal_sheet():
    return strip([seal(0), seal(1), seal(2)])


# --- De Vergeten Wachter (48x48) -------------------------------------------------------------------------

def _limb(img, p0, p1, width, fill_col, edge=None):
    """Een dikke lijn als veelhoek (voor armen en benen)."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length * width / 2.0, dx / length * width / 2.0
    pts = [(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny), (p1[0] - nx, p1[1] - ny), (p0[0] - nx, p0[1] - ny)]
    polygon(img, pts, fill_col, edge)


def _fist(img, cx, cy, big=True):
    s = 5 if big else 4
    rect(img, cx - s, cy - s + 1, cx + s, cy + s, STONE)
    rect(img, cx - s, cy - s + 1, cx + s, cy - s + 2, STONE_L)
    rect(img, cx + s - 1, cy - s + 3, cx + s, cy + s, STONE_D)
    for k in (-2, 0, 2):  # knokkels
        put(img, cx + k, cy + 1, STONE_X)
    put(img, cx - s + 1, cy - s + 1, CR)


def guardian(frame):
    """0/1 rustig, 2 aanloop storm, 3 storm, 4 klap omhoog, 5 klap omlaag, 6 uitgeput, 7 brul."""
    img = blank(48, 48)
    bob = 1 if frame == 1 else 0
    # houding per vakje: (romp-dy, romp-dx, hoofd-dy, kern-helderheid, armen)
    posture = {
        0: dict(dy=0, dx=0, head=0, core=1, arms=((10, 26), (38, 26))),
        1: dict(dy=bob, dx=0, head=0, core=2, arms=((10, 27), (38, 27))),
        2: dict(dy=3, dx=-2, head=2, core=2, arms=((6, 30), (40, 30))),
        3: dict(dy=2, dx=4, head=3, core=3, arms=((5, 26), (41, 28))),
        4: dict(dy=-1, dx=0, head=-1, core=3, arms=((7, 3), (41, 3))),
        5: dict(dy=5, dx=0, head=4, core=3, arms=((6, 41), (42, 41))),
        6: dict(dy=9, dx=0, head=7, core=0, arms=((10, 40), (38, 40))),
        7: dict(dy=-1, dx=0, head=-1, core=3, arms=((3, 18), (45, 18))),
    }[frame]
    dy, dx, head_dy, core, arms = posture["dy"], posture["dx"], posture["head"], posture["core"], posture["arms"]

    # benen (breed uit elkaar, als twee stenen zuilen)
    leg_top = 31 + dy
    for lx in (14, 27):
        rect(img, lx, leg_top, lx + 6, 44, STONE)
        rect(img, lx, leg_top, lx + 1, 44, STONE_L)
        rect(img, lx + 5, leg_top, lx + 6, 44, STONE_D)
        rect(img, lx - 2, 41, lx + 8, 46, STONE_D)
        rect(img, lx - 2, 41, lx + 8, 42, STONE)
        hline(img, lx, lx + 6, leg_top + 5, STONE_X)

    # romp: brede borstplaat die naar onder smaller wordt
    tx = 24 + dx
    top, bottom = 14 + dy, 34 + dy
    polygon(img, [(tx - 13, top), (tx + 13, top), (tx + 9, bottom), (tx - 9, bottom)], STONE)
    polygon(img, [(tx - 13, top), (tx - 4, top), (tx - 3, bottom), (tx - 9, bottom)], STONE_L)
    polygon(img, [(tx + 6, top), (tx + 13, top), (tx + 9, bottom), (tx + 4, bottom)], STONE_D)
    hline(img, tx - 9, tx + 9, bottom - 1, STONE_X)
    hline(img, tx - 12, tx + 12, top + 1, STONE_L)
    # oude barsten in de steen, met paars licht erin
    line(img, (tx - 10, top + 3), (tx - 7, top + 9), STONE_X)
    put(img, tx - 8, top + 6, c("#6a58d8"))
    line(img, (tx + 8, top + 9), (tx + 10, top + 15), STONE_X)
    put(img, tx + 9, top + 12, c("#6a58d8"))
    # riem met runen
    rect(img, tx - 9, bottom - 4, tx + 9, bottom - 2, STONE_X)
    for rx in (-6, -2, 2, 6):
        put(img, tx + rx, bottom - 3, c("#6a58d8"))
    # de kern: een ster op de borst (het kaartteken)
    cy = 22 + dy
    glow_cols = [(c("#3a3470"), c("#4a4390")), (c("#8c7cf0"), c("#cfc4ff")), (c("#b8a8ff"), c("#ffffff")), (c("#d8ccff"), c("#ffffff"))][core]
    polygon(img, [(tx, cy - 6), (tx + 2, cy - 2), (tx + 6, cy), (tx + 2, cy + 2), (tx, cy + 6), (tx - 2, cy + 2),
                  (tx - 6, cy), (tx - 2, cy - 2)], glow_cols[0], STONE_X)
    polygon(img, [(tx, cy - 3), (tx + 1, cy - 1), (tx + 3, cy), (tx + 1, cy + 1), (tx, cy + 3), (tx - 1, cy + 1),
                  (tx - 3, cy), (tx - 1, cy - 1)], glow_cols[1])

    # schouders met kristallen
    for sx, flip in ((tx - 15, -1), (tx + 15, 1)):
        ellipse(img, (sx - 5, top - 3, sx + 5, top + 8), STONE, STONE_X)
        rect(img, sx - 3, top - 2, sx + 1, top, STONE_L)
        base_x = sx + flip * 1
        polygon(img, [(base_x - 3, top - 2), (base_x, top - 10), (base_x + 3, top - 2)], CR, CR_EDGE)
        polygon(img, [(base_x, top - 10), (base_x + 3, top - 2), (base_x, top - 2)], CR_D)
        put(img, base_x - 1, top - 6, CR_L)

    # armen
    for (ax, ay), sx in zip(arms, (tx - 15, tx + 15)):
        _limb(img, (sx, top + 4), (ax + dx // 2, ay), 7, STONE, STONE_X)
        _limb(img, (sx - 1, top + 4), (ax - 1 + dx // 2, ay), 2, STONE_L)
        _fist(img, ax + dx // 2, ay)

    # hoofd: een helm met een gleuf en gloeiende ogen
    hy = 4 + dy + head_dy
    hx = tx
    polygon(img, [(hx - 8, hy + 14), (hx - 9, hy + 4), (hx - 5, hy), (hx + 5, hy), (hx + 9, hy + 4), (hx + 8, hy + 14)], STONE, STONE_X)
    rect(img, hx - 8, hy + 3, hx - 5, hy + 12, STONE_L)
    rect(img, hx + 5, hy + 3, hx + 8, hy + 12, STONE_D)
    rect(img, hx - 5, hy + 5, hx + 5, hy + 11, DEEP)  # donker gezicht
    eye = GLOW if frame != 6 else c("#3a3470")
    rect(img, hx - 4, hy + 7, hx - 2, hy + 8, eye)
    rect(img, hx + 2, hy + 7, hx + 4, hy + 8, eye)
    if frame in (3, 5, 7):  # kwaad: schuine wenkbrauwen
        line(img, (hx - 5, hy + 5), (hx - 1, hy + 6), STONE_X, 1)
        line(img, (hx + 5, hy + 5), (hx + 1, hy + 6), STONE_X, 1)
    if frame == 7:  # mond open: brul
        rect(img, hx - 3, hy + 10, hx + 3, hy + 12, c("#6a58d8"))
    # kroon van drie kristallen
    for kx, kh in ((-5, 7), (0, 10), (5, 7)):
        polygon(img, [(hx + kx - 2, hy + 1), (hx + kx, hy + 1 - kh), (hx + kx + 2, hy + 1)], CR, CR_EDGE)
        polygon(img, [(hx + kx, hy + 1 - kh), (hx + kx + 2, hy + 1), (hx + kx, hy + 1)], CR_D)
    put(img, hx, hy - 6, CR_L)

    out = outline(img, DEEP)
    if frame in (2, 3):  # snelheidsstreepjes bij de storm
        for y in (18, 26, 34):
            hline(out, 1 if frame == 2 else 0, 6 if frame == 2 else 4, y, c("#6a58d8"))
    return out


def guardian_sheet():
    return strip([guardian(i) for i in range(8)])


# --- paarse golem ------------------------------------------------------------------------------------------

def golem_void_sheet():
    mapping = {
        ch.ST: c("#5e4f9c"), ch.ST_D: c("#3d3274"), ch.ST_L: c("#8b7ccc"), ch.ST_M: c("#2d2859"),
        ch.GLOW: c("#c27bff"), ch.GLOW_L: c("#f4e4ff"), c("#1f88d6"): c("#6a2fc0"),
    }
    return recolor(ch.golem_sheet(), mapping)


def sheets():
    return {
        "items_diepte": items_sheet(),
        "depths_objects": objects_sheet(),
        "depths_pillar": pillar_sheet(),
        "depths_seal": seal_sheet(),
        "guardian": guardian_sheet(),
        "golem_void": golem_void_sheet(),
    }
