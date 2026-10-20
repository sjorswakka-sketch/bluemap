extends SceneTree
## Read the original state/player methods in an isolated project; only run via record_migration_foundation_state.py.

func _initialize() -> void:
	_run.call_deferred()

func _float64_le(value: float) -> String:
	return PackedFloat64Array([value]).to_byte_array().hex_encode()

func _run() -> void:
	var output := ""
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size(): output = args[index + 1]
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-") or output == "" or FileAccess.file_exists(output):
		push_error("Unverified isolated foundation export"); quit(1); return
	if _float64_le(1.0) != "000000000000f03f":
		push_error("Foundation oracle requires little-endian Float64 bytes"); quit(1); return
	var gs := root.get_node("GameState")
	gs.set_process(false)
	gs.new_game()
	var condition_state := {"hp":4,"coins":23,"inventory":{"gel":2,"heart_container":2,"crystal_bos":5,"crystal_ruine":1},"flags":{"demo":true},"quests":{"main":{"state":"active","step":2},"done":{"state":"done","step":3}},"map":"village","weapon":"iron"}
	gs.hp=condition_state.hp;gs.coins=condition_state.coins;gs.inventory=condition_state.inventory.duplicate(true);gs.flags=condition_state.flags.duplicate(true);gs.quests=condition_state.quests.duplicate(true);gs.map_id=condition_state.map;gs.weapon=condition_state.weapon
	var inputs := [["flag","demo"],["flag","missing"],["no_flag","demo"],["no_flag","missing"],["quest","main","active"],["quest","done","done"],["quest","missing","none"],["step","main",2],["step","main",3],["step","done",3],["has","gel"],["has","gel",2],["has","gel",3],["has","missing"],["lacks","gel"],["lacks","gel",3],["lacks","missing"],["coins",23],["coins",24],["map","village"],["map","forest"],["weapon","iron"],["weapon","wood"],["crystals",2],["crystals",3],["hurt"]]
	var conditions: Array=[]
	for condition: Array in inputs: conditions.append({"condition":condition,"expected":gs.check(condition)})
	var clocks: Array=[]
	for fixture: Dictionary in [
		{"in_game":false,"ended":false,"transitioning":false,"ui_open":false,"external_paused":false,"delta":12.0,"day_time":0.15},
		{"in_game":true,"ended":false,"transitioning":false,"ui_open":false,"external_paused":false,"delta":24.0,"day_time":0.15},
		{"in_game":true,"ended":false,"transitioning":false,"ui_open":true,"external_paused":false,"delta":12.0,"day_time":0.15},
		{"in_game":true,"ended":false,"transitioning":false,"ui_open":false,"external_paused":true,"delta":12.0,"day_time":0.15},
		{"in_game":true,"ended":true,"transitioning":false,"ui_open":false,"external_paused":false,"delta":12.0,"day_time":0.15},
		{"in_game":true,"ended":false,"transitioning":true,"ui_open":false,"external_paused":false,"delta":12.0,"day_time":0.15},
		{"in_game":true,"ended":false,"transitioning":false,"ui_open":false,"external_paused":false,"delta":48.0,"day_time":0.9},
		{"in_game":true,"ended":false,"transitioning":false,"ui_open":false,"external_paused":false,"delta":960.0,"day_time":0.9},
		{"in_game":true,"ended":false,"transitioning":false,"ui_open":false,"external_paused":false,"delta":0.0,"day_time":0.5}
	]:
		gs.new_game();gs.set_process(false)
		gs.in_game=fixture.in_game;gs.ended=fixture.ended;gs.transitioning=fixture.transitioning;gs.day_time=fixture.day_time;gs.day_count=3;gs.play_time=17.5
		gs.set_ui("oracle",fixture.ui_open)
		paused=fixture.ui_open or fixture.external_paused
		var before: Dictionary=fixture.duplicate();before.erase("delta");before["play_time"]=gs.play_time;before["day_count"]=gs.day_count
		before["play_time_bits_le"]=_float64_le(gs.play_time);before["day_time_bits_le"]=_float64_le(gs.day_time)
		gs._process(fixture.delta)
		clocks.append({"before":before,"delta":fixture.delta,"delta_bits_le":_float64_le(fixture.delta),"expected":{"play_time":gs.play_time,"day_time":gs.day_time,"play_time_bits_le":_float64_le(gs.play_time),"day_time_bits_le":_float64_le(gs.day_time),"day_count":gs.day_count,"input_locked":gs.input_locked()}})
	paused=false;gs.new_game();gs.set_process(false)
	var player: Node2D=load("res://scripts/entities/player.gd").new()
	player.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(player)
	var controls:=root.get_node("Controls");controls.controller_active=false
	var targeting: Array=[]
	for fixture: Dictionary in [
		{"candidates":[{"id":"edge","x":40,"y":0}],"aiming":false,"aimX":1,"aimY":0,"locked":false},
		{"candidates":[{"id":"west","x":-8,"y":0},{"id":"east","x":12,"y":0}],"aiming":false,"aimX":1,"aimY":0,"locked":false},
		{"candidates":[{"id":"west","x":-8,"y":0},{"id":"east","x":12,"y":0}],"aiming":true,"aimX":1,"aimY":0,"locked":false},
		{"candidates":[{"id":"first","x":5,"y":0},{"id":"second","x":-5,"y":0}],"aiming":false,"aimX":1,"aimY":0,"locked":false},
		{"candidates":[{"id":"origin","x":0,"y":0},{"id":"east","x":15,"y":0}],"aiming":true,"aimX":1,"aimY":0,"locked":false},
		{"candidates":[{"id":"inside","x":39,"y":0}],"aiming":false,"aimX":1,"aimY":0,"locked":true}
	]:
		var nodes: Array=[]
		for candidate: Dictionary in fixture.candidates:
			var node:=Node2D.new();node.name=candidate.id;node.position=Vector2(candidate.x,candidate.y);root.add_child(node);node.add_to_group("interactable");nodes.append(node)
		controls.mouse_aim_active=fixture.aiming;player.aim_direction=Vector2(fixture.aimX,fixture.aimY);gs.set_ui("oracle",fixture.locked)
		player._update_target()
		var entry:=fixture.duplicate(true);entry["expected"]=str(player.target.name) if player.target else "";targeting.append(entry)
		for node: Node in nodes: node.free()
	gs.set_ui("oracle",false);player.free()
	var report: Dictionary={"schema":"bluemap.foundation.source-oracle.v1","engineVersion":Engine.get_version_info().string,"float64Encoding":"ieee754-binary64-little-endian-hex","conditionState":condition_state,"conditions":conditions,"clocks":clocks,"targeting":targeting,"personalSavesUsed":false,"sourceMethods":["scripts/core/game_state.gd::check","scripts/core/game_state.gd::_process","scripts/core/game_state.gd::input_locked","scripts/entities/player.gd::_update_target"]}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:push_error("Cannot write foundation oracle");quit(1);return
	file.store_string(JSON.stringify(report,"",true,true)+"\n");file.close()
	print("MIGRATION FOUNDATION STATE EXPORT OK")
	quit(0)
