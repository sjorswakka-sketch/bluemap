extends RefCounted
## Grote polish-uitbreiding: Dauwbos, langere quests, meer NPC's.
## Unieke outfits via art_x_polish.py.

const MAPS := {
	"dauwbos": preload("res://scripts/maps/dauwbos.gd"),
}

const QUESTS := {
	"lantaarn": {
		"title": "De Verdwenen Lantaarn",
		"steps": [
			{
				"text": "Lotte zoekt haar speciale nachtlantaarn. Ze denkt dat die ergens in de Vergeten Ruïne is achtergebleven.",
				"advance_if": [["has", "special_lantern", 1]],
			},
			{"text": "Breng de nachtlantaarn terug naar Lotte in het dorp."},
		],
	},
	"kruiden": {
		"title": "Verse kruiden voor Elke",
		"steps": [
			{
				"text": "Elke de kruidenier wil 4 verse kruiden. Ze groeien in het bos.",
				"advance_if": [["has", "herb", 4]],
			},
			{"text": "Breng de kruiden naar Elke in het dorp."},
		],
	},
	"dauw": {
		"title": "Het Geheim van de Dauw",
		"steps": [
			{
				"text": "Mira in het Dauwbos zoekt een oude dauwsteen. Hij ligt ergens in het bos.",
				"advance_if": [["has", "dauwsteen", 1]],
			},
			{
				"text": "Breng de dauwsteen naar Mira en hoor het verhaal van Tomas.",
				"advance_if": [["flag", "tomas_verhaal"]],
			},
			{"text": "Keer terug naar Mira om het evenwicht te herstellen."},
		],
	},
	"mistbloemen": {
		"title": "Bloemen in de mist",
		"steps": [
			{
				"text": "Mira wil 3 dauwklauwen voor haar mistedrank. Ze bloeien waar de mist het zachtst is: bij de vijver en langs de westelijke paden.",
				"advance_if": [["has", "prof_dauwklauw", 3]],
			},
			{"text": "Breng de dauwklauwen naar Mira in het Dauwbos."},
		],
	},
}

const ITEMS := {
	"special_lantern": {
		"name": "Nachtlantaarn", "sheet": "items", "icon": 1, "type": "quest",
		"desc": "Een lantaarn die 's nachts verder en warmer schijnt dan een gewone fakkel.",
	},
	"dauwsteen": {
		"name": "Dauwsteen", "sheet": "items", "icon": 3, "type": "quest",
		"desc": "Een steen die altijd bedekt is met fijne dauw. Hij voelt koel en levend.",
	},
	"herb": {
		"name": "Verse kruiden", "sheet": "items", "icon": 2, "type": "material", "sell": 2,
		"desc": "Verse kruiden uit het bos. Elke de kruidenier heeft ze nodig.",
	},
}

