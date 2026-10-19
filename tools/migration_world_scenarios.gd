extends RefCounted
## Synthetic, in-memory fixture states for the isolated phase-5 world exporter.
## They describe states to inspect, not playthroughs or a Unity implementation.
## Caller must discard the previous world BEFORE configure and load each map anew.

const Maps := preload("res://scripts/maps/registry.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Items := preload("res://scripts/data/items.gd")
const Farm := preload("res://scripts/core/homestead.gd")
const House := preload("res://scripts/core/personal_home.gd")
const Yard := preload("res://scripts/core/yard.gd")
const Stock := preload("res://scripts/core/stockroom.gd")
const Crops := preload("res://scripts/data/orchard_catalog.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const FIXTURE_SEED := 504034
static var current_id := ""

static func _descriptor(id: String, label: String, maps: Array, stage: String, fixtures: Array) -> Dictionary:
	return {"id":id,"label":label,"maps":maps,"stage":stage,"sourceFixtures":fixtures,"baseline":id=="fresh_baseline",
		"stateMode":"synthetic in-memory fixture, not a completed playthrough",
		"captureStage":"after world.load_map and exporter-controlled fixed initialization",
		"seed":FIXTURE_SEED,"offlineGrowth":false,"personalSavesUsed":false}

static func manifest() -> Array:
	var all_maps: Array=Maps.MAPS.keys();all_maps.sort()
	var living := ["res://tests/living_world_test.gd","res://scripts/core/living_world.gd"]
	var regional := ["res://tests/regional_test.gd","res://scripts/core/regional_adventures.gd"]
	var route := ["res://tests/first_route_test.gd","res://scripts/core/first_route.gd"]
	var farm := ["res://tests/homestead_test.gd","res://tests/orchard_test.gd"]
	return [
		_descriptor("fresh_baseline","Fresh adventure, all registered maps",all_maps,"fresh",["res://scripts/core/game_state.gd:new_game","res://tests/world_atlas_test.gd"]),
		_descriptor("opening_water_restored","Fountain restored and Greta introduction complete",["village","smithy"],"restored",["res://tests/opening_test.gd"]),
		_descriptor("opening_legacy","Older adventure without the new opening flag",["village"],"legacy",["res://tests/opening_test.gd"]),
		_descriptor("routines_evening","Fixed evening routines and all restored-memory residents",["village","lake","inn","harbor","prismamine","mistgarden","ijsdal","kruipmoeras","dorstvallei","reedvault","ridgepass"],"evening",["res://tests/opening_test.gd","res://tests/world_memory_test.gd","res://tests/lake_supper_test.gd"]),
		_descriptor("sluices_closed","Both marsh valves closed, bridge broken",["kruipmoeras"],"closed_closed",living),
		_descriptor("sluices_west","West open, east closed; before surveyed drainage completion",["kruipmoeras"],"open_closed",living),
		_descriptor("sluices_east","West closed, east open; unsafe valve setting",["kruipmoeras"],"closed_open",living),
		_descriptor("sluices_both","Both valves open; unsafe valve setting",["kruipmoeras"],"open_open",living),
		_descriptor("marsh_drained","Surveyed valves drained the archive bank, bridge unrepaired",["kruipmoeras","reedvault"],"drained",living),
		_descriptor("marsh_bridge","Archive bank drained and bridge repaired",["kruipmoeras","reedvault"],"bridge_repaired",living),
		_descriptor("tide_low","Low water at synthetic second 20",["tide_cove"],"low",["res://tests/tides_test.gd"]),
		_descriptor("tide_rising","Rising water at synthetic second 54",["tide_cove"],"rising",["res://tests/tides_test.gd"]),
		_descriptor("tide_high","High water at synthetic second 70",["tide_cove"],"high",["res://tests/tides_test.gd"]),
		_descriptor("tide_falling","Falling water at synthetic second 90",["tide_cove"],"falling",["res://tests/tides_test.gd"]),
		_descriptor("tide_held","High tide waits while player occupies formerly dry bank",["tide_cove"],"occupied_hold",["res://tests/tides_test.gd"]),
		_descriptor("tide_released","High tide closes only after occupied bank is cleared",["tide_cove"],"occupied_released",["res://tests/tides_test.gd"]),
		_descriptor("desert_wild","Spring restored, water directed to wildlife",["dorstvallei","sunwell"],"wildlife",regional),
		_descriptor("desert_caravan","Spring restored, reversible caravan water choice",["dorstvallei","sunwell"],"caravan",regional),
		_descriptor("ice_west","Only western houses heated",["ijsdal"],"west_heated",living),
		_descriptor("ice_restored","Both housing areas heated and mountain passage available",["ijsdal","ridgepass"],"both_heated",living),
		_descriptor("ridge_rope","Rope secured and climbing chart returned",["ridgepass","ijsdal"],"rope_completed",regional),
		_descriptor("archive_clues","Three archive folios found, chronology not resolved",["reedvault"],"evidence",regional),
		_descriptor("archive_routes","Archive reconstructed with routes exhibit",["reedvault","kruipmoeras"],"routes",regional),
		_descriptor("archive_stories","Archive reconstructed with stories exhibit",["reedvault","kruipmoeras"],"stories",regional),
		_descriptor("route_cat_home","Cat found and returned to the village",["forest","village"],"cat_home",route),
		_descriptor("route_clues","Relief and journal found before medallion return",["ruins","cave"],"clues",route),
		_descriptor("route_echo_begin","First echo bowl completed",["cave"],"echo_begin",route),
		_descriptor("route_echo_mid","First two echo bowls completed",["cave"],"echo_mid",route),
		_descriptor("route_echo_end","All echo bowls completed and refuge revealed",["cave"],"echo_end",route),
		_descriptor("route_memorial_guard","Completed memorial, guard inscription",["ruins","village"],"guard",route),
		_descriptor("route_memorial_guide","Completed memorial, guide inscription",["ruins","village"],"guide",route),
		_descriptor("mine_restored","Prism mine stabilized and workshop restored",["prismamine","smithy"],"mine_restored",living),
		_descriptor("forest_restored","Rune route reveals garden and resource",["dauwbos","mistgarden"],"forest_restored",living),
		_descriptor("home_furnished","Valid redesigned personal interior",["player_home"],"furnished",["res://tests/personal_home_test.gd"]),
		_descriptor("yard_moved","Existing wine vat moved without losing batch",["village"],"moved",["res://tests/yard_test.gd"]),
		_descriptor("yard_packed","Wine vat and beehive packed, saved production retained",["village"],"packed",["res://tests/yard_test.gd"]),
		_descriptor("yard_gate_far","Valid optional gate with distant player",["village"],"gate_closed",["res://tests/yard_test.gd"]),
		_descriptor("yard_gate_near","Same optional gate refreshes open near player",["village"],"gate_open",["res://tests/yard_test.gd"]),
		_descriptor("farm_dry","Planted vine and apple tree without connected water",["village"],"dry",farm),
		_descriptor("farm_irrigated","Connected brook channels and partial crop growth",["village"],"growing",farm),
		_descriptor("farm_disconnected","Source channel removed; downstream channels remain dry",["village"],"disconnected",farm),
		_descriptor("farm_ready","Ripe crops, established orchard, fertilizer and ready production",["village","player_home"],"ready",farm),
		_descriptor("honey_no_flowers","Tilled natural flowers, no pollen sources",["village"],"no_flowers",farm),
		_descriptor("honey_grown_flowers","Moved hive supported by ripe cultivated flowers and herbs",["village"],"grown_flowers",["res://tests/yard_test.gd","res://tests/orchard_test.gd"]),
		_descriptor("coastal_workshop","Coastal storage and placed shelf/sea lamp",["coast_workshop","harbor"],"furnished",["res://tests/coastal_home_test.gd"]),
		_descriptor("hollow_wheel","Tidal hollow wheel repairs physical crossing",["tidal_hollow"],"wheel",["res://tests/coastal_adventures_test.gd","res://scripts/core/coastal_adventures.gd"]),
		_descriptor("hollow_pool","Keeper resolved peacefully, pool restored",["tidal_hollow"],"pool",["res://tests/coastal_adventures_test.gd","res://scripts/core/coastal_adventures.gd"]),
		_descriptor("hollow_workwater","Keeper resolved through combat, workwater choice",["tidal_hollow"],"workwater",["res://tests/coastal_adventures_test.gd","res://scripts/core/coastal_adventures.gd"]),
		_descriptor("hollow_duel","Unresolved keeper duel projects live keeper",["tidal_hollow"],"duel",["res://tests/coastal_adventures_test.gd"]),
		_descriptor("headland_shelter","Completed pilot route restores physical wind shelter",["headland"],"shelter",["res://tests/coastal_adventures_test.gd"]),
		_descriptor("library_backroom","Lena returned books unlock physical library floor",["library"],"backroom_open",["res://tests/meer_test.gd","res://scripts/entities/meer_kast.gd"]),
		_descriptor("guardian_alive","Living dormant guardian with deferred pillars",["depths2"],"alive",["res://tests/diepte_test.gd"]),
		_descriptor("guardian_defeated","Defeated guardian projects unopened heart-container chest",["depths2"],"defeated",["res://tests/diepte_test.gd"]),
		_descriptor("guardian_reward_opened","Stable guardian heart chest key already opened",["depths2"],"reward_opened",["res://tests/diepte_test.gd"]),
		_descriptor("guardian_full_hearts","Defeated guardian reward substitutes potions/coins at eight hearts",["depths2"],"full_hearts",["res://tests/diepte_test.gd"]),
		_descriptor("saved_manure","Existing animal drop journal projects magnetic manure pickup",["forest"],"saved_drop",["res://tests/homestead_test.gd","res://scripts/core/homestead.gd"]),
		_descriptor("boss_gate_closed","Boss trigger consumed and temple exit sealed; enemy AI state is not fabricated",["temple"],"boss_started",["res://scripts/maps/temple.gd","res://tests/whole_adventure_test.gd"]),
		_descriptor("full_progress","Synthetic completed quests, opened real slot keys, earned world changes",all_maps.duplicate(),"completed_synthetic",["res://tests/whole_adventure_test.gd","res://tests/living_world_test.gd","res://tests/first_route_test.gd"]),
		_descriptor("legacy_completed","Legacy completed quests before three load_map migrations",["ijsdal","kruipmoeras","dorstvallei","ruins","cave"],"legacy_completed",["res://tests/living_world_test.gd","res://tests/regional_test.gd","res://tests/first_route_test.gd"]),
	]

static func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")

static func _flags(ids: Array) -> void:
	for id: String in ids:_gs().flags[id]=true

static func _quest(id: String, state: String="done", step: int=-1) -> void:
	assert(Quests.QUESTS.has(id),"Scenario must use an existing quest ID: "+id)
	var last: int=Quests.QUESTS[id].steps.size()-1
	_gs().quests[id]={"state":state,"step":last if step<0 else step}

static func _revision_flags() -> void:
	_flags(["lw_revision_1","ra_revision_1","rf_revision_1"])

static func _opening() -> void:
	_flags(["op_water","op_grate","op_greta"])
	_quest("first_water")

static func _drained(bridge: bool=false) -> void:
	_flags(["lw_sluice_west","lw_sluice_west_seen","lw_sluice_east_seen","lw_drained"])
	_gs().flags.erase("lw_sluice_east")
	if bridge:_flags(["lw_bridge","lw_tailoring"])
	_quest("wilgentwijgen","done" if bridge else "active",1)

static func _heat(west_only: bool=false) -> void:
	_flags(["lw_heat_west"])
	if not west_only:_flags(["lw_heat_east","lw_heat"])
	_quest("warmte","active",0 if west_only else 1)

static func _desert(caravan: bool=false) -> void:
	_flags(["ra_prepared","ra_spring","ra_water_caravan" if caravan else "ra_water_wild"])
	_gs().inventory["ra_waterskin"]=1
	_quest("cactusvijgen")

static func _archive(stage: String) -> void:
	_flags(["ra_folio_reed","ra_folio_port","ra_folio_flood"])
	_quest("ra_archive","active",0)
	if stage!="clues":
		_drained(true)
		_flags(["ra_archive_done"])
		if stage=="routes":_flags(["ra_exhibit_routes"])
		_quest("ra_archive")
		_gs().inventory["gear_ra_compass"]=1

static func _route_clues() -> void:
	_flags(["rf_relief","rf_journal"])
	_quest("rf_memory","active",1)
	_quest("medaillon","active",0)

static func _echo(stage: int) -> void:
	_route_clues()
	var steps := ["rf_echo_begin","rf_echo_mid","rf_echo_end"]
	for index in range(stage):_flags([steps[index]])
	_quest("rf_echo","done" if stage==3 else "active",mini(stage,2))
	if stage==3:_gs().inventory["gear_rf_cord"]=1

static func _memorial(guide: bool=false) -> void:
	_echo(3)
	_quest("medaillon")
	_quest("rf_memory")
	_flags(["rf_memorial","rf_guide" if guide else "rf_guard"])
	_gs().inventory["gear_rf_keepsake"]=1

static func _house() -> void:
	var data: Dictionary=House.defaults()
	data.layout.bed.cell=[2,2];data.layout.table.cell=[4,9]
	data.floor=1;data.wall=1;data.light=1
	data.layout=House.candidate(data.layout,"chair:1","chair",Vector2i(4,10),1)
	data.layout=House.candidate(data.layout,"plant_leaf:1","plant_leaf",Vector2i(2,8),0)
	data.layout=House.candidate(data.layout,"lamp:1","lamp",Vector2i(10,9),2)
	assert(House.layout_reason(data.layout,data.owned)=="","Verified house fixture must remain valid")
	_gs().personal_home=data
	_gs().stockroom=Stock.normalize({"home":{"prof_log":12,"prof_branch":9,"hs_grape":15,"hs_fertilizer":6},"favorites":{"hs_grape":true},"sort":1})

static func _farm(stage: String) -> void:
	var gs: Node=_gs()
	_flags(["hs_supplies","or_starter"])
	gs.inventory={"hs_hoe":1,"hs_seed":8,"hs_flower_seed":4,"hs_manure":4,"hs_fertilizer":3,"hs_grape":9}
	var cells: Dictionary={"16,33":{"kind":"soil","crop":"grape","growth":0.0,"fertilized":false},"9,34":{"kind":"soil","crop":"apple","growth":0.0,"fertilized":false}}
	if stage!="dry":
		for x in range(11,20):cells[str(x)+",34"]={"kind":"channel"}
		cells["19,33"]={"kind":"channel"};cells["18,33"]={"kind":"channel"};cells["17,33"]={"kind":"channel"}
		cells["17,32"]={"kind":"channel"}
		cells["16,33"].growth=40.0;cells["9,34"].growth=120.0
	if stage=="disconnected":
		cells.erase("19,33");cells.erase("19,34")
	if stage=="ready":
		cells["16,33"].growth=90.0;cells["16,33"].fertilized=true
		cells["9,34"].growth=150.0;cells["9,34"].established=true
		var crops := ["carrot","pumpkin","mint","rosemary","berry"]
		for i in crops.size():
			cells[str(12+i)+",35"]={"kind":"soil","crop":crops[i],"growth":float(Crops.CROPS[crops[i]].seconds),"fertilized":i==1}
		cells["16,32"]={"kind":"soil","crop":"flower","growth":60.0,"fertilized":false}
	gs.homestead=Farm.normalize({"cells":cells,"jobs":{"wine_a":{"batches":2,"time":90.0 if stage=="ready" else 42.0},"wine_b":{"batches":1,"time":20.0},"compost":{"batches":1,"time":30.0 if stage=="ready" else 10.0}},"honey":2,"honey_time":45.0})
	gs.yard=Yard.defaults();gs.yard.extensions=["west"]
	Farm.dirty=true

static func _full_progress() -> void:
	var gs: Node=_gs()
	_opening();_drained(true);_heat();_desert();_archive("routes");_memorial(true)
	_flags(["gate_ruin","gate_temple","boss_started","boss_defeated","game_completed","diepte_opened","guardian_defeated","chest:depths2:heart","meer_achterkamer","golem_ruins","boog_bos_a","boog_bos_b","boog_ruine_a","boog_ruine_b","cat_found","cat_home","lw_mine","lw_workshop","lw_clues","lw_forest","ra_rope_kit","ra_rope","ra_chart","ra_ridge_done","ls_basket","ls_cooked","ls_served","cw_raf_notes","ad_wheel_done","ad_keeper_done","ad_pool","ad_pilot_done"])
	gs.flags.erase("ra_water_caravan")
	for id: String in Quests.QUESTS:_quest(id)
	for id: String in Items.ITEMS:gs.inventory[id]=1
	gs.weapon="star";gs.coins=999;gs.hero_xp=9999
	var arena: Script=load("res://scripts/data/arena.gd")
	for rank: String in arena.ORDER:gs.flags[arena.DONE_FLAG % rank]=true
	for map_id: String in Maps.MAPS:
		var objects: Array=Maps.get_map(map_id).objects
		for index in objects.size():
			var obj: Dictionary=objects[index]
			if obj.type=="chest" or (obj.type=="pickup" and obj.get("unique",false)):
				gs.flags["%s:%s:%d" % [obj.type,map_id,index]]=true
			if obj.type=="enemy" and obj.get("flag","")!="":gs.flags[obj.flag]=true
			if obj.type=="savepoint":gs.flags["altaar_%s_%d_%d" % [map_id,int(obj.pos[0]),int(obj.pos[1])]]=true
	_farm("ready");_house()
	# Farm supplies are a bounded fixture; preserve completed quest possessions too.
	for id: String in Items.ITEMS:
		if not gs.inventory.has(id):gs.inventory[id]=1
	gs.hp=gs.max_hp()

static func configure(id: String) -> Dictionary:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):
		push_error("Migration world scenarios require an isolated Bluemap-Codex-Tests-* user directory.")
		return {}
	var selected: Dictionary={}
	for entry: Dictionary in manifest():
		if entry.id==id:selected=entry;break
	if selected.is_empty():
		push_error("Unknown migration world scenario: "+id)
		return {}
	current_id=id
	var gs: Node=_gs()
	gs.in_game=false;gs.set_process(false)
	gs.meta_achievements={};gs.achievements={};gs.new_game()
	gs.meta_achievements={};gs.achievements={};gs.achievement_queue.clear()
	gs._achievements_dirty=false;gs._achievement_timer=gs.ACHIEVEMENT_INTERVAL
	gs.day_time=0.4;gs.day_count=2;gs.play_time=600.0
	gs.load_pos=Vector2.ZERO;gs.use_load_pos=false
	gs.in_game=true;gs.set_process(false)
	seed(FIXTURE_SEED)
	for action: StringName in InputMap.get_actions():Input.action_release(action)
	var arena: Script=load("res://scripts/data/arena.gd");arena.run_active=false;arena.run_owner=0
	for path: String in ["living_world","regional_adventures","first_route","coastal_region","lake_supper"]:
		var logic: Script=load("res://scripts/core/"+path+".gd");logic.pending=null
	load("res://scripts/core/lake_supper.gd").busy=false
	for path: String in ["yard","personal_home","stockroom","coastal_home","orchard"]:load("res://scripts/core/"+path+".gd").busy=false
	if id!="fresh_baseline" and id!="legacy_completed":_revision_flags()
	match id:
		"fresh_baseline":gs.play_time=0.0;gs.day_time=gs.Daynight.START;gs.day_count=0
		"opening_water_restored":_opening()
		"opening_legacy":gs.flags.erase("op_new_adventure")
		"routines_evening":
			_opening();_drained(true);_heat();_desert();_archive("routes")
			_flags(["ls_basket","ls_cooked","ls_served","lw_mine","lw_forest","ra_rope"]);_quest("ls_supper");gs.day_time=0.9
		"sluices_closed":pass
		"sluices_west":_flags(["lw_sluice_west"])
		"sluices_east":_flags(["lw_sluice_east"])
		"sluices_both":_flags(["lw_sluice_west","lw_sluice_east"])
		"marsh_drained":_drained()
		"marsh_bridge":_drained(true)
		"tide_low":gs.day_time=20.0/480.0
		"tide_rising":gs.day_time=54.0/480.0
		"tide_high":gs.day_time=70.0/480.0
		"tide_falling":gs.day_time=90.0/480.0
		"tide_held", "tide_released":gs.day_time=20.0/480.0
		"desert_wild":_desert()
		"desert_caravan":_desert(true)
		"ice_west":_heat(true)
		"ice_restored":_heat()
		"ridge_rope":_heat();_flags(["ra_rope_kit","ra_rope","ra_chart","ra_ridge_done"]);_quest("ra_ridge");gs.inventory["gear_ra_grip"]=1
		"archive_clues":_archive("clues")
		"archive_routes":_archive("routes")
		"archive_stories":_archive("stories")
		"route_cat_home":_flags(["cat_found","cat_home"]);_quest("kat")
		"route_clues":_route_clues()
		"route_echo_begin":_echo(1)
		"route_echo_mid":_echo(2)
		"route_echo_end":_echo(3)
		"route_memorial_guard":_memorial()
		"route_memorial_guide":_memorial(true)
		"mine_restored":_flags(["lw_mine","lw_workshop","lw_mirror_b_turn_1","lw_mirror_c_turn_2"]);_quest("prisma_herstel");gs.weapon="iron"
		"forest_restored":_flags(["lw_clues","lw_forest"]);_quest("mistsporen");gs.inventory["lw_lantern"]=1
		"home_furnished":_house()
		"yard_moved", "yard_packed":
			gs.yard=Yard.defaults();gs.yard.stations.wine_a=[5,27]
			gs.homestead=Farm.normalize({"jobs":{"wine_a":{"batches":2,"time":42}},"honey":2,"honey_time":45})
			if id=="yard_packed":gs.yard.stations.wine_a=[];gs.yard.stations.hive=[]
		"yard_gate_far", "yard_gate_near":
			gs.yard=Yard.defaults();gs.yard.extensions=["west"];gs.yard.fences["9,35"]="gate_h"
		"farm_dry":_farm("dry")
		"farm_irrigated":_farm("growing")
		"farm_disconnected":_farm("disconnected")
		"farm_ready":_farm("ready");_house()
		"honey_no_flowers":
			gs.homestead=Farm.normalize({})
			for at: Vector2i in Farm.FLOWERS:gs.homestead.cells[Farm.key(at)]={"kind":"soil"}
		"honey_grown_flowers":
			gs.yard=Yard.defaults();gs.yard.extensions=["east"];gs.yard.stations.hive=[28,32]
			gs.homestead=Farm.normalize({"cells":{"27,35":{"kind":"soil","crop":"mint","growth":85.0},"28,35":{"kind":"soil","crop":"rosemary","growth":110.0},"29,35":{"kind":"soil","crop":"flower","growth":60.0}},"honey":1,"honey_time":45})
		"coastal_workshop":
			_flags(["cw_raf_notes","cw_shelf_placed","cw_lamp_on","cw_lamp_sea"])
			gs.inventory={"cw_shelf":1,"cw_lamp":1};gs.coastal_storage={"cw_driftwood":12,"cw_reed":6}
		"hollow_wheel":_flags(["ad_wheel_done"])
		"hollow_pool", "hollow_workwater":_flags(["ad_wheel_done","ad_keeper_done","ad_pool" if id=="hollow_pool" else "ad_workwater"]);_quest("ad_keeper")
		"hollow_duel":_flags(["ad_duel"]);_quest("ad_keeper","active",0)
		"headland_shelter":_flags(["ad_pilot_done"]);_quest("ad_pilot")
		"library_backroom":_flags(["meer_achterkamer"]);_quest("meer_boeken")
		"guardian_alive":_flags(["game_completed","diepte_opened"]);_quest("diepte","active",1);gs.weapon="crystal"
		"guardian_defeated", "guardian_reward_opened", "guardian_full_hearts":
			_flags(["game_completed","diepte_opened","guardian_defeated"]);_quest("diepte");gs.weapon="star"
			if id=="guardian_reward_opened":_flags(["chest:depths2:heart"])
			if id=="guardian_full_hearts":gs.inventory["heart_container"]=3;gs.hp=8
		"saved_manure":
			gs.homestead=Farm.normalize({})
			for obj: Dictionary in Maps.get_map("forest").objects:
				if obj.type=="enemy" and obj.kind not in ["trail_moth","trail_gull"] and Enemies.info(obj.kind).get("behavior","")=="animal":
					var at:=Vector2i(int(obj.pos[0]),int(obj.pos[1]))
					var animal_id: String="forest:"+str(obj.kind)+":"+Farm.key(at)
					var drop_id: String=animal_id+":600000"
					gs.homestead.animal_due[animal_id]=690.0
					gs.homestead.drops[drop_id]={"map":"forest","pos":[at.x*32+16,at.y*32+16]}
					break
		"boss_gate_closed":_flags(["gate_temple","boss_started"]);_quest("main","active",2);gs.weapon="star"
		"full_progress":_full_progress()
		"legacy_completed":
			for quest: String in ["warmte","wilgentwijgen","cactusvijgen","medaillon"]:_quest(quest)
	Farm.dirty=true
	return {"scenario":selected.duplicate(true),"state":snapshot(),"limitations":["Direct synthetic state, not proof of reachability through normal play.","Per-node RNGs that call randomize(), moving actors, combat timers and transitions require exporter-controlled sampling; a global seed alone does not make them deterministic.","No personal save was read; no save/load or offline growth operation was invoked.","load_map may apply legacy migrations and inject map/object/resource state; export its result separately."]}

static func _record_call(calls: Array, node: Node, method: String, arguments: Array, reason: String) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():return
	assert(node.has_method(method),"Unknown whitelisted projection handler: "+method)
	var script: Script=node.get_script()
	node.callv(method,arguments)
	calls.append({"script":script.resource_path if script!=null else "", "method":method,"arguments":arguments,"reason":reason,"timeAdvanced":0.0})

static func project(world: Node) -> Array:
	## Deliberate allowlist, never a blanket _process(0) or a physics frame.
	## The exporter must freeze newly projected children and flush deferred calls.
	var calls: Array=[]
	var tree: SceneTree=Engine.get_main_loop()
	for child: Node in world.ground.get_children():
		var script: Script=child.get_script()
		if script==null:continue
		match script.resource_path:
			"res://scripts/entities/building_landmarks.gd", "res://scripts/entities/window_glow.gd":
				_record_call(calls,child,"_process",[0.0],"Resolve fixed-clock building/window light fields only; no interaction or time advancement.")
			"res://scripts/entities/living_scenery.gd":_record_call(calls,child,"refresh",[],"Apply flag-driven terrain and saved restoration actors without advancing time.")
			"res://scripts/entities/world_memory.gd":_record_call(calls,child,"refresh",[],"Project restored residents and fixed-clock rest routes.")
			"res://scripts/entities/first_route.gd":
				if _gs().map_id=="cave":_record_call(calls,child,"_process",[0.0],"Set refuge light visibility from rf_echo_end; cave branch does not move actors.")
			"res://scripts/entities/tide_cove.gd":
				if current_id in ["tide_held","tide_released"]:
					world.player.position=Vector2(25.5,25.5)*32;_gs().day_time=70.0/480.0
					_record_call(calls,child,"sync",[],"Occupied formerly dry bank holds high-tide collision open.")
					if current_id=="tide_released":
						world.player.position=Vector2(32.5,25.5)*32
						_record_call(calls,child,"sync",[],"Leaving the occupied bank permits flooding without a physics step.")
				else:_record_call(calls,child,"sync",[],"Resolve fixed tide clock to authored terrain/collision.")
			"res://scripts/entities/homestead.gd":
				if current_id=="saved_manure":_record_call(calls,child,"_process",[0.0],"Materialize saved drop journal only; empty tool mode and released inputs prevent work, delta is zero.")
	for child: Node in world.entities.get_children():
		var script: Script=child.get_script()
		if script==null:continue
		if script.resource_path in ["res://scripts/entities/npc.gd","res://scripts/entities/coast_resident.gd"] and child.get("exists_if") is Array:
			_record_call(calls,child,"_process",[0.0],"Resolve exists_if and zero-time NPC route state; no movement time advances.")
		elif script.resource_path=="res://scripts/entities/gate.gd":_record_call(calls,child,"_refresh",[true],"Resolve condition-based gate collision without interaction or key consumption.")
		elif script.resource_path in ["res://scripts/entities/house_furniture.gd","res://scripts/entities/torch.gd","res://scripts/entities/lantern.gd","res://scripts/entities/savepoint.gd","res://scripts/entities/window_glow.gd","res://scripts/entities/region_landmark.gd","res://scripts/entities/diepte_lamp.gd"]:
			_record_call(calls,child,"_process",[0.0],"Resolve saved ownership/style and fixed-clock native light fields only; no interaction, combat or movement.")
		elif script.resource_path=="res://scripts/entities/living_object.gd" and child.active==false:
			_record_call(calls,child,"_process",[0.0],"Resolve inactive restoration-object light then return before encounter/spawn/quest logic.")
		elif script.resource_path=="res://scripts/entities/coastal_workstation.gd":_record_call(calls,child,"_process",[0.0],"Apply saved coastal lamp ownership, on/off and sea-color fields; no time or movement advances.")
		elif script.resource_path=="res://scripts/entities/coastal_adventure.gd":_record_call(calls,child,"_process",[0.0],"Resolve keeper-rest interactability and saved shelter/wheel collider flags without advancing time.")
		elif script.resource_path=="res://scripts/entities/supper_actor.gd" and _gs().map_id=="lake" and child.wait_time>0 and child.path.is_empty():
			_record_call(calls,child,"_physics_process",[0.0],"Resolve fixed evening route while initial wait_time is positive and path empty; guarded branch cannot move_and_slide.")
		elif script.resource_path=="res://scripts/entities/coastal_adventure_director.gd" and current_id=="hollow_duel":
			_record_call(calls,child,"_process",[0.0],"Project unresolved saved keeper duel; no AI tick or combat advancement.")
		elif script.resource_path=="res://scripts/entities/yard_fence.gd" and current_id in ["yard_gate_far","yard_gate_near"]:
			world.player.position=child.position+Vector2(0,32 if current_id=="yard_gate_near" else 110)
			_record_call(calls,child,"_physics_process",[0.0],"Evaluate gate proximity hysteresis only; this direct zero-delta call does not step the physics engine.")
	Farm.irrigate()
	# diepte_seal._process is deliberately excluded: even delta zero may start a
	# story break transition. Frozen ready-state snapshots do not advance it.
	calls.append({"script":"res://scripts/core/homestead.gd","method":"irrigate","arguments":[],"reason":"Recompute connected-channel derived water state without growing crops.","timeAdvanced":0.0})
	return calls

static func snapshot() -> Dictionary:
	var gs: Node=_gs()
	var out: Dictionary={"seed":FIXTURE_SEED,"processEnabled":gs.is_processing()}
	for field: String in ["hp","coins","inventory","flags","quests","weapon","map_id","visited_maps","spawn_name","play_time","hero_xp","meer","professions","homestead","yard","personal_home","stockroom","coastal_storage","equipment","appearance","clothing","day_time","day_count","achievements","meta_achievements","arena_records","in_game","ended","transitioning","dialogue_open","save_is_ours"]:
		var value: Variant=gs.get(field)
		out[field]=value.duplicate(true) if value is Dictionary or value is Array else value
	return out
