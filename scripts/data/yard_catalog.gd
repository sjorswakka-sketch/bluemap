extends RefCounted
const UNITS:={
 "wine_a":{"name":"Westelijk wijnvat","role":"wine","start":[4,25],"desc":"Verplaats het bestaande vat; flessen en rijptijd blijven behouden."},
 "wine_b":{"name":"Oostelijk wijnvat","role":"wine","start":[12,25],"desc":"Een tweede vaste productie-eenheid, vrij te verplaatsen zonder extra batches te maken."},
 "compost":{"name":"Mesthoop","role":"compost","start":[7,15],"desc":"Geef compost een bereikbare plek op je erf. De actieve porties verhuizen mee."},
 "hive":{"name":"Bijenkast","role":"hive","start":[15,32],"desc":"Bijen hebben drie bloeiende planten binnen vijf tegels nodig. Opbergen pauzeert honing, zonder verlies."}
}
const PIECES:={
 "gravel":{"name":"Grindpad","group":"gravel","path":true,"frame":0,"desc":"Een smal, aansluitend pad met passende voetstappen en de bestaande padsnelheid."},
 "stone":{"name":"Stapstenenpad","group":"stone","path":true,"frame":1,"desc":"Rustige, aansluitende stenen. Houd kanalen en gewassen vrij."},
 "boards":{"name":"Houten tuinpad","group":"boards","path":true,"frame":2,"desc":"Een laag houten pad met houten voetstappen; geen brug over water."},
 "fence_h":{"name":"Hek · liggend","group":"fence","frame":0,"desc":"Een lage houten erfgrens. Laat een poortje of ruime opening over."},
 "fence_v":{"name":"Hek · staand","group":"fence","frame":1,"desc":"Een hek langs de zijkant van je tuin; bestaande routes blijven vrij."},
 "gate_h":{"name":"Poortje · liggend","group":"gate","frame":2,"gate":true,"desc":"Opent vanzelf van beide kanten en sluit pas als je er voorbij bent."},
 "gate_v":{"name":"Poortje · staand","group":"gate","frame":3,"gate":true,"desc":"Een automatisch poortje voor een grens die van noord naar zuid loopt."}
}
const SUPPLIES:={
 "gravel":{"amount":8,"cap":120,"cost":{"prof_stone":2}},
 "stone":{"amount":8,"cap":120,"cost":{"prof_stone":3}},
 "boards":{"amount":8,"cap":120,"cost":{"prof_log":2}},
 "fence":{"amount":4,"cap":48,"cost":{"prof_log":2,"prof_branch":2}},
 "gate":{"amount":1,"cap":8,"cost":{"prof_log":2,"prof_branch":2}}
}
const OWNED:={"gravel":24,"stone":0,"boards":0,"fence":12,"gate":2}
const BASE_PLOTS:=[Rect2i(3,24,15,5),Rect2i(4,14,10,4),Rect2i(13,30,5,6)]
const EXTENSIONS:={
 "west":{"name":"Westweide","rect":Rect2i(4,29,14,12),"cost":{"prof_log":6,"prof_stone":6},"desc":"Extra bouwruimte in de open weide. Bestaande landbouw blijft ook zonder uitbreiding beschikbaar."},
 "east":{"name":"Oeverweide","rect":Rect2i(24,29,11,12),"cost":{"prof_log":8,"prof_stone":8},"desc":"Verspreid je erf over de rustige overkant; beide beekbruggen blijven open."}
}
const WILD_FLOWERS:=[Vector2i(14,34),Vector2i(16,34),Vector2i(14,35)]
const VIEWS:=[Rect2i(3,23,33,19),Rect2i(3,14,15,15)]
const VIEW_NAMES:=["Voorerf en tuin","Achter het huis"]
