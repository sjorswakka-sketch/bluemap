"""Personages en vijanden."""
from artlib import *  # noqa: F401,F403

HAIR, HAIR_D = c("#7a4a24"), c("#4f2e14")
SKIN, SKIN_D = c("#f6cfa6"), c("#dba57c")
TUN, TUN_D, TUN_L = c("#3f7fe0"), c("#2c58aa"), c("#86b9ff")
BELT, GOLD = c("#6b4423"), c("#ffd83a")
PANTS, BOOT = c("#3a3f66"), c("#5a3a1c")


# --- speler ------------------------------------------------------------------------------

def legs_front(img, step):
    left_up = step == 1
    right_up = step == 2
    rect(img, 5, 12, 6, 12 if left_up else 13, PANTS)
    rect(img, 9, 12, 10, 12 if right_up else 13, PANTS)
    rect(img, 5, 13 if left_up else 14, 6, 13 if left_up else 14, BOOT)
    rect(img, 9, 13 if right_up else 14, 10, 13 if right_up else 14, BOOT)


def body_front(img, buckle):
    rect(img, 4, 8, 11, 10, TUN)
    rect(img, 3, 8, 3, 9, TUN)
    rect(img, 12, 8, 12, 9, TUN)
    put(img, 3, 10, SKIN)
    put(img, 12, 10, SKIN)
    rect(img, 11, 8, 11, 10, TUN_D)
    rect(img, 12, 8, 12, 9, TUN_D)
    put(img, 5, 8, TUN_L)
    put(img, 6, 8, TUN_L)
    rect(img, 4, 11, 11, 11, BELT)
    if buckle:
        rect(img, 7, 11, 8, 11, GOLD)


def player(direction, step):
    # De basis-speler is kaal en zonder ogen: haarstijl en ogen komen uit de
    # uiterlijk-laag (scripts/core/appearance_draw.gd), zodat de speler ze kan kiezen.
    img = blank()
    if direction == "down":
        rect(img, 4, 1, 11, 6, SKIN)
        rect(img, 5, 5, 10, 7, SKIN)
        rect(img, 5, 7, 10, 7, SKIN_D)
        body_front(img, buckle=True)
        legs_front(img, step)
    elif direction == "up":
        rect(img, 4, 1, 11, 7, SKIN)
        rect(img, 6, 7, 9, 7, SKIN_D)
        body_front(img, buckle=False)
        legs_front(img, step)
    else:  # rechts
        rect(img, 4, 1, 11, 3, SKIN)
        rect(img, 4, 4, 6, 6, SKIN)
        rect(img, 7, 4, 11, 7, SKIN)
        rect(img, 7, 7, 10, 7, SKIN_D)
        put(img, 11, 6, SKIN_D)
        rect(img, 5, 8, 10, 10, TUN)
        rect(img, 10, 8, 10, 10, TUN_D)
        rect(img, 7, 9, 8, 9, TUN_L)
        put(img, 8, 10, SKIN)
        rect(img, 5, 11, 10, 11, BELT)
        put(img, 9, 11, GOLD)
        if step == 0:
            back, front = (6, 7), (8, 9)
        elif step == 1:
            back, front = (5, 6), (9, 10)
        else:
            back, front = (7, 8), (7, 8)
        rect(img, back[0], 12, back[1], 13, PANTS)
        rect(img, front[0], 12, front[1], 13, PANTS)
        rect(img, back[0], 13 if step == 2 else 14, back[1], 13 if step == 2 else 14, BOOT)
        rect(img, front[0], 14, front[1], 14, BOOT)
    return outline(img)


def player_sheet():
    rows = []
    for direction in ("down", "up", "right"):
        rows.append([player(direction, s) for s in range(3)])
    rows.append([ImageOps.mirror(f) for f in rows[2]])  # links = gespiegeld rechts
    return grid_sheet(rows)


# --- slijmen ---------------------------------------------------------------------------------

SLIME_PALETTES = {
    "green": (c("#5fd36b"), c("#3a9e4c"), c("#b9f7bf"), c("#1f6b34")),
    "blue": (c("#5aa9ff"), c("#3a6fc9"), c("#c0e0ff"), c("#1f3f7a")),
    "red": (c("#ff6a5a"), c("#c23a3a"), c("#ffc0b8"), c("#7a1f1f")),
}


