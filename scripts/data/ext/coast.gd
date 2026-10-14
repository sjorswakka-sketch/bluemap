extends RefCounted
const MAPS := {"coast":preload("res://scripts/maps/coast.gd"),"gull_island":preload("res://scripts/maps/gull_island.gd")}
const OBJECTS := {"coast_dock":"res://scripts/entities/coast_dock.gd","coast_note":"res://scripts/entities/coast_note.gd"}
const MAP_MARKERS := {"coast_dock":{"color":Color("9cdee0"),"label":"Veersteiger"}}
const ARROW_OVER := ["ce_sea","ce_shore"]
const ACTIONS := ["ce_sail"]
const SOUNDS := ["ce_rope","ce_water"]
const TRACKS := ["coast"]
const TALKS := {
	"ce_sail_island":{"speaker":"Veerboot","lines":["De riviermonding komt hier uit op de Blauwe Kust. De kleine veerboot ligt klaar voor Meeuweneiland.","De overtocht is gratis. Op het eiland ligt dezelfde boot klaar voor de terugvaart."],"choices":[{"text":"Vaar naar Meeuweneiland.","do":[["ce_sail"]]},{"text":"Blijf op de kust."}]},
	"ce_sail_coast":{"speaker":"Veerboot","lines":["De veerboot brengt je terug naar de Blauwe Kust. Vanaf daar volg je het westelijke pad naar het Zilvermeer.","De overtocht is gratis; je spullen en gezondheid blijven zoals ze zijn."],"choices":[{"text":"Vaar terug naar de kust.","do":[["ce_sail"]]},{"text":"Blijf op het eiland."}]}
}
static func run(_action: Array) -> void:
	for director: Node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("coast_voyage"):
		if not director.is_queued_for_deletion():director.begin.call_deferred()
