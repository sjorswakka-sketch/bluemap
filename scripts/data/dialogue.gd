extends RefCounted
## Alle gesprekken. Een gesprek is een verzameling "knopen" (nodes):
##
##   speaker  = wie er praat
##   lines    = de regels, die je een voor een doorklikt ({crystals}, {gel}, {coins} worden ingevuld)
##   do       = acties die worden uitgevoerd nadat de regels zijn gelezen
##   choices  = keuzes: [{"text", "if", "do", "next"}] (keuzes met een `if` die niet klopt verdwijnen)
##   branch   = [{"if", "next"}]: de eerste die klopt bepaalt de volgende knoop
##   next     = de volgende knoop (zonder next, choices of branch is het gesprek afgelopen)
##
## Voorwaarden en acties staan beschreven in scripts/core/game_state.gd.

const Content := preload("res://scripts/data/content.gd")

const BASE_TALKS := {
	# --- Oudste Bram ---------------------------------------------------------------------
	"bram_intro": {
		"speaker": "Oudste Bram",
		"lines": [
			"Ah, een reiziger! Welkom in Dageraadsdorp.",
			"Ik ben Bram, de oudste van het dorp en de bewaker van de Blauwe Kaart.",
			"Kijk, in de tempel hangt de kaart van heel Azura, gemaakt van gloeiend kristal. Hij houdt de slijmen rustig en laat zien waar het land veilig is.",
		],
		"next": "bram_intro2",
	},
	"bram_intro2": {
		"speaker": "Oudste Bram",
		"lines": [
			"Maar drie nachten geleden barstte de kaart. De drie grote kristallen sprongen eruit en vlogen het land in: naar het Fluisterbos, de Vergeten Ruïne en de Echo-grot.",
			"Sindsdien zijn de slijmen wild geworden. En onder de tempel... daar hoor ik iets groots bewegen.",
		],
		"choices": [
			{"text": "Ik help je!", "do": [["start_quest", "main"]], "next": "bram_accept"},
			{"text": "Wat moet ik precies doen?", "next": "bram_explain"},
			{"text": "Ik moet er even over nadenken.", "next": "bram_later"},
		],
	},
	"bram_explain": {
		"speaker": "Oudste Bram",
		"lines": [
			"Zoek de drie kaartkristallen en breng ze naar mij. Het Fluisterbos ligt over de brug in het oosten, de Wachter Hein houdt er een oogje op.",
			"Met een houten zwaard kom je niet ver. Greta de smid kan beter spul maken als je haar slijmgel brengt, en Tobias verkoopt drankjes.",
		],
		"choices": [
			{"text": "Ik help je!", "do": [["start_quest", "main"]], "next": "bram_accept"},
			{"text": "Ik kom straks terug.", "next": "bram_later"},
		],
	},
	"bram_accept": {
		"speaker": "Oudste Bram",
		"lines": [
			"Dank je, held! Neem dit mee voor onderweg.",
			"Een helddrank. Druk op H als je gewond bent. En rol met Shift om aanvallen te ontwijken, dan kan niets je raken!",
		],
		"do": [["give", "potion", 1], ["sound", "quest"]],
	},
	"bram_later": {
		"speaker": "Oudste Bram",
		"lines": ["Neem de tijd. Maar de slijmen wachten niet..."],
	},
	"bram_progress": {
		"speaker": "Oudste Bram",
		"lines": [
			"Hoe gaat het met de zoektocht? Je hebt {crystals} van de 3 kristallen.",
			"Het Fluisterbos, de Vergeten Ruïne en de Echo-grot. Pas goed op jezelf!",
		],
	},
	"bram_crystals": {
		"speaker": "Oudste Bram",
		"lines": [
			"Je hebt ze alle drie! Ik kan het bijna niet geloven...",
			"Geef maar hier. Ik leg ze terug in de Blauwe Kaart.",
		],
		"do": [["take", "crystal_bos"], ["take", "crystal_ruine"], ["take", "crystal_grot"], ["sound", "upgrade"]],
		"next": "bram_crystals2",
	},
	"bram_crystals2": {
		"speaker": "Oudste Bram",
		"lines": [
			"Kijk! De kaart gloeit weer. Maar luister... de deur van de tempel is opengesprongen.",
			"Daarbeneden zit de Slijmkoning. Hij dronk de kracht van de gebarsten kaart en is gigantisch geworden.",
			"Alleen jij kunt hem nog stoppen. Rust uit in de herberg, drink een drankje en neem je beste zwaard mee.",
			"Veel succes, held. Heel Azura rekent op je.",
		],
		"do": [["set_flag", "gate_temple"], ["quest_step", "main", 2]],
	},
	"bram_boss_wait": {
		"speaker": "Oudste Bram",
		"lines": ["De tempeldeur staat open. Rust eerst goed uit in de herberg, dan ben je er klaar voor."],
	},
	"bram_done": {
		"speaker": "Oudste Bram",
		"lines": [
			"Dankzij jou is de Blauwe Kaart weer heel!",
			"Het dorp viert feest. Rust maar uit, held. Je hebt het verdiend.",
		],
	},

	# --- Greta de smid -------------------------------------------------------------------
	"greta_intro": {
		"speaker": "Greta",
		"lines": [
			"Hé! Jij bent dat reizigertje van Bram, hè? Ik ben Greta, de smid.",
			"Dat houten ding van jou is geen zwaard, het is een stok met ambitie.",
		],
		"do": [["set_flag", "met_greta"]],
		"next": "greta_menu",
	},
	"greta_menu": {
		"speaker": "Greta",
		"lines": ["Wat kan ik voor je smeden?"],
		"choices": [
			{"text": "Een ijzeren zwaard", "if": [["weapon", "wood"]], "next": "greta_iron"},
			{"text": "Een kristalzwaard", "if": [["weapon", "iron"]], "next": "greta_crystal"},
			{"text": "Niets, bedankt."},
		],
	},
	"greta_iron": {
		"speaker": "Greta",
		"lines": ["Een ijzeren zwaard? Dat kost 5 slijmgel en 40 munten. Je hebt {gel} slijmgel en {coins} munten."],
		"branch": [
			{"if": [["has", "gel", 5], ["coins", 40]], "next": "greta_iron_ask"},
			{"next": "greta_iron_no"},
		],
	},
	"greta_iron_ask": {
		"speaker": "Greta",
		"lines": ["Dat kan! Zal ik hem voor je smeden?"],
		"choices": [
			{
				"text": "Ja, smeed maar!",
				"do": [["take", "gel", 5], ["coins", -40], ["weapon", "iron"], ["sound", "upgrade"]],
				"next": "greta_iron_done",
			},
			{"text": "Nog even niet."},
		],
	},
	"greta_iron_no": {
		"speaker": "Greta",
		"lines": ["Dan ben je nog niet klaar. Slijmen in het bos laten slijmgel vallen. Kom maar terug als je genoeg hebt."],
	},
	"greta_iron_done": {
		"speaker": "Greta",
		"lines": ["Zo! Voel dat gewicht eens. Dit raakt een stuk harder dan je stok."],
	},
	"greta_crystal": {
		"speaker": "Greta",
		"lines": [
			"Een kristalzwaard... Dat is werk voor een meester. Ik heb 2 kristalscherven nodig, 8 slijmgel en 80 munten.",
			"Je hebt {shards} scherven, {gel} slijmgel en {coins} munten. Golems in de ruïne en de grot laten scherven vallen.",
		],
		"branch": [
			{"if": [["has", "shard", 2], ["has", "gel", 8], ["coins", 80]], "next": "greta_crystal_ask"},
			{"next": "greta_crystal_no"},
		],
	},
	"greta_crystal_ask": {
		"speaker": "Greta",
		"lines": ["Je hebt alles! Dit wordt mijn mooiste zwaard. Zal ik beginnen?"],
		"choices": [
			{
				"text": "Ja, smeed maar!",
				"do": [["take", "shard", 2], ["take", "gel", 8], ["coins", -80], ["weapon", "crystal"], ["sound", "upgrade"]],
				"next": "greta_crystal_done",
			},
			{"text": "Nog even niet."},
		],
	},
	"greta_crystal_no": {
		"speaker": "Greta",
		"lines": ["Nog niet genoeg. Kom terug als je alles hebt, dan maak ik er iets moois van."],
	},
	"greta_crystal_done": {
		"speaker": "Greta",
		"lines": ["Kijk dat nou... het gloeit! Pas er goed op, dit is het beste wat ik ooit gemaakt heb."],
	},
	"greta_max": {
		"speaker": "Greta",
		"lines": ["Dat kristalzwaard is mijn beste werk. Meer kan ik er niet aan doen. Ga ze maar een lesje leren!"],
	},

	"greta_done": {
		"speaker": "Greta",
		"lines": ["De held van Azura in mijn smederij! Ik heb net nieuwe zwaarden gesmeed, voor op het feest. Nou ja, voor de taart."],
		"do": [["set_flag", "heard_greta_done"]],
		"branch": [
			{"if": [["weapon", "crystal"]], "next": "greta_max"},
			{"next": "greta_menu"},
		],
	},

	# --- Tobias de koopman ---------------------------------------------------------------
	"tobias_intro": {
		"speaker": "Tobias",
		"lines": ["Welkom, welkom! Tobias, koopman van de beste waar van heel Azura!", "Of eigenlijk van het hele dorp. Maar dat is wel eerlijk gezegd het enige."],
		"do": [["set_flag", "met_tobias"]],
		"next": "tobias_menu",
	},
	"tobias_menu": {
		"speaker": "Tobias",
		"lines": ["Zeg het maar, wat mag het zijn?"],
		"choices": [
			{"text": "Ik wil iets kopen.", "do": [["shop", "tobias"]]},
			{"text": "Ik wil slijmgel verkopen.", "if": [["has", "gel", 1]], "next": "tobias_sell"},
			{"text": "Tot ziens."},
		],
	},
	"tobias_sell": {
		"speaker": "Tobias",
		"lines": ["Slijmgel? Prima spul! Ik geef 3 munten per stuk. Je hebt {gel} stuks. Pas op: Greta en Mila hebben het ook nodig."],
		"choices": [
			{"text": "Verkoop alles.", "do": [["sell_all", "gel"]], "next": "tobias_sold"},
			{"text": "Toch maar niet."},
		],
	},
	"tobias_sold": {
		"speaker": "Tobias",
		"lines": ["Prima zaken doen met jou!"],
	},

	"tobias_done": {
		"speaker": "Tobias",
		"lines": ["Mijn omzet is verdubbeld sinds de Slijmkoning weg is! Alles blijft voor jou gewoon hetzelfde. Maar dan wel met een knipoog."],
		"do": [["set_flag", "heard_tobias_done"]],
		"next": "tobias_menu",
	},

	# --- Mila de herbergierster ----------------------------------------------------------
	"mila_intro": {
		"speaker": "Mila",
		"lines": [
			"Welkom in de herberg! Ik ben Mila.",
			"Je mag hier altijd uitrusten, dat is gratis voor een held. Je wordt helemaal beter en ik schrijf op waar je gebleven was.",
		],
		"do": [["set_flag", "met_mila"]],
		"next": "mila_menu",
	},
	"mila_menu": {
		"speaker": "Mila",
		"lines": ["Hoe kan ik je helpen?"],
		"choices": [
			{"text": "Ik wil uitrusten.", "do": [["heal"], ["save"]], "next": "mila_rest"},
			{"text": "Heb je werk voor me?", "if": [["quest", "drank", "none"]], "next": "mila_quest"},
			{"text": "Nee, bedankt."},
		],
	},
	"mila_rest": {
		"speaker": "Mila",
		"lines": ["Zo, helemaal opgeknapt! Ik heb je voortgang opgeschreven."],
	},
	"mila_quest": {
		"speaker": "Mila",
		"lines": [
			"Eigenlijk wel! Ik wil helddrankjes brouwen voor het dorp, maar ik heb slijmgel nodig. Vijf stuks.",
			"Breng je ze mij, dan krijg je er drie drankjes en wat munten voor je moeite.",
		],
		"choices": [
			{"text": "Dat doe ik.", "do": [["start_quest", "drank"]], "next": "mila_quest_ok"},
			{"text": "Misschien later."},
		],
	},
	"mila_quest_ok": {
		"speaker": "Mila",
		"lines": ["Fijn! Slijmen in het bos laten het vaak vallen."],
	},
	"mila_potion_progress": {
		"speaker": "Mila",
		"lines": ["Heb je al genoeg slijmgel? Je hebt er {gel} van de 5."],
	},
	"mila_potion_done": {
		"speaker": "Mila",
		"lines": ["Slijmgel! Vijf stuks! Dan ga ik meteen aan de slag.", "Hier, drie helddrankjes en 25 munten. Dank je wel!"],
		"do": [["take", "gel", 5], ["give", "potion", 3], ["coins", 25], ["finish_quest", "drank"], ["sound", "quest"]],
	},

	"mila_done": {
		"speaker": "Mila",
		"lines": ["De herberg zit vol met mensen die jou willen zien. Jouw bed is altijd vrij, held."],
		"do": [["set_flag", "heard_mila_done"]],
		"next": "mila_menu",
	},

	# --- Pim en Muis -----------------------------------------------------------------------
	"pim_intro": {
		"speaker": "Pim",
		"lines": [
			"Snif... Muis is weg!",
			"Mijn kat Muis is gisteren het bos in gerend. Het is daar zo eng... Wil jij haar zoeken?",
		],
		"choices": [
			{"text": "Ik zoek haar wel!", "do": [["start_quest", "kat"]], "next": "pim_ok"},
			{"text": "Misschien later."},
		],
	},
	"pim_ok": {
		"speaker": "Pim",
		"lines": ["Echt waar?! Dankjewel! Ze is wit met een zwart vlekje op haar neus."],
	},
	"pim_progress": {
		"speaker": "Pim",
		"lines": ["Heb je Muis al gezien? Ze is wit met een zwart vlekje op haar neus."],
	},
	"pim_cat_back": {
		"speaker": "Pim",
		"lines": [
			"Muis!!! Je hebt haar gevonden!",
			"Dankjewel, dankjewel! Hier, dit vond ik in het bos. Het is vast iets waard.",
		],
		"do": [["give", "heart_container"], ["set_flag", "cat_home"], ["finish_quest", "kat"], ["sound", "quest"]],
	},
	"pim_done": {
		"speaker": "Pim",
		"lines": ["Muis slaapt de hele dag op mijn bed. Ze is wel een beetje dik geworden van het bos."],
	},
	"muis_bos": {
		"speaker": "Muis",
		"lines": [
			"Miauw?",
			"Muis snuffelt aan je hand en rent met een grote boog het bos uit, richting het dorp.",
		],
		"do": [["set_flag", "cat_found"]],
	},
	"muis_dorp": {
		"speaker": "Muis",
		"lines": ["Miauw. (Ze rolt zich op en begint te spinnen.)"],
	},

	# --- Dorpelingen -----------------------------------------------------------------------
	"hein_talk": {
		"speaker": "Wachter Hein",
		"lines": [
			"Halt! Oh, jij bent het. Het Fluisterbos is gevaarlijk: slijmen en vleermuizen overal.",
			"Een tip: met Shift rol je weg en kan niets je raken. En de blauwe altaren slaan je voortgang op.",
		],
	},
	"hein_done": {
		"speaker": "Wachter Hein",
		"lines": ["Het bos is veel rustiger sinds je de Slijmkoning hebt verslagen. Bedankt, held!"],
	},
	"anja_talk": {
		"speaker": "Anja",
		"lines": [
			"De Blauwe Kaart is al duizend jaar oud. Mijn oma zei altijd dat hij het land beschermt.",
			"Als die kaart echt breekt, wordt Azura weer wild. Gelukkig heb jij nu die opdracht!",
		],
	},
	"anja_done": {
		"speaker": "Anja",
		"lines": ["Heb je het gehoord? De Blauwe Kaart straalt weer helderblauw! Alles dankzij jou."],
	},
	"joost_done": {
		"speaker": "Joost",
		"lines": ["De slijmen zijn rustiger nu de kaart weer heel is. Ik gaf er een een appel. Hij at hem op. Het was raar."],
	},
	"joost_talk": {
		"speaker": "Joost",
		"lines": [
			"De Vergeten Ruïne is dichtgemetseld met een poortje. Je hebt de sleutel nodig.",
			"Ik hoorde dat er ergens in het bos een kist ligt, bewaakt door slijmen. Misschien zit daar iets in...",
		],
	},
	"joost_key": {
		"speaker": "Joost",
		"lines": ["Is dat een sleutel? Dan weet je wat je moet doen: naar het poortje van de ruïne, in het noordoosten van het bos!"],
	},

	# --- Wilfred, de geest in de ruïne -----------------------------------------------------
	"wilfred_intro": {
		"speaker": "Wilfred",
		"lines": [
			"Ooooh... een levende! Wees niet bang, ik bijt niet. Ik ben Wilfred.",
			"Ik was de bewaker van deze ruïne, lang geleden. Mijn medaillon is zoekgeraakt... ik denk dat het in de Echo-grot ligt.",
		],
		"choices": [
			{"text": "Ik breng het terug.", "do": [["start_quest", "medaillon"]], "next": "wilfred_ok"},
			{"text": "Sorry, geen tijd."},
		],
	},
	"wilfred_ok": {
		"speaker": "Wilfred",
		"lines": ["Wat aardig van je. Het is een zilveren medaillon met mijn naam erin."],
	},
	"wilfred_progress": {
		"speaker": "Wilfred",
		"lines": ["Zoek je mijn medaillon nog? Het ligt in de Echo-grot, ergens diep onder de grond."],
	},
	"wilfred_return": {
		"speaker": "Wilfred",
		"lines": [
			"Mijn medaillon! Na al die jaren!",
			"Neem deze kristalscherven als dank. Ze zijn van een kaartkristal dat hier ooit brak.",
		],
		"do": [["take", "medallion"], ["give", "shard", 2], ["finish_quest", "medaillon"], ["sound", "quest"]],
	},
	"wilfred_done": {
		"speaker": "Wilfred",
		"lines": ["Nu kan ik eindelijk rusten. Dank je, vriend."],
	},

	# --- De baas -----------------------------------------------------------------------------
	"king_intro": {
		"speaker": "De Slijmkoning",
		"lines": [
			"Blub... blub blub...",
			"WIE DURFT MIJN TEMPEL BINNEN TE KOMEN?!",
			"De kaart is van MIJ! Ik zal je tot gel verwerken!",
		],
	},
}


## Basis en uitbreidingen samen (zie content.gd).
static var TALKS: Dictionary = Content.merged("TALKS", BASE_TALKS)


static func get_talk(talk_id: String) -> Dictionary:
	return TALKS[talk_id]