def slime(frame, angry, palette="green"):
    body, dark, light, edge = SLIME_PALETTES[palette]
    img = blank()
    x0, y0, x1, y1 = [(2, 6, 13, 14), (3, 4, 12, 14)][frame]
    ellipse(img, (x0, y0, x1, y1), body)
    for y in range(y1 - 2, y1 + 1):
        for x in range(img.width):
            if img.getpixel((x, y))[3] > 0:
                put(img, x, y, dark)
    for dx, dy in ((3, 2), (4, 2), (3, 3)):
        put(img, x0 + dx, y0 + dy, light)
    ey = y0 + 5
    lx, rx = x0 + 3, x1 - 3
    for x in (lx, rx):
        put(img, x, ey, OUTLINE)
        put(img, x, ey + 1, OUTLINE)
    if angry:
        put(img, lx - 1, ey - 2, OUTLINE)
        put(img, lx, ey - 1, OUTLINE)
        put(img, rx + 1, ey - 2, OUTLINE)
        put(img, rx, ey - 1, OUTLINE)
    return outline(img, edge)


def slime_sheet(palette):
    return strip([slime(0, False, palette), slime(1, False, palette), slime(0, True, palette), slime(1, True, palette)])


# --- vleermuis -----------------------------------------------------------------------------------

def bat(frame):
    body, wing, wing_d = c("#6a4a8a"), c("#4a3268"), c("#2e1e44")
    img = blank()
    if frame == 0:  # vleugels omhoog
        polygon(img, [(6, 8), (1, 2), (2, 9), (5, 11)], wing)
        polygon(img, [(9, 8), (14, 2), (13, 9), (10, 11)], wing)
    elif frame == 1:  # vleugels omlaag
        polygon(img, [(6, 8), (1, 12), (3, 6)], wing)
        polygon(img, [(9, 8), (14, 12), (12, 6)], wing)
    else:  # duikvlucht: vleugels naar achteren
        polygon(img, [(6, 7), (3, 3), (5, 10)], wing)
        polygon(img, [(9, 7), (12, 3), (10, 10)], wing)
    ellipse(img, (5, 6, 10, 12), body)
    put(img, 5, 5, body)
    put(img, 6, 4, body)
    put(img, 10, 5, body)
    put(img, 9, 4, body)
    put(img, 6, 8, c("#ff5a5a"))
    put(img, 9, 8, c("#ff5a5a"))
    put(img, 7, 10, c("#ffffff"))
    put(img, 8, 10, c("#ffffff"))
    return outline(img)


def bat_sheet():
    return strip([bat(0), bat(1), bat(2)])


# --- skelet ------------------------------------------------------------------------------------------

BONE, BONE_D, BONE_L, DARK = c("#e8e4d4"), c("#b8b4a0"), c("#fffff0"), c("#2a2030")


def skeleton(direction, step, aim=False):
    img = blank()
    if direction in ("down", "up"):
        rect(img, 4, 1, 11, 6, BONE)
        rect(img, 5, 7, 10, 7, BONE_D)
        if direction == "down":
            rect(img, 5, 3, 6, 4, DARK)
            rect(img, 9, 3, 10, 4, DARK)
            put(img, 7, 5, DARK)
            put(img, 8, 5, DARK)
            for x in (6, 8, 10):
                put(img, x, 7, DARK)
        else:
            rect(img, 5, 2, 10, 5, BONE_D)
        put(img, 5, 2, BONE_L)
        rect(img, 5, 8, 10, 11, BONE)
        for y in (9, 11):
            hline(img, 5, 10, y, DARK) if direction == "down" else None
        vline(img, 7, 8, 11, BONE_D)
        vline(img, 8, 8, 11, BONE_D)
        if aim:
            vline(img, 3, 6, 9, BONE)
            vline(img, 12, 6, 9, BONE)
            arc_pts = [(1, 4), (0, 8), (1, 12)] if direction == "down" else [(14, 4), (15, 8), (14, 12)]
            line(img, arc_pts[0], arc_pts[1], c("#8a5a2c"), 1)
            line(img, arc_pts[1], arc_pts[2], c("#8a5a2c"), 1)
        else:
            vline(img, 3, 8, 11, BONE)
            vline(img, 12, 8, 11, BONE)
        rect(img, 5, 12, 10, 12, BONE_D)
        left_up = step == 1
        right_up = step == 2
        vline(img, 6, 13, 13 if left_up else 14, BONE)
        vline(img, 9, 13, 13 if right_up else 14, BONE)
        rect(img, 5, 14, 6, 14, BONE_D) if not left_up else None
        rect(img, 9, 14, 10, 14, BONE_D) if not right_up else None
    else:  # rechts
        rect(img, 4, 1, 10, 6, BONE)
        rect(img, 10, 4, 12, 6, BONE)
        rect(img, 7, 3, 8, 4, DARK)
        rect(img, 10, 7, 12, 7, BONE_D)
        for x in (10, 12):
            put(img, x, 7, DARK)
        put(img, 5, 2, BONE_L)
        rect(img, 6, 8, 9, 11, BONE)
        for y in (9, 11):
            hline(img, 6, 9, y, DARK)
        vline(img, 6, 8, 11, BONE_D)
        if aim:
            hline(img, 9, 12, 9, BONE)
            line(img, (13, 5), (14, 8), c("#8a5a2c"))
            line(img, (14, 8), (13, 12), c("#8a5a2c"))
            line(img, (13, 5), (13, 12), c("#cfcfcf"))
            hline(img, 9, 13, 8, c("#cfb890"))
        else:
            vline(img, 9, 9, 11, BONE)
        rect(img, 6, 12, 9, 12, BONE_D)
        if step == 0:
            back, front = 6, 8
        elif step == 1:
            back, front = 5, 9
        else:
            back, front = 7, 7
        vline(img, back, 13, 14, BONE)
        vline(img, front, 13, 14, BONE)
        put(img, back + 1, 14, BONE_D)
        put(img, front + 1, 14, BONE_D)
    return outline(img)


