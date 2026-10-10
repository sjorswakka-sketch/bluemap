#!/usr/bin/env python3
"""Genereert alle pixel art van het spel in assets/ (16x16 per sprite, bazen groter).

Gebruik:  python3 tools/make_art.py      (Pillow nodig: pip install pillow)

Alles is zelfgemaakt voor dit project. Wil je andere art? Vervang gewoon de PNG's in assets/
door eigen bestanden met dezelfde indeling (zie README), de game-code hoeft dan niet te veranderen.

  tools/artlib.py     hulpfuncties
  tools/art_tiles.py  alle tegels (volgorde staat in scripts/data/tiles.gd)
  tools/art_chars.py  speler, vijanden, bazen en personages
  tools/art_items.py  voorwerpen, objecten en projectielen
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.normpath(os.path.join(HERE, ".."))
OUT = os.path.join(ROOT, "assets")

from PIL import Image  # noqa: E402

import art_chars as ch  # noqa: E402
import art_items as it  # noqa: E402
import art_tiles as ti  # noqa: E402
from artlib import c, centered, strip  # noqa: E402


def sheets():
    s = {
        "tiles": ti.tiles_sheet(ROOT),                # volgorde: scripts/data/tiles.gd
        "player": ch.player_sheet(),                  # 3 kolommen (stil, stap, stap) x 4 rijen (onder, boven, rechts, links)
        "slime": ch.slime_sheet("green"),             # 4 vakjes: rustig (2), boos (2)
        "slime_blue": ch.slime_sheet("blue"),
        "slime_red": ch.slime_sheet("red"),
        "bat": ch.bat_sheet(),                        # 3 vakjes: vleugels omhoog, omlaag, duikvlucht
        "skeleton": ch.skeleton_sheet(),              # 4 kolommen (stil, stap, stap, boog) x 4 rijen
        "golem": ch.golem_sheet(),                    # 32x32: rustig (2), armen omhoog, klap
        "king": ch.king_sheet(),                      # 48x48: rustig (2), ineengedoken, in de lucht
        "items": strip(it.icons()),                   # zie scripts/data/items.gd
        "coin": strip([it.coin(6), it.coin(4), it.coin(2), it.coin(4)]),
        "heart": centered(it.heart(it.HEART_PAL, c("#5a0f1f"))),
        "ui_heart": strip([it.heart(it.HEART_PAL, c("#5a0f1f")), it.heart(it.HEART_EMPTY, c("#1f2233"))]),
        "crystal": strip([it.crystal(False), it.crystal(True)]),
        "chest": strip([it.chest(False), it.chest(True)]),
        "sign": it.sign(),
        "gate": it.gate(),
        "altar": strip([it.altar(0), it.altar(1)]),
        "torch": strip([it.torch(0), it.torch(1)]),
        "projectiles": strip([it.projectile_arrow(), it.projectile_rock(), it.projectile_slimeball()]),
    }
    npcs = {
        "npc_bram": ch.wizard, "npc_greta": ch.greta, "npc_tobias": ch.tobias, "npc_mila": ch.mila,
        "npc_pim": ch.pim, "npc_hein": ch.hein, "npc_anja": ch.anja, "npc_joost": ch.joost,
        "npc_wilfred": ch.wilfred, "npc_muis": ch.cat,
    }
    for name, fn in npcs.items():
        s[name] = ch.npc_sheet(fn)                    # 2 vakjes: rustig en een beetje bewegen
    return s


def main():
    os.makedirs(OUT, exist_ok=True)
    out = sheets()
    for name, img in out.items():
        img.save(os.path.join(OUT, name + ".png"))
        print(f"assets/{name}.png  {img.width}x{img.height}")

    # Voorbeeldplaatje om het resultaat snel te bekijken (niet in het spel gebruikt).
    if os.environ.get("PREVIEW"):
        names = [n for n in out if n != "tiles"]
        scale = 6
        w = max(out[n].width for n in names) * scale
        h = sum(out[n].height * scale + 10 for n in names)
        sheet = Image.new("RGBA", (w, h), (70, 74, 90, 255))
        y = 0
        for n in names:
            big = out[n].resize((out[n].width * scale, out[n].height * scale), Image.NEAREST)
            sheet.paste(big, (0, y), big)
            y += big.height + 10
        sheet.save(os.environ["PREVIEW"])


if __name__ == "__main__":
    main()
