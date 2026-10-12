"""Herontwerp van Dauwbos, IJsdal en Dorstvallei: elk gebied krijgt een eigen landschap.

Dauwbos     -> organisch mistbos: kronkelpaden, open plekken, een vijver, paddenstoelenkring.
IJsdal      -> bergdorp rond een groot bevroren meer, mijnhoek met rotspartijen.
Dorstvallei -> kloof met zandsteenwanden, oase als groen hart, cactusvelden en jachtgronden.

Het script herschrijft alleen het "rows"-blok van de kaartbestanden en controleert dat
alle objecten, portalen en beroepsplekken begaanbaar en bereikbaar blijven.
"""
import io
import random
import re
import sys

SOLID_CHARS = set("#~W|^HhDEotOxXMZINCSp;lqgj") | set("PG")  # zie tiles.gd SOLID
# '^' dak, 'H/h' huis, 'D' deur is begaanbaar, '=' brug begaanbaar.
WALKABLE_EXCEPTIONS = set("D=,-!n*>")

RNG = random.Random(20261012)


def is_solid(ch):
    return ch in SOLID_CHARS and ch not in WALKABLE_EXCEPTIONS


class Map:
    def __init__(self, w, h, fill):
        self.w, self.h = w, h
        self.g = [[fill] * w for _ in range(h)]
        self.keep = set()  # tegels die nooit dichtgebouwd mogen worden

    def set(self, x, y, ch, force=False):
        if 0 <= x < self.w and 0 <= y < self.h and (force or (x, y) not in self.keep):
            self.g[y][x] = ch

    def get(self, x, y):
        return self.g[y][x]

    def border(self, ch, thickness=2, openings=()):
        for y in range(self.h):
            for x in range(self.w):
                if x < thickness or y < thickness or x >= self.w - thickness or y >= self.h - thickness:
                    if (x, y) not in openings:
                        self.g[y][x] = ch
        for x, y in openings:
            self.g[y][x] = ","

    def blob(self, cx, cy, rx, ry, ch, seed=0, jag=0.45, skip_solid=False):
        """Organische vlek: ellips met rafelige rand."""
        for y in range(int(cy - ry - 2), int(cy + ry + 3)):
            for x in range(int(cx - rx - 2), int(cx + rx + 3)):
                if not (0 <= x < self.w and 0 <= y < self.h):
                    continue
                dx, dy = (x - cx) / rx, (y - cy) / ry
                noise = (hash((x * 31 + y * 17 + seed)) % 100) / 100.0
                if dx * dx + dy * dy <= 1.0 + (noise - 0.5) * 2 * jag:
                    if skip_solid and is_solid(self.g[y][x]) and self.g[y][x] != ch:
                        continue
                    self.set(x, y, ch)

    def path(self, points, ch=","):
        """Kronkelpad door de waypoints; breedte 1, af en toe 2."""
        for i in range(len(points) - 1):
            x0, y0 = points[i]
            x1, y1 = points[i + 1]
            x, y = x0, y0
            guard = 0
            while (x, y) != (x1, y1) and guard < 500:
                guard += 1
                self.set(x, y, ch, force=True)
                if RNG.random() < 0.35:  # zijsprongetje voor het kronkelige
                    dx, dy = RNG.choice([(1, 0), (-1, 0), (0, 1), (0, -1)])
                    nx, ny = x + dx, y + dy
                    if 1 < nx < self.w - 2 and 1 < ny < self.h - 2:
                        self.set(nx, ny, ch, force=True)
                if x != x1 and (y == y1 or RNG.random() < 0.6):
                    x += 1 if x1 > x else -1
                else:
                    y += 1 if y1 > y else -1
            self.set(x1, y1, ch, force=True)

    def scatter(self, ch, count, seed=0, min_dist_border=3, only_on=None):
        placed = 0
        tries = 0
        rng = random.Random(seed)
        while placed < count and tries < 4000:
            tries += 1
            x = rng.randrange(min_dist_border, self.w - min_dist_border)
            y = rng.randrange(min_dist_border, self.h - min_dist_border)
            if (x, y) in self.keep:
                continue
            if only_on and self.g[y][x] not in only_on:
                continue
            if self.g[y][x] != only_on[0] if only_on else False:
                continue
            self.g[y][x] = ch
            placed += 1

    def ring(self, cx, cy, r, ch, gaps=(), seed=0):
        """Kring van tegels (bv. struiken) met openingen."""
        for y in range(cy - r - 1, cy + r + 2):
            for x in range(cx - r - 1, cx + r + 2):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if abs(d - r) < 0.6 and (x, y) not in gaps:
                    self.set(x, y, ch)

    def rows(self):
        return ["".join(row) for row in self.g]