def skeleton_sheet():
    rows = []
    for direction in ("down", "up", "right"):
        rows.append([skeleton(direction, 0), skeleton(direction, 1), skeleton(direction, 2), skeleton(direction, 0, aim=True)])
    rows.append([ImageOps.mirror(f) for f in rows[2]])
    return grid_sheet(rows)


# --- golem (32x32) ---------------------------------------------------------------------------------

ST, ST_D, ST_L, ST_M = c("#7a8299"), c("#566078"), c("#a4adc4"), c("#4f7a55")
GLOW, GLOW_L = c("#4cc3ff"), c("#d8f6ff")


def golem(frame):
    """0/1 = rustig, 2 = armen omhoog (aanloop), 3 = armen op de grond (klap)."""
    img = blank(32, 32)
    bob = 1 if frame == 1 else 0
    # benen
    rect(img, 9, 22, 14, 29, ST_D)
    rect(img, 18, 22, 23, 29, ST_D)
    rect(img, 8, 28, 14, 30, ST)
    rect(img, 18, 28, 24, 30, ST)
    # romp
    rect(img, 7, 9 + bob, 24, 23, ST)
    rect(img, 7, 9 + bob, 24, 11 + bob, ST_L)
    rect(img, 21, 11 + bob, 24, 23, ST_D)
    for x, y in [(9, 14), (10, 14), (19, 18), (12, 20), (20, 13)]:
        put(img, x, y, ST_M)
    # borstkristal
    polygon(img, [(15, 12 + bob), (19, 17), (15, 22), (11, 17)], GLOW, c("#1f88d6"))
    polygon(img, [(15, 13 + bob), (17, 16), (15, 17), (13, 16)], GLOW_L)
    # hoofd
    rect(img, 11, 3 + bob, 20, 9 + bob, ST_D)
    rect(img, 12, 3 + bob, 19, 4 + bob, ST)
    rect(img, 13, 6 + bob, 14, 7 + bob, GLOW)
    rect(img, 17, 6 + bob, 18, 7 + bob, GLOW)
    # schouderkristallen
    polygon(img, [(5, 10 + bob), (7, 3 + bob), (9, 10 + bob)], GLOW, c("#1f88d6"))
    polygon(img, [(22, 10 + bob), (24, 4 + bob), (26, 10 + bob)], GLOW, c("#1f88d6"))
    # armen
    if frame == 2:
        rect(img, 3, 1, 7, 12, ST)
        rect(img, 24, 1, 28, 12, ST)
        rect(img, 2, 0, 8, 3, ST_L)
        rect(img, 23, 0, 29, 3, ST_L)
        rect(img, 3, 4, 4, 12, ST_L)
        rect(img, 7, 8, 8, 12, ST_D)
        rect(img, 24, 8, 25, 12, ST_D)
    elif frame == 3:
        rect(img, 1, 14, 6, 27, ST)
        rect(img, 25, 14, 30, 27, ST)
        rect(img, 0, 25, 8, 31, ST_L)
        rect(img, 23, 25, 31, 31, ST_L)
        rect(img, 5, 16, 6, 27, ST_D)
        rect(img, 29, 16, 30, 27, ST_D)
    else:
        rect(img, 2, 11 + bob, 6, 24, ST)
        rect(img, 25, 11 + bob, 29, 24, ST)
        rect(img, 1, 22, 7, 28, ST_L)
        rect(img, 24, 22, 30, 28, ST_L)
        rect(img, 5, 13 + bob, 6, 24, ST_D)
        rect(img, 29, 13 + bob, 29, 24, ST_D)
    return outline(img)


