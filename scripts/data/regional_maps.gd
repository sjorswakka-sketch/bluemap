extends RefCounted
## Append-only object identities preserve existing saves.
const EXTRAS := {
	"dorstvallei": [
		{
			"type": "regional_object",
			"kind": "water",
			"name": "Nours waterpunt",
			"pos": [
				14,
				11
			]
		},
		{
			"type": "portal",
			"pos": [
				24,
				3
			],
			"to": "sunwell",
			"spawn": "start",
			"requires": [
				[
					"has",
					"ra_waterskin",
					1
				]
			],
			"locked_text": "Vul eerst Nours waterzak bij de blauwe luifel naast Sana."
		},
		{
			"type": "sign",
			"pos": [
				24,
				5
			],
			"lines": [
				"De Zonnekloof",
				"Neem water mee van Sana. Blauwe luifels geven schaduw en vers water."
			]
		}
	],
	"ridgepass": [
		{
			"type": "regional_object",
			"kind": "camp",
			"name": "Het bergkamp",
			"pos": [
				5,
				14
			]
		},
		{
			"type": "regional_object",
			"kind": "anchor",
			"name": "De oostelijke touwpaal",
			"pos": [
				18,
				7
			]
		},
		{
			"type": "regional_object",
			"kind": "chart",
			"name": "De verloren weerkaart",
			"pos": [
				24,
				16
			]
		}
	],
	"reedvault": [
		{
			"type": "regional_object",
			"kind": "desk",
			"name": "De leestafel",
			"pos": [
				12,
				15
			],
			"talk": "ra_order"
		},
		{
			"type": "regional_object",
			"kind": "folio",
			"name": "Reliëf: de rietvelden",
			"pos": [
				5,
				15
			],
			"id": "ra_folio_reed",
			"clue": "Riet, vissers en een brede oever. Er zijn nog geen huizen of aanlegpalen. Dit is het begin van de nederzetting."
		},
		{
			"type": "regional_object",
			"kind": "folio",
			"name": "Reliëf: de aanlegplaats",
			"pos": [
				5,
				4
			],
			"id": "ra_folio_port",
			"clue": "Huizen staan op de vroegere rietvelden. Lange aanlegpalen steken ver boven het lage water uit. De handel groeit."
		},
		{
			"type": "regional_object",
			"kind": "folio",
			"name": "Reliëf: het hoogwater",
			"pos": [
				23,
				4
			],
			"id": "ra_folio_flood",
			"clue": "Het water staat boven dezelfde aanlegpalen. Bewoners verlaten hun huizen en trekken naar het hoge eiland."
		}
	],
	"kruipmoeras": [
		{
			"type": "regional_object",
			"kind": "exhibit",
			"name": "Mees’ tentoonstelling",
			"pos": [
				41,
				12
			],
			"talk": "ra_exhibit"
		}
	]
}
static func enrich(map_id: String,data: Dictionary) -> void:
	data["objects"].append_array(EXTRAS.get(map_id,[]).duplicate(true))
	if map_id=="reedvault":
		for x in [6,12,19]:
			data["objects"].append({"type":"regional_object","kind":"shelf","name":"Archiefkast","pos":[x,2]})
	if map_id=="sunwell":
		data["objects"].append({"type":"sign","pos":[6,20],"lines":["Terug naar Dorstvallei: de zuidelijke opening bij de eerste waterluifel."]})
	if map_id=="kruipmoeras":
		# A clear reading corner beside Mees, with room to approach the display.
		for y in range(11,15):
			var row: String=data["rows"][y]
			data["rows"][y]=row.substr(0,40)+"UUUU"+row.substr(44)
	if map_id=="dorstvallei":
		data["spawns"]["from_sunwell"]=[24,6]
		# Carve an actual approach through the sandstone; the arch alone is not a door.
		for y in range(2,8):
			var row: String=data["rows"][y]
			data["rows"][y]=row.substr(0,22)+"aaaaa"+row.substr(27)
		for spec: Dictionary in data["objects"]:
			if spec.get("lines",[])==["De Zonnekloof","Neem water mee van Sana. Blauwe luifels geven schaduw en vers water."]: spec["pos"]=[22,6]
	if map_id=="ridgepass":
		# The only crossing is the visible northern saddle; no hidden bottom bypass.
		for y in [17,18]:
			var row: String=data["rows"][y]
			data["rows"][y]=row.substr(0,13)+"PPP"+row.substr(16)
		data["objects"][1]["lines"]=["Terug naar IJsdal: zuidwestelijk lichtpad.","Het bergkamp heeft klimtouw. Steek de pas bovenlangs over wanneer de wimpels slap hangen. Zet de oostelijke touwpaal vast en haal de weerkaart bij de zuidoostelijke schuilhut."]
