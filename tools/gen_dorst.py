"""Bouwt scripts/maps/dorstvallei.gd: de woestijnvallei Dorstvallei, en valideert de kaart direct."""
import sys

W, H = 48, 34

g = [["a"] * W for _ in range(H)]

# Grens: twee tegels zandsteenrotsen
for x in range(W):
    for y in (0, 1, H - 2, H - 1):
        g[y][x] = "q"
for y in range(H):
    for x in (0, 1, W - 2, W - 1):
        g[y][x] = "q"

# De oase (midden-west): water met een ring sappig oasegras
for y in range(15, 21):
    for x in range(9, 17):
        g[y][x] = "~"
for y in range(13, 23):
    for x in range(7, 19):
        if g[y][x] == "a":
            g[y][x] = "L"
# oevers weer open zand aan de randen van de ring
for x in range(7, 19):
    g[13][x] = "L" if g[13][x] == "a" else g[13][x]
for x, y in [(7, 14), (7, 15), (7, 20), (7, 21), (18, 14), (18, 15), (18, 20), (18, 21), (10, 13), (15, 13), (10, 22), (15, 22)]:
    g[y][x] = "a"

# Plein en paden rond de put (oost van de oase)
for y in range(15, 19):
    for x in range(25, 34):
        g[y][x] = ","
for x in range(19, 26):
    g[17][x] = ","   # pad van de oase naar het plein
for y in range(19, 30):
    g[29][y] = ","   # pad naar het zuiden (portaal)
for y in range(19, 30):
    g[30][y] = ","
g[16][29] = "O"      # put op het plein

# Huizen (6 breed, 3 hoog): dak, ramen, deur
def house(x0, y0, door_dx):
    for x in range(x0, x0 + 6):
        g[y0][x] = "^"
    for i, ch in enumerate("HhHHhH"):
        g[y0 + 1][x0 + i] = ch
    for i, ch in enumerate("HHHHHH"):
        g[y0 + 2][x0 + i] = ch
    g[y0 + 2][x0 + door_dx] = "D"

house(26, 11, 2)  # huis noord, deur op x28 y13
house(36, 16, 2)  # huis oost, deur op x38 y18
for y in range(14, 16):
    g[y][28] = ","  # pad naar huis noord
for x in range(33, 39):
    g[18][x] = ","  # pad naar huis oost

# Cactusvelden: noordwesten en oosten
for x, y in [(4, 5), (8, 4), (12, 6), (5, 9), (16, 5), (9, 11), (3, 12), (14, 9)]:
    g[y][x] = "g"
for x, y in [(38, 4), (42, 6), (40, 9), (44, 11), (36, 7), (43, 3), (39, 13)]:
    g[y][x] = "g"

# Zandsteenklippen als decor: zuidwesten en noordrand
for x, y in [(5, 26), (8, 28), (12, 25), (4, 30), (15, 29), (9, 31)]:
    g[y][x] = "q"
for x, y in [(20, 4), (24, 3), (30, 5), (33, 3), (27, 6)]:
    g[y][x] = "q"

# Droge graspollen als versiering
for x, y in [(6, 15), (20, 12), (23, 20), (35, 12), (41, 20), (37, 25), (25, 26), (31, 24), (18, 27), (44, 22), (12, 18), (33, 28)]:
    if g[y][x] == "a":
        g[y][x] = "e"

rows = ["".join(r) for r in g]

# --- objecten en plekken -----------------------------------------------------------------------------------
objects = [
    {"type": "portal", "pos": [29, 31], "to": "dauwbos", "spawn": "from_dorstvallei", "size": [2, 1]},
    {"type": "savepoint", "pos": [31, 14], "spawn": "altar"},
    {"type": "sign", "pos": [27, 14], "lines": ["Dorstvallei", "De zon brandt, het zand waait. De oase geeft leven."]},
    {"type": "sign", "pos": [40, 21], "lines": ["Jachtgronden", "Woestijnvossen en zandhazen. Kom je te dichtbij, dan rennen ze weg."]},
    {"type": "npc", "pos": [28, 15], "id": "jelle"},
    {"type": "npc", "pos": [11, 12], "id": "sana"},
    {"type": "npc", "pos": [32, 18], "id": "nour"},
    {"type": "chest", "pos": [3, 3], "contents": [["coins", 40], ["prof_cactusvijg", 2]]},
    {"type": "chest", "pos": [44, 29], "contents": [["coins", 30], ["jacht_vlees", 1]]},
    {"type": "pickup", "pos": [20, 3], "item": "heart"},
    {"type": "pickup", "pos": [6, 24], "item": "potion", "unique": True},
    {"type": "enemy", "pos": [36, 24], "kind": "woestijnvos"},
    {"type": "enemy", "pos": [41, 27], "kind": "woestijnvos"},
    {"type": "enemy", "pos": [33, 27], "kind": "woestijnvos"},
    {"type": "enemy", "pos": [22, 24], "kind": "zandhaas"},
    {"type": "enemy", "pos": [26, 28], "kind": "zandhaas"},
    {"type": "enemy", "pos": [16, 26], "kind": "zandhaas"},
    {"type": "wereld_lantaarn", "pos": [26, 15]},
    {"type": "wereld_lantaarn", "pos": [33, 17]},
    {"type": "wereld_lantaarn", "pos": [29, 24]},
]

spawns = {"start": [29, 29], "from_dauwbos": [29, 29], "altar": [31, 16]}

# --- validatie ---------------------------------------------------------------------------------------------
SOLID = set("qg~W|^Hh#btOxoXvMIZNCBGP")  # q en g zijn hier de vaste woestijntegels
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
if (spawns["altar"][0], spawns["altar"][1]) not in seen:
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
lines.append('## Dorstvallei – woestijnvallei ten oosten van het Dauwbos (spoor "dorst").')
lines.append('## Altijd snikheet ("weather": "heat"), een oase met dichtbegroeide oevers, cactusvelden,')
lines.append('## zandsteenklippen en vreedzaam wild (woestijnvossen en zandhazen) voor de jacht.')
lines.append('## Drie personages met eigen opdrachten (zie scripts/data/ext/dorst.gd).')
lines.append('## Gemaakt met tools/gen_dorst.py (je mag dit bestand ook met de hand aanpassen).')
lines.append('')
lines.append('const DATA := {')
lines.append('\t"name": "Dorstvallei",')
lines.append('\t"music": "village",')
lines.append('\t"outdoor": true,')
lines.append('\t"weather": "heat", # de zon brandt hier altijd')
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
with open("scripts/maps/dorstvallei.gd", "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
print("dorstvallei.gd geschreven: %dx%d, %d objecten, bereikbaar OK" % (W, H, len(objects)))