def golem_sheet():
    return strip([golem(0), golem(1), golem(2), golem(3)])


# --- Slijmkoning (48x48) ---------------------------------------------------------------------------

def king(frame):
    """0/1 = rustig, 2 = ineengedoken/landing, 3 = gestrekt (in de lucht)."""
    body, dark, light = c("#5fd36b"), c("#3a9e4c"), c("#b9f7bf")
    img = blank(48, 48)
    boxes = {0: (4, 15, 43, 46), 1: (5, 13, 42, 46), 2: (1, 23, 46, 46), 3: (9, 12, 38, 46)}
    x0, y0, x1, y1 = boxes[frame]
    ellipse(img, (x0, y0, x1, y1), body)
    for y in range(y1 - 6, y1 + 1):
        for x in range(48):
            if img.getpixel((x, y))[3] > 0:
                put(img, x, y, dark)
    for dx, dy in ((7, 4), (8, 4), (9, 4), (7, 5), (8, 5), (7, 6)):
        put(img, x0 + dx, y0 + dy, light)
    # ingeslikte kristallen
    cx = (x0 + x1) // 2
    for ox, oy in ((-11, 12), (9, 15), (-2, 20)):
        polygon(img, [(cx + ox, y0 + oy - 4), (cx + ox + 2, y0 + oy), (cx + ox, y0 + oy + 4), (cx + ox - 2, y0 + oy)],
                c("#4cc3ff"), c("#1f88d6"))
    # gezicht
    ey = y0 + 11 + (3 if frame == 2 else 0)
    for ex in (cx - 9, cx + 4):
        rect(img, ex, ey, ex + 4, ey + 5, c("#ffffff"))
        rect(img, ex + 2, ey + 2, ex + 4, ey + 5, OUTLINE)
    line(img, (cx - 10, ey - 3), (cx - 4, ey - 1), OUTLINE, 2)
    line(img, (cx + 9, ey - 3), (cx + 3, ey - 1), OUTLINE, 2)
    my = ey + 9
    rect(img, cx - 7, my, cx + 7, my + 3, OUTLINE)
    for tx in range(cx - 6, cx + 7, 3):
        rect(img, tx, my, tx + 1, my + 1, c("#ffffff"))
    # kroon
    top = y0 - 1
    crown = c("#ffd83a")
    crown_d = c("#c98f12")
    rect(img, cx - 9, top - 2, cx + 9, top + 3, crown)
    polygon(img, [(cx - 9, top - 2), (cx - 9, top - 8), (cx - 5, top - 3)], crown)
    polygon(img, [(cx - 3, top - 2), (cx, top - 10), (cx + 3, top - 2)], crown)
    polygon(img, [(cx + 5, top - 3), (cx + 9, top - 8), (cx + 9, top - 2)], crown)
    hline(img, cx - 9, cx + 9, top + 3, crown_d)
    put(img, cx, top, c("#e8334a"))
    put(img, cx - 5, top, c("#4cc3ff"))
    put(img, cx + 5, top, c("#4cc3ff"))
    return outline(img, c("#1f6b34"))


def king_sheet():
    return strip([king(0), king(1), king(2), king(3)])


# --- NPC's ----------------------------------------------------------------------------------------------

def _head(img, dy, skin=SKIN, skin_d=SKIN_D):
    rect(img, 5, 5 + dy, 10, 7 + dy, skin)
    rect(img, 5, 7 + dy, 10, 7 + dy, skin_d)
    put(img, 6, 6 + dy, OUTLINE)
    put(img, 9, 6 + dy, OUTLINE)


