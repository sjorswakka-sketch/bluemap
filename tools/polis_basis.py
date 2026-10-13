"""Polis voor de basisgebieden: Dageraadsdorp, Fluisterbos en Zilvermeer.

Voegt decor toe op logische plekken (tuinen met hekjes, bosvlekken, lelies en riet,
rotsen bij mijnplekken, struiken bij besplekken) zonder bestaande objecten, paden
of bereikbaarheid te verstoren. Elke kandidaat wordt alleen geplaatst als de tegel
nu leeg is ('.', of '~' voor waterdecor) en buiten de vrije zones valt; daarna
bewijst een padvindingstest dat alles nog bereikbaar is.
"""
import io
import re
import sys

SOLID_CHARS = set("#~W|^HhoOtxXMZINCS;lpgGqP")  # zie tiles.gd SOLID (D en = zijn begaanbaar)


def is_solid(ch):
    return ch in SOLID_CHARS


def load(path):
    src = io.open(path, encoding="utf-8").read()
    rows = [r for r in re.findall(r'^\s+"([^"]+)",?\s*$', src, re.M) if len(r) > 20]
    objects = re.findall(r'\{"type": "([^"]+)", "pos": \[(\d+), (\d+)\][^}]*\}', src)
    fysiek = [(int(x), int(y)) for typ, x, y in objects if typ not in ("meer_water", "trigger", "boog_baan")]
    spawns = re.search(r'"spawns": \{([^}]*)\}', src).group(1)
    spawn_xy = [(int(x), int(y)) for x, y in re.findall(r"\[\s*(\d+),\s*(\d+)\s*\]", spawns)]
    return src, [list(r) for r in rows], fysiek, spawn_xy


def bereikbaar(g, start):
    h, w = len(g), len(g[0])
    seen = set()
    stack = [start]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h) or is_solid(g[y][x]):
            continue
        seen.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return seen


def laad_resources():
    """Beroepsplekken per kaart uit beroepen.gd, zodat decor ze niet begraaft."""
    src = io.open("scripts/data/ext/beroepen.gd", encoding="utf-8").read()
    blok = re.search(r"RESOURCE_PLACEMENTS := \{(.*?)\n\}", src, re.S).group(1)
    res = {}
    for line in blok.splitlines():
        m = re.match(r'\s*"(\w+)": \[(.*)\],?\s*$', line)
        if m:
            res[m.group(1)] = [(int(x), int(y)) for x, y in re.findall(r",\s*(\d+),\s*(\d+)\]", m.group(2))]
    return res


