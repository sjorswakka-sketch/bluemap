"""Genereert uitsluitend de twee nieuwe grotten; bestaande kaarten blijven behouden."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def board(w, h):
    return [["X"] * w for _ in range(h)]


def room(grid, x, y, w, h, tile="c"):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            grid[yy][xx] = tile


def save(name, title, grid, spawns, objects, dark):
    data = {"name": title, "music": "cave", "dark": dark,
            "rows": ["".join(row) for row in grid], "spawns": spawns, "objects": objects}
    # JSON is also valid GDScript data when booleans use their normal lowercase form.
    (ROOT / "scripts/maps" / (name + ".gd")).write_text(
        "extends RefCounted\n## Gemaakt met tools/gen_echo.py.\nconst DATA := " + json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def main():
    g = board(42, 30)
    for bounds in [(2, 19, 10, 8), (5, 7, 12, 9), (21, 3, 17, 10), (24, 18, 15, 9),
                   (7, 13, 3, 10), (14, 9, 11, 3), (29, 11, 3, 12), (10, 22, 17, 3)]:
        room(g, *bounds)
    # Een verzonken plas met een brede brug; twee routes verbinden de hoofdkamers.
    room(g, 10, 9, 5, 4, "~")
    room(g, 9, 10, 7, 2, "=")
    for x, y in [(5, 7), (16, 7), (22, 3), (37, 4), (37, 12), (25, 18), (38, 25), (2, 20)]:
        g[y][x] = "y"
    obj = [
        {"type": "portal", "pos": [3, 25], "to": "cave", "spawn": "from_prismamine"},
        {"type": "portal", "pos": [36, 5], "to": "resonance", "spawn": "start"},
        {"type": "savepoint", "pos": [6, 22]},
        {"type": "sign", "pos": [8, 24], "lines": ["De Prismamijn", "Drie snelle zwaardaanvallen vormen een combo. De derde is een brede veeg voor 18 stamina. Zonder energie blijft het een gewone slag."]},
        {"type": "sign", "pos": [34, 7], "lines": ["Naar de Resonantiekamer", "Raak daar het zwevende kristal aan om drie golven te beginnen. Je kunt altijd terugtrekken."]},
        {"type": "chest", "pos": [14, 8], "contents": [["potion", 2], ["coins", 25]]},
        {"type": "chest", "pos": [36, 24], "contents": [["shard", 3], ["coins", 35]]},
        {"type": "enemy", "pos": [8, 10], "kind": "crystal_beetle"},
        {"type": "enemy", "pos": [24, 7], "kind": "prism_moth"},
        {"type": "enemy", "pos": [28, 24], "kind": "crystal_beetle"},
        {"type": "enemy", "pos": [34, 20], "kind": "prism_moth"},
    ]
    for i, (x, y) in enumerate([(3, 20), (10, 20), (6, 8), (15, 14), (22, 4), (35, 11), (25, 19), (37, 25)]):
        obj.append({"type": "echo_crystal", "pos": [x, y], "violet": bool(i % 2)})
    save("prismamine", "De Prismamijn", g, {"start": [5, 24], "altar": [6, 23], "from_resonance": [34, 5]}, obj, 0.48)
    g = board(32, 24)
    room(g, 3, 3, 26, 17, "d")
    room(g, 13, 18, 6, 4, "c")
    # Concentrische vloerrunen maken het gevechtsvlak herkenbaar zonder obstakels.
    for x in range(8, 25):
        g[5][x] = g[16][x] = "*"
    for y in range(5, 17):
        g[y][8] = g[y][24] = "*"
    obj = [
        {"type": "portal", "pos": [15, 21], "size": [2, 1], "to": "prismamine", "spawn": "from_resonance"},
        {"type": "echo_trial", "pos": [16, 15]},
        {"type": "sign", "pos": [18, 19], "lines": ["Resonantieproef", "Kristalkevers stormen na hun lichtspoor recht vooruit. Prismamotten schieten tussen drie stralen. Ontwijk opzij of onderbreek de mot met je zwaard.", "Win drie golven voor een kristallen amulet en 120 munten. De beloning krijg je eenmaal per avontuur."]},
    ]
    for i, (x, y) in enumerate([(4, 4), (27, 4), (4, 17), (27, 17), (15, 3), (17, 3)]):
        obj.append({"type": "echo_crystal", "pos": [x, y], "violet": bool(i % 2)})
    save("resonance", "De Resonantiekamer", g, {"start": [16, 19]}, obj, 0.35)


if __name__ == "__main__":
    main()
