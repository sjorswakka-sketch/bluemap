#!/usr/bin/env python3
"""Maakt de kaarten in scripts/maps/*.gd en controleert of alles bereikbaar is.

Gebruik:  python3 tools/gen_maps.py

Dit is een startpunt: de kaarten zijn gewone tekstbestanden. Je kunt ze daarna ook gewoon met de hand
aanpassen (dan niet opnieuw genereren, want dat overschrijft je wijzigingen).
"""
import os
import random
import re
import sys
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
OUT = os.path.join(ROOT, "scripts", "maps")


def load_tiles():
    text = open(os.path.join(ROOT, "scripts", "data", "tiles.gd"), encoding="utf-8").read()
    solid = set(re.findall(r'"([a-z_]+)"', re.search(r"const SOLID: Array\[String\] = \[(.*?)\n\]", text, re.S).group(1)))
    chars = dict(re.findall(r'"(.)": "([a-z_]+)"', re.search(r"const CHARS := \{(.*?)\n\}", text, re.S).group(1)))
    return {ch: name in solid for ch, name in chars.items()}


SOLID = load_tiles()


def is_solid(ch):
    return SOLID.get(ch, False)


class Level:
    def __init__(self, key, name, w, h, music, fill=".", dark=0.0):
        self.key, self.name, self.w, self.h, self.music, self.dark = key, name, w, h, music, dark
        self.g = [[fill] * w for _ in range(h)]
        self.objects = []
        self.spawns = {}
        self.protect = set()

    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        return "#"

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, ch)

    def border(self, ch, thickness=1):
        for t in range(thickness):
            for x in range(self.w):
                self.put(x, t, ch)
                self.put(x, self.h - 1 - t, ch)
            for y in range(self.h):
                self.put(t, y, ch)
                self.put(self.w - 1 - t, y, ch)

    def path(self, points, ch=",", width=2):
        """Trekt een pad langs hoekpunten (alleen horizontaal/verticaal)."""
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                for y in range(min(y0, y1), max(y0, y1) + 1):
                    for dx in range(width):
                        for dy in range(width):
                            self.put(x + dx, y + dy, ch)

    def keep(self, x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.protect.add((x, y))

    def add(self, typ, x, y, **kw):
        obj = {"type": typ, "pos": [x, y]}
        obj.update(kw)
        self.objects.append(obj)
        self.keep(x - 1, y - 1, x + 1, y + 1)
        return obj

    def scatter(self, ch, density, seed, only=".", margin=1):
        rnd = random.Random(seed)
        for y in range(margin, self.h - margin):
            for x in range(margin, self.w - margin):
                if self.g[y][x] in only and (x, y) not in self.protect and rnd.random() < density:
                    self.g[y][x] = ch

    def rows(self):
        return ["".join(r) for r in self.g]


def house(lv, x, y, w, door_dx, window_every=2):
    """Een huisje: twee rijen dak, een rij muur met ramen en een rij muur met deur. Geeft de deurtegel terug."""
    lv.rect(x, y, x + w - 1, y + 1, "^")
    for dx in range(w):
        lv.put(x + dx, y + 2, "h" if dx % window_every == 1 and dx != door_dx else "H")
        lv.put(x + dx, y + 3, "H")
    lv.put(x + door_dx, y + 3, "D")
    lv.keep(x - 1, y - 1, x + w, y + 4)
    return (x + door_dx, y + 3)


# ---------------------------------------------------------------------------------------------------------
# Dageraadsdorp
# ---------------------------------------------------------------------------------------------------------

def build_village():
    lv = Level("village", "Dageraadsdorp", 40, 28, "village")
    lv.border("#", 2)
    # tempel
    lv.rect(14, 1, 25, 6, "Z")
    lv.put(19, 6, "T")
    lv.put(20, 6, "T")
    lv.keep(13, 0, 26, 7)
    # paden en plein
    lv.path([(19, 7), (19, 12)], ",", 2)
    lv.rect(16, 11, 23, 16, ",")
    lv.path([(2, 13), (38, 13)], ",", 2)
    lv.path([(19, 14), (19, 26)], ",", 2)
    lv.put(19, 13, "O")  # de put
    lv.keep(15, 10, 24, 17)
    # huisjes
    smithy_door = house(lv, 4, 8, 6, 2)
    shop_door = house(lv, 11, 8, 6, 2)
    inn_door = house(lv, 27, 7, 8, 3)
    house(lv, 5, 18, 6, 2)
    house(lv, 28, 18, 6, 3)
    for door in (smithy_door, shop_door, inn_door):
        lv.path([(door[0], door[1] + 1), (door[0], 12)], ",", 1)
    # hek om Pims huis
    for x in range(26, 35):
        lv.put(x, 22, "|")
    # losse dingen
    lv.rect(37, 13, 38, 14, ",")
    lv.keep(35, 12, 38, 15)
    lv.put(16, 20, "x")
    lv.put(17, 20, "x")
    # personages en dingen
    lv.spawns = {
        "start": [19, 9], "from_forest": [36, 13], "from_smithy": [smithy_door[0], smithy_door[1] + 1],
        "from_shop": [shop_door[0], shop_door[1] + 1], "from_inn": [inn_door[0], inn_door[1] + 1], "from_temple": [19, 8],
    }
    lv.add("npc", 17, 8, id="bram")
    lv.add("npc", 24, 18, id="pim")
    lv.add("npc", 25, 18, id="muis_dorp", **{"if": [["flag", "cat_home"]]})
    lv.add("npc", 13, 15, id="anja")
    lv.add("npc", 22, 24, id="joost")
    lv.add("npc", 34, 11, id="hein")
    lv.add("savepoint", 22, 12)
    lv.add("pickup", 8, 15, item="coin")
    lv.add("pickup", 30, 15, item="coin")
    lv.add("sign", 21, 8, lines=["Dageraadsdorp", "Tempel van de Blauwe Kaart. Bewaker: Oudste Bram."])
    lv.add("sign", 33, 15, lines=["Oostelijke weg: Fluisterbos.", "Pas op voor slijmen!"])
    # doorgangen
    lv.add("portal", smithy_door[0], smithy_door[1], to="smithy", spawn="door")
    lv.add("portal", shop_door[0], shop_door[1], to="shop", spawn="door")
    lv.add("portal", inn_door[0], inn_door[1], to="inn", spawn="door")
    lv.add("portal", 38, 13, to="forest", spawn="from_village", size=[1, 2])
    lv.add("portal", 19, 6, to="temple", spawn="start", size=[2, 1],
           requires=[["flag", "gate_temple"]], locked_text="De tempeldeur is verzegeld door de gebarsten kaart.")
    lv.scatter("#", 0.10, 11)
    lv.scatter("b", 0.02, 12)
    lv.scatter("o", 0.012, 13)
    return lv


def interior(key, name, w, h, npc_id, npc_x, shelf=True, beds=False, extra=None, back_to="village", back_spawn=""):
    lv = Level(key, name, w, h, "village", fill="w")
    lv.border("N", 1)
    lv.rect(0, 0, w - 1, 1, "N")
    cx = w // 2
    lv.put(cx - 1, h - 1, "m")
    lv.put(cx, h - 1, "m")
    if shelf:
        for x in range(2, w - 2):
            lv.put(x, 1, "S" if x % 2 == 0 else "N")
    # toonbank met een opening waar de verkoper staat
    cy = 4
    for x in range(3, w - 3):
        lv.put(x, cy, "C")
    lv.put(npc_x, cy, "w")
    lv.put(2, 2, "x")
    lv.put(w - 3, 2, "x")
    if beds:
        for x in (2, 4, 6):
            lv.put(x, 6, "B")
    lv.spawns = {"start": [cx, h - 2], "door": [cx, h - 2]}
    lv.add("npc", npc_x, cy, id=npc_id)
    lv.add("torch", 3, 2)
    lv.add("torch", w - 4, 2)
    lv.add("portal", cx - 1, h - 1, to=back_to, spawn=back_spawn, size=[2, 1])
    if extra:
        extra(lv)
    return lv


def build_smithy():
    return interior("smithy", "Smederij", 14, 10, "greta", 7, back_spawn="from_smithy")


def build_shop():
    return interior("shop", "Winkel van Tobias", 14, 10, "tobias", 7, back_spawn="from_shop")


def build_inn():
    def extra(lv):
        lv.add("chest", 12, 7, contents=[["potion", 1], ["coins", 15]])
    return interior("inn", "Herberg De Blauwe Slijm", 16, 10, "mila", 8, beds=True, extra=extra, back_spawn="from_inn")


# ---------------------------------------------------------------------------------------------------------
# Fluisterbos
# ---------------------------------------------------------------------------------------------------------

def build_forest():
    lv = Level("forest", "Fluisterbos", 54, 38, "forest")
    lv.border("#", 2)
    # rivier met brug
    lv.rect(24, 0, 25, lv.h - 1, "~")
    lv.rect(24, 17, 25, 18, "=")
    # hoofdpaden
    lv.path([(2, 17), (23, 17)], ",", 2)
    lv.path([(26, 17), (44, 17)], ",", 2)
    lv.path([(10, 17), (10, 6)], ",", 2)       # noord: kist met sleutel
    lv.path([(12, 17), (12, 30)], ",", 2)      # zuid: Muis
    lv.path([(34, 17), (34, 8)], ",", 2)       # noord: kristalruïne
    lv.path([(44, 17), (48, 17), (48, 15)], ",", 2)  # naar de poort van de ruïne
    lv.path([(40, 17), (40, 33), (47, 33)], ",", 2)  # zuid-oost: grot
    lv.path([(30, 17), (30, 30)], ",", 2)      # zuid: verborgen kist
    # open plekken
    lv.rect(5, 3, 15, 9, ".")                  # sleutelkist
    lv.rect(5, 26, 17, 34, ".")                # kattenplek
    lv.rect(27, 28, 33, 33, ".")               # kistplek
    lv.rect(29, 14, 38, 20, ".")               # kruispunt
    for y in range(14, 21):
        for x in range(29, 39):
            if lv.get(x, y) == "~":
                lv.put(x, y, ".")
    lv.path([(26, 17), (44, 17)], ",", 2)
    # stenen ruïne met het bos-kristal
    lv.rect(36, 1, 46, 9, "W")
    lv.rect(37, 2, 45, 8, ".")
    lv.rect(40, 9, 42, 9, ".")
    lv.path([(41, 8), (41, 14)], ",", 1)
    for x, y in ((38, 3), (44, 3), (38, 7), (44, 7)):
        lv.put(x, y, "W")
    # nis van de ruïne-poort
    lv.rect(46, 9, 52, 16, "W")
    lv.rect(47, 10, 51, 14, ".")
    lv.put(49, 11, "A")
    lv.put(49, 15, ",")
    lv.put(48, 15, ",")
    lv.path([(48, 15), (48, 17)], ",", 2)
    # grotingang
    lv.rect(44, 29, 51, 36, "o")
    lv.rect(45, 30, 50, 35, ".")
    lv.put(48, 31, "E")
    lv.path([(40, 33), (47, 33)], ",", 2)
    lv.keep(44, 29, 51, 36)
    # kleine vijver
    lv.rect(16, 22, 20, 24, "~")
    lv.keep(14, 20, 22, 26)
    # beschermde plekken
    for (x0, y0, x1, y1) in [(2, 14, 8, 21), (36, 0, 47, 10), (46, 9, 53, 17), (26, 15, 41, 20)]:
        lv.keep(x0, y0, x1, y1)
    for pts in ([(2, 17), (23, 17)], [(26, 17), (44, 17)], [(10, 17), (10, 6)], [(12, 17), (12, 30)],
                [(34, 17), (34, 8)], [(40, 17), (40, 33)], [(30, 17), (30, 30)]):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            lv.keep(min(x0, x1) - 1, min(y0, y1) - 1, max(x0, x1) + 2, max(y0, y1) + 2)
    lv.spawns = {
        "start": [4, 17], "from_village": [4, 17], "from_ruins": [49, 16], "from_cave": [48, 32],
    }
    # personages en voorwerpen
    lv.add("portal", 1, 17, to="village", spawn="from_forest", size=[1, 2])
    lv.add("savepoint", 6, 15)
    lv.add("sign", 5, 19, lines=["Fluisterbos", "Hier fluisteren de bomen. En de slijmen zijn niet te vertrouwen."])
    lv.add("sign", 28, 19, lines=["Noord: oude stenen ruïne.", "Oost: Vergeten Ruïne.", "Zuid-oost: Echo-grot."])
    lv.add("chest", 10, 4, contents=[["ruin_key", 1], ["coins", 20]])
    lv.add("npc", 9, 30, id="muis_bos", **{"if": [["no_flag", "cat_found"]], "exists_if": [["no_flag", "cat_found"]]})
    lv.add("chest", 31, 30, contents=[["potion", 2], ["coins", 25]])
    lv.add("pickup", 41, 4, item="crystal_bos", unique=True)
    lv.add("portal", 49, 11, to="ruins", spawn="start")
    lv.add("gate", 48, 15, id="ruin", key="ruin_key", block_if=[["no_flag", "gate_ruin"]],
           locked_text="Het poortje zit op slot. Je hebt een sleutel nodig.")
    lv.add("portal", 48, 31, to="cave", spawn="start")
    lv.add("sign", 47, 19, lines=["Vergeten Ruïne.", "Het poortje is al eeuwen op slot."])
    # vijanden
    for x, y in [(8, 6), (12, 5), (10, 8)]:
        lv.add("enemy", x, y, kind="slime")
    for x, y in [(14, 29), (7, 31)]:
        lv.add("enemy", x, y, kind="slime")
    for x, y in [(8, 17), (17, 16), (20, 20), (14, 23)]:
        lv.add("enemy", x, y, kind="slime")
    for x, y in [(28, 15), (36, 18), (33, 12), (31, 24), (42, 20), (42, 28)]:
        lv.add("enemy", x, y, kind="slime")
    for x, y in [(39, 4), (43, 6), (41, 3)]:
        lv.add("enemy", x, y, kind="slime")
    for x, y in [(35, 11), (44, 12), (40, 24), (46, 33)]:
        lv.add("enemy", x, y, kind="bat")
    # losse spullen
    for x, y in [(15, 17), (4, 12), (6, 30), (28, 22), (36, 10), (44, 19), (38, 30), (22, 8), (46, 22), (16, 8)]:
        lv.add("pickup", x, y, item="coin")
    for x, y in [(11, 27), (35, 5), (45, 31)]:
        lv.add("pickup", x, y, item="heart")
    lv.add("pickup", 20, 28, item="potion", unique=True)
    lv.rect(0, 17, 1, 18, ",")  # opening in de rand bij het dorp
    lv.scatter("#", 0.20, 21)
    lv.scatter("b", 0.03, 22)
    lv.scatter("o", 0.015, 23)
    lv.scatter("t", 0.01, 24)
    return lv


# ---------------------------------------------------------------------------------------------------------
# Vergeten Ruïne
# ---------------------------------------------------------------------------------------------------------

def build_ruins():
    lv = Level("ruins", "De Vergeten Ruïne", 42, 34, "ruins", fill="M", dark=0.55)
    # ingangshal
    lv.rect(2, 26, 14, 31, "r")
    lv.put(3, 30, "A")
    lv.rect(7, 19, 8, 25, "r")
    # grote zaal
    lv.rect(3, 9, 22, 18, "r")
    for x, y in [(6, 11), (6, 16), (12, 11), (12, 16), (18, 11), (18, 16)]:
        lv.put(x, y, "I")
    # gang naar de golem-zaal
    lv.rect(23, 13, 27, 14, "r")
    lv.rect(28, 3, 39, 17, "r")
    for x, y in [(30, 5), (30, 15), (38, 15), (38, 5)]:
        lv.put(x, y, "I")
    # gang naar de kistzaal
    lv.rect(20, 19, 21, 22, "r")
    lv.rect(17, 23, 31, 31, "r")
    # hoekje met kist
    lv.rect(3, 3, 11, 7, "r")
    lv.rect(6, 8, 7, 8, "r")
    # gebarsten stenen en pilaren in de kistzaal
    lv.put(22, 26, "I")
    lv.put(26, 28, "I")
    lv.spawns = {"start": [5, 29]}
    lv.add("portal", 3, 30, to="forest", spawn="from_ruins")
    lv.add("npc", 11, 29, id="wilfred")
    lv.add("torch", 3, 27)
    lv.add("torch", 13, 27)
    lv.add("torch", 8, 20)
    lv.add("savepoint", 5, 16)
    for x, y in [(4, 10), (21, 10), (4, 17), (21, 17), (24, 13), (29, 4), (38, 4), (29, 16), (38, 16), (18, 24), (30, 24), (12, 4)]:
        lv.add("torch", x, y)
    lv.add("chest", 10, 4, contents=[["potion", 2], ["coins", 30]])
    lv.add("chest", 29, 29, contents=[["coins", 40], ["potion", 1]])
    lv.add("pickup", 36, 5, item="crystal_ruine", unique=True)
    lv.add("enemy", 33, 10, kind="golem", flag="golem_ruins")
    for x, y in [(8, 12), (15, 14), (19, 12), (10, 5), (25, 29)]:
        lv.add("enemy", x, y, kind="skeleton")
    for x, y in [(12, 18), (14, 12), (22, 24), (28, 26)]:
        lv.add("enemy", x, y, kind="slime_blue")
    for x, y in [(5, 13), (20, 15), (13, 28), (26, 25), (34, 14), (7, 22)]:
        lv.add("pickup", x, y, item="coin")
    lv.add("pickup", 8, 6, item="heart")
    lv.add("pickup", 22, 29, item="heart")
    lv.add("sign", 9, 28, lines=["Hier rust de bewaker van de ruïne.", "Wie het kristal wil, moet de golem verslaan."])
    rnd = random.Random(3)
    for _ in range(26):
        x, y = rnd.randrange(2, 40), rnd.randrange(2, 32)
        if lv.get(x, y) == "r" and (x, y) not in lv.protect:
            lv.put(x, y, "k")
    return lv


# ---------------------------------------------------------------------------------------------------------
# Echo-grot
# ---------------------------------------------------------------------------------------------------------

def build_cave():
    lv = Level("cave", "De Echo-grot", 48, 36, "cave", fill="X", dark=0.78)
    # beginkamer
    lv.rect(2, 27, 11, 33, "c")
    lv.put(4, 33, "E")
    # tunnels
    lv.path([(6, 27), (6, 21), (16, 21)], "c", 3)
    lv.rect(10, 15, 22, 23, "c")                     # kamer 1 (vleermuizen)
    lv.path([(16, 15), (16, 8), (7, 8)], "c", 2)     # naar het medaillon
    lv.rect(3, 3, 9, 9, "c")
    lv.path([(20, 15), (20, 10)], "c", 2)
    lv.rect(17, 5, 25, 11, "c")                      # kamer 2 (altaar)
    lv.path([(25, 8), (31, 8)], "c", 2)
    lv.rect(29, 6, 42, 16, "c")                      # kamer 3 (rode slijmen)
    lv.path([(38, 6), (38, 3), (44, 3)], "c", 2)     # naar de hartcontainer
    lv.rect(41, 1, 45, 5, "c")
    lv.path([(35, 16), (35, 22)], "c", 2)
    lv.rect(28, 22, 44, 33, "c")                     # laatste kamer (golem)
    lv.spawns = {"start": [5, 31]}
    lv.add("portal", 4, 33, to="forest", spawn="from_cave")
    lv.add("torch", 3, 28)
    lv.add("torch", 10, 28)
    lv.add("sign", 7, 30, lines=["Echo-grot", "Het is hier pikkedonker. Volg het licht van de fakkels."])
    for x, y in [(6, 23), (14, 21), (12, 16), (21, 16), (16, 9), (8, 5), (19, 7), (24, 7), (30, 8), (31, 14), (41, 14), (38, 4), (36, 20), (30, 24)]:
        lv.add("torch", x, y)
    lv.add("savepoint", 21, 9)
    lv.add("chest", 5, 5, contents=[["medallion", 1], ["coins", 20]])
    lv.add("chest", 43, 3, contents=[["heart_container", 1], ["coins", 30]])
    lv.add("pickup", 41, 30, item="crystal_grot", unique=True)
    lv.add("enemy", 35, 28, kind="golem", flag="golem_cave")
    for x, y in [(14, 18), (19, 20), (13, 22), (20, 17), (31, 12), (37, 13), (16, 10), (42, 4), (41, 3)]:
        lv.add("enemy", x, y, kind="bat")
    for x, y in [(32, 10), (37, 14), (34, 8), (31, 26), (40, 26)]:
        lv.add("enemy", x, y, kind="slime_red")
    for x, y in [(8, 22), (11, 17), (20, 21), (33, 10), (40, 9), (30, 30), (42, 24), (21, 7)]:
        lv.add("pickup", x, y, item="coin")
    for x, y in [(17, 22), (35, 15)]:
        lv.add("pickup", x, y, item="heart")
    lv.add("pickup", 24, 10, item="potion", unique=True)
    # stalagmieten en kristallen
    rnd = random.Random(8)
    cells = [(x, y) for y in range(lv.h) for x in range(lv.w) if lv.get(x, y) == "c"]
    for _ in range(46):
        x, y = rnd.choice(cells)
        if (x, y) not in lv.protect and all(lv.get(x + dx, y + dy) == "c" for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            lv.put(x, y, "v")
    walls = [(x, y) for y in range(1, lv.h - 1) for x in range(1, lv.w - 1)
             if lv.get(x, y) == "X" and any(lv.get(x + dx, y + dy) == "c" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for _ in range(26):
        x, y = rnd.choice(walls)
        lv.put(x, y, "y")
    return lv


# ---------------------------------------------------------------------------------------------------------
# Kristaltempel
# ---------------------------------------------------------------------------------------------------------

def build_temple():
    lv = Level("temple", "De Kristaltempel", 24, 22, "temple", fill="Z", dark=0.62)
    lv.rect(2, 2, 21, 14, "_")                      # arena
    lv.rect(10, 15, 13, 15, "_")                    # hals
    lv.rect(8, 16, 15, 20, "_")                     # voorkamer
    lv.rect(11, 21, 12, 21, "T")                    # uitgang
    # tapijt en runen
    lv.rect(11, 3, 12, 20, "%")
    lv.rect(10, 7, 13, 10, "u")
    lv.rect(11, 8, 12, 9, "u")
    # pilaren
    for x, y in [(4, 4), (4, 11), (19, 4), (19, 11)]:
        lv.rect(x, y, x + 1, y + 1, "Z")
    lv.spawns = {"start": [11, 19]}
    lv.add("portal", 11, 21, to="village", spawn="from_temple", size=[2, 1])
    lv.add("savepoint", 9, 18)
    for x, y in [(3, 3), (3, 8), (3, 13), (20, 3), (20, 8), (20, 13), (9, 17), (14, 17)]:
        lv.add("torch", x, y, glow="blue")
    lv.add("enemy", 11, 6, kind="king", flag="boss_defeated")
    lv.add("trigger", 4, 12, size=[16, 2], once="boss_started",
           do=[["talk", "king_intro"], ["boss_start"]])
    lv.add("gate", 10, 15, id="arena", size=[4, 1],
           block_if=[["flag", "boss_started"], ["no_flag", "boss_defeated"]], locked_text="De deur zit dicht. Er is geen weg terug!")
    lv.add("pickup", 15, 18, item="potion")
    return lv


# ---------------------------------------------------------------------------------------------------------
# Opslaan en controleren
# ---------------------------------------------------------------------------------------------------------

def gd(value, indent=0):
    """Python-waarde naar GDScript-tekst."""
    pad = "\t" * indent
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(value, list):
        return "[" + ", ".join(gd(v, indent) for v in value) + "]"
    if isinstance(value, dict):
        return "{" + ", ".join(f"{gd(k)}: {gd(v, indent)}" for k, v in value.items()) + "}"
    raise TypeError(value)


def check(levels):
    problems = []
    keys = {lv.key: lv for lv in levels}
    for lv in levels:
        rows = lv.rows()
        assert all(len(r) == lv.w for r in rows), lv.key
        sx, sy = lv.spawns["start"]
        if is_solid(lv.get(sx, sy)):
            problems.append(f"{lv.key}: startplek ligt in een muur")
        for name, (x, y) in lv.spawns.items():
            if is_solid(lv.get(x, y)):
                problems.append(f"{lv.key}: spawn {name} ligt in een muur ({x},{y})")
        seen = {(sx, sy)}
        queue = deque([(sx, sy)])
        while queue:
            x, y = queue.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) not in seen and 0 <= nx < lv.w and 0 <= ny < lv.h and not is_solid(lv.get(nx, ny)):
                    seen.add((nx, ny))
                    queue.append((nx, ny))
        def reachable(x, y):
            return any((x + dx, y + dy) in seen for dx in (-1, 0, 1) for dy in (-1, 0, 1))
        used = {}
        for obj in lv.objects:
            x, y = obj["pos"]
            label = f"{lv.key}: {obj['type']} {obj.get('id', obj.get('kind', obj.get('item', '')))} op ({x},{y})"
            if obj["type"] not in ("portal", "trigger", "gate") and (x, y) in used:
                problems.append(f"{label} staat op dezelfde plek als {used[(x, y)]}")
            used[(x, y)] = label
            if obj["type"] in ("trigger", "gate"):
                continue
            if obj["type"] in ("chest", "sign", "savepoint") and not is_solid(lv.get(x, y)) and not reachable(x, y):
                problems.append(f"{label} is niet bereikbaar")
            elif obj["type"] not in ("chest", "sign", "savepoint", "torch") and is_solid(lv.get(x, y)):
                problems.append(f"{label} staat in een muur")
            elif obj["type"] not in ("torch",) and not reachable(x, y):
                problems.append(f"{label} is niet bereikbaar")
            if obj["type"] == "portal":
                target = keys.get(obj["to"])
                if target is None or obj.get("spawn", "start") not in target.spawns:
                    problems.append(f"{label}: doel {obj['to']}/{obj.get('spawn')} bestaat niet")
    return problems


def write(lv):
    lines = [
        "extends RefCounted",
        f"## {lv.name}. Gemaakt met tools/gen_maps.py (je mag dit bestand ook met de hand aanpassen).",
        "## Tekens: zie scripts/data/tiles.gd. Voorwerpen in `objects`: zie scripts/world.gd (_spawn_objects).",
        "",
        "const DATA := {",
        f'\t"name": {gd(lv.name)},',
        f'\t"music": {gd(lv.music)},',
    ]
    if lv.dark:
        lines.append(f'\t"dark": {lv.dark},')
    lines.append('\t"rows": [')
    for row in lv.rows():
        lines.append(f'\t\t"{row}",')
    lines.append("\t],")
    lines.append(f'\t"spawns": {gd(lv.spawns)},')
    lines.append('\t"objects": [')
    for obj in lv.objects:
        lines.append(f"\t\t{gd(obj)},")
    lines.append("\t],")
    lines.append("}")
    path = os.path.join(OUT, lv.key + ".gd")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return path


def write_registry(levels):
    lines = [
        "extends RefCounted",
        "## Alle kaarten. Voeg een nieuwe kaart toe door een bestand in scripts/maps/ te maken en hier te registreren.",
        "",
        "const MAPS := {",
    ]
    for lv in levels:
        lines.append(f'\t"{lv.key}": preload("res://scripts/maps/{lv.key}.gd"),')
    lines += ["}", "", "", "static func get_map(map_id: String) -> Dictionary:", "\treturn MAPS[map_id].DATA", ""]
    with open(os.path.join(OUT, "registry.gd"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main():
    levels = [build_village(), build_smithy(), build_shop(), build_inn(), build_forest(), build_ruins(), build_cave(), build_temple()]
    problems = check(levels)
    for p in problems:
        print("PROBLEEM:", p)
    if "--force" not in sys.argv:
        # Sinds fase 7 zijn de kaarten in scripts/maps/ met de hand aangepast en zijn er nieuwe kaarten bij.
        # Dit script overschrijft ze, dus standaard controleert het alleen de oorspronkelijke acht.
        print("Alleen gecontroleerd (niets geschreven). Met --force worden scripts/maps/*.gd en registry.gd OVERSCHREVEN.")
        sys.exit(1 if problems else 0)
    for lv in levels:
        print(write(lv), f"{lv.w}x{lv.h}, {len(lv.objects)} objecten")
    write_registry(levels)
    if "--show" in sys.argv:
        for lv in levels:
            print("\n==", lv.name)
            print("\n".join(lv.rows()))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