def _torso(img, col, col_d, sleeve=None):
    sleeve = sleeve or col
    rect(img, 4, 8, 11, 11, col)
    rect(img, 11, 8, 11, 11, col_d)
    rect(img, 3, 8, 3, 10, sleeve)
    rect(img, 12, 8, 12, 10, col_d)
    put(img, 3, 11, SKIN)
    put(img, 12, 11, SKIN)


def _legs(img, pants=PANTS, boots=BOOT):
    rect(img, 5, 12, 6, 13, pants)
    rect(img, 9, 12, 10, 13, pants)
    rect(img, 5, 14, 6, 14, boots)
    rect(img, 9, 14, 10, 14, boots)


def wizard(frame):  # Oudste Bram
    hy = 1 if frame else 0
    img = blank()
    HAT, HAT_D = c("#7b49c7"), c("#52308f")
    ROBE, ROBE_D = c("#6a3fb5"), c("#4b2a85")
    BEARD, BEARD_D = c("#f2f2f7"), c("#c4c6d6")
    rect(img, 7, 1 + hy, 8, 1 + hy, HAT)
    rect(img, 6, 2 + hy, 9, 2 + hy, HAT)
    rect(img, 5, 3 + hy, 10, 3 + hy, GOLD)
    rect(img, 3, 4 + hy, 12, 4 + hy, HAT_D)
    rect(img, 4, 4 + hy, 11, 4 + hy, HAT)
    put(img, 8, 2 + hy, GOLD)
    rect(img, 5, 5 + hy, 10, 7 + hy, SKIN)
    put(img, 6, 6 + hy, OUTLINE)
    put(img, 9, 6 + hy, OUTLINE)
    put(img, 7, 7 + hy, SKIN_D)
    put(img, 8, 7 + hy, SKIN_D)
    rect(img, 4, 8, 11, 11, ROBE)
    rect(img, 3, 12, 12, 14, ROBE)
    rect(img, 10, 8, 11, 11, ROBE_D)
    rect(img, 11, 12, 12, 14, ROBE_D)
    rect(img, 3, 12, 12, 12, ROBE_D)
    rect(img, 4, 11, 11, 11, GOLD)
    rect(img, 3, 9, 3, 10, ROBE_D)
    put(img, 3, 11, SKIN)
    rect(img, 5, 8, 10, 9, BEARD)
    rect(img, 6, 10, 9, 10, BEARD)
    rect(img, 7, 11, 8, 11, BEARD)
    rect(img, 9, 8, 10, 10, BEARD_D)
    put(img, 10, 9, BEARD)
    rect(img, 13, 4, 13, 14, BELT)
    put(img, 12, 10, ROBE_D)
    put(img, 12, 11, SKIN)
    rect(img, 13, 1, 13, 3, c("#4cc3ff"))
    put(img, 13, 1, c("#a8e8ff"))
    return outline(img)


def greta(frame):  # smid
    hy = 1 if frame else 0
    img = blank()
    hair = c("#b5532a")
    rect(img, 4, 2 + hy, 11, 4 + hy, hair)
    rect(img, 7, 1 + hy, 8, 1 + hy, hair)
    rect(img, 4, 4 + hy, 11, 4 + hy, c("#c8372d"))
    _head(img, hy)
    rect(img, 4, 5 + hy, 4, 6 + hy, hair)
    rect(img, 11, 5 + hy, 11, 6 + hy, hair)
    _torso(img, c("#c8372d"), c("#9a2a22"), c("#e8d0b0"))
    rect(img, 5, 9, 10, 13, c("#6b4423"))
    rect(img, 5, 9, 10, 9, c("#8a5a2c"))
    _legs(img, c("#3a3028"), c("#2a2018"))
    rect(img, 13, 9, 13, 13, BELT)
    rect(img, 12, 7 if frame else 8, 14, 9 if frame else 9, c("#9aa0b4"))
    return outline(img)


