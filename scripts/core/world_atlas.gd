extends RefCounted
## Authored geography, actual routes and evidence-based discovery; never a travel API.
const Maps := preload("res://scripts/maps/registry.gd")
const Journey := preload("res://scripts/core/journey.gd")
const REGIONS := {
	"steampeak":{"at":Vector2(264,25),"label":"Dampkroon","label_y":49,"biome":"peak"},
	"ijsdal":{"at":Vector2(264,75),"label":"IJsdal","label_y":99,"biome":"snow"},
	"ridgepass":{"at":Vector2(360,60),"label":"Bergpas","label_y":43,"biome":"ridge"},
	"sunwell":{"at":Vector2(408,85),"label":"Zonnekloof","label_y":109,"biome":"canyon"},
	"dauwbos":{"at":Vector2(264,139),"label":"Dauwbos","label_y":163,"biome":"mist"},
	"dorstvallei":{"at":Vector2(384,135),"label":"Dorstvallei","label_y":159,"biome":"dunes"},
	"mistgarden":{"at":Vector2(336,170),"label":"Dauwtuin","label_x":354,"label_y":193,"biome":"garden"},
	"village":{"at":Vector2(120,213),"label":"Dageraadsdorp","label_y":194,"biome":"town"},
	"forest_edge":{"at":Vector2(192,217),"label":"Bosrand","label_y":240,"biome":"edge"},
	"forest":{"at":Vector2(264,209),"label":"Fluisterbos","label_x":240,"label_y":191,"biome":"forest"},
	"watchyard":{"at":Vector2(228,252),"label":"Oefenerf","label_y":277,"biome":"yard"},
	"lake":{"at":Vector2(120,280),"label":"Zilvermeer","label_y":306,"biome":"lake"},
	"kruipmoeras":{"at":Vector2(120,333),"label":"Kruipmoeras","label_y":358,"biome":"marsh"},
	"river_mouth":{"at":Vector2(294,249),"label":"Zilvermonding","label_y":233,"biome":"river"},
	"coast":{"at":Vector2(294,291),"label":"Blauwe Kust","label_y":316,"biome":"shore"},
	"harbor":{"at":Vector2(420,245),"label":"Rietwenk","label_y":229,"biome":"port"},
	"headland":{"at":Vector2(522,227),"label":"Lichtkaap","label_y":210,"biome":"cape"},
	"gull_island":{"at":Vector2(432,326),"label":"Meeuweneiland","label_x":410,"label_y":353,"biome":"island"},
	"tide_cove":{"at":Vector2(522,326),"label":"Getijdenbaai","label_x":546,"label_y":353,"biome":"cove"},
}
const LOCALES := {
	"village":["smithy","shop","inn","player_home","arena_hall","arena","temple","depths1","depths2"],
	"forest":["ruins","cave","prismamine","resonance"],
	"lake":["fisher_hut","library"],
	"kruipmoeras":["reedvault"],
	"river_mouth":["tidal_hollow"],
	"harbor":["coast_workshop"],
}
const DUNGEONS := ["ruins","cave","temple","depths1","depths2","prismamine","resonance","reedvault","tidal_hollow"]
const LEGACY_BATTLES := {"golem_ruins":"ruins","golem_cave":"cave","boss_defeated":"temple","golem_depths":"depths1","guardian_started":"depths2","guardian_epilogue":"depths2","ad_crab_defeated":"tidal_hollow","ad_wisp_defeated":"tidal_hollow"}
static var _connections: Array[Dictionary] = []
static var _evidence: Array[Dictionary] = []
static var _unique_npcs: Dictionary = {}

static func _legacy_inventory() -> void:
	if not _evidence.is_empty():return
	var npc_maps: Dictionary = {}
	for id: String in Maps.MAPS:
		var data: Dictionary = Maps.get_map(id)
		for i in data.objects.size():
			var obj: Dictionary = data.objects[i]
			var key := ""
			if obj.type=="chest":key="chest:%s:%d" % [id,i]
			elif obj.type=="pickup" and obj.get("unique",false):key="pickup:%s:%d" % [id,i]
			elif obj.type=="savepoint":key="altaar_%s_%d_%d" % [id,int(obj.pos[0]),int(obj.pos[1])]
			elif obj.type=="npc":
				var npc: String = obj.get("id","")
				if not npc_maps.has(npc):npc_maps[npc]={}
				npc_maps[npc][id]=true
			if key!="":_evidence.append({"key":key,"map":id})
	for npc: String in npc_maps:
		# Joris also appears as a dynamically spawned supper guest at the inn.
		if npc_maps[npc].size()==1 and npc!="meer_joris":_unique_npcs[npc]=npc_maps[npc].keys()[0]

static func gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")

static func valid_map(id: String) -> bool:
	return Maps.MAPS.has(id)

static func region_for(id: String) -> String:
	if REGIONS.has(id):return id
	for region: String in LOCALES:
		if id in LOCALES[region]:return region
	return ""

static func locales(region: String) -> Array[String]:
	var result: Array[String] = []
	if not REGIONS.has(region):return result
	result.append(region)
	for id: String in LOCALES.get(region,[]):result.append(id)
	return result

