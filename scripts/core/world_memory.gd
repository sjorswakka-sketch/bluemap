extends RefCounted
## Residents are a projection of existing save flags, never another reward system.
const Daynight := preload("res://scripts/core/daynight.gd")
const PLACES := {
	"miner":{"map":"prismamine","flag":"lw_mine","work":[[28,7],[30,7]],"rest":[[28,8]],"frame":0},
	"gardener":{"map":"mistgarden","flag":"lw_forest","work":[[7,10],[8,11]],"rest":[[6,11]],"frame":1},
	"hearth":{"map":"ijsdal","flag":"lw_heat_west","work":[[10,12],[11,12]],"rest":[[9,11]],"frame":2},
	"lamplighter":{"map":"ijsdal","flag":"lw_heat_east","work":[[34,12],[36,12]],"rest":[[34,11]],"frame":3},
	"carrier":{"map":"kruipmoeras","flag":"lw_bridge","work":[[26,17],[28,16]],"rest":[[27,16]],"frame":4},
	"caravan":{"map":"dorstvallei","flag":"ra_spring","work":[[19,12],[20,13]],"rest":[[19,13]],"frame":5},
	"reader":{"map":"reedvault","flag":"ra_archive_done","work":[[9,13],[10,13]],"rest":[[9,14]],"frame":6},
	"courier":{"map":"ridgepass","flag":"ra_rope","work":[[6,14],[7,15]],"rest":[[6,15]],"frame":7}
}
static func gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
static func enabled(role: String) -> bool:
	return gs().flag(PLACES[role].flag)
static func resting(weather: String) -> bool:
	var state := gs()
	return Daynight.phase_at(state.day_time) in ["avond","nacht"] or Daynight.raining(weather,state.day_count,state.day_time) or (weather == "heat" and state.day_time >= 0.3 and state.day_time < 0.52)
static func name_for(role: String) -> String:
	match role:
		"miner": return TranslationServer.translate("Ivo de mijnwerker")
		"gardener": return TranslationServer.translate("Tess de tuinier")
		"hearth": return TranslationServer.translate("Edda van de winterkeuken")
		"lamplighter": return TranslationServer.translate("Wout de lampenmaker")
		"carrier": return TranslationServer.translate("Ada de veenkoerier")
		"caravan": return TranslationServer.translate("Ravi de reiziger")
		"reader": return TranslationServer.translate("Fien de verteller")
		"courier": return TranslationServer.translate("Cas de bergpost")
	return ""
static func introduction(role: String) -> String:
	match role:
		"miner": return TranslationServer.translate("Nu de kern rustig is, kan ik hier weer werken. Ik ben Ivo. Mijn gereedschap trilt eindelijk niet meer uit mijn handen!")
		"gardener": return TranslationServer.translate("Tess, aangenaam. Ik zag het lichtpad opengaan en kwam kijken. Deze tuin verdient meer dan een bezoek voor één bloem.")
		"hearth": return TranslationServer.translate("Ik ben Edda. Dat warme huis heeft ons teruggebracht. De winterkeuken is weer open, ook wanneer jij laat langskomt.")
		"lamplighter": return TranslationServer.translate("Wout is de naam. Dankzij het vuur kan ik mijn lampen hier weer herstellen. Het oostelijke pad hoeft nooit meer dicht.")
		"carrier": return TranslationServer.translate("Ada. Vroeger moest ik met elke mand om het water heen. Je brug maakt van twee oevers weer één buurt.")
		"caravan": return TranslationServer.translate("Ik ben Ravi. Sana vertelde over de bron. Nu durven reizigers hier weer te stoppen in plaats van door te haasten.")
		"reader": return TranslationServer.translate("Fien. Mees stuurde me naar het geordende archief. Er passen hier meer stemmen dan alleen die van onderzoekers.")
		"courier": return TranslationServer.translate("Cas, bergpost! Door jouw klimlijn kan de post ook bij harde wind over de pas. Geen brieven meer onder een steen verstoppen.")
	return ""
