extends RefCounted
## Original interior pieces. Size includes visible overhang, not just a collision dot.
const PIECES:={
 "bed":{"name":"Eigen bed","size":Vector2i(1,2),"frame":0,"cap":1,"base":true,"desc":"Verplaats je bed; rusten en opslaan blijven beschikbaar.","cost":{}},
 "table":{"name":"Eiken tafel","size":Vector2i(2,1),"frame":1,"cap":1,"base":true,"desc":"Een rustige plek voor een boek en een kop thee.","cost":{}},
 "shelf":{"name":"Boekenkast","size":Vector2i(2,2),"frame":2,"cap":1,"base":true,"desc":"Boeken, aardewerk en ruimte voor je verhalen.","cost":{}},
 "chair":{"name":"Houten stoel","size":Vector2i(1,1),"frame":3,"cap":4,"desc":"Een eenvoudige stoel voor bij je tafel.","cost":{"prof_log":2,"prof_branch":2}},
 "plant_leaf":{"name":"Bladplant","size":Vector2i(1,1),"frame":4,"cap":4,"desc":"Een groene kamerplant zonder onderhoud.","cost":{"prof_herb":2,"prof_branch":1}},
 "plant_bloom":{"name":"Bloemenpot","size":Vector2i(1,1),"frame":5,"cap":4,"desc":"Een kleine pot met blijvende bloemen; geen waterbeurt nodig.","cost":{"prof_herb":2,"hs_flower_seed":1}},
 "lamp":{"name":"Staande lamp","size":Vector2i(1,2),"frame":6,"cap":3,"desc":"Een zachte lichtplek; kies warm, zeelicht of uit.","cost":{"prof_log":2,"prof_copper_bar":1}},
 "bench":{"name":"Linnen bankje","size":Vector2i(2,1),"frame":7,"cap":2,"desc":"Een laag bankje met een kussen in je gekozen kleur.","cost":{"prof_log":3,"prof_branch":2}},
 "cabinet":{"name":"Servieskast","size":Vector2i(2,2),"frame":8,"cap":2,"desc":"Een kast met eigen aardewerk; decoratie, je huisvoorraad blijft in de kist.","cost":{"prof_log":4,"prof_copper_bar":1}},
 "rug":{"name":"Geweven kleed","size":Vector2i(4,2),"frame":9,"cap":1,"floor":true,"desc":"Een zacht vloerkleed waar je overheen loopt; meubels mogen erop staan.","cost":{}},
 "trophy_forest":{"name":"Aandenken aan het bos","size":Vector2i(1,1),"frame":10,"cap":1,"item":"crystal_bos","hint":"Vind het kaartkristal van het Fluisterbos.","desc":"Een houten blad met een blauwe glaskern; een herinnering aan je bosavontuur.","cost":{}},
 "trophy_swamp":{"name":"Aandenken aan de sluizen","size":Vector2i(1,1),"frame":11,"cap":1,"flag":"lw_bridge","hint":"Herstel de brug bij het Rietarchief.","desc":"Een klein sluisrad op een sokkel, voor de weer verbonden oevers.","cost":{}},
 "trophy_coast":{"name":"Aandenken aan de kust","size":Vector2i(1,1),"frame":12,"cap":1,"flag":"cw_raf_notes","hint":"Leer Rafs kustpatronen in de haven.","desc":"Een zelfgemaakte schelp met een gevlochten rand, als herinnering aan Raf.","cost":{}}
}
const FLOORS:=["Eiken planken","Lichte visgraat","Koele leisteen","Zachte terracotta"]
const WALLS:=["Hout en linnen","Saliegroene wand","Warme kalkwand","Blauwe steen"]
const COLORS:=["Salie en linnen","Oker en crème","Blauw en heide"]
const LIGHTS:=["Warm licht","Zeelicht","Licht uit"]
const START_OWNED:={"bed":1,"table":1,"shelf":1,"chair":1,"plant_leaf":1,"lamp":1,"rug":1}
const DEFAULT_LAYOUT:={
 "bed":{"kind":"bed","cell":[3,3],"tint":0},
 "table":{"kind":"table","cell":[4,8],"tint":0},
 "shelf":{"kind":"shelf","cell":[8,2],"tint":0},
 "rug:1":{"kind":"rug","cell":[4,6],"tint":0}
}
