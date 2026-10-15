extends RefCounted
const MAPS:={"coast_workshop":preload("res://scripts/maps/coast_workshop.gd")}
const OBJECTS:={"cw_station":"res://scripts/entities/coastal_workstation.gd"}
const MAP_MARKERS:={"cw_station":{"color":Color("d8bd89"),"label":"Kustwerkplaats of lijnpaal"}}
const SOUNDS:=["cw_thread","cw_stow","cw_guard","cw_fan"]
const ITEMS:={
 "cw_driftwood":{"name":"Zoutdrijfhout","type":"material","sheet":"cw_items","icon":0,"desc":"Droog hout van een rustige zijplek aan de Blauwe Kust. Voor Rafs herbruikbare oeverlijn en meubels."},
 "cw_reed":{"name":"Oevervezel","type":"material","sheet":"cw_items","icon":1,"desc":"Soepele vezels uit één rietplek bij Zilvermonding. Voor een herbruikbare lijn en waaierbanden."},
 "cw_seaglass":{"name":"Zeeagaat","type":"material","sheet":"cw_items","icon":2,"desc":"Win in de veilige zuidelijke gang van de Tijholte met een stenen of koperen pikhouweel. Voor kustuitrusting en een werkplaatslamp."},
 "cw_saltleaf":{"name":"Zoutblad","type":"material","sheet":"cw_items","icon":3,"desc":"Een kruid van de open graslanden van Lichtkaap. Met een baars van Joris maak je er kustbouillon van."},
 "cw_hook":{"name":"Herbruikbare oeverlijn","type":"gear","max":1,"sheet":"cw_items","icon":4,"desc":"Rafs haak en lijn. Verbindt de twee lijnpalen aan Zilvermonding. Niet verbruikt; de hoge rivierbrug blijft altijd open."},
 "cw_shelf":{"name":"Drijfhouten wandrek","type":"key","max":1,"sheet":"cw_items","icon":7,"desc":"Plaats of berg het gratis op via de inrichttafel in de havenwerkplaats. Heeft een vaste plek tegen de wand; geen onderhoud."},
 "cw_lamp":{"name":"Zeeagaatlamp","type":"key","max":1,"sheet":"cw_items","icon":8,"desc":"Lena's lamp voor de vaste sokkel in de havenwerkplaats. Kies warm licht, zeelicht of uit. Plaatsen verbruikt hem niet."},
 "cw_broth":{"name":"Kustbouillon","type":"use","heal":2,"stamina":20,"sheet":"cw_items","icon":9,"desc":"Baars van het Zilvermeer met zoutblad van Lichtkaap. Herstelt 2 hartjes en 20 stamina. Gebruik via Beroepen → Eten & drinken."}
}
