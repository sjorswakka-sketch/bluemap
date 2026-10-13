#!/usr/bin/env python3
"""Genereert de kaart van Het Kruipmoeras (scripts/maps/kruipmoeras.gd), 48 x 34.

Tekens: Y = knotwilg (rand), U = moerasgras, j = polgras, 2 = modder, F = drijfmest (onbegaanbaar),
R = riet (onbegaanbaar), , = pad, = = loopbrug, o = kei, t = dood boompje.

Draai:  python tools/gen_moeras.py  (print de rijen + controle van de objectplekken)
"""
import random

W, H = 48, 34
rng = random.Random(4187)

g = [["U"] * W for _ in range(H)]


def rect(x0, y0, x1, y1, ch, only=None):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if only is None or g[y][x] in only:
                g[y][x] = ch


def ellipse(cx, cy, rx, ry, ch, only=None):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if ((x - cx) ** 2) / (rx * rx + 0.01) + ((y - cy) ** 2) / (ry * ry + 0.01) <= 1.0:
                if 0 <= x < W and 0 <= y < H and (only is None or g[y][x] in only):
                    g[y][x] = ch


# Rand van knotwilgen, twee tegels dik, met een opening in het noorden (naar het Zilvermeer).
rect(0, 0, W - 1, 1, "Y")
rect(0, H - 2, W - 1, H - 1, "Y")
rect(0, 0, 1, H - 1, "Y")
rect(W - 2, 0, W - 1, H - 1, "Y")
g[0][23] = g[0][24] = ","
g[1][23] = g[1][24] = ","

# Modderpaden: van de noordingang naar het hart, en van daar naar west en oost.
rect(23, 2, 24, 9, "2")                    # noordpad
rect(7, 8, 22, 9, "2")                     # westtak naar de wilgenhut
rect(25, 8, 38, 9, "2")                    # oosttak naar het rietland
rect(11, 10, 12, 21, "2")                  # zuidwesttak naar de turfvelden
rect(38, 10, 39, 12, "2")                  # afdaling rietland

# De grote drijfmestplas in het midden, met een eilandje en loopbruggen erheen.
ellipse(25, 16, 9, 5, "F")
rect(22, 15, 28, 17, "U")                  # het eilandje
rect(24, 11, 24, 14, "=")                  # brug van de noordoever
rect(24, 18, 24, 20, "=")                  # brug naar de zuidoever
g[14][23] = "U"
g[18][23] = "U"

# Losse plassen en poelen met rietoevers, verspreid over het moeras.
for cx, cy, rx, ry in [(7, 15, 2, 1), (15, 4, 2, 1), (33, 25, 3, 2), (42, 27, 2, 2), (18, 29, 2, 1)]:
    ellipse(cx, cy, rx, ry, "F")
    ellipse(cx, cy, rx + 1, ry + 1, "R", only={"U"})

# Het rietland in het oosten: rietkragen met smalle gangen ertussen.
for _ in range(26):
    cx = rng.randint(33, 44)
    cy = rng.randint(3, 16)
    ellipse(cx, cy, 1, 1, "R", only={"U", "j"})
ellipse(39, 10, 2, 2, "U", only={"R", "j"})   # open plek voor Mees
ellipse(41, 5, 2, 2, "U", only={"R", "j"})    # open plek voor de kist

# De turfvelden in het zuidwesten: open modder met keien en dode boompjes.
rect(3, 21, 16, 30, "2")
for _ in range(9):
    x, y = rng.randint(4, 15), rng.randint(22, 29)
    g[y][x] = "o" if rng.random() < 0.5 else "t"

# De wilgenhut van Wouda in het noordwesten: een krans van knotwilgen met een opening.
ellipse(7, 6, 3, 2, "Y", only={"U", "j"})
ellipse(7, 6, 2, 1, "U", only={"Y"})
g[8][7] = "2"                              # opening aan de zuidkant, op het pad

# Polgras en verspreide rietpluimen als versiering op open grond.
for _ in range(150):
    x, y = rng.randint(2, W - 3), rng.randint(2, H - 3)
    if g[y][x] == "U":
        g[y][x] = "j"
for _ in range(24):
    x, y = rng.randint(2, W - 3), rng.randint(2, H - 3)
    if g[y][x] in ("U", "j"):
        g[y][x] = "R"

# Plekken waar iets moet staan of lopen: altijd begaanbaar houden.
MOET_VRIJ = [
    (23, 3), (24, 3),           # ingang / spawn
    (22, 3), (26, 4),           # borden noord
    (28, 7), (28, 8),           # altaar + spawn
    (7, 7), (7, 8),             # Wouda + opening
    (39, 10), (38, 9),          # Mees + pad
    (8, 25),                    # Stien
    (23, 16), (26, 16),         # eiland: amulet + kist
    (36, 7), (5, 22), (31, 23), # borden
    (36, 26), (12, 6), (42, 22),# pickups
    (26, 6), (10, 20), (37, 18),# lantaarns
    (33, 20), (18, 26), (29, 27), (38, 14), (15, 12), (30, 10),  # wild
    (41, 5), (4, 29),           # kisten
    (17, 13), (33, 18), (25, 6), (21, 24), (5, 10), (40, 20), (7, 27), (12, 24),  # grondstoffen
]
for x, y in MOET_VRIJ:
    if g[y][x] in ("R", "F", "Y", "o", "t"):
        g[y][x] = "U" if y < 20 else "2"

for row in g:
    print('"%s",' % "".join(row))

# Controle: alle plekken begaanbaar?
SOLID = set("YRFot")  # knotwilg, riet, drijfmest, kei, dood boompje
fouten = [(x, y, g[y][x]) for x, y in MOET_VRIJ if g[y][x] in SOLID]
print("# vaste plekken onbegaanbaar:", fouten, file=__import__("sys").stderr)