static func activity(role: String, rest: bool) -> String:
	match role:
		"miner": return TranslationServer.translate("Ik sorteer de nieuwe ertslagen. Het ijzer en koper bij de lichtkring zijn nu veilig te verzamelen; je pikhouweel blijft nodig.") if not rest else TranslationServer.translate("Even mijn gereedschap nakijken bij de rustige kern. Morgen werk ik verder; het erts blijft bereikbaar.")
		"gardener": return TranslationServer.translate("Ik geef de jonge planten water. Dauwklauwen staan langs de stroom, honingzwammen onder de bomen. Laat de vogels ook wat ruimte.") if not rest else TranslationServer.translate("Ik sorteer zaden op de droge hoek van de tuin. Regen en avond veranderen mijn werk, maar de kruiden blijven bereikbaar.")
		"hearth": return TranslationServer.translate("Ik roer de wintersoep. IJsbloemen en winterbessen zijn weer de moeite waard om mee te nemen naar de kookplek.") if not rest else TranslationServer.translate("De soep staat zachtjes te dampen. We blijven bij het huis; je hoeft voor een gesprek nooit op de ochtend te wachten.")
		"lamplighter": return TranslationServer.translate("Ik controleer de lonten voor vanavond. De Bergpas is open; zoek de klimlijn en neem wat hout mee voor je werkpak.") if not rest else TranslationServer.translate("Nu mogen de lampen hun werk doen. Ook in het donker blijft het pad naar de Bergpas open.")
		"carrier": return TranslationServer.translate("Ik bind de veenmanden vast voor het volgende transport. De brug blijft vrij voor jou. Aan de lage oever kun je vissen en watermunt vinden.") if not rest else TranslationServer.translate("De manden staan droog voor de nacht. De brug en de ingang van het Rietarchief blijven gewoon open.")
		"caravan": return TranslationServer.translate("Ik vul mijn kruiken en verdeel de bagage. Deze halte bestaat dankzij de bron; de Zonnekloof kun je blijven bezoeken.") if not rest else TranslationServer.translate("In de hitte en tegen de avond zoek ik schaduw. Mijn kruiken zijn gevuld; er is geen haast om nu de kloof in te gaan.")
		"reader": return TranslationServer.translate("Ik lees de drie beelden voor: riet, aanlegplaats, overstroming. Een bezoeker kan nu zelf begrijpen wat hier gebeurd is.") if not rest else TranslationServer.translate("Even aantekeningen maken voor mijn volgende verhaal. Het archief blijft open; de beelden verliezen hun volgorde niet.")
		"courier": return TranslationServer.translate("Ik maak een postbundel vast met hetzelfde vlechtwerk als de klimlijn. Die lijn blijft veilig, ook wanneer de wind opnieuw aantrekt.") if not rest else TranslationServer.translate("De post ligt droog bij het kamp. Morgen gaat de volgende bundel mee. Jij kunt de klimlijn op elk moment gebruiken.")
	return ""
