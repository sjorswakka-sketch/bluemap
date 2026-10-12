"""Unieke outfits voor de polish-NPC's en een duidelijkere herbergier."""
from artlib import *  # noqa: F401,F403
import art_chars as ch

SKIN, SKIN_D = c("#f6cfa6"), c("#dba57c")
OUTLINE = c("#1a1220")

def _head(img, dy=0):
    rect(img, 5, 5 + dy, 10, 7 + dy, SKIN)
    rect(img, 5, 7 + dy, 10, 7 + dy, SKIN_D)
    put(img, 6, 6 + dy, OUTLINE)
    put(img, 9, 6 + dy, OUTLINE)


def _legs(img, color, dark):
    """Twee benen met schoenen, in de kleuren van het personage."""
    rect(img, 5, 12, 7, 14, color)
    rect(img, 8, 12, 10, 14, color)
    rect(img, 8, 12, 8, 14, dark)
    rect(img, 5, 15, 7, 15, dark)
    rect(img, 8, 15, 10, 15, dark)

def lotte(frame):
    """Lantaarnmaker: leren schort, gereedschapsriem, lantaarn in de hand."""
    hy = 1 if frame else 0
    img = blank()
    hair = c("#c47a3a")
    rect(img, 4, 2 + hy, 11, 4 + hy, hair)
    rect(img, 4, 5 + hy, 4, 8 + hy, hair)
    rect(img, 11, 5 + hy, 11, 8 + hy, hair)
    _head(img, hy)
    # werkschort
    rect(img, 4, 8, 11, 12, c("#8b5a2b"))
    rect(img, 11, 8, 11, 12, c("#6a421c"))
    rect(img, 5, 9, 10, 11, c("#a06c3a"))
    # gereedschapsriem
    rect(img, 4, 11, 11, 11, c("#4a3020"))
    put(img, 6, 11, c("#d0d0d0"))
    put(img, 9, 11, c("#d0d0d0"))
    # lantaarn
    rect(img, 12, 9, 14, 12, c("#6a4220"))
    rect(img, 13, 8, 13, 8, c("#ffd83a"))
    put(img, 13, 10, c("#ffee88"))
    _legs(img, c("#3a3028"), c("#2a2018"))
    return outline(img)

def kasper(frame):
    """Handelaar: kleurrijke mantel, tas, hoed met veer."""
    hy = 1 if frame else 0
    img = blank()
    # hoed
    rect(img, 5, 1 + hy, 10, 3 + hy, c("#4a2a6a"))
    rect(img, 3, 4 + hy, 12, 4 + hy, c("#6a3a8a"))
    put(img, 11, 1 + hy, c("#e8334a"))  # veer
    _head(img, hy)
    # mantel
    rect(img, 3, 8, 12, 13, c("#5a3a8a"))
    rect(img, 11, 8, 12, 13, c("#3a2060"))
    rect(img, 5, 8, 10, 8, c("#ffd83a"))
    # tas
    rect(img, 12, 9, 14, 12, c("#8a5a2c"))
    put(img, 13, 10, c("#ffd83a"))
    _legs(img, c("#3a2a50"), c("#2a1a30"))
    return outline(img)

def elke(frame):
    """Kruidenier: groene schort, kruidenmandje, bloem in het haar."""
    hy = 1 if frame else 0
    img = blank()
    hair = c("#5a8a3a")
    rect(img, 4, 2 + hy, 11, 4 + hy, hair)
    rect(img, 4, 5 + hy, 4, 8 + hy, hair)
    rect(img, 11, 5 + hy, 11, 8 + hy, hair)
    put(img, 10, 2 + hy, c("#ff6a8a"))  # bloem
    _head(img, hy)
    # schort
    rect(img, 4, 8, 11, 13, c("#4a7a3a"))
    rect(img, 5, 9, 10, 12, c("#6a9a5a"))
    # mandje
    rect(img, 12, 10, 14, 12, c("#8a5a2c"))
    put(img, 13, 9, c("#5fd36b"))
    put(img, 12, 9, c("#3a9e4c"))
    _legs(img, c("#3a3028"), c("#2a2018"))
    return outline(img)