const NPCS := {
	"lotte": {
		"name": "Lotte de lantaarnmaker", "sheet": "npc_lotte",
		"rules": [
			{"if": [["step", "lantaarn", 1]], "talk": "lotte_klaar"},
			{"if": [["no_flag", "lotte_ontmoet"]], "talk": "lotte_intro"},
			{"talk": "lotte_menu"},
		],
	},
	"kasper": {
		"name": "Kasper de handelaar", "sheet": "npc_kasper",
		"rules": [
			{"if": [["no_flag", "kasper_ontmoet"]], "talk": "kasper_intro"},
			{"talk": "kasper_menu"},
		],
	},
	"elke": {
		"name": "Elke de kruidenier", "sheet": "npc_elke",
		"rules": [
			{"if": [["step", "kruiden", 1]], "talk": "elke_klaar"},
			{"if": [["no_flag", "elke_ontmoet"]], "talk": "elke_intro"},
			{"talk": "elke_menu"},
		],
	},
	"willem": {
		"name": "Willem de verhalenverteller", "sheet": "npc_willem",
		"rules": [
			{"if": [["no_flag", "willem_ontmoet"]], "talk": "willem_intro"},
			{"talk": "willem_menu"},
		],
	},
	"mira": {
		"name": "Mira de dauwbewaarder", "sheet": "npc_mira",
		"rules": [
			{"if": [["step", "dauw", 2]], "talk": "mira_klaar"},
			{"if": [["step", "dauw", 1]], "talk": "mira_steen"},
			{"if": [["step", "mistbloemen", 1]], "talk": "mira_mist_klaar"},
			{"if": [["step", "mistbloemen", 0]], "talk": "mira_mist_menu"},
			{"if": [["quest", "dauw", "done"], ["no_flag", "mira_mist_gevraagd"]], "talk": "mira_mist_intro"},
			{"if": [["no_flag", "mira_ontmoet"]], "talk": "mira_intro"},
			{"talk": "mira_menu"},
		],
	},
	"tomas": {
		"name": "Tomas de oude", "sheet": "npc_tomas",
		"rules": [
			{"if": [["no_flag", "tomas_ontmoet"]], "talk": "tomas_intro"},
			{"talk": "tomas_menu"},
		],
	},
	"noor": {
		"name": "Noor de verzamelaar", "sheet": "npc_noor",
		"rules": [
			{"if": [["no_flag", "noor_ontmoet"]], "talk": "noor_intro"},
			{"talk": "noor_menu"},
		],
	},
}