def polis(path, map_id, decor, vrije_zones=()):
    """decor: lijst van (x, y, teken, basis) — basis is '.' of '~'."""
    src, g, objects, spawns = load(path)
    h, w = len(g), len(g[0])
    keep = set()
    for x, y in objects + spawns + RESOURCES.get(map_id, []):
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                keep.add((x + dx, y + dy))
    for x0, y0, x1, y1 in vrije_zones:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                keep.add((x, y))
    geplaatst = 0
    for x, y, ch, basis in decor:
        if (x, y) in keep or not (0 <= x < w and 0 <= y < h):
            continue
        if g[y][x] == basis:
            g[y][x] = ch
            geplaatst += 1
    # Bewijs: vanaf elke spawn blijft elk object bereikbaar.
    fouten = []
    for start in spawns:
        if is_solid(g[start[1]][start[0]]):
            fouten.append("spawn %s is dicht" % (start,))
            continue
        seen = bereikbaar(g, start)
        for pos in objects + RESOURCES.get(map_id, []):
            if pos in seen:
                continue
            if not any((pos[0] + dx, pos[1] + dy) in seen for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                fouten.append("object %s onbereikbaar vanaf %s" % (pos, start))
    if fouten:
        for f in fouten[:10]:
            print("  !!", f)
        return False
    blok = "\n".join('\t\t"%s",' % "".join(r) for r in g)
    nieuw, n = re.subn(r'(\t"rows": \[\n).*?(\n\t\],)', lambda m: m.group(1) + blok + m.group(2), src, flags=re.S)
    assert n == 1, path
    if "--write" in sys.argv:
        io.open(path, "w", encoding="utf-8").write(nieuw)
    print("ok %s: %d decorstukken geplaatst, alles bereikbaar%s" % (path, geplaatst, "" if "--write" in sys.argv else " (droog)"))
    return True


# ------------------------------------------------------------- Dageraadsdorp
DORP_DECOR = [
    # Buurttuin West: hekjes met twee openingen, om de kruid- en besplek heen.
    *[(x, 15, "|", ".") for x in (3, 4, 5, 7, 8, 9)],
    *[(3, y, "|", ".") for y in (16, 17)],
    *[(x, 18, "|", ".") for x in (4, 5)],
    # Bloemenstruiken in de tuin en bij de bessenplek.
    (6, 16, "b", "."), (7, 17, "b", "."), (9, 16, "b", "."),
    # Bomen langs de westrand en bij de tempel.
    (3, 2, "#", "."), (4, 3, "#", "."), (3, 5, "#", "."),
    (16, 5, "#", "."), (17, 4, "#", "."),
    # Kratten bij de smederij en de winkel.
    (3, 11, "x", "."), (16, 10, "x", "."),
    # Stenen bij de vuursteenplekken.
    (4, 16, "o", "."), (24, 23, "o", "."),
    # Struiken in de zuidhoeken en bij het meerpad.
    (5, 24, "b", "."), (14, 24, "b", "."), (30, 24, "b", "."), (35, 16, "b", "."),
    (11, 24, "#", "."), (28, 25, "#", "."), (34, 23, "#", "."),
    # Verdere vergroening langs de oostrand.
    (36, 16, "#", "."), (37, 17, "#", "."), (36, 19, "b", "."),
    # Lege hoeken aankleden.
    (33, 24, "#", "."), (34, 25, "#", "."), (35, 24, "b", "."),
    (3, 24, "b", "."), (5, 25, "b", "."), (3, 6, "#", "."), (36, 21, "b", "."),
]
DORP_VRIJ = [(29, 2, 39, 6), (30, 13, 39, 18)]  # arena-ingang en schietbaan vrijhouden

# ------------------------------------------------------------- Fluisterbos
BOS_DECOR = [
    # Bosvlekken in de open westhelft.
    *[(x + dx, y + dy, "#", ".") for (x, y) in [(8, 4), (17, 5), (36, 6), (16, 31)] for dx, dy in [(0, 0), (1, 0), (0, 1), (-1, 1)]],
    # Struiken bij de bessenplek (west).
    (9, 20, "b", "."), (11, 22, "b", "."), (12, 21, "b", "."),
    # Dode bomen bij de paddenstoelenplekken.
    (7, 24, "t", "."), (9, 26, "t", "."), (44, 24, "t", "."), (42, 22, "t", "."),
    # Rotsen bij de koper- en vuursteenplekken.
    (4, 25, "o", "."), (6, 27, "o", "."), (29, 19, "o", "."), (31, 21, "o", "."),
    (4, 21, "o", "."), (2, 21, "o", "."),
    # Struiken bij de kruidenplek.
    (9, 19, "b", "."), (7, 19, "b", "."),
    # Extra bomen als omlijsting van de vijver.
    (15, 21, "#", "."), (21, 25, "#", "."),
    # Nog twee bosvlekken in de open plekken.
    (14, 8, "#", "."), (15, 8, "#", "."), (14, 9, "#", "."), (13, 9, "#", "."),
    (6, 29, "#", "."), (7, 29, "#", "."), (44, 16, "#", "."), (17, 33, "t", "."),
]
BOS_VRIJ = [(20, 29, 29, 36)]  # schietbaan in het bos vrijhouden

# ------------------------------------------------------------- Zilvermeer
MEER_DECOR = [
    # Extra lelievelden op het water.
    (12, 17, "l", "~"), (14, 20, "l", "~"), (30, 15, "l", "~"), (33, 18, "l", "~"),
    (27, 25, "l", "~"), (10, 19, "l", "~"), (36, 17, "l", "~"),
    # Dikkere rietkragen.
    (13, 15, ";", "~"), (25, 25, ";", "~"), (35, 22, ";", "~"),
    # Stenen bij de vuursteenplek op de oostoever.
    (36, 12, "o", "."), (34, 13, "o", "."),
    # Struiken bij de bessenplek in het noorden.
    (24, 10, "b", "."), (26, 10, "b", "."),
    # Stenen en een struik bij de takkenplek op de westoever.
    (5, 12, "o", "."), (7, 11, "b", "."),
]

RESOURCES = laad_resources()
ok = True
ok = polis("scripts/maps/village.gd", "village", DORP_DECOR, DORP_VRIJ) and ok
ok = polis("scripts/maps/forest.gd", "forest", BOS_DECOR, BOS_VRIJ) and ok
ok = polis("scripts/maps/lake.gd", "lake", MEER_DECOR) and ok
sys.exit(0 if ok else 1)
