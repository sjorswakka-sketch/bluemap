extends RefCounted
## Fase 1: een vangst wordt een maaltijd en een blijvende ontmoetingsplek.
const QUESTS := {
	"ls_supper": {"title":"Een plek aan tafel", "effect":"Een vaste dorpsmaaltijd bij Mila en twee recepten voor onderweg.", "steps":[
		{"text":"Haal Joris' vismand met je hengel uit het water, links naast het begin van de middelste steiger in het Zilvermeer.","advance_if":[["flag","ls_basket"]]},
		{"text":"Ga naar het fornuis rechts in de herberg. Kies een gerecht en bereid Joris' vangst met Mila.","advance_if":[["flag","ls_cooked"]]},
		{"text":"Zet één portie op de grote tafel in de nieuwe eetkamer. De rest mag mee op avontuur."}]}
}
const ITEMS := {
	"ls_crate":{"name":"Joris' maaltijdmand","sheet":"ls_items","icon":0,"type":"quest","max":1,"desc":"Verse vangst en groente voor Mila. Bereid twee porties bij het fornuis in de herberg."},
	"ls_chowder":{"name":"Zilvermeerstoof","sheet":"ls_items","icon":1,"type":"use","heal":3,"stamina":20,"desc":"Stevige visstoof: herstelt 3 hartjes en 20 uithoudingsvermogen. Gebruik via Beroepen → Eten & drinken."},
	"ls_broth":{"name":"Oeverbouillon","sheet":"ls_items","icon":2,"type":"use","heal":1,"stamina":60,"desc":"Lichte visbouillon: herstelt 1 hartje en 60 uithoudingsvermogen. Gebruik via Beroepen → Eten & drinken."}
}
const TALKS := {
	"ls_invite":{"branch":[{"if":[["flag","ls_served"]],"next":"ls_after"},{"if":[["flag","ls_basket"]],"next":"ls_ready"},{"next":"ls_start"}]},
	"ls_after":{"speaker":"Mila","lines":["Jouw gerecht staat op de kaart! Kom gerust koken of praat met de gasten aan de dorpstafel. Er is altijd een plek vrij."]},
	"ls_ready":{"speaker":"Mila","lines":["De vangst is gered. Bij het fornuis rechts kies je tussen stevige stoof en lichte bouillon. Kook twee porties en deel er één aan de grote tafel."],"do":[["start_quest","ls_supper"]]},
	"ls_start":{"speaker":"Mila","lines":["Joris brengt vis, Bo brengt brood. Maar aan mijn grote tafel zitten we zelden samen. Help je de eerste maaltijd op tafel zetten?","Zijn mand is losgeraakt bij de middelste steiger. Met een hengel haal je hem vanaf de planken binnen. Joris leent je er een. Mijn fornuis staat rechts in de herberg."],"do":[["start_quest","ls_supper"],["save"]]},
	"ls_net":{"speaker":"Joris' nettenrek","lines":["Volg de gekleurde draad: boven, onder, boven. Steek {ls_stitch} van 3."],"choices":[
		{"text":"Haal de draad bovenlangs.","do":[["ls_weave","over"]],"next":"ls_net_check"},
		{"text":"Haal de draad onderlangs.","do":[["ls_weave","under"]],"next":"ls_net_check"},
		{"text":"Laat het net even liggen."}]},
	"ls_net_check":{"branch":[{"if":[["flag","ls_net"]],"next":"ls_net_done"},{"next":"ls_net"}]},
	"ls_net_done":{"speaker":"Visser Joris","lines":["Dat houdt! Mijn reservevangst is voor jou: twee baarzen en wat zilverkruid. Daarmee kun je later weer bij Mila koken."]},
	"ls_share":{"speaker":"De dorpsmaaltijd","lines":["Bo heeft brood gebracht. Zet één portie neer; Mila maakt er een maaltijd voor de tafel van. Je overige porties blijven in je tas."],"choices":[
		{"text":"Deel Zilvermeerstoof.","if":[["has","ls_chowder",1]],"do":[["ls_share","ls_chowder"]]},
		{"text":"Deel Oeverbouillon.","if":[["has","ls_broth",1]],"do":[["ls_share","ls_broth"]]},
		{"text":"Nog even niet."}]}
}
const OBJECTS := {"supper_object":"res://scripts/entities/supper_object.gd"}
const MAP_MARKERS := {"supper_object":{"color":Color("e5b969"),"label":"Dorpsmaaltijd"}}
const ACTIONS := ["ls_weave","ls_share"]
const FORMATS := ["ls_stitch"]
const SOUNDS := ["ls_reel","ls_chop","ls_simmer","ls_serve"]
static func run(action: Array) -> void:
	load("res://scripts/core/lake_supper.gd").action(action)
static func format(_token: String) -> String:
	return str(load("res://scripts/core/lake_supper.gd").stitch()+1)
