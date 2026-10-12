"""Bouwt scripts/maps/ijsdal.gd: het besneeuwde bergdorp IJsdal, en valideert de kaart direct."""
import re
import sys

W, H = 50, 36

g = [["z"] * W for _ in range(H)]

# Grens: twee tegels dicht dennenbos
for x in range(W):
    for y in (0, 1, H - 2, H - 1):
        g[y][x] = "P"
for y in range(H):
    for x in (0, 1, W - 2, W - 1):
        g[y][x] = "P"

# Bevroren meer (zuidwesten)
for y in range(24, 31):
    for x in range(3, 14):
        g[y][x] = "i"

# Plein en paden
for y in range(13, 18):
    for x in range(20, 31):
        g[y][x] = ","
for y in range(16, 32):
    for x in (24, 25):
        g[y][x] = ","
for y in range(11, 14):
    g[y][11] = ","   # pad naar huis west
for y in range(11, 14):
    g[y][36] = ","   # pad naar huis oost
for x in range(11, 37):
    g[13][x] = ","   # pleinrand verbindt de huizen
g[25][24] = ","      # huis zuid-deur aan het pad

# Bron op het plein
g[16][25] = "O"

# Huizen (6 breed, 3 hoog): dak, ramen, deur
def house(x0, y0, door_dx):
    for x in range(x0, x0 + 6):
        g[y0][x] = "^"
    for i, ch in enumerate("HhHHhH"):
        g[y0 + 1][x0 + i] = ch
    for i, ch in enumerate("HHHHHH"):
        g[y0 + 2][x0 + i] = ch
    g[y0 + 2][x0 + door_dx] = "D"

house(9, 8, 2)    # west, deur op x11
house(34, 8, 2)   # oost, deur op x36
house(22, 22, 2)  # zuid, deur op x24

# Dennen en besneeuwde struiken: westelijk bosje
for x, y in [(4, 12), (7, 12), (3, 15), (9, 15), (5, 18), (8, 19), (3, 21), (10, 13)]:
    g[y][x] = "P"
for x, y in [(6, 14), (4, 17), (8, 16), (6, 21), (10, 19)]:
    g[y][x] = "G"

# Noordband: dennen, rotsen en struiken
for x, y in [(5, 3), (9, 5), (13, 3), (18, 4), (22, 3), (31, 4), (35, 3), (40, 5)]:
    g[y][x] = "P"
for x, y in [(7, 4), (26, 5), (45, 3)]:
    g[y][x] = "o"
for x, y in [(11, 6), (20, 6), (33, 6), (43, 4)]:
    g[y][x] = "G"

# Mijnhoek (noordoosten): rotsen en kisten
for x, y in [(39, 23), (41, 22), (45, 24), (38, 27), (42, 29), (46, 28), (40, 26)]:
    g[y][x] = "o"
for x, y in [(46, 22), (37, 30)]:
    g[y][x] = "x"

# Sneeuwplukken als versiering
for x, y in [(16, 10), (28, 9), (31, 11), (6, 23), (15, 20), (33, 17), (44, 8), (22, 6), (12, 25), (36, 24), (27, 27), (19, 22)]:
    g[y][x] = "f"

rows = ["".join(r) for r in g]

# --- objecten en plekken -----------------------------------------------------------------------------------
objects = [
    {"type": "portal", "pos": [24, 33], "to": "dauwbos", "spawn": "from_ijsdal", "size": [2, 1]},
    {"type": "savepoint", "pos": [25, 12], "spawn": "altar"},
    {"type": "sign", "pos": [22, 13], "lines": ["IJsdal", "Wit en stil. De sneeuw knarst onder je laarzen."]},
    {"type": "sign", "pos": [37, 25], "lines": ["Mijn van IJsdal", "Ijskristal diep in de rotsen. Nodig: een koperen pikhouweel."]},
    {"type": "npc", "pos": [13, 13], "id": "fenna"},
    {"type": "npc", "pos": [37, 13], "id": "roos"},
    {"type": "npc", "pos": [26, 18], "id": "olav"},
    {"type": "chest", "pos": [44, 4], "contents": [["coins", 50], ["prof_ijsbloem", 2]]},
    {"type": "chest", "pos": [8, 27], "contents": [["coins", 30], ["prof_winterbes", 2]]},
    {"type": "pickup", "pos": [45, 7], "item": "heart"},
    {"type": "pickup", "pos": [6, 29], "item": "potion", "unique": True},
    {"type": "enemy", "pos": [42, 25], "kind": "slime_blue"},
    {"type": "enemy", "pos": [39, 29], "kind": "slime_blue"},
    {"type": "enemy", "pos": [44, 23], "kind": "slime_blue"},
    {"type": "enemy", "pos": [7, 17], "kind": "slime_blue"},
    {"type": "enemy", "pos": [33, 27], "kind": "bat"},
    {"type": "wereld_lantaarn", "pos": [20, 13]},
    {"type": "wereld_lantaarn", "pos": [30, 13]},
    {"type": "wereld_lantaarn", "pos": [24, 27]},
]