def tobias(frame):  # koopman
    hy = 1 if frame else 0
    img = blank()
    brown = c("#8a5a2c")
    rect(img, 5, 1 + hy, 10, 3 + hy, brown)
    rect(img, 3, 4 + hy, 12, 4 + hy, c("#6a4220"))
    rect(img, 4, 4 + hy, 11, 4 + hy, brown)
    put(img, 11, 1 + hy, c("#5fd36b"))
    put(img, 12, 0 + hy, c("#5fd36b"))
    put(img, 12, 1 + hy, c("#3a9e4c"))
    _head(img, hy)
    hline(img, 6, 9, 7 + hy, c("#4f2e14"))
    _torso(img, c("#3a9e4c"), c("#2a7a38"), c("#f0e8d8"))
    rect(img, 4, 8, 4, 11, c("#f0e8d8"))
    rect(img, 11, 8, 11, 11, c("#f0e8d8"))
    rect(img, 5, 8, 10, 8, c("#5fd36b"))
    rect(img, 13, 7, 14, 12, brown)
    rect(img, 13, 7, 13, 12, c("#a8743c"))
    _legs(img, c("#4a3a5c"), c("#3a2410"))
    return outline(img)


def mila(frame):  # herbergierster
    hy = 1 if frame else 0
    img = blank()
    hair = c("#f2d36a")
    rect(img, 4, 2 + hy, 11, 4 + hy, hair)
    rect(img, 4, 5 + hy, 4, 9 + hy, hair)
    rect(img, 11, 5 + hy, 11, 9 + hy, hair)
    rect(img, 4, 2 + hy, 11, 3 + hy, c("#e8334a"))
    put(img, 7, 2 + hy, c("#ffffff"))
    put(img, 8, 2 + hy, c("#ffffff"))
    _head(img, hy)
    rect(img, 4, 5 + hy, 4, 6 + hy, hair)
    rect(img, 11, 5 + hy, 11, 6 + hy, hair)
    _torso(img, c("#f4f4f8"), c("#c8c8d8"))
    rect(img, 3, 12, 12, 14, c("#f4f4f8"))
    rect(img, 11, 12, 12, 14, c("#c8c8d8"))
    hline(img, 3, 12, 14, c("#c8c8d8"))
    put(img, 7, 9, c("#e8334a"))
    put(img, 8, 9, c("#e8334a"))
    put(img, 7, 10, c("#e8334a"))
    put(img, 8, 10, c("#e8334a"))
    put(img, 6, 9, c("#e8334a"))
    put(img, 9, 9, c("#e8334a"))
    return outline(img)


def pim(frame):  # kind: kleiner
    hy = 1 if frame else 0
    img = blank()
    hair = c("#7a4a24")
    rect(img, 5, 4 + hy, 10, 5 + hy, hair)
    rect(img, 4, 5 + hy, 11, 5 + hy, c("#e8334a"))
    rect(img, 4, 4 + hy, 11, 4 + hy, c("#c8372d"))
    rect(img, 5, 6 + hy, 10, 9 + hy, SKIN)
    rect(img, 5, 9 + hy, 10, 9 + hy, SKIN_D)
    put(img, 6, 8 + hy, OUTLINE)
    put(img, 9, 8 + hy, OUTLINE)
    for i, y in enumerate((10, 11, 12)):
        col = c("#3f7fe0") if i % 2 == 0 else c("#f4f4f8")
        rect(img, 5, y, 10, y, col)
    put(img, 4, 11, c("#3f7fe0"))
    put(img, 11, 11, c("#f4f4f8"))
    put(img, 4, 12, SKIN)
    put(img, 11, 12, SKIN)
    rect(img, 5, 13, 6, 13, c("#6a5a3c"))
    rect(img, 9, 13, 10, 13, c("#6a5a3c"))
    rect(img, 5, 14, 6, 14, BOOT)
    rect(img, 9, 14, 10, 14, BOOT)
    return outline(img)


def hein(frame):  # wachter
    hy = 1 if frame else 0
    img = blank()
    steel, steel_d, steel_l = c("#8a94b0"), c("#5a6480"), c("#c0c8e0")
    rect(img, 4, 1 + hy, 11, 4 + hy, steel)
    rect(img, 4, 1 + hy, 11, 1 + hy, steel_l)
    rect(img, 7, 0 + hy, 8, 0 + hy, c("#c8372d"))
    rect(img, 7, 4 + hy, 8, 6 + hy, steel)
    _head(img, hy)
    rect(img, 4, 5 + hy, 4, 7 + hy, steel_d)
    rect(img, 11, 5 + hy, 11, 7 + hy, steel_d)
    _torso(img, c("#6c7aa0"), c("#4a5878"), steel)
    rect(img, 5, 8, 10, 8, steel_l)
    rect(img, 4, 11, 11, 11, BELT)
    _legs(img, c("#3a4058"), c("#2a2030"))
    rect(img, 13, 1, 13, 14, c("#8a5a2c"))
    polygon(img, [(12, 3), (13, -1), (14, 3)], steel_l)
    return outline(img)