static func connection(role: String) -> String:
	var state := gs()
	match role:
		"miner":
			return TranslationServer.translate("Greta gebruikt onze rustige lichtkern in haar werkplaats. Dat is herstel dat verder reikt dan deze grot.") if state.flag("lw_workshop") else TranslationServer.translate("Greta kan iets met de herstelde kern. Zoek haar werkbank in de smederij wanneer je terug in het dorp bent.")
		"gardener":
			return TranslationServer.translate("Door de open moerasbrug kunnen kruiden ook naar de andere oever. Een tuin is pas echt levend als mensen haar gebruiken.") if state.flag("lw_bridge") else TranslationServer.translate("Verderop ligt het Kruipmoeras. Als die brug weer open is, kunnen onze kruiden ook naar de andere oever.")
		"hearth", "lamplighter":
			return TranslationServer.translate("Cas bezorgt weer post over de klimlijn. Twee warme huizen en een veilige pas brengen de buurt bij elkaar.") if state.flag("ra_rope") else TranslationServer.translate("Boven ons wacht de Bergpas. Een vaste klimlijn zou ook de post weer op gang helpen.")
		"carrier", "reader":
			return TranslationServer.translate("Mees toont veilige vluchtroutes. Ada gebruikt de oude aanlegplaatsen nu als herkenningspunten voor transport.") if state.flag("ra_exhibit_routes") else (TranslationServer.translate("Mees bewaart de verhalen van de bewoners. Fien neemt ze mee in haar vertellingen tussen de archiefbeelden.") if state.flag("ra_archive_done") else TranslationServer.translate("Nu de oever droog is, kun je de beelden in het Rietarchief onderzoeken. Mees wacht op wat je daar ontdekt."))
		"caravan":
			return TranslationServer.translate("Je koos ruimte voor het wild. Ik vul mijn kruiken, maar laat de rustige waterkant aan de dieren.") if state.flag("ra_water_wild") else TranslationServer.translate("Je koos een halte voor reizigers. We houden de kruiken en bagage aan deze kant, zodat het water bereikbaar blijft.")
		"courier":
			return TranslationServer.translate("Joris' bergwerkpak gebruikt hetzelfde vlechtwerk. Handig wanneer je onderweg hout of kruiden verzamelt.") if state.count("gear_pg_pack_plus") > 0 else TranslationServer.translate("Bij het Zilvermeer ligt Joris' vlechtpatroon. Nu je de klimlijn kent, kun je zijn werkpak verder verbeteren.")
	return ""
static func lines(role: String, weather: String) -> Array:
	var result: Array = []
	if not gs().flag("wm_met_"+role): result.append(introduction(role))
	else:
		match role:
			"miner": result.append(TranslationServer.translate("Daar ben je weer! Hoor je hoe rustig het hier klinkt? Zo klinkt een mijn waar je kunt werken."))
			"gardener": result.append(TranslationServer.translate("Welkom terug tussen het groen. Ik heb de nieuwe scheuten al gezien; de tuin blijft groeien."))
			"hearth": result.append(TranslationServer.translate("Ah, een bekend gezicht. Het vuur is gebleven, dus onze keuken ook."))
			"lamplighter": result.append(TranslationServer.translate("Je bent terug! Kijk vanavond naar de ramen: die warmte zit nu in het dagelijkse leven."))
			"carrier": result.append(TranslationServer.translate("Dag weer! Sinds jouw brug open is, ken ik ook de mensen aan de andere kant bij naam."))
			"caravan": result.append(TranslationServer.translate("Je vindt me weer bij het water. Een echte halte herken je aan mensen die terugkomen."))
			"reader": result.append(TranslationServer.translate("Mooi, je komt nog eens lezen. De beelden veranderen niet, maar ieder bezoek brengt een ander verhaal."))
			"courier": result.append(TranslationServer.translate("Weer op de pas? De post gaat inmiddels geregeld heen en terug. Jouw lijn doet nog steeds haar werk."))
	result.append(activity(role,resting(weather)))
	result.append(connection(role))
	return result
static func meet(role: String) -> void:
	if gs().flag("wm_met_"+role): return
	gs().set_flag("wm_met_"+role)
	gs().save_requested.emit()
static func news() -> Array:
	var result: Array = [TranslationServer.translate("Dit boek wordt bijgehouden door reizigers. Herstelde plekken krijgen opnieuw bewoners. Ga gerust overdag of in de avond langs.")]
	for role: String in PLACES:
		if not enabled(role): continue
		var map_name: String = preload("res://scripts/maps/registry.gd").MAPS[PLACES[role].map].DATA.name
		result.append(TranslationServer.translate("%s — %s. %s") % [TranslationServer.translate(map_name),name_for(role),TranslationServer.translate("Al ontmoet; het werk gaat verder.") if gs().flag("wm_met_"+role) else TranslationServer.translate("Nieuwe ontmoeting na je herstel.")])
	if result.size()==1: result.append(TranslationServer.translate("De eerste berichten komen wanneer je de lichtkern, de tuin, een huis, een bron, een brug, het archief of de klimlijn herstelt."))
	return result