def reachable(m, starts):
    """BFS vanaf starts; geeft de set bereikbare tegels."""
    seen = set()
    stack = [s for s in starts if not is_solid(m.get(*s))]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < m.w and 0 <= y < m.h) or is_solid(m.get(x, y)):
            continue
        seen.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return seen


# ---------------------------------------------------------------- Dauwbos
DAUWBOS_OBJECTS = [  # (x, y) van alle objecten die begaanbaar/bereikbaar moeten blijven
    (2, 20), (25, 2), (26, 2), (48, 19), (48, 20),  # portalen (incl. tweede tegel)
    (46, 18), (8, 18), (6, 22), (27, 4),            # borden + savepoint
    (15, 12), (28, 18), (22, 28),                   # npc's
    (40, 10), (12, 30),                             # kisten
    (32, 8), (18, 8), (35, 25), (10, 15), (25, 25),  # pickups
    (10, 8), (20, 15), (30, 22), (38, 12),          # vijanden
    (14, 14), (26, 20),                             # lantaarns
]
DAUWBOS_RESOURCES = [(20, 9), (27, 27), (20, 20), (36, 22), (16, 16), (30, 6), (8, 24), (34, 10), (38, 29)]
DAUWBOS_SPAWNS = [(5, 20), (25, 4), (47, 20)]


def build_dauwbos():
    m = Map(50, 37, ".")
    for pos in DAUWBOS_OBJECTS + DAUWBOS_RESOURCES + DAUWBOS_SPAWNS:
        m.keep.add(pos)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m.keep.add((pos[0] + dx, pos[1] + dy))
    # Boomrand, met openingen waar de portalen zitten.
    openings = [(2, 20), (2, 19), (2, 21), (25, 2), (26, 2), (48, 19), (48, 20), (25, 1), (2, 18), (2, 22)]
    m.border("#", 2, openings)
    # Bosvlekken (organische clusters, weg van de objecten).
    for cx, cy, r in [(8, 6, 3), (17, 4, 2), (36, 5, 3), (44, 8, 2), (45, 24, 2),
                      (6, 28, 2), (18, 33, 3), (31, 33, 2), (42, 33, 2), (7, 12, 2)]:
        m.blob(cx, cy, r, r * 0.8, "#", seed=cx * 7 + cy)
    # Kronkelende paden.
    m.path([(2, 20), (8, 20), (13, 17), (19, 19), (24, 21), (31, 19), (37, 21), (43, 18), (48, 19)])
    m.path([(24, 21), (25, 16), (24, 11), (25, 6), (25, 3)])
    m.path([(13, 17), (11, 22), (12, 27), (12, 30)])
    m.path([(37, 21), (34, 24), (29, 27), (24, 28)])
    m.path([(8, 20), (8, 18)])
    m.path([(19, 19), (18, 14), (16, 12)])
    # Vijver in het zuidoosten, pad loopt erlangs.
    m.blob(38, 28, 3.2, 2.2, "~", seed=99)
    # Paddenstoelenkring bij het hartje: struikenring met openingen.
    m.ring(20, 9, 2, "b", gaps=[(20, 11), (18, 9)], seed=5)
    m.set(21, 8, "t")
    m.set(19, 10, "t")
    # Oude dode bomen hier en daar (past bij het mistige).
    for x, y in [(33, 12), (6, 24), (27, 30), (43, 12)]:
        m.set(x, y, "t")
    # Struiken bij de bessenplekken en verspreid.
    for x, y in [(16, 15), (17, 16), (30, 5), (29, 6), (14, 26), (39, 16), (9, 9), (35, 30)]:
        m.set(x, y, "b")
    # Stenen bij de vijver (vuursteenplek).
    m.set(39, 29, "o")
    m.set(37, 30, "o")
    # Verstrooide losse bomen voor het bosgevoel.
    m.scatter("#", 26, seed=7, only_on=["."])
    return m


# ---------------------------------------------------------------- IJsdal
IJSDAL_OBJECTS = [
    (24, 33), (25, 33),                 # portaal (2 breed)
    (25, 12), (22, 13), (37, 25),       # savepoint + borden
    (13, 13), (37, 13), (26, 18),       # npc's
    (44, 4), (8, 27),                   # kisten
    (45, 7), (6, 29),                   # pickups
    (42, 25), (39, 29), (44, 23), (7, 17), (33, 27),  # vijanden
    (20, 13), (30, 13), (24, 27),       # lantaarns
]
IJSDAL_RESOURCES = [(5, 14), (16, 25), (30, 5), (4, 19), (42, 6), (7, 16), (33, 20), (40, 24), (44, 28), (38, 26), (28, 19)]
IJSDAL_SPAWNS = [(25, 31), (25, 14)]

