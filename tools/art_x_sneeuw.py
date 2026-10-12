"""Uitbreiding "sneeuw" (IJsdal): nieuwe tegels voor het sneeuwklimaat.

art_tiles.py laadt dit bestand vanzelf (tile_painters()). De kleuren sluiten aan bij de paletten
van de rest van het spel, maar dan bevroren: helderwit, ijsblauw en donker dennengroen.
"""
import random

from artlib import *  # noqa: F401,F403

# --- paletten ----------------------------------------------------------------------------------------------

SNOW, SNOW_D, SNOW_L = c("#e4edf7"), c("#c3d4e8"), c("#fbfdff")
PINE, PINE_D, PINE_L = c("#2a5f4a"), c("#173f30"), c("#4a8a66")
TRUNK, TRUNK_D = c("#5a3d28"), c("#3a2416")
ICE, ICE_D, ICE_L = c("#a9d6ec"), c("#6ba6cc"), c("#e2f4fc")
BUSH, BUSH_D = c("#3d6b52"), c("#24493a")


# --- tegels (16x16) ----------------------------------------------------------------------------------------

def tile_painters(ti):
    """Geeft {tegelnaam: tekenfunctie} voor de nieuwe tegels. `ti` is de module art_tiles."""

    def snow():
        img = blank()
        fill(img, SNOW)
        rnd = random.Random(71)
        for _ in range(14):
            put(img, rnd.randrange(16), rnd.randrange(16), rnd.choice([SNOW_D, SNOW_L]))
        # glinsterende kristalletjes in de sneeuw
        for x, y in [(3, 5), (11, 3), (7, 12), (13, 10)]:
            put(img, x, y, SNOW_L)
        return img

    def snow_tufts():
        img = snow()
        # grassprieten die door de sneeuw pieken
        rnd = random.Random(72)
        for _ in range(4):
            x, y = rnd.randrange(2, 14), rnd.randrange(4, 14)
            put(img, x, y, c("#7d9a6a"))
            put(img, x, y - 1, c("#93b07c"))
            put(img, x + 1, y, SNOW_D)
        return img

    def pine():
        img = snow()
        rect(img, 7, 12, 8, 15, TRUNK)
        rect(img, 8, 12, 8, 15, TRUNK_D)
        # drie laagjes den, van breed naar smal
        polygon(img, [(8, 1), (13, 7), (3, 7)], PINE)
        polygon(img, [(8, 4), (14, 11), (2, 11)], PINE)
        polygon(img, [(8, 8), (15, 14), (1, 14)], PINE_D)
        # sneeuw op de takken
        for x, y in [(8, 1), (7, 2), (9, 2), (5, 6), (11, 6), (4, 10), (12, 10), (8, 4), (8, 8), (3, 13), (13, 13)]:
            put(img, x, y, SNOW_L)
        return img

    def snow_bush():
        img = snow()
        ellipse(img, (1, 5, 14, 14), BUSH, BUSH_D)
        # een dikke sneeuwpet
        ellipse(img, (2, 3, 13, 9), SNOW_L, SNOW_D)
        for x, y in [(5, 10), (9, 11), (7, 12)]:
            put(img, x, y, c("#b8d0dc"))
        for x, y in [(4, 9), (11, 10)]:
            put(img, x, y, c("#c85a6e"))  # winterbes die door de sneeuw piekt
        return img

    def ice():
        img = blank()
        fill(img, ICE)
        rnd = random.Random(73)
        for _ in range(10):
            put(img, rnd.randrange(16), rnd.randrange(16), rnd.choice([ICE_L, ICE_D]))
        # barsten in het ijs
        line(img, (2, 12), (7, 7), ICE_D)
        line(img, (7, 7), (12, 8), ICE_D)
        line(img, (10, 3), (13, 6), ICE_D)
        for x, y in [(4, 4), (12, 12), (8, 9)]:
            put(img, x, y, ICE_L)
        return img

    return {
        "snow": snow, "snow_tufts": snow_tufts, "snow_bush": snow_bush, "pine": pine, "ice": ice,
    }


def sheets():
    """Geen eigen sheets: deze uitbreiding levert alleen tegels (via tile_painters)."""
    return {}


if __name__ == "__main__":
    from pathlib import Path
    for name, painter in tile_painters(None).items():
        painter().save(Path(__file__).resolve().parent.parent / "assets" / ("tile_%s.png" % name))
