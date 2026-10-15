extends RefCounted
const MAPS:={"player_home":preload("res://scripts/maps/player_home.gd")}
const OBJECTS:={"home_station":"res://scripts/entities/home_station.gd"}
const MAP_MARKERS:={"home_station":{"color":Color("d9bc86"),"label":"Woning en productie"}}
const SOUNDS:=["hs_soil"]
const ITEMS:={
 "hs_hoe":{"name":"Tuinhak","type":"gear","max":1,"sheet":"items_home","icon":0,"desc":"Eén gereedschap voor grond en smalle kanalen. Open de tuinstanden met U of via Beroepen → Tuinstanden; de ingestelde binding staat in Bediening."},
 "hs_manure":{"name":"Dierenpoep","type":"material","sheet":"items_home","icon":1,"desc":"Wilde dieren laten dit ook levend achter. Verwerk het op de mesthoop achter je huis tot meststof."},
 "hs_fertilizer":{"name":"Meststof","type":"material","sheet":"items_home","icon":2,"desc":"Eén per druivenplant: de volgende oogst geeft vijf in plaats van drie druiven. Geen verplichte onderhoudsronde."},
 "hs_seed":{"name":"Druivenpitten","type":"material","sheet":"items_home","icon":3,"desc":"Plant op bewerkte, bewaterde grond. Een druivenstok blijft na de oogst staan. Maak meer pitten van bosdruiven via Beroepen."},
 "hs_flower_seed":{"name":"Bloemenzaad","type":"material","sheet":"items_home","icon":4,"desc":"Plant in je tuin. Drie bloeiende planten binnen vijf tegels houden de bijenkast aan het werk."},
 "hs_grape":{"name":"Druiven","type":"use","heal":1,"sheet":"items_home","icon":5,"desc":"Bosdruiven of je eigen oogst. Herstellen één hartje; ook bruikbaar voor wijn of nieuwe pitten."},
 "hs_wine":{"name":"Druivenwijn","type":"use","stamina":40,"sheet":"items_home","icon":6,"desc":"Drie druiven rijpen in een wijnvat tot één fles. Gebruik via Eten & drinken voor 40 stamina."},
 "hs_honey":{"name":"Bloemenhoning","type":"use","heal":1,"stamina":25,"sheet":"items_home","icon":7,"desc":"Bijen maken honing zolang er minstens drie bloemen in de buurt bloeien. Herstelt één hartje en 25 stamina."}
}
