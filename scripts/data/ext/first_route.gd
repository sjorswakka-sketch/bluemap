extends RefCounted
## De eerste reis: observeren, herinneringen reconstrueren en stil luisteren.
const QUESTS := {
	"rf_memory": {"title":"De naam op de stenen", "effect":"Een verlichte herdenkingsplek in de Ruïne; jouw inscriptie blijft staan.", "steps":[
		{"text":"Onderzoek het beschadigde reliëf in de westelijke zaal en het wachtersboek in de zuidoostelijke kamer van de Ruïne.","advance_if":[["flag","rf_relief"],["flag","rf_journal"]]},
		{"text":"De bewaker hield de doorgang open voor vluchtelingen. Breng zijn medaillon uit de Echo-grot terug naar Wilfred.","advance_if":[["quest","medaillon","done"]]},
		{"text":"Kies bij de gedenksteen naast Wilfred hoe zijn verhaal herinnerd wordt."}]},
	"rf_echo": {"title":"Wat de stilte vertelt", "effect":"Blijvende lichtbakens wijzen naar de oude schuilplaats met het medaillon.", "steps":[
		{"text":"Luister bij de klankschaal aan de ingang van de Echo-grot.","advance_if":[["flag","rf_echo_begin"]]},
		{"text":"Volg de blauwe tekens naar de schaal in de middelste kamer. Lopen is stil; rennen, rollen en aanvallen wekken de luisteraars.","advance_if":[["flag","rf_echo_mid"]]},
		{"text":"Volg de westelijke echo naar de laatste schaal. Luister rustig: de oude schuilplaats ligt achter de bocht."}]}
}
const TALKS := {
	"rf_inscription": {"speaker":"Wilfreds gedenksteen", "lines":["Het wachtersboek en het reliëf vertellen hetzelfde: Wilfred bleef bij de poort zodat anderen de grot konden bereiken. Wat schrijf je op de steen?"], "choices":[
		{"text":"De bewaker die bleef.","do":[["rf_choose","guard"]]},
		{"text":"De gids die anderen liet ontsnappen.","do":[["rf_choose","guide"]]},
		{"text":"Ik wil er nog over nadenken."}]}
}
const ACTIONS := ["rf_choose"]
const OBJECTS := {"route_object":"res://scripts/entities/route_object.gd"}
const MAP_MARKERS := {"route_object":{"color":Color(0.65,0.85,0.8),"label":"Herinnering"}}
static func run(action: Array) -> void:
	load("res://scripts/core/first_route.gd").choose(str(action[1]))
const SOUNDS := ["rf_bird", "rf_rustle", "rf_purr", "rf_low", "rf_mid", "rf_high"]
const ENEMIES := {
	"rf_bramble": {"name":"Struiksluiper","hp":4,"damage":1,"behavior":"rf_ambush","speed":0.0,"sight":115.0,"sheet":"rf_bramble","cell":16,"scale":2.0,"radius":7.0,"shadow":10.0,"drops":[["coin",1.0,2],["gel",0.4,1]],"desc":"Ritselende bladeren verraden zijn sprong. Stap opzij tijdens de aanloop en raak hem wanneer hij uitrust."},
	"rf_listener": {"name":"Steenluisteraar","hp":5,"damage":1,"behavior":"rf_listen","speed":0.0,"sight":170.0,"sheet":"rf_listener","cell":16,"scale":2.0,"radius":8.0,"shadow":11.0,"drops":[["coin",1.0,3],["prof_stone",0.3,1]],"desc":"Slaapt op trillingen. Hij springt naar de plek van een hard geluid, niet naar waar je daarna heen loopt. Rustig passeren kan ook."}
}