static func normalize_visits(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw is Dictionary:return result
	for id: Variant in raw:
		if id is String and valid_map(id) and raw[id] is bool and raw[id]:result[id]=true
	return result

static func _positive(flags: Dictionary,key: String) -> bool:
	return flags.get(key,false) is bool and flags.get(key,false)

static func restore_visits(saved: Dictionary) -> Dictionary:
	var result := normalize_visits(saved.get("visited_maps",{}))
	var current: String = str(saved.get("map","village"))
	if valid_map(current):result[current]=true
	if saved.has("visited_maps"):return result
	# Old unlocks, quests, inherited gear and meta achievements prove no visit.
	# Inspect the raw save, before old world migrations can synthesize flags.
	var flags: Dictionary = saved.get("flags",{}) if saved.get("flags",{}) is Dictionary else {}
	var talked: Array = saved.get("talked",[]) if saved.get("talked",[]) is Array else []
	_legacy_inventory()
	for proof: Dictionary in _evidence:
		if _positive(flags,proof.key):result[proof.map]=true
	for npc: String in talked:
		if _unique_npcs.has(npc):result[_unique_npcs[npc]]=true
	for role: String in preload("res://scripts/core/world_memory.gd").PLACES:
		if _positive(flags,"wm_met_"+role):result[preload("res://scripts/core/world_memory.gd").PLACES[role].map]=true
	for key: String in LEGACY_BATTLES:
		if _positive(flags,key):result[LEGACY_BATTLES[key]]=true
	return result

static func visited(id: String) -> bool:
	return bool(gs().visited_maps.get(id,false))

static func region_visited(region: String) -> bool:
	for id: String in locales(region):
		if visited(id):return true
	return false

static func current_region() -> String:
	return region_for(gs().map_id)

static func state(id: String) -> int:
	return 2 if gs().map_id==id else 1 if visited(id) else 0

static func region_state(id: String) -> int:
	return 2 if current_region()==id else 1 if region_visited(id) else 0

static func title(id: String) -> String:
	return TranslationServer.translate(Maps.MAPS[id].DATA.name) if valid_map(id) else ""

static func display_title(id: String) -> String:
	return title(id) if visited(id) or gs().map_id==id else TranslationServer.translate("Onbekende plek")

static func region_title(id: String) -> String:
	return title(id) if region_state(id)>0 else TranslationServer.translate("Onbekend gebied")

static func kind(id: String) -> String:
	if REGIONS.has(id):return TranslationServer.translate("Streek")
	if id in DUNGEONS:return TranslationServer.translate("Dungeon")
	return TranslationServer.translate("Arena") if id=="arena" else TranslationServer.translate("Gebouw")

static func visited_count(region: String="") -> int:
	var count := 0
	var ids: Array = Maps.MAPS.keys() if region=="" else locales(region)
	for id: String in ids:
		if visited(id):count+=1
	return count

static func connections() -> Array[Dictionary]:
	if not _connections.is_empty():return _connections
	var found: Dictionary = {}
	for source: String in Journey.graph():
		for portal: Dictionary in Journey.graph()[source]:
			if not portal.get("enabled",true):continue
			var a := region_for(source);var b := region_for(str(portal.to))
			if a=="" or b=="" or a==b:continue
			var mode := "ferry" if portal.type in ["coast_route","coast_dock"] else "land"
			var names: Array[String] = [a,b];names.sort()
			var key := ":".join(names)+":"+mode
			if not found.has(key):found[key]={"a":names[0],"b":names[1],"mode":mode,"directions":[]}
			found[key].directions.append({"from":source,"portal":portal})
	for edge: Dictionary in found.values():_connections.append(edge)
	return _connections

static func connection_locked(edge: Dictionary) -> bool:
	for direction: Dictionary in edge.directions:
		if not Journey.portal_open(direction.from,direction.portal):return true
	return false

static func route_hint(id: String) -> String:
	if state(id)==2:return TranslationServer.translate("Je bent hier.")
	if not visited(id):return TranslationServer.translate("Nog niet bezocht. Ontdek deze plek tijdens je reis.")
	var route := Journey.path(gs().map_id,id)
	if route.is_empty():
		var closed := Journey.path(gs().map_id,id,false)
		for i in range(closed.size()-1):
			for portal: Dictionary in Journey.graph()[closed[i]]:
				if portal.to==closed[i+1] and not Journey.portal_open(closed[i],portal):
					return TranslationServer.translate("Route gesloten. %s") % TranslationServer.translate(portal.get("locked_text","Onderzoek de doorgang ter plaatse."))
		return TranslationServer.translate("Volg de bestaande doorgangen naar deze plek.")
	return TranslationServer.translate("Volgende doorgang: %s.") % display_title(route[1]) if route.size()>1 else ""

static func neighbor(id: String,direction: Vector2) -> String:
	var best := id;var score := INF
	for candidate: String in REGIONS:
		if candidate==id:continue
		var delta: Vector2 = REGIONS[candidate].at-REGIONS[id].at
		var forward: float = delta.normalized().dot(direction)
		if forward<0.2:continue
		var value: float = delta.length()/forward
		if value<score:score=value;best=candidate
	return best
