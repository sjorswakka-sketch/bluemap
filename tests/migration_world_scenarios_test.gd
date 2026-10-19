extends SceneTree
## Run only through the existing isolated UUID test-project wrapper.
const Fixtures := preload("res://tools/migration_world_scenarios.gd")
const Maps := preload("res://scripts/maps/registry.gd")
const Farm := preload("res://scripts/core/homestead.gd")
const House := preload("res://scripts/core/personal_home.gd")
const Yard := preload("res://scripts/core/yard.gd")
const Tide := preload("res://scripts/core/tides.gd")
var failures := 0

func _initialize() -> void:_run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("  ok   " if ok else "  FAIL ",message)
	if not ok:failures+=1

func _run() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):
		push_error("Scenario tests require an isolated Bluemap-Codex-Tests-* directory.");quit(1);return
	await process_frame
	var gs: Node=root.get_node("GameState")
	var entries: Array=Fixtures.manifest()
	var ids: Dictionary={}
	check(entries.size()>=40,"broad scenario manifest retained")
	for entry: Dictionary in entries:
		check(not ids.has(entry.id),"scenario ID unique: "+entry.id);ids[entry.id]=true
		check(not entry.maps.is_empty(),"scenario has target maps: "+entry.id)
		for map: String in entry.maps:check(Maps.MAPS.has(map),"actual map ID: "+entry.id+"/"+map)
		for source: String in entry.sourceFixtures:
			var path: String=source.split(":new_game")[0]
			check(FileAccess.file_exists(path),"source fixture exists: "+path)
		gs.meta_achievements={"not_a_real_achievement":true};gs.flags={"contamination":true}
		var first: Dictionary=Fixtures.configure(entry.id)
		check(not first.is_empty() and not gs.flags.has("contamination"),"configure resets previous state: "+entry.id)
		check(gs.achievements.is_empty() and gs.meta_achievements.is_empty(),"no inherited meta state: "+entry.id)
		check(not gs.is_processing(),"active-time clock frozen: "+entry.id)
		var repeated: Dictionary=Fixtures.configure(entry.id)
		check(JSON.stringify(first)==JSON.stringify(repeated),"configuration deterministic: "+entry.id)
		check(gs.save_is_ours==false and gs.day_count>=0,"synthetic state without a save owner: "+entry.id)
		if entry.id=="fresh_baseline":check(entry.maps.size()==37 and gs.play_time==0 and gs.flags=={"op_new_adventure":true},"all 37 untouched fresh registry maps")
		if entry.id in ["tide_low","tide_rising","tide_high","tide_falling"]:check(Tide.state(gs.day_time)==entry.stage,"fixed tide stage: "+entry.id)
		if entry.id in ["tide_held","tide_released"]:check(Tide.state(gs.day_time)=="low","occupied bank stages begin dry before explicit projection: "+entry.id)
		if entry.id in ["home_furnished","farm_ready","full_progress"]:check(House.layout_reason(House.state().layout,House.state().owned)=="","redesigned house fixture valid: "+entry.id)
		if entry.id in ["yard_moved","yard_packed"]:check(Yard.layout_reason(Yard.state(),Farm.state().cells)=="","yard fixture layout valid: "+entry.id)
	Fixtures.configure("farm_irrigated")
	check(Farm.watered(Vector2i(16,33)) and Farm.crop_watered(Vector2i(9,34),Farm.state().cells["9,34"]),"synthetic channels really connect to brook and orchard roots")
	Fixtures.configure("farm_disconnected")
	check(not Farm.watered(Vector2i(16,33)),"source removal leaves downstream irrigation dry")
	Fixtures.configure("honey_no_flowers");check(Farm.flowers()==0,"tilled natural flowers do not feed bees")
	Fixtures.configure("honey_grown_flowers");check(Farm.flowers()==3,"three ripe cultivated pollen plants feed moved hive")
	Fixtures.configure("legacy_completed")
	check(not gs.flag("lw_revision_1") and not gs.flag("ra_revision_1") and not gs.flag("rf_revision_1"),"legacy scenario is captured before migration")
	load("res://scripts/core/living_world.gd").migrate()
	load("res://scripts/core/regional_adventures.gd").migrate()
	load("res://scripts/core/first_route.gd").migrate()
	check(gs.flag("lw_bridge") and gs.flag("ra_spring") and gs.flag("rf_memorial"),"existing three migrations produce expected world consequences")
	for id: String in ["sluices_closed","sluices_west","sluices_east","sluices_both"]:
		Fixtures.configure(id);var before: Dictionary=gs.flags.duplicate(true)
		load("res://scripts/core/living_world.gd").migrate()
		check(gs.flags==before,"unsolved valve configuration survives load migration: "+id)
	print("MIGRATION WORLD SCENARIOS OK" if failures==0 else "MIGRATION WORLD SCENARIOS FAILED: "+str(failures))
	quit(0 if failures==0 else 1)
