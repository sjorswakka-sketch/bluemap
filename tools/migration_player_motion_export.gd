extends SceneTree
## Actual original stamina, terrain and player methods; invoke only through the UUID-isolating recorder.

const Equipment := preload("res://scripts/core/equipment.gd")
const Tiles := preload("res://scripts/data/tiles.gd")

func _initialize() -> void: _run.call_deferred()
func _f(value: float) -> String: return PackedFloat64Array([value]).to_byte_array().hex_encode()
func _v(value: Vector2) -> String: return PackedFloat32Array([value.x,value.y]).to_byte_array().hex_encode()
func _stamina(m: RefCounted) -> Dictionary:
	return {"stamina":_f(m.stamina),"delay":_f(m.regen_delay),"exhausted":m.exhausted,"capacity":_f(m.capacity()),"regenRate":_f(m.regen_rate()),"threshold":_f(m.recovery_threshold()),"canSprint":m.can_sprint(),"maxBonus":_f(Equipment.bonus("stamina_max")),"regenBonus":_f(Equipment.bonus("stamina_regen"))}
func _motor(p: Node2D) -> Dictionary:
	return {"facing":_v(p.facing),"aim":_v(p.aim_direction),"rollDirection":_v(p.roll_dir),"knockback":_v(p.knockback),"velocity":_v(p.velocity),"rollTimer":_f(p.roll_timer),"rollCooldown":_f(p.roll_cooldown),"walkTime":_f(p.walk_time),"stepDistance":_f(p.step_distance),"moving":p.moving,"sprinting":p.sprinting,"rollSafe":p.roll_timer>p.ROLL_TIME-p.ROLL_SAFE_TIME}
func _input(direction: Vector2, sprint: bool) -> Vector2:
	for action: String in ["move_left","move_right","move_up","move_down","sprint"]: Input.action_release(action)
	if direction.x<0:Input.action_press("move_left",-direction.x)
	if direction.x>0:Input.action_press("move_right",direction.x)
	if direction.y<0:Input.action_press("move_up",-direction.y)
	if direction.y>0:Input.action_press("move_down",direction.y)
	if sprint:Input.action_press("sprint")
	return Input.get_vector("move_left","move_right","move_up","move_down")