const TALKS := {
	"lotte_intro": {
		"speaker": "Lotte",
		"lines": ["Ik ben Lotte. Ik maak lantaarns voor het dorp.", "Mijn beste werk, de nachtlantaarn, is verdwenen. Ik had hem meegenomen naar de ruïne en daar gelaten."],
		"do": [["set_flag", "lotte_ontmoet"]],
		"next": "lotte_vraag",
	},
	"lotte_vraag": {
		"speaker": "Lotte",
		"lines": ["Wil je hem voor me zoeken? Hij geeft veel beter licht in het donker."],
		"choices": [
			{"text": "Ik zoek hem wel.", "do": [["start_quest", "lantaarn"]], "next": "lotte_ok"},
			{"text": "Later misschien."},
		],
	},
	"lotte_ok": {"speaker": "Lotte", "lines": ["Dank je. Kijk in de Vergeten Ruïne, ergens bij de oude gangen."], "do": [["sound", "quest"]]},
	"lotte_menu": {"speaker": "Lotte", "lines": ["Heb je de nachtlantaarn al gevonden?"], "choices": [{"text": "Nog niet."}, {"text": "Tot later."}]},
	"lotte_klaar": {
		"speaker": "Lotte",
		"lines": ["Je hebt hem! Hij werkt nog. Neem hem maar, hij helpt je beter in het donker dan een gewone.", "En hier wat munten voor de moeite."],
		"do": [["take", "special_lantern"], ["give", "special_lantern"], ["coins", 25], ["finish_quest", "lantaarn"], ["sound", "quest"]],
	},

	"kasper_intro": {
		"speaker": "Kasper",
		"lines": ["Ha, een reiziger! Ik ben Kasper. Ik verhandel alles wat de slijmen niet opeten.", "Munten, kruiden, geruchten... als het waarde heeft, koop of verkoop ik het."],
		"do": [["set_flag", "kasper_ontmoet"]],
		"next": "kasper_menu",
	},
	"kasper_menu": {
		"speaker": "Kasper",
		"lines": ["Wat brengt je naar mijn kraam?"],
		"choices": [
			{"text": "Heb je iets bijzonders?", "next": "kasper_bijzonder"},
			{"text": "Hoe gaat de handel?", "next": "kasper_handel"},
			{"text": "Tot later."},
		],
	},
	"kasper_bijzonder": {"speaker": "Kasper", "lines": ["Bijzonders? Alles is bijzonder als je het hard genoeg wilt. Maar echte schatten liggen buiten het dorp."], "next": "kasper_menu"},
	"kasper_handel": {"speaker": "Kasper", "lines": ["De handel bloeit. Zolang de Slijmkoning weg blijft, blijft mijn tas vol."], "next": "kasper_menu"},

	"elke_intro": {
		"speaker": "Elke",
		"lines": ["Welkom bij mijn kruiden. Ik ben Elke. Ik droog, maal en brouw alles wat groen is.", "De verse kruiden uit het bos zijn het beste. Die mis ik nu."],
		"do": [["set_flag", "elke_ontmoet"]],
		"next": "elke_vraag",
	},
	"elke_vraag": {
		"speaker": "Elke",
		"lines": ["Wil je 4 verse kruiden voor me plukken in het Fluisterbos of Dauwbos?"],
		"choices": [
			{"text": "Ik haal ze.", "do": [["start_quest", "kruiden"]], "next": "elke_ok"},
			{"text": "Misschien later."},
		],
	},
	"elke_ok": {"speaker": "Elke", "lines": ["Fijn. Ze liggen in kisten of op de grond in de bossen."], "do": [["sound", "quest"]]},
	"elke_menu": {"speaker": "Elke", "lines": ["Heb je de kruiden al?"], "choices": [{"text": "Nog niet."}, {"text": "Tot zo."}]},
	"elke_klaar": {
		"speaker": "Elke",
		"lines": ["Prachtig vers! Hier, een drankje en wat munten. Kom gerust terug."],
		"do": [["take", "herb", 4], ["give", "potion"], ["coins", 15], ["finish_quest", "kruiden"], ["sound", "quest"]],
	},

	"willem_intro": {
		"speaker": "Willem",
		"lines": ["Ah, een luisteraar! Ik ben Willem. Ik ken alle verhalen van Azura.", "Van de gebarsten kaart tot de oude wachters in de Diepte."],
		"do": [["set_flag", "willem_ontmoet"]],
		"next": "willem_menu",
	},
	"willem_menu": {
		"speaker": "Willem",
		"lines": ["Welk verhaal wil je horen?"],
		"choices": [
			{"text": "Over de Blauwe Kaart.", "next": "willem_kaart"},
			{"text": "Over de Diepte.", "next": "willem_diepte"},
			{"text": "Een ander keer."},
		],
	},
	"willem_kaart": {"speaker": "Willem", "lines": ["De Blauwe Kaart hield Azura bijeen. Toen hij barstte, vlogen de kristallen het land in. Zonder hen raakt alles uit balans."], "next": "willem_menu"},
	"willem_diepte": {"speaker": "Willem", "lines": ["Onder de tempel slaapt een oude wachter. Hij bewaakt het origineel van de kaart. Wees voorzichtig als je hem wekt."], "next": "willem_menu"},

	"mira_intro": {
		"speaker": "Mira",
		"lines": ["Welkom in het Dauwbos. Ik ben Mira. Ik bewaar de dauw hier.", "De mist wordt dikker. Ik zoek een oude dauwsteen om het evenwicht te herstellen."],
		"do": [["set_flag", "mira_ontmoet"]],
		"next": "mira_vraag",
	},
	"mira_vraag": {
		"speaker": "Mira",
		"lines": ["Wil je de dauwsteen voor me zoeken? Hij ligt ergens in dit bos."],
		"choices": [
			{"text": "Ik zoek hem.", "do": [["start_quest", "dauw"]], "next": "mira_ok"},
			{"text": "Later."},
		],
	},
	"mira_ok": {"speaker": "Mira", "lines": ["Dank je. Zoek in het noorden of bij de kisten."], "do": [["sound", "quest"]]},
	"mira_menu": {"speaker": "Mira", "lines": ["Heb je de steen al?"], "choices": [{"text": "Nog niet."}, {"text": "Tot zo."}]},
	"mira_steen": {
		"speaker": "Mira",
		"lines": ["Je hebt de steen! Prachtig. Nu moet ik het oude verhaal horen. Praat met Tomas."],
		"do": [["sound", "quest"]],
	},
	"mira_klaar": {
		"speaker": "Mira",
		"lines": ["Het verhaal klopt. De steen werkt. De dauw blijft, maar de mist wordt zachter.", "Hier, een beloning voor je hulp."],
		"do": [["take", "dauwsteen"], ["coins", 35], ["give", "potion"], ["finish_quest", "dauw"], ["sound", "quest"]],
	},
	"mira_mist_intro": {
		"speaker": "Mira",
		"lines": ["De mist is zacht nu, dankzij jou. Precies goed voor de dauwklauw: een bleke bloem die alleen in zachte mist bloeit.", "Ik brouw er mistedrank van — koel en helder, net als het bos zelf."],
		"do": [["set_flag", "mira_mist_gevraagd"]],
		"next": "mira_mist_vraag",
	},
	"mira_mist_vraag": {
		"speaker": "Mira",
		"lines": ["Wil je 3 dauwklauwen voor me plukken? Bij de vijver en langs de westelijke paden groeien ze het dichtst."],
		"choices": [
			{"text": "Ik pluk ze wel.", "do": [["start_quest", "mistbloemen"]], "next": "mira_mist_ok"},
			{"text": "Later misschien."},
		],
	},
	"mira_mist_ok": {"speaker": "Mira", "lines": ["Dank je. Zoek de bleke bloemen met de dauwdruppels — die glinsteren zelfs in de mist."], "do": [["sound", "quest"]]},
	"mira_mist_menu": {"speaker": "Mira", "lines": ["Heb je de dauwklauwen al?"], "choices": [{"text": "Nog niet."}, {"text": "Tot zo."}]},
	"mira_mist_klaar": {
		"speaker": "Mira",
		"lines": ["Prachtig, ze zijn vers. Kijk — zo brouw ik het mistedrank.", "De eerste fles is voor jou. En leer het recept: zo kun je er zelf meer maken in de bibliotheek."],
		"do": [["take", "prof_dauwklauw", 3], ["give", "prof_mistdrank"], ["coins", 30], ["finish_quest", "mistbloemen"], ["sound", "quest"]],
	},

	"tomas_intro": {
		"speaker": "Tomas",
		"lines": ["Ik ben Tomas. Ik woon al lang in dit bos. De dauw kent me."],
		"do": [["set_flag", "tomas_ontmoet"]],
		"next": "tomas_menu",
	},
	"tomas_menu": {
		"speaker": "Tomas",
		"lines": ["Wat wil je weten?"],
		"choices": [
			{"text": "Vertel het oude verhaal.", "next": "tomas_verhaal"},
			{"text": "Tot later."},
		],
	},
	"tomas_verhaal": {
		"speaker": "Tomas",
		"lines": ["Lang geleden viel de dauwsteen uit de sterren. Hij houdt de mist levend. Zonder hem wordt het bos dor.", "Mira weet wat ze doet. Geef haar de steen."],
		"do": [["set_flag", "tomas_verhaal"]],
		"next": "tomas_menu",
	},

	"noor_intro": {
		"speaker": "Noor",
		"lines": ["Ik ben Noor. Ik verzamel alles wat glimt in de dauw."],
		"do": [["set_flag", "noor_ontmoet"]],
		"next": "noor_menu",
	},
	"noor_menu": {
		"speaker": "Noor",
		"lines": ["Heb je iets moois gevonden in het bos?"],
		"choices": [
			{"text": "Nog niet."},
			{"text": "Tot ziens."},
		],
	},
}

const ACHIEVEMENTS := {
	"lantaarn_gevonden": {"name": "Licht in de duisternis", "desc": "Vind en terugbreng de nachtlantaarn van Lotte.", "if": [["quest", "lantaarn", "done"]]},
	"kruiden_gehaald": {"name": "Groene vingers", "desc": "Breng verse kruiden naar Elke.", "if": [["quest", "kruiden", "done"]]},
	"dauw_hersteld": {"name": "Bewaarder van de dauw", "desc": "Herstel het evenwicht in het Dauwbos.", "if": [["quest", "dauw", "done"]]},
	"mist_gebrouwen": {"name": "Mistvanger", "desc": "Pluk dauwklauwen voor Mira en proef het mistedrank.", "if": [["quest", "mistbloemen", "done"]]},
}
