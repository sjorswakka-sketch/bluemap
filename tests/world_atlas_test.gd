extends "res://tests/coast_expedition_test.gd"
const Atlas:=preload("res://scripts/core/world_atlas.gd")

func _save_fixture(data: Dictionary) -> void:
	var file:=FileAccess.open(gs.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()

func _mouse(at: Vector2) -> void:
	var move:=InputEventMouseMotion.new();move.position=at;move.global_position=at;move.relative=Vector2(6,0)
	Input.parse_input_event(move);await frames(2)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		Input.parse_input_event(event);await frames(2)

func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	gs=root.get_node("GameState");gs.new_game();gs.in_game=true
	# Every registered map has exactly one region, including all indoor/dungeon locales.
	var assigned: Dictionary={}
	for region: String in Atlas.REGIONS:
		for id: String in Atlas.locales(region):
			check(Atlas.valid_map(id) and not assigned.has(id),"locale exists once: "+id)
			assigned[id]=true
			check(Atlas.region_for(id)==region,"locale belongs to its geographical region: "+id)
	check(assigned.size()==37 and assigned.size()==Maps.MAPS.size(),"atlas covers all 37 maps across 19 regions")
	check(Atlas.REGIONS.steampeak.at.y<Atlas.REGIONS.ijsdal.at.y and Atlas.REGIONS.lake.at.y>Atlas.REGIONS.village.at.y,"north mountain and south lake preserve the game's geography")
	check(gs.visited_maps.is_empty(),"starting a new adventure does not pre-discover the world")
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(6);p=world.player
	check(gs.visited_maps=={"village":true},"actual first map load records only the village")
	var flags_before: Dictionary=gs.flags.duplicate(true)
	var inventory_before: Dictionary=gs.inventory.duplicate(true)
	Atlas.connections();Atlas.connections()
	check(gs.visited_maps.size()==1 and gs.flags==flags_before and gs.inventory==inventory_before,"inspecting geographical connections grants no visits, rewards or unlocks")
	for edge: Dictionary in Atlas.connections():
		check(not edge.directions.is_empty() and edge.a!=edge.b,"regional connection has real portal evidence "+edge.a+" → "+edge.b)
		for direction: Dictionary in edge.directions:
			check(Journey.graph()[direction.from].has(direction.portal),"connection comes from the actual game topology")
	check(Atlas.region_state("forest")==0 and Atlas.region_title("forest")=="Onbekend gebied" and Atlas.display_title("cave")=="Onbekende plek","unvisited regions and locales remain clearly unconfirmed")
	await enter("player_home")
	check(Atlas.current_region()=="village" and Atlas.state("player_home")==2 and Atlas.state("village")==1,"inside the home shows the current room within the village")
	await enter("lake")
	check(gs.visited_maps.size()==3 and Atlas.visited("player_home") and not Atlas.visited("forest"),"actual visits accumulate without marking intermediate maps")
	gs.record_map_visit("missing");check(not gs.visited_maps.has("missing"),"invalid map IDs cannot pollute the save")
	gs.save_game(p.position)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH))
	check(data.visited_maps.size()==3,"visit history is persisted in the existing save")
	gs.visited_maps={};check(gs.load_game() and gs.visited_maps.size()==3,"visits survive a real save/load round trip")
	# The first legacy import uses positive spatial proof only, never globally inherited unlocks or gear.
	data.erase("visited_maps");data.map="player_home"
	data.flags={"gate_temple":true,"lw_forest":true,"diepte_opened":true,"golem_ruins":false,"wm_met_courier":true,"chest:cave:2":false,"chest:bogus:3":true}
	data.talked=["librarian","meer_joris"]
	var cave_chest:="";var cave_pickup:="";var winter_altar:=""
	var cave_data:=Maps.get_map("cave")
	for i in cave_data.objects.size():
		var obj: Dictionary=cave_data.objects[i]
		if obj.type=="chest":cave_chest="chest:cave:%d" % i
		if obj.type=="pickup" and obj.get("unique",false):cave_pickup="pickup:cave:%d" % i
	for obj: Dictionary in Maps.get_map("ijsdal").objects:
		if obj.type=="savepoint":winter_altar="altaar_ijsdal_%d_%d" % [obj.pos[0],obj.pos[1]]
	check(cave_chest!="" and cave_pickup!="" and winter_altar!="","legacy proof fixtures match actual object IDs")
	data.flags[cave_chest]=true;data.flags[winter_altar]=true
	var migrated:=Atlas.restore_visits(data)
	check(migrated.has("player_home") and migrated.has("cave") and migrated.has("ijsdal") and migrated.has("ridgepass"),"legacy current location, actual chest, altar and resident meeting prove exact maps")
	check(not migrated.has("temple") and not migrated.has("ruins") and not migrated.has("mistgarden") and not migrated.has("inn"),"unlock flags, false flags, unknown chest keys and travelling NPCs prove no visit")
	var npc_library:=""
	for obj: Dictionary in Maps.get_map("library").objects:
		if obj.type=="npc":npc_library=str(obj.id)
	data.talked=[npc_library];data.flags={cave_pickup:true}
	var from_pickup:=Atlas.restore_visits(data)
	check(npc_library!="" and from_pickup.has("library") and from_pickup.has("cave"),"unique resident conversation and actual unique pickup are safe legacy evidence")
	data["visited_maps"]={"village":true,"forest":false,"lake":1,"fake":true}
	var normalized:=Atlas.restore_visits(data)
	check(normalized=={"village":true,"player_home":true},"new save history is normalized strictly without re-inferring evidence")
	data.erase("visited_maps");_save_fixture(data)
	check(gs.load_game() and gs.visited_maps.has("cave") and gs.visited_maps.has("library") and not gs.visited_maps.has("forest"),"real legacy save loading migrates conservatively")
	await enter("village")
	var menu: Node=world.menu_ui
	menu.open(menu.TAB_MAP);await frames(4)
	check(not menu.atlas_mode and not menu.atlas_page.visible,"local map and altar panel remain the default")
	await tap(KEY_H)
	check(menu.atlas_mode and menu.atlas_page.visible and menu.atlas_page.selected_region=="village","keyboard context shortcut opens the atlas on the current region")
	for language: String in ["nl","en"]:
		TranslationServer.set_locale(language)
		var labels: Array=menu.atlas_page.label_layout()
		check(labels.size()==19,"all known region labels have measured bounds in "+language)
		for i in labels.size():
			check(Rect2(2,2,608,378).encloses(labels[i].rect),"region label stays inside its map: "+language+" "+labels[i].id)
			for j in range(i+1,labels.size()):
				check(not labels[i].rect.grow(4).intersects(labels[j].rect.grow(4)),"region labels retain 8px space: "+language+" "+labels[i].id+" / "+labels[j].id)
	TranslationServer.set_locale("nl")
	gs.record_map_visit("temple");gs.flags.erase("gate_temple")
	var locked_hint:=Atlas.route_hint("temple")
	check(locked_hint.begins_with("Route gesloten.") and not Journey.path("village","temple",true).size(),"a visited but quest-locked destination keeps its real lock and explains it")
	var long_layout: Array=menu.atlas_page.hint_layout(locked_hint+" "+"Een lange uitleg over een gesloten doorgang en de zoektocht die daarbij hoort. ".repeat(10))
	check(long_layout.size()==3 and long_layout[-1].text.ends_with("…"),"long route hints visibly end within three lines")
	check(long_layout[-1].bottom<382 and long_layout[-1].bottom<403-14,"long gate explanations cannot overlap the separate current-location line")
	var before_map: String=gs.map_id;var before_visits: Dictionary=gs.visited_maps.duplicate(true);flags_before=gs.flags.duplicate(true)
	await tap(JOY_BUTTON_A,true)
	for i in 11:await tap(JOY_BUTTON_DPAD_DOWN,true)
	check(menu.atlas_page.focus_locales and menu.atlas_page.selected_locale==9 and menu.atlas_page.locale_scroll==3,"controller scroll follows the last village locale beyond the visible rows")
	await tap(JOY_BUTTON_A,true)
	check(gs.map_id==before_map and gs.visited_maps==before_visits and gs.flags==flags_before and not menu.travel_confirm,"atlas confirmation cannot travel, discover or bypass a quest gate")
	await tap(JOY_BUTTON_B,true)
	check(menu.atlas_mode and not menu.atlas_page.focus_locales,"controller Back first leaves the locale list")
	await tap(JOY_BUTTON_DPAD_UP,true)
	check(menu.atlas_page.selected_region!="village","controller navigates the geographical map spatially")
	await tap(JOY_BUTTON_B,true)
	check(not menu.atlas_mode and menu.active,"controller Back then returns to the working local map")
	await tap(JOY_BUTTON_Y,true)
	check(menu.atlas_mode,"controller Y switches local and world views")
	for view: Vector2i in [Vector2i(960,540),Vector2i(1152,648)]:
		root.size=view;await frames(3);menu._fit()
		var point: Vector2=menu.content.get_global_transform_with_canvas()*(menu.atlas_page.position+Atlas.REGIONS.harbor.at+menu.atlas_page.ORIGIN)
		await _mouse(point)
		check(menu.atlas_page.selected_region=="harbor","mouse selects a geographical region at "+str(view))
		menu.atlas_page.pointer(Vector2(668,menu.atlas_page.ROW_TOP+12))
		check(menu.atlas_page.focus_locales,"mouse enters the place list without traveling")
		menu.atlas_page.back()
		var toggle_point: Vector2=menu.content.get_global_transform_with_canvas()*menu.ATLAS_TOGGLE.get_center()
		await _mouse(toggle_point)
		check(not menu.atlas_mode,"mouse switches back at "+str(view))
		await _mouse(toggle_point)
		check(menu.atlas_mode,"mouse reopens the atlas at "+str(view))
	menu.close()
	gs.new_game();check(gs.visited_maps.is_empty(),"new adventure clears visits from the previous adventure")
	print("WORLD ATLAS OK" if failures==0 else "WORLD ATLAS FAILED")
	quit(0 if failures==0 else 1)
