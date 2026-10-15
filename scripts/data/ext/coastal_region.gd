extends RefCounted
const MAPS:={"river_mouth":preload("res://scripts/maps/river_mouth.gd"),"harbor":preload("res://scripts/maps/harbor.gd"),"headland":preload("res://scripts/maps/headland.gd")}
const OBJECTS:={"region_landmark":"res://scripts/entities/region_landmark.gd","region_chart":"res://scripts/entities/region_chart.gd","region_view":"res://scripts/entities/region_view.gd"}
const MAP_MARKERS:={"region_landmark":{"color":Color("f0d79d"),"label":"Kustwerkplek of vuurtoren"},"region_chart":{"color":Color("9de0d0"),"label":"Regiokaart"}}
const SOUNDS:=["rg_bell"]
const ACTIONS:=["rg_routes","rg_atlas"]
const NPCS:={
	"rg_ise":{"name":"Ise de veervrouw","sheet":"npc_rg_ise","rules":[{"talk":"rg_ise"}]},
	"rg_raf":{"name":"Raf de nettenmaker","sheet":"npc_rg_raf","rules":[{"talk":"rg_raf"}]}
}
const TALKS:={
	"rg_ise":{"speaker":"Ise de veervrouw","lines":["Ik houd de overtochten kort. De veer vaart naar de Blauwe Kust, Meeuweneiland en de Getijdenbaai, ook bij hoogwater.","Liever wandelen? Achter de kade loopt een vrij hoog pad naar Lichtkaap. Over de westelijke rivierbrug kom je terug aan de Blauwe Kust."],"choices":[{"text":"Bekijk de veerbestemmingen.","do":[["rg_routes"]]},{"text":"Ik loop zelf verder."}]},
	"rg_raf":{"speaker":"Raf de nettenmaker","lines":["Ik knoop mijn netten hier, uit de loop. De weidse riviermonding ligt achter de westelijke brug; de vuurtoren staat op de oostelijke kaap.","Ik teken de paden en veerroutes op dezelfde kaart. De hoge loopbruggen blijven bij hoogwater vrij, zodat iedereen weer naar huis kan."],"choices":[{"text":"Laat de regiokaart zien.","do":[["rg_atlas"]]},{"text":"Ik kijk rustig rond."}]}
}
static func run(action: Array):load("res://scripts/core/coastal_region.gd").choose(str(action[0]))