def willem(frame):
    """Verhalenverteller: lange mantel, boek, grijze baard."""
    hy = 1 if frame else 0
    img = blank()
    # mantel + baard
    rect(img, 4, 2 + hy, 11, 5 + hy, c("#d0d0d8"))
    rect(img, 5, 6 + hy, 10, 8 + hy, c("#b0b0c0"))
    _head(img, hy)
    rect(img, 4, 8, 11, 14, c("#4a3a6a"))
    rect(img, 11, 8, 11, 14, c("#2a2040"))
    # boek
    rect(img, 12, 9, 14, 11, c("#8a3a2a"))
    put(img, 13, 10, c("#ffd83a"))
    return outline(img)

def mira(frame):
    """Dauwbewaarder: lichte mantel, dauwdruppels, zilveren accenten."""
    hy = 1 if frame else 0
    img = blank()
    hair = c("#a0c0e0")
    rect(img, 4, 2 + hy, 11, 4 + hy, hair)
    rect(img, 4, 5 + hy, 4, 8 + hy, hair)
    rect(img, 11, 5 + hy, 11, 8 + hy, hair)
    _head(img, hy)
    # mantel
    rect(img, 4, 8, 11, 14, c("#c0d8f0"))
    rect(img, 11, 8, 11, 14, c("#90b0d0"))
    # dauwdruppels
    put(img, 6, 10, c("#ffffff"))
    put(img, 9, 12, c("#e0f0ff"))
    put(img, 7, 13, c("#ffffff"))
    return outline(img)

def tomas(frame):
    """Oude man: grijze baard, eenvoudige tuniek, stok."""
    hy = 1 if frame else 0
    img = blank()
    rect(img, 5, 2 + hy, 10, 5 + hy, c("#d0d0d8"))
    _head(img, hy)
    rect(img, 4, 8, 11, 12, c("#6a5a4a"))
    rect(img, 11, 8, 11, 12, c("#4a3a2a"))
    # stok
    rect(img, 13, 8, 13, 14, c("#8a5a2c"))
    _legs(img, c("#4a3a30"), c("#2a2018"))
    return outline(img)

def noor(frame):
    """Verzamelaar: zak, hoed, bruine kleding."""
    hy = 1 if frame else 0
    img = blank()
    rect(img, 5, 1 + hy, 10, 3 + hy, c("#6a4220"))
    rect(img, 3, 4 + hy, 12, 4 + hy, c("#8a5a2c"))
    _head(img, hy)
    rect(img, 4, 8, 11, 12, c("#8a6a4a"))
    rect(img, 11, 8, 11, 12, c("#6a4a2a"))
    # zak
    rect(img, 12, 9, 14, 12, c("#5a3a20"))
    put(img, 13, 10, c("#ffd83a"))
    _legs(img, c("#4a3a30"), c("#2a2018"))
    return outline(img)

def mila_improved(frame):
    """Herbergierster met duidelijke schort, dienblad en rode strik."""
    hy = 1 if frame else 0
    img = blank()
    hair = c("#f2d36a")
    rect(img, 4, 2 + hy, 11, 4 + hy, hair)
    rect(img, 4, 5 + hy, 4, 9 + hy, hair)
    rect(img, 11, 5 + hy, 11, 9 + hy, hair)
    # rode strik
    rect(img, 4, 2 + hy, 11, 3 + hy, c("#e8334a"))
    put(img, 7, 2 + hy, c("#ffffff"))
    put(img, 8, 2 + hy, c("#ffffff"))
    _head(img, hy)
    # witte blouse + schort
    rect(img, 4, 8, 11, 11, c("#f4f4f8"))
    rect(img, 5, 9, 10, 13, c("#e8e8f0"))  # schort
    rect(img, 5, 11, 10, 11, c("#c8c8d8"))
    # dienblad
    rect(img, 12, 9, 14, 10, c("#8a5a2c"))
    put(img, 13, 8, c("#ffd83a"))  # glas
    _legs(img, c("#3a3028"), c("#2a2018"))
    return outline(img)

def sheets():
    return {
        "npc_lotte": ch.npc_sheet(lotte),
        "npc_kasper": ch.npc_sheet(kasper),
        "npc_elke": ch.npc_sheet(elke),
        "npc_willem": ch.npc_sheet(willem),
        "npc_mira": ch.npc_sheet(mira),
        "npc_tomas": ch.npc_sheet(tomas),
        "npc_noor": ch.npc_sheet(noor),
        "npc_mila": ch.npc_sheet(mila_improved),  # overschrijft de oude
    }
