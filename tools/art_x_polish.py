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

def fenna(frame):
    """IJsdalse kruidenvrouwe: bontgevoerde mantel, muts, kruidenbundel."""
    hy = 1 if frame else 0
    img = blank()
    # muts met pompon
    rect(img, 4, 1 + hy, 11, 3 + hy, c("#3a5a8a"))
    put(img, 7, 0 + hy, c("#f0f0f8"))
    put(img, 8, 0 + hy, c("#f0f0f8"))
    rect(img, 4, 4 + hy, 4, 6 + hy, c("#c47a3a"))  # haar onder de muts
    rect(img, 11, 4 + hy, 11, 6 + hy, c("#c47a3a"))
    _head(img, hy)
    # mantel met bontkraag
    rect(img, 3, 8, 12, 14, c("#3a5a8a"))
    rect(img, 12, 8, 12, 14, c("#2a4060"))
    rect(img, 4, 8, 11, 8, c("#e8e0d0"))  # bontkraag
    # kruidenbundel
    rect(img, 12, 10, 14, 12, c("#5fd36b"))
    put(img, 13, 9, c("#3a9e4c"))
    _legs(img, c("#2a3a50"), c("#1a2030"))
    return outline(img)

def roos(frame):
    """Jageres van het IJsdal: bontjas, pijlkoker op de rug, laarzen."""
    hy = 1 if frame else 0
    img = blank()
    hair = c("#8a3a2a")
    rect(img, 4, 2 + hy, 11, 4 + hy, hair)
    rect(img, 11, 5 + hy, 12, 9 + hy, hair)  # vlecht
    _head(img, hy)
    # jas met bontzoom
    rect(img, 4, 8, 11, 13, c("#6a4a2a"))
    rect(img, 11, 8, 11, 13, c("#4a2a1a"))
    rect(img, 4, 12, 11, 12, c("#e8e0d0"))  # bontzoom
    rect(img, 4, 10, 11, 10, c("#4a3020"))  # riem
    # pijlkoker op de rug
    rect(img, 1, 5, 2, 11, c("#8a5a2c"))
    put(img, 1, 4, c("#d0d0d0"))
    put(img, 2, 4, c("#d0d0d0"))
    _legs(img, c("#3a3028"), c("#2a2018"))
    return outline(img)

def olav(frame):
    """Kaartenbewaarder: dikke donsjas, wollen sjaal, kaartrol in de hand."""
    hy = 1 if frame else 0
    img = blank()
    # grijze haren + baard
    rect(img, 5, 2 + hy, 10, 4 + hy, c("#c0c0d0"))
    rect(img, 5, 6 + hy, 10, 8 + hy, c("#a8a8b8"))
    _head(img, hy)
    # donsjas
    rect(img, 3, 8, 12, 14, c("#4a6a5a"))
    rect(img, 12, 8, 12, 14, c("#2a4038"))
    rect(img, 4, 9, 11, 9, c("#e8334a"))  # sjaal
    # kaartrol
    rect(img, 13, 8, 14, 12, c("#e8d8a0"))
    put(img, 13, 8, c("#8a5a2c"))
    put(img, 14, 12, c("#8a5a2c"))
    return outline(img)

def jelle(frame):
    """Vellenhandelaar: zandkleurige jas, vellen over de schouder, brede hoed."""
    hy = 1 if frame else 0
    img = blank()
    # brede zonnehoed
    rect(img, 3, 2 + hy, 12, 2 + hy, c("#c8a060"))
    rect(img, 5, 1 + hy, 10, 3 + hy, c("#b08040"))
    _head(img, hy)
    # jas
    rect(img, 4, 8, 11, 13, c("#a08050"))
    rect(img, 11, 8, 11, 13, c("#705830"))
    rect(img, 4, 10, 11, 10, c("#5a4020"))  # riem
    # vellen over de schouder
    rect(img, 1, 6, 3, 12, c("#c87840"))
    put(img, 2, 7, c("#a05828"))
    put(img, 2, 10, c("#a05828"))
    _legs(img, c("#5a4a30"), c("#3a3020"))
    return outline(img)

def sana(frame):
    """Vrouw van de oase: sluier in oasekleuren, waterkruik, gouden band."""
    hy = 1 if frame else 0
    img = blank()
    # sluier
    rect(img, 4, 1 + hy, 11, 4 + hy, c("#3a9e8c"))
    rect(img, 4, 5 + hy, 4, 9 + hy, c("#3a9e8c"))
    rect(img, 11, 5 + hy, 11, 9 + hy, c("#3a9e8c"))
    rect(img, 4, 3 + hy, 11, 3 + hy, c("#ffd83a"))  # gouden band
    _head(img, hy)
    # gewaad
    rect(img, 4, 8, 11, 14, c("#48b8a8"))
    rect(img, 11, 8, 11, 14, c("#2a7a6a"))
    rect(img, 4, 11, 11, 11, c("#ffd83a"))  # gouden zoom
    # waterkruik
    rect(img, 12, 9, 14, 12, c("#8a5a2c"))
    put(img, 13, 8, c("#6a4220"))
    put(img, 13, 10, c("#5ac8e8"))
    return outline(img)

def nour(frame):
    """Woestijngids: tulband, lange gewaad, wandelstaf met kraal."""
    hy = 1 if frame else 0
    img = blank()
    # tulband
    rect(img, 4, 1 + hy, 11, 4 + hy, c("#e8e0d0"))
    put(img, 10, 1 + hy, c("#e8334a"))  # juweel
    rect(img, 4, 4 + hy, 4, 5 + hy, c("#e8e0d0"))
    _head(img, hy)
    # gewaad
    rect(img, 3, 8, 12, 14, c("#c86a3a"))
    rect(img, 12, 8, 12, 14, c("#8a4a2a"))
    rect(img, 4, 10, 11, 10, c("#ffd83a"))  # sjerp
    # staf
    rect(img, 14, 4, 14, 15, c("#8a5a2c"))
    put(img, 14, 3, c("#5ac8e8"))
    return outline(img)

def vera(frame):
    """Kleermaakster: speldenkussen op de pols, meetlint om de nek, schort."""
    hy = 1 if frame else 0
    img = blank()
    hair = c("#4a3a5a")
    rect(img, 4, 2 + hy, 11, 4 + hy, hair)
    rect(img, 4, 5 + hy, 4, 8 + hy, hair)
    rect(img, 11, 5 + hy, 11, 8 + hy, hair)
    put(img, 7, 1 + hy, hair)  # opgestoken knot
    put(img, 8, 1 + hy, hair)
    _head(img, hy)
    # schort over jurk
    rect(img, 4, 8, 11, 14, c("#7a4a8a"))
    rect(img, 5, 9, 10, 13, c("#9a6aaa"))
    rect(img, 11, 8, 11, 14, c("#4a2a5a"))
    # meetlint om de nek
    put(img, 5, 8, c("#ffd83a"))
    put(img, 10, 8, c("#ffd83a"))
    put(img, 6, 9, c("#ffd83a"))
    # speldenkussen
    rect(img, 12, 10, 14, 11, c("#e8334a"))
    put(img, 13, 9, c("#d0d0d0"))
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
        "npc_fenna": ch.npc_sheet(fenna),
        "npc_roos": ch.npc_sheet(roos),
        "npc_olav": ch.npc_sheet(olav),
        "npc_jelle": ch.npc_sheet(jelle),
        "npc_sana": ch.npc_sheet(sana),
        "npc_nour": ch.npc_sheet(nour),
        "npc_vera": ch.npc_sheet(vera),
        "npc_mila": ch.npc_sheet(mila_improved),  # overschrijft de oude
    }
