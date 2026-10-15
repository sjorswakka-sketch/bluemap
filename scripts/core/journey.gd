extends RefCounted
## One optional quest focus, persisted in the existing flags. Routes use real portals.
const Maps := preload("res://scripts/maps/registry.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Equipment := preload("res://scripts/core/equipment.gd")
const TARGETS := {
	"ad_message":["gull_island","harbor"], "ad_pilot":["headland","headland","headland"],
	"ad_wheel":["tidal_hollow","tidal_hollow"], "ad_keeper":["tidal_hollow"],
	"main":["forest","village","temple"], "kat":["forest","village"],
	"medaillon":["cave","ruins"], "drank":["forest","inn"],
	"ra_ridge":["ridgepass","ridgepass","ridgepass","ridgepass"], "ra_archive":["reedvault"],
	"ls_supper":["lake","inn","inn"], "boog_schietbaan":["village","village"],
	"meer_karper":["lake","lake"], "meer_boeken":["lake","library"],
	"diepte":["temple","depths1","depths2","depths2"],
	"arena_kampioen":["arena_hall","arena_hall","arena_hall"],
	"lantaarn":["ruins","village"], "kruiden":["forest","village"],
	"dauw":["dauwbos","dauwbos","dauwbos"], "mistbloemen":["dauwbos","dauwbos"],
	"warmte":["ijsdal","ijsdal"], "ijswacht":["ijsdal","ijsdal"],
	"vellen_en_vlees":["dorstvallei","dorstvallei"],
	"cactusvijgen":["dorstvallei","sunwell","dorstvallei"],
	"veenbessen":["kruipmoeras","kruipmoeras"], "wilgentwijgen":["kruipmoeras","kruipmoeras"],
	"zonneschijf":["kruipmoeras","kruipmoeras"],
	"prisma_herstel":["prismamine","prismamine","smithy"], "lichtwerk":["smithy"],
	"mistsporen":["dauwbos","dauwbos"], "first_water":["village","village","smithy"],
	"rf_memory":["ruins","cave","ruins"], "rf_echo":["cave","cave","cave"]
}
static var links: Dictionary = {}
static func gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
static func focus() -> String:
	for id: String in Quests.QUESTS:
		if gs().flag("jr_focus_"+id) and gs().quest_state(id)=="active": return id
	return ""
static func toggle(id: String) -> bool:
	if not Quests.QUESTS.has(id) or gs().quest_state(id)!="active": return false
	var old := focus()
	for key: String in gs().flags.keys():
		if key.begins_with("jr_focus_"): gs().flags.erase(key)
	if old!=id: gs().flags["jr_focus_"+id]=true
	gs().quests_changed.emit()
	gs().save_requested.emit()
	return true
static func target(id: String) -> String:
	if not TARGETS.has(id): return ""
	var step: int = maxi(gs().quest_step(id),0)
	if id=="main" and step==0:
		var crystals := {"forest":"crystal_bos","ruins":"crystal_ruine","cave":"crystal_grot"}
		if crystals.has(gs().map_id) and gs().count(crystals[gs().map_id])==0: return gs().map_id
		for map: String in crystals:
			if gs().count(crystals[map])==0: return map
	if id=="meer_boeken" and step==0:
		if gs().count("meer_boek_eiland")<1 or gs().count("meer_boek_sanne")<1: return "lake"
		if gs().count("meer_boek_hut")<1: return "fisher_hut"
		return "library"
	if id=="rf_memory" and step==1 and gs().count("medallion")>0: return "ruins"
	return TARGETS[id][mini(step,TARGETS[id].size()-1)]
static func title(map: String) -> String:
	return TranslationServer.translate(Maps.MAPS[map].DATA.name) if Maps.MAPS.has(map) else ""
static func graph() -> Dictionary:
	if not links.is_empty(): return links
	for map: String in Maps.MAPS:
		links[map]=Maps.get_map(map).objects.filter(func(o: Dictionary) -> bool:return o.type in ["portal","coast_dock"])
		for object: Dictionary in Maps.get_map(map).objects:
			if object.type=="tide_station" and object.get("role","")=="routes":
				for route: Dictionary in object.routes:
					links[map].append({"type":"coast_route","pos":object.pos,"to":route.to,"spawn":route.spawn})
	return links
static func portal_open(from: String,portal: Dictionary) -> bool:
	if from=="forest" and portal.to=="ruins" and not gs().flag("gate_ruin"): return false
	return gs().check_all(portal.get("requires",[]))
static func path(from: String,to: String,open_only:=true) -> Array[String]:
	var result: Array[String]=[]
	if not Maps.MAPS.has(from) or not Maps.MAPS.has(to): return result
	var queue: Array[String]=[from]
	var previous := {from:""}
	while not queue.is_empty():
		var here:=queue.pop_front() as String
		if here==to:
			while here!="": result.push_front(here); here=previous[here]
			return result
		for portal: Dictionary in graph()[here]:
			if previous.has(portal.to) or (open_only and not portal_open(here,portal)): continue
			previous[portal.to]=here; queue.append(portal.to)
	return result
static func route_text(id: String) -> String:
	var to:=target(id)
	if to=="": return ""
	if to==gs().map_id: return TranslationServer.translate("Je bent in het juiste gebied: %s.") % title(to)
	var route:=path(gs().map_id,to)
	if route.is_empty():
		route=path(gs().map_id,to,false)
		if route.is_empty(): return TranslationServer.translate("Doelgebied: %s.") % title(to)
		for i in range(route.size()-1):
			for portal: Dictionary in graph()[route[i]]:
				if portal.to!=route[i+1] or portal_open(route[i],portal): continue
				var hint:=TranslationServer.translate("Onderzoek de gemarkeerde doorgang.")
				if portal.has("locked_text"):hint=TranslationServer.translate(portal.locked_text)
				if route[i]=="forest" and portal.to=="ruins":hint=TranslationServer.translate("Open het ruïnepoortje met de bossleutel.")
				return TranslationServer.translate("Route naar %s nog gesloten. %s") % [title(to),hint]
	var next:=route[1] if route.size()>1 else to
	for portal: Dictionary in graph()[gs().map_id]:
		if portal.to==next:
			if portal.type=="coast_route":return TranslationServer.translate("Naar %s: kies de veer op het reisbord (%d, %d op de kaart).") % [title(to),int(portal.pos[0])+1,int(portal.pos[1])+1]
			return TranslationServer.translate("Naar %s: neem de doorgang naar %s (%d, %d op de kaart).") % [title(to),title(next),int(portal.pos[0])+1,int(portal.pos[1])+1]
	return ""
static func compact_route(id: String) -> String:
	var to:=target(id)
	if to=="" or to==gs().map_id:return ""
	var route:=path(gs().map_id,to)
	return TranslationServer.translate("Via %s → %s") % [title(route[1]),title(to)] if route.size()>2 else TranslationServer.translate("Doel: %s") % title(to)
static func preparation(map: String) -> Array[String]:
	var result: Array[String]=[]
	match map:
		"tidal_hollow":result.append(TranslationServer.translate("De brede zuidelijke gang blijft veilig. De korte brug vraagt alleen herstel met gereedschap ter plaatse. Noordelijke poelen en de krachtproef zijn optioneel; je kunt altijd teruglopen."))
		"ruins","cave","prismamine":
			if gs().weapon=="wood": result.append(TranslationServer.translate("Greta smeedt ijzer voor 5 slijmgel en 40 munten. Een korter gevecht geeft meer ruimte om te ontwijken."))
			if map=="prismamine":result.append(TranslationServer.translate("De mijnpoort vraagt een ijzeren zwaard. Richt spiegels vóór je de kern benadert; aardingspoeder is een alternatief voor het gevecht."))
			elif map=="cave":result.append(TranslationServer.translate("Lopen is stil. Wissel gevechten af met luisteren bij de schalen; sprinten en rollen trekken luisteraars aan."))
		"temple","depths1","depths2":
			if gs().weapon in ["wood","iron"]: result.append(TranslationServer.translate("Voor een zwaar gevecht: Greta smeedt kristal voor 2 scherven, 8 slijmgel en 80 munten. Dit is voorbereiding, geen verplichte levelgrens."))
			result.append(TranslationServer.translate("Gebruik het altaar vóór je de arena inloopt. Het herstelt hartjes én stamina. Voorbij de gevechtsdeur kun je pas terug na de baas."))
			if gs().max_hp()<=5:result.append(TranslationServer.translate("Meer ruimte voor fouten? Pim geeft een extra hartje als Muis thuis is. Wilfred geeft twee scherven voor je kristalzwaard wanneer je zijn medaillon terugbrengt."))
		"ijsdal":result.append(TranslationServer.translate("De huizen kunnen met hout, wintergloed of de prismatechniek worden verwarmd. Houd aanvallers bij de vuurkorven weg; je hoeft niet alle drie de middelen te verzamelen."))
		"ridgepass":result.append(TranslationServer.translate("Het kamp geeft klimtouw. Wacht op slappe wimpels vóór de oversteek; de vastgezette lijn maakt latere bezoeken veilig."))
		"sunwell":result.append(TranslationServer.translate("Vul eerst de waterzak bij Sana. De blauwe luifels in de kloof vullen water bij en geven schaduw. Een lege zak brengt je veilig terug naar je laatste waterpunt."))
		"kruipmoeras","reedvault":result.append(TranslationServer.translate("De westelijke sluis open en de oostelijke dicht verlagen het water. Herstel daarna de brug; het archief draait om onderzoeken, geen verzamelquotum."))
		"lake","inn","library","mistgarden":result.append(TranslationServer.translate("Hier is ruimte voor een rustiger bezoek: vissen, koken, lezen of kruiden zoeken. Deze route wacht gewoon op je als je eerst ergens anders heen wilt."))
		"arena_hall","arena":result.append(TranslationServer.translate("De arena is optioneel. Bruno toont iedere rang en inzet vóór je begint; een gewone avonturenroute vraagt geen arenarang."))
		"dauwbos":result.append(TranslationServer.translate("De lichtkring vraagt een prismalantaarn. Na de mijn kun je die bij Greta maken met een lens en twee takken, of laten monteren voor 40 munten."))
	if map in ["ruins","cave","temple","depths1","depths2","prismamine"]:
		result.append(TranslationServer.translate("Bij je: %d helddrankjes · %d/%d hartjes · %.0f/%.0f stamina.") % [gs().count("potion"),gs().hp,gs().max_hp(),gs().movement.stamina,gs().movement.capacity()])
		if Equipment.bonus("armor")>0:result.append(TranslationServer.translate("Gedragen pantser: %.0f. Bonussen komen alleen van je gedragen set.") % Equipment.bonus("armor"))
	return result
static func detail(id: String) -> String:
	if not Quests.QUESTS.has(id):return ""
	var q: Dictionary=Quests.info(id)
	if gs().quest_state(id)=="done":return TranslationServer.translate(q.title)+"\n\n"+TranslationServer.translate(q.get("effect","Voltooid."))+"\n\n"+TranslationServer.translate("Deze opdracht is afgerond. Kies een lopende opdracht om op het scherm te volgen.")
	var lines: Array[String]=[TranslationServer.translate(q.title),TranslationServer.translate("Huidige stap"),gs().quest_text(id),route_text(id)]
	var prep:=preparation(target(id))
	if not prep.is_empty():lines.append(TranslationServer.translate("Voor je verdergaat"));lines.append_array(prep)
	lines.append(TranslationServer.translate("Snel terug? Ontdekte altaren staan op de kaart. Reizen vult niets bij; rusten bij het altaar wel."))
	return "\n\n".join(lines)
static func tracker() -> String:
	var id:=focus()
	if id=="":return ""
	return TranslationServer.translate("Volg: %s") % TranslationServer.translate(Quests.info(id).title)+"\n"+gs().quest_text(id)+( "\n"+compact_route(id) if compact_route(id)!="" else "")