func _run() -> void:
	var output := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--output" and i+1<args.size():output=args[i+1]
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-") or output=="" or FileAccess.file_exists(output):
		push_error("Unverified isolated motion export");quit(1);return
	if _f(1.0)!="000000000000f03f" or _v(Vector2(1,0))!="0000803f00000000":push_error("Unsupported float byte order");quit(1);return
	var gs := root.get_node("GameState")
	gs.set_process(false);gs.new_game()
	var stamina_cases: Array=[]
	var fixtures: Array=[
		["full_run","advance",100.0,0.0,false,1.0,true,0.0],
		["last_partial","advance",1.0,0.0,false,0.1,true,0.0],
		["last_threshold","advance",0.0011,0.0,false,0.00001,true,0.0],
		["threshold_no_sprint","advance",0.001,0.0,false,0.1,true,0.0],
		["delay_equal","advance",0.0,0.8,true,0.8,false,0.0],
		["delay_excess","advance",0.0,0.8,true,1.0,false,0.0],
		["recovery_below","advance",24.0,0.0,true,0.02,true,0.0],
		["recovery_equal","advance",24.5,0.0,true,0.02,false,0.0],
		["zero_delta_clamps","advance",110.0,0.8,false,0.0,true,0.0],
		["negative_delta_clamps","advance",-1.0,0.8,false,-0.1,true,0.0],
		["long_frame","advance",100.0,0.0,false,10.0,true,0.0],
		["full_rest","reset",3.0,0.8,true,0.0,false,0.0],
		["spend_exact","spend",10.0,0.0,false,0.0,false,10.0],
		["spend_too_much","spend",10.0,0.0,false,0.0,false,10.01],
		["spend_exhausted","spend",50.0,0.0,true,0.0,false,1.0],
		["spend_zero","spend",50.0,0.0,false,0.0,false,0.0],
		["spend_negative","spend",50.0,0.0,false,0.0,false,-1.0],
		["spend_near_zero","spend",1.0005,0.0,false,0.0,false,1.0],
		["restore_full","restore",100.0,0.8,false,0.0,false,1.0],
		["restore_part","restore",20.0,0.8,true,0.0,false,4.0],
		["restore_threshold","restore",20.0,0.8,true,0.0,false,5.0],
		["restore_caps","restore",20.0,0.8,true,0.0,false,200.0],
		["restore_zero","restore",20.0,0.8,false,0.0,false,0.0],
		["restore_negative","restore",20.0,0.8,false,0.0,false,-1.0],
		["clamp_negative","clamp",-1.0,0.8,false,0.0,false,0.0],
		["clamp_releases","clamp",25.0,0.8,true,0.0,false,0.0]
	]
	for fixture: Array in fixtures:
		gs.new_game();gs.set_process(false)
		var m: RefCounted=gs.movement
		m.stamina=fixture[2];m.regen_delay=fixture[3];m.exhausted=fixture[4]
		var before:=_stamina(m)
		var factor: float=m.sprint_multiplier(fixture[5])
		var result:=false
		match fixture[1]:
			"advance":m.advance(fixture[5],fixture[6])
			"reset":m.reset()
			"spend":result=m.spend(fixture[7])
			"restore":result=m.restore(fixture[7])
			"clamp":m.clamp_capacity()
		stamina_cases.append({"id":fixture[0],"operation":fixture[1],"delta":_f(fixture[5]),"sprinting":fixture[6],"amount":_f(fixture[7]),"before":before,"factor":_f(factor),"result":result,"expected":_stamina(m)})
	var surfaces: Array=[]
	var surface_names: Array=Tiles.NAMES.duplicate();surface_names.append_array(["yard_boards","","unknown_future"])
	for tile: String in surface_names:surfaces.append({"tile":tile,"multiplier":_f(Tiles.movement_multiplier(tile)),"footstep":Tiles.footstep_surface(tile)})
	var equipment_cases: Array=[]
	for fixture: Dictionary in [
		{"id":"none","inventory":{},"equipment":{}},
		{"id":"boots","inventory":{"boots":1},"equipment":{}},
		{"id":"scout_climber_speed_cap","inventory":{"boots":1,"gear_scout_coat":1,"gear_ra_grip":1},"equipment":{"chest":"gear_scout_coat","hands":"gear_ra_grip"}},
		{"id":"heavy_armor_penalty","inventory":{"gear_bastion_coat":1},"equipment":{"chest":"gear_bastion_coat"}},
		{"id":"capacity_cap","inventory":{"gear_bronze_helm":1,"gear_rf_cord":1,"gear_ra_grip":1},"equipment":{"head":"gear_bronze_helm","neck":"gear_rf_cord","hands":"gear_ra_grip"}},
		{"id":"regen_cap","inventory":{"gear_crystal_amulet":1,"gear_rf_keepsake":1},"equipment":{"neck":"gear_crystal_amulet","ring":"gear_rf_keepsake"}},
		{"id":"unowned_equipment_no_bonus","inventory":{},"equipment":{"chest":"gear_scout_coat"}},
		{"id":"owned_not_equipped_no_bonus","inventory":{"gear_scout_coat":1},"equipment":{}}
	]:
		gs.new_game();gs.set_process(false);gs.inventory=fixture.inventory.duplicate(true);gs.equipment=fixture.equipment.duplicate(true)
		gs.movement.stamina=120.0;gs.movement.regen_delay=.4;gs.movement.exhausted=true
		var before:=_stamina(gs.movement)
		gs.movement.advance(1.0,false)
		equipment_cases.append({"id":fixture.id,"inventory":fixture.inventory,"equipment":fixture.equipment,"ownsBoots":gs.count("boots")>0,"moveBonus":_f(Equipment.bonus("move_speed")),"speedMultiplier":_f(gs.speed_multiplier()),"delta":_f(1.0),"before":before,"expected":_stamina(gs.movement)})
	gs.new_game();gs.set_process(false)
	# Load after autoload globals exist, just like the original game does. Only presentation/environment reads are substituted.
	var motion_script:=GDScript.new()
	motion_script.source_code='extends "res://scripts/entities/player.gd"\nvar oracle_tile := "grass"\nfunc ground_tile() -> String: return oracle_tile\nfunc _update_aim() -> void: pass\nfunc _update_target() -> void: pass\nfunc _update_shake(_delta: float) -> void: pass\n'
	if motion_script.reload()!=OK:push_error("Cannot load original motion adapter");quit(1);return
	var p: Variant=motion_script.new();p.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(p)
	p.set_physics_process(false);p.set_process(false)
	await physics_frame
	await process_frame
	var motions: Array=[]
	var motion_fixtures: Array=[
		["walk_grass",Vector2.RIGHT,false,"grass",100.0,false,false,false,Vector2.ZERO,0.0,0.0],
		["walk_path",Vector2.RIGHT,false,"path",100.0,false,false,false,Vector2.ZERO,0.0,0.0],
		["run_path",Vector2.RIGHT,true,"path",100.0,false,false,false,Vector2.ZERO,0.0,0.0],
		["run_diagonal",Vector2(1,-1),true,"grass",100.0,false,false,false,Vector2.ZERO,0.0,0.0],
		["analog_walk",Vector2(.4,.3),false,"snow",100.0,false,false,false,Vector2.ZERO,0.0,0.0],
		["partial_run",Vector2.RIGHT,true,"grass",.1,false,false,false,Vector2.ZERO,0.0,0.0],
		["exhausted_run",Vector2.RIGHT,true,"grass",0.0,true,false,false,Vector2.ZERO,0.0,0.0],
		["idle_regen",Vector2.ZERO,false,"grass",20.0,true,false,false,Vector2.ZERO,0.0,0.0],
		["locked_stamina",Vector2.RIGHT,true,"grass",20.0,false,true,false,Vector2.ZERO,0.0,0.0],
		["pushed_no_sprint",Vector2.RIGHT,true,"mud",40.0,false,false,false,Vector2(-30,4),0.0,0.0],
		["push_threshold",Vector2.RIGHT,true,"grass",40.0,false,false,false,Vector2(1,0),0.0,0.0],
		["rolling",Vector2.LEFT,true,"grass",40.0,false,false,false,Vector2.ZERO,.3,.7],
		["roll_safe_boundary",Vector2.RIGHT,false,"grass",40.0,false,false,false,Vector2.ZERO,.06,.2],
		["attack_no_sprint",Vector2.RIGHT,true,"grass",40.0,false,false,true,Vector2.ZERO,0.0,0.0],
		["aim_independent",Vector2.LEFT,false,"grass",40.0,false,false,false,Vector2.ZERO,0.0,0.0]
	]
	for fixture: Array in motion_fixtures:
		gs.new_game();gs.set_process(false);gs.in_game=true;gs.transitioning=fixture[6]
		p.position=Vector2(512,512);p.facing=Vector2.DOWN;p.aim_direction=Vector2.RIGHT;p.roll_dir=Vector2.DOWN;p.velocity=Vector2.ZERO
		p.knockback=fixture[8];p.roll_timer=fixture[9];p.roll_cooldown=fixture[10];p.walk_time=0.0;p.step_distance=21.0;p.moving=false;p.sprinting=false
		p.attack_timer=1.0 if fixture[7] else 0.0;p.bow_anim=0;p.oracle_tile=fixture[3];p.combat.cancel()
		gs.movement.stamina=fixture[4];gs.movement.exhausted=fixture[5];gs.movement.regen_delay=.2
		var direction:=_input(fixture[1],fixture[2])
		var before:=_motor(p)
		var stamina_before:=_stamina(gs.movement)
		var position_before: Vector2=p.position
		var steps: Array=[]
		var callback:=func(surface: String):steps.append(surface)
		p.footstep.connect(callback)
		p._physics_process(1.0/60.0)
		p.footstep.disconnect(callback)
		motions.append({"id":fixture[0],"direction":_v(direction),"sprint":fixture[2],"tile":fixture[3],"locked":fixture[6],"attack":fixture[7],"delta":_f(1.0/60.0),"speedMultiplier":_f(gs.speed_multiplier()),"distance":_f((p.position-position_before).length()),"before":before,"staminaBefore":stamina_before,"expected":_motor(p),"staminaExpected":_stamina(gs.movement),"footsteps":steps})
	var rolls: Array=[]
	for fixture: Array in [[Vector2.ZERO,0.0,0.0],[Vector2(-1,1),0.0,0.0],[Vector2.RIGHT,.01,0.0],[Vector2.RIGHT,0.0,.01]]:
		gs.new_game();gs.set_process(false);gs.in_game=true;p.facing=Vector2.LEFT;p.roll_dir=Vector2.DOWN;p.roll_timer=fixture[1];p.roll_cooldown=fixture[2]
		var direction:=_input(fixture[0],false)
		var before:=_motor(p)
		p._roll()
		rolls.append({"direction":_v(direction),"before":before,"expected":_motor(p)})
	gs.movement.stamina=17.0;p.knockback=Vector2(20,10);p.roll_timer=.2;p.roll_cooldown=.4;p.step_distance=13;p.walk_time=4;p.velocity=Vector2(12,5);p.moving=true;p.sprinting=true
	var transition_before:=_motor(p);var transition_stamina:=_stamina(gs.movement)
	p.stop_for_transition()
	var transition: Dictionary={"before":transition_before,"staminaBefore":transition_stamina,"expected":_motor(p),"staminaExpected":_stamina(gs.movement)}
	_input(Vector2.ZERO,false);p.free()
	var source_hashes: Dictionary={}
	for name: String in ["scripts/core/movement.gd","scripts/core/game_state.gd","scripts/core/equipment.gd","scripts/data/tiles.gd","scripts/entities/player.gd"]:source_hashes[name]=FileAccess.get_file_as_string("res://"+name).replace("\r\n","\n").sha256_text()
	var report: Dictionary={"schema":"bluemap.player.motion.source-oracle.v1","engineVersion":Engine.get_version_info().string,"float64Encoding":"ieee754-binary64-little-endian-hex","vectorEncoding":"ieee754-binary32-xy-little-endian-hex","stamina":stamina_cases,"surfaces":surfaces,"equipment":equipment_cases,"motions":motions,"rolls":rolls,"transition":transition,"personalSavesUsed":false,"sourceHashes":source_hashes,"sourceMethods":["scripts/core/movement.gd","scripts/data/tiles.gd::movement_multiplier","scripts/data/tiles.gd::footstep_surface","scripts/entities/player.gd::_physics_process","scripts/entities/player.gd::_roll","scripts/entities/player.gd::_update_footsteps","scripts/entities/player.gd::stop_for_transition"],"physicsAdapter":"Original CharacterBody2D methods; no world colliders. Actual measured distance is supplied to the C# post-collision stage.","excludedPresentationMethods":["ground_tile (explicit fixture)","_update_aim","_update_target","_update_shake"]}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:push_error("Cannot write motion oracle");quit(1);return
	file.store_string(JSON.stringify(report,"",true,true)+"\n");file.close()
	print("MIGRATION PLAYER MOTION EXPORT OK");quit(0)
