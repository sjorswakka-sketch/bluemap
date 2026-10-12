"""Render kaarten uit de data met de echte tiles.png om de lay-out te beoordelen."""
import io, re
from PIL import Image

CHARS = {}
text = io.open("scripts/data/tiles.gd", encoding="utf-8").read()
names_block = re.search(r"const NAMES[^=]*= *\[(.*?)\]", text, re.S).group(1)
NAMES = re.findall(r'"([^"]+)"', names_block)
chars_block = re.search(r"const CHARS[^=]*= *\{(.*?)\n\}", text, re.S).group(1)
for ch, name in re.findall(r'"([^"]+)": "([^"]+)"', chars_block):
    CHARS[ch] = name

tiles = Image.open("assets/tiles.png").convert("RGBA")
TILE = {name: tiles.crop((i * 16, 0, i * 16 + 16, 16)) for i, name in enumerate(NAMES)}

def name_for(ch, x, y):
    name = CHARS.get(ch, "grass")
    if name == "grass":
        h = (x * 7 + y * 13 + x * y) % 11
        if h < 1:
            return "grass_flowers"
        if h < 5:
            return "grass_tufts"
    if name == "snow":
        h = (x * 7 + y * 13 + x * y) % 11
        if h < 1:
            return "snow_flowers"
        if h < 5:
            return "snow_tufts"
    if name == "dune_sand":
        h = (x * 7 + y * 13 + x * y) % 11
        if h < 5:
            return "dune_tufts"
    return name

MARKERS = {"npc": (0, 255, 255, 255), "portal": (255, 255, 255, 255), "savepoint": (80, 140, 255, 255),
           "chest": (255, 200, 40, 255), "pickup": (255, 120, 255, 255), "enemy": (255, 60, 60, 255),
           "sign": (200, 200, 200, 255), "wereld_lantaarn": (255, 230, 120, 255)}

for map_id in ["dauwbos", "ijsdal", "dorstvallei"]:
    src = io.open("scripts/maps/%s.gd" % map_id, encoding="utf-8").read()
    rows = re.findall(r'^\s+"([#~.,=+|^HhDEATobtOxcXyvrMIk_Zu%wNCSBms;lpQJdVK*>:!nzaegqLfGiP]+)",?\s*$', src, re.M)
    rows = [r for r in rows if len(set(r) - set(CHARS)) == 0 and len(r) > 20]
    w, h = len(rows[0]), len(rows)
    img = Image.new("RGBA", (w * 16, h * 16))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            img.paste(TILE.get(name_for(ch, x, y), TILE["grass"]), (x * 16, y * 16))
    objects = re.findall(r'\{"type": "([^"]+)", "pos": \[(\d+), (\d+)\][^}]*\}', src)
    for typ, sx, sy in objects:
        x, y = int(sx) * 16, int(sy) * 16
        color = MARKERS.get(typ, (255, 255, 0, 255))
        for dx in range(16):
            for dy in range(16):
                if dx in (0, 15) or dy in (0, 15):
                    img.putpixel((x + dx, y + dy), color)
    img = img.resize((w * 8, h * 8), Image.NEAREST)
    img.save("tools/map_%s.png" % map_id)
    print("tools/map_%s.png  %dx%d tegels, %d objecten" % (map_id, w, h, len(objects)))