HUIS = ["^^^^^^", "HhHHhH", "HHDHHH"]


def zet_huis(m, x, y):
    for dy, rij in enumerate(HUIS):
        for dx, ch in enumerate(rij):
            m.set(x + dx, y + dy, ch, force=True)
    m.keep.add((x + 2, y + 2))  # deur vrijhouden


def build_ijsdal():
    m = Map(50, 36, "z")
    for pos in IJSDAL_OBJECTS + IJSDAL_RESOURCES + IJSDAL_SPAWNS:
        m.keep.add(pos)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m.keep.add((pos[0] + dx, pos[1] + dy))
    m.border("P", 2, openings=[(24, 33), (25, 33), (24, 34), (25, 34)])
    # Bevroren meer: groot, organisch, met een eilandje met een den.
    m.blob(9, 26, 6.0, 4.2, "i", seed=11)
    m.blob(15, 24, 2.5, 2.0, "i", seed=12)
    m.set(9, 25, "P", force=True)
    m.set(8, 25, "G", force=True)
    # Het dorp: twee huizenclusters en een pleintje met de put.
    zet_huis(m, 8, 8)
    zet_huis(m, 34, 8)
    zet_huis(m, 14, 15)
    for x, y in [(24, 15), (25, 15), (26, 15), (24, 17), (25, 17), (26, 17), (24, 16), (26, 16)]:
        m.set(x, y, ",", force=True)
    m.set(25, 16, "O", force=True)  # dorpsput op het plein
    # Paden: portaal -> plein -> savepoint, en naar huizen, meer en mijn.
    m.path([(24, 32), (25, 28), (24, 24), (25, 20), (25, 17)])
    m.path([(25, 15), (25, 13)])
    m.path([(24, 15), (18, 14), (14, 13)])
    m.path([(26, 15), (31, 14), (36, 13)])
    m.path([(18, 14), (17, 19), (16, 23)])
    m.path([(31, 14), (35, 18), (37, 23), (38, 25)])
    # Mijnhoek in het zuidoosten: rotspartijen en kisten.
    for x, y in [(39, 22), (41, 23), (43, 22), (45, 24), (46, 26), (42, 27), (40, 30), (46, 29)]:
        m.set(x, y, "o")
    m.set(43, 24, "x")
    m.set(41, 29, "x")
    # Dennenclusters (bij de stronk- en besplekken).
    for cx, cy, r in [(6, 14, 2), (34, 20, 1.6), (44, 6, 2), (12, 4, 2), (28, 33, 2), (40, 33, 2), (6, 33, 2)]:
        m.blob(cx, cy, r, r, "P", seed=cx + cy * 3, skip_solid=False)
    # Besneeuwde struiken bij de winterbessen.
    for x, y in [(4, 18), (5, 19), (42, 5), (43, 6), (19, 6), (33, 30)]:
        m.set(x, y, "G")
    # Sneeuwplukjes als versiering.
    m.scatter("f", 18, seed=13, only_on=["z"])
    return m


# ---------------------------------------------------------------- Dorstvallei
DORST_OBJECTS = [
    (29, 31), (30, 31),                 # portaal (2 breed)
    (31, 14), (27, 14), (40, 21),       # savepoint + borden
    (28, 15), (11, 12), (32, 18),       # npc's
    (3, 3), (44, 29),                   # kisten
    (20, 3), (6, 24),                   # pickups
    (36, 24), (41, 27), (33, 27), (22, 24), (26, 28), (16, 26),  # wild
    (26, 15), (33, 17), (29, 24),       # lantaarns
]
DORST_RESOURCES = [(6, 7), (41, 8), (38, 12), (11, 8), (20, 12), (37, 22), (7, 27), (25, 4), (13, 30), (21, 26), (12, 13)]
DORST_SPAWNS = [(29, 29), (31, 16)]


