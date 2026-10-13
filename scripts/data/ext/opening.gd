extends RefCounted
## Een vrijwillige eerste opdracht; oude opslagen houden hun herstelde dorp.
const QUESTS := {
	"first_water": {"title":"Water voor het plein", "steps":[
		{"text":"Help Nelle bij het rooster ten westen van de fontein. Gebruik haar hark om het riet los te maken.", "advance_if":[["flag","op_grate"]]},
		{"text":"Het rooster is vrij. Draai het sluisrad iets zuidelijker open en volg het water naar de fontein.", "advance_if":[["flag","op_water"]]},
		{"text":"Er zit een prismateken onder het riet. Laat Greta in de smederij aan de westkant van het plein weten wat je vond."}
	], "effect":"De fontein stroomt, Nelle verzorgt de bloembakken en Greta herkent het oude prismateken."}
}
const ITEMS := {
	"op_rake":{"name":"Nelles tuinhark", "sheet":"op_rake", "icon":0, "type":"quest", "max":1,
		"desc":"Geleend van Nelle. Gebruik bij het verstopte rooster naast de dorpsfontein; daarna krijgt ze hem terug."}
}
const SOUNDS := ["op_hammer", "op_rake", "op_water", "op_drip"]