def anja(frame):
    hy = 1 if frame else 0
    img = blank()
    hair = c("#2a2030")
    rect(img, 4, 2 + hy, 11, 4 + hy, hair)
    _head(img, hy)
    rect(img, 4, 5 + hy, 4, 6 + hy, hair)
    rect(img, 11, 5 + hy, 11, 6 + hy, hair)
    rect(img, 11, 8, 11, 12, hair)
    put(img, 11, 10, c("#e8334a"))
    _torso(img, c("#8a4fc9"), c("#5a2d94"))
    rect(img, 4, 8, 11, 9, c("#f2c94c"))
    rect(img, 3, 12, 12, 14, c("#8a4fc9"))
    rect(img, 11, 12, 12, 14, c("#5a2d94"))
    hline(img, 3, 12, 14, c("#5a2d94"))
    return outline(img)


def joost(frame):
    hy = 1 if frame else 0
    img = blank()
    straw = c("#e8cf6a")
    rect(img, 5, 1 + hy, 10, 3 + hy, straw)
    rect(img, 2, 4 + hy, 13, 4 + hy, c("#c8aa40"))
    rect(img, 3, 4 + hy, 12, 4 + hy, straw)
    _head(img, hy)
    rect(img, 5, 7 + hy, 10, 9 + hy, c("#b8b8c0"))
    rect(img, 6, 7 + hy, 9, 7 + hy, SKIN_D)
    _torso(img, c("#e8873a"), c("#b8602a"))
    rect(img, 5, 8, 6, 12, c("#3f7fe0"))
    rect(img, 9, 8, 10, 12, c("#3f7fe0"))
    _legs(img, c("#3f6ab0"), c("#5a3a1c"))
    return outline(img)


def wilfred(frame):  # geest, half doorzichtig
    img = blank()
    body = c("#cfe8ff", 190)
    body_d = c("#9ec3ea", 190)
    steel = c("#a4b4d0", 210)
    wob = 1 if frame else 0
    polygon(img, [(4, 7), (11, 7), (13, 13 + wob), (11, 15), (9, 13 - wob), (7, 15), (5, 13 + wob), (3, 14)], body)
    rect(img, 4, 8, 11, 11, body)
    rect(img, 10, 8, 11, 12, body_d)
    rect(img, 4, 1, 11, 6, steel)
    rect(img, 4, 1, 11, 2, c("#d0dcf0", 220))
    rect(img, 7, 4, 8, 7, steel)
    rect(img, 5, 5, 6, 6, c("#1a1a2e", 230))
    rect(img, 9, 5, 10, 6, c("#1a1a2e", 230))
    put(img, 5, 5, c("#6ae8ff"))
    put(img, 9, 5, c("#6ae8ff"))
    put(img, 3, 9, body)
    put(img, 12, 9, body)
    rect(img, 6, 9, 9, 9, c("#ffffff", 200))
    return outline(img, c("#7aa0d8", 200))


def cat(frame):  # Muis
    img = blank()
    white, shade = c("#f6f6fa"), c("#cfd0dc")
    ellipse(img, (3, 8, 11, 14), white)
    rect(img, 3, 12, 11, 14, shade)
    ellipse(img, (8, 4, 14, 10), white)
    polygon(img, [(8, 5), (9, 1), (11, 4)], white)
    polygon(img, [(11, 4), (13, 1), (14, 5)], white)
    put(img, 9, 2, c("#f4a0b0"))
    put(img, 13, 2, c("#f4a0b0"))
    put(img, 10, 6, OUTLINE)
    put(img, 13, 6, OUTLINE)
    rect(img, 11, 7, 12, 8, c("#2a2030"))
    put(img, 12, 8, c("#f4a0b0"))
    tail = [(3, 11), (1, 9), (1, 6)] if frame == 0 else [(3, 11), (1, 10), (0, 8)]
    line(img, tail[0], tail[1], white, 2)
    line(img, tail[1], tail[2], white, 2)
    rect(img, 4, 14, 5, 14, shade)
    rect(img, 9, 14, 10, 14, shade)
    return outline(img)


def npc_sheet(fn):
    return strip([fn(0), fn(1)])