def build_dorstvallei():
    m = Map(48, 34, "a")
    for pos in DORST_OBJECTS + DORST_RESOURCES + DORST_SPAWNS:
        m.keep.add(pos)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m.keep.add((pos[0] + dx, pos[1] + dy))
    m.border("q", 2, openings=[(29, 31), (30, 31), (29, 32), (30, 32)])
    # Kloofwanden: twee zandsteenruggen die een kronkelende kloof vormen.
    m.blob(38, 5, 2.2, 4.5, "q", seed=21)
    m.blob(44, 20, 2.0, 6.0, "q", seed=22)
    m.blob(20, 6, 1.8, 3.0, "q", seed=23)
    # Oase: twee verbonden plassen met een brede groene oever.
    m.blob(10, 17, 3.4, 3.2, "~", seed=31)
    m.blob(13, 20, 2.0, 1.6, "~", seed=32)
    m.blob(10, 17, 5.2, 4.8, "L", seed=33, jag=0.5, skip_solid=False)
    # water opnieuw bovenop het gras van het hart
    m.blob(10, 17, 3.4, 3.2, "~", seed=31, jag=0.45)
    m.blob(13, 20, 2.0, 1.6, "~", seed=32, jag=0.45)
    # Adobe dorpje bij de oase.
    zet_huis(m, 24, 11)
    zet_huis(m, 33, 9)
    # Paden: portaal -> dorp -> oase, en naar de jachtgronden in het zuidoosten.
    m.path([(29, 30), (29, 26), (30, 21), (28, 17), (28, 15)])
    m.path([(28, 17), (22, 16), (16, 14), (12, 13)])
    m.path([(30, 21), (35, 21), (39, 22)])
    m.path([(39, 22), (42, 25), (44, 28)])
    m.path([(16, 14), (12, 9), (7, 5), (4, 4)])
    m.path([(30, 21), (26, 24), (22, 24)])
    # Cactusvelden bij de vijgenplekken.
    for x, y in [(5, 6), (7, 8), (8, 6), (40, 7), (42, 9), (37, 11), (39, 13), (15, 25), (8, 22), (30, 4), (44, 12), (24, 27)]:
        m.set(x, y, "g")
    # Zandsteenrotsen bij de mijnplekken.
    for x, y in [(24, 3), (26, 4), (7, 28), (8, 27), (14, 30), (14, 29)]:
        m.set(x, y, "q")
    # Vuursteen bij een rotspartijtje.
    m.set(20, 26, "o")
    m.set(22, 25, "o")
    # Dor gras in de jachtgronden en hier en daar.
    for cx, cy, r in [(22, 26, 3), (35, 25, 2.5), (12, 8, 2), (20, 12, 1.5)]:
        m.blob(cx, cy, r, r * 0.8, "e", seed=cx + cy)
    # Dode bomen als dor decor.
    for x, y in [(17, 21), (33, 5), (9, 28)]:
        m.set(x, y, "t")
    return m


# ---------------------------------------------------------------- schrijven + controleren
def rewrite(path, m):
    src = io.open(path, encoding="utf-8").read()
    blok = "\n".join('\t\t"%s",' % r for r in m.rows())
    nieuw, n = re.subn(r'(\t"rows": \[\n).*?(\n\t\],)', lambda mo: mo.group(1) + blok + mo.group(2), src, flags=re.S)
    assert n == 1, path
    io.open(path, "w", encoding="utf-8").write(nieuw)
    print("herschreven:", path)


def check(naam, m, objects, resources, spawns):
    fouten = []
    for x, y in objects + resources + spawns:
        if is_solid(m.get(x, y)):
            fouten.append("(%d,%d) is dicht: %s" % (x, y, m.get(x, y)))
    bereik = reachable(m, spawns)
    for x, y in objects + resources:
        if (x, y) not in bereik:
            # naast een dichte tegel (kist naast muur) is ok als een buur bereikbaar is
            buren = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            if not any(b in bereik for b in buren):
                fouten.append("(%d,%d) onbereikbaar" % (x, y))
    if fouten:
        print("!! %s:" % naam)
        for f in fouten:
            print("   ", f)
        return False
    print("ok %s: alles begaanbaar en bereikbaar" % naam)
    return True


def main():
    schrijf = "--write" in sys.argv
    ok = True
    for naam, bouw, objs, res, spawns, pad in [
        ("dauwbos", build_dauwbos, DAUWBOS_OBJECTS, DAUWBOS_RESOURCES, DAUWBOS_SPAWNS, "scripts/maps/dauwbos.gd"),
        ("ijsdal", build_ijsdal, IJSDAL_OBJECTS, IJSDAL_RESOURCES, IJSDAL_SPAWNS, "scripts/maps/ijsdal.gd"),
        ("dorstvallei", build_dorstvallei, DORST_OBJECTS, DORST_RESOURCES, DORST_SPAWNS, "scripts/maps/dorstvallei.gd"),
    ]:
        m = bouw()
        ok = check(naam, m, objs, res, spawns) and ok
        if schrijf:
            rewrite(pad, m)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