spawns = {"start": [25, 31], "from_dauwbos": [25, 31], "altar": [25, 14]}

# --- validatie ---------------------------------------------------------------------------------------------
SOLID = set("PG~W|^Hh#btOxoXvMIZNCB")
# portal/savepoint/sign/npc/chest/pickup/wereld_lantaarn staan op of naast begaanbare tegels
ok = True
def fail(msg):
    global ok
    ok = False
    print("FOUT:", msg)

for name, (sx, sy) in spawns.items():
    if g[sy][sx] in SOLID:
        fail(f"spawn {name} op vaste tegel {g[sy][sx]} ({sx},{sy})")
for obj in objects:
    ox, oy = obj["pos"]
    if obj["type"] in ("savepoint", "sign", "npc", "chest", "wereld_lantaarn"):
        if g[oy][ox] in SOLID:
            fail(f"{obj['type']} op vaste tegel ({ox},{oy})")
    if obj["type"] == "portal":
        for dx in range(obj.get("size", [1, 1])[0]):
            for dy in range(obj.get("size", [1, 1])[1]):
                if g[oy + dy][ox + dx] in SOLID:
                    fail(f"portaal op vaste tegel ({ox+dx},{oy+dy})")

# Bereikbaarheid vanaf start (objecten die blokkeren meetellen)
blocked = set()
for obj in objects:
    if obj["type"] in ("npc", "sign", "chest", "savepoint", "wereld_lantaarn"):
        blocked.add((obj["pos"][0], obj["pos"][1]))
start = (spawns["start"][0], spawns["start"][1])
seen = {start}
queue = [start]
while queue:
    cx, cy = queue.pop()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = cx + dx, cy + dy
        if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in seen and g[ny][nx] not in SOLID and (nx, ny) not in blocked:
            seen.add((nx, ny))
            queue.append((nx, ny))
for obj in objects:
    ox, oy = obj["pos"]
    neighbours = [(ox + dx, oy + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
    if obj["type"] == "portal":
        if (ox, oy) not in seen:
            fail(f"portaal ({ox},{oy}) onbereikbaar")
    elif not any(n in seen for n in neighbours):
        fail(f"{obj['type']} ({ox},{oy}) onbereikbaar")
if spawns["altar"][0:2] and (spawns["altar"][0], spawns["altar"][1]) not in seen:
    fail("altaar-aankomst onbereikbaar")

if not ok:
    sys.exit(1)

# --- bestand schrijven -------------------------------------------------------------------------------------
def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, list):
        return "[" + ", ".join(fmt(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join('"%s": %s' % (k, fmt(x)) for k, x in v.items()) + "}"
    return str(v)

lines = []
lines.append('extends RefCounted')
lines.append('## IJsdal – besneeuwd bergdorp ten noorden van het Dauwbos (spoor "sneeuw").')
lines.append('## Altijd sneeuw ("weather": "snow"), een bevroren meer, een mijnhoek met ijskristal')
lines.append('## en drie personages met eigen opdrachten (zie scripts/data/ext/sneeuw.gd).')
lines.append('## Gemaakt met tools/gen_ijsdal.py (je mag dit bestand ook met de hand aanpassen).')
lines.append('')
lines.append('const DATA := {')
lines.append('\t"name": "IJsdal",')
lines.append('\t"music": "village",')
lines.append('\t"outdoor": true,')
lines.append('\t"weather": "snow", # het sneeuwt hier altijd')
lines.append('\t"rows": [')
for r in rows:
    lines.append('\t\t"%s",' % r)
lines.append('\t],')
lines.append('\t"spawns": {%s},' % ", ".join('"%s": %s' % (k, fmt(v)) for k, v in spawns.items()))
lines.append('\t"objects": [')
for obj in objects:
    lines.append('\t\t%s,' % fmt(obj).replace("'", '"'))
lines.append('\t],')
lines.append('}')
text = "\n".join(lines) + "\n"
# fmt() maakt "True" niet, maar strings tussen enkele quotes komen niet voor; dict-sleutels wel
with open("scripts/maps/ijsdal.gd", "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
print("ijsdal.gd geschreven: %dx%d, %d objecten, bereikbaar OK" % (W, H, len(objects)))
