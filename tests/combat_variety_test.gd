extends SceneTree
var ai: Script
var failures := 0
var gs: Node
var controls: Node
var world: Node2D
var p: Node2D
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("  ok   " if ok else "  FAIL ", message)
	if not ok: failures += 1
func frames(n := 3) -> void:
	for i in n: await process_frame; await physics_frame
func reset() -> void:
	p.combat.cancel()
	p.combat.recovery = 0
	p.cooldown = 0
	p.bow_cooldown = 0
	p.roll_timer = 0
	p.roll_cooldown = 0
	p.knockback = Vector2.ZERO
	gs.movement.reset()
	Input.action_release("technique")
func foe(kind: String, at: Vector2) -> Node2D:
	var n: Node2D = world.spawn_enemy(kind,at)
	n.player = p
	n.set_physics_process(false)
	return n
func event_key(code: int, down := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	return event
func run() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-") and OS.get_environment("XDG_DATA_HOME") == "": quit(1); return
	await frames()
	ai = load("res://scripts/entities/combat_enemy.gd")
	gs = root.get_node("GameState")
	controls = root.get_node("Controls")
	gs.new_game()
	gs.in_game = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	world.load_map("watchyard","start")
	await frames(8)
	p = world.player
	p.set_physics_process(false)
	p.invuln = 999
	p.position = Vector2(8.5,12.5)*32
	p.facing = Vector2.RIGHT
	controls.mouse_aim_active = false
	var guard := foe("lw_warden",p.position+Vector2(30,0))
	guard.aim_dir = Vector2.LEFT
	var hp: int = guard.hp
	gs.weapon = "wood"
	p._attack()
	check(guard.hp == hp,"normal frontal hit is blocked")
	reset()
	Input.parse_input_event(event_key(KEY_V))
	await frames()
	Input.parse_input_event(event_key(KEY_J))
	await frames()
	check(p.combat.phase == "prepare" and gs.movement.stamina == 84,"physical V + J starts wood technique and pays 16 stamina once")
	check(guard.hp == hp,"preparation does not damage early")
	p.combat.update(p,0.19)
	check(guard.guard_broken > 0 and guard.hp == hp-1,"committed thrust opens shield and hits")
	p._attack()
	check(guard.hp == hp-1,"recovery prevents instant extra light hit")
	Input.parse_input_event(event_key(KEY_J,false))
	Input.parse_input_event(event_key(KEY_V,false))
	guard.queue_free()
	await frames()
	for weapon: String in ["wood","iron","crystal"]:
		reset()
		gs.weapon = weapon
		var front := foe("cv_ram",p.position+Vector2(44,0))
		var side := foe("cv_ram",p.position+Vector2(-5,25))
		var far := foe("cv_ram",p.position+Vector2(70,0))
		p.combat.begin(p,false)
		p.combat.update(p,0.5)
		check(front.hp < front.max_hp,"front target hit with "+weapon)
		check((side.hp < side.max_hp) == (weapon == "iron"),"only wide iron technique hits side target")
		check((far.hp < far.max_hp) == (weapon == "crystal"),"only crystal technique reaches far target")
		front.queue_free(); side.queue_free(); far.queue_free()
		await frames()
	reset()
	gs.movement.stamina = 5
	p.combat.begin(p,false)
	check(p.combat.phase == "" and gs.movement.stamina == 5,"insufficient stamina neither starts nor charges a technique")
	p._attack()
	check(p.attack_timer > 0,"ordinary attack still available while stamina is low")
	reset()
	gs.give("bow",1,true)
	gs.give("arrow",8,true)
	var arrows: int = gs.count("arrow")
	p.combat.begin(p,true)
	check(gs.count("arrow") == arrows and p.combat.phase == "prepare","bow reserves no arrow during preparation")
	p._roll()
	check(p.combat.phase == "" and gs.count("arrow") == arrows,"roll cancels without consuming arrow")
	reset()
	p.combat.begin(p,true)
	paused = true
	await process_frame
	paused = false
	check(p.combat.phase == "" and gs.count("arrow") == arrows,"pause cancels prepared shot")
	reset()
	p.combat.begin(p,true)
	p.invuln = 0
	p.hurt(p.position-Vector2(30,0),1,"test")
	check(p.combat.phase == "","hit interrupts preparation")
	p.invuln = 999
	reset()
	p.combat.begin(p,true)
	p.facing = Vector2.UP
	p.combat.update(p,0.66)
	check(gs.count("arrow") == arrows-1,"precise shot consumes exactly one arrow on release")
	var found := false
	for shot in world.entities.get_children():
		if shot.get_script() == load("res://scripts/entities/arrow.gd") and shot.precise:
			found = shot.direction == Vector2.RIGHT and shot.damage == 3 and shot.max_range == 400
			shot.queue_free()
	check(found,"precise arrow uses committed direction, damage and reach")
	reset()
	p.combat.begin(p,false)
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	trigger.axis_value = 1.0
	Input.parse_input_event(trigger)
	await frames()
	check(controls.controller_active and p.combat.phase == "","switching device cancels preparation")
	check(Input.is_action_pressed("technique") and controls.action_label("technique") == "LT","left trigger is the active modifier")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_X
	button.pressed = true
	Input.parse_input_event(button)
	await frames()
	check(p.combat.phase == "prepare","controller LT + X starts technique")
	trigger.axis_value = 0
	Input.parse_input_event(trigger)
	button.pressed = false
	Input.parse_input_event(button)
	Input.parse_input_event(event_key(KEY_V))
	Input.parse_input_event(event_key(KEY_V,false))
	await frames()
	reset()
	p.position = Vector2(8.5,12.5)*32
	p.facing = Vector2.RIGHT
	var ram := foe("cv_ram",p.position+Vector2(100,0))
	ram.state_time = 2
	ai.update(ram,0.1)
	check(ram.state == "cv_warn","nearby ram warns before charging")
	var locked: Vector2 = ram.aim_dir
	p.position.y += 70
	ram.state_time = 0.86
	ai.update(ram,0.1)
	check(ram.state == "cv_charge" and ram.aim_dir == locked,"moving aside does not retarget committed ram")
	var slinger := foe("cv_slinger",p.position+Vector2(80,0))
	slinger.state_time = 2
	ai.update(slinger,0.1)
	check(slinger.state == "idle","nearby enemies leave one readable attack lane at a time")
	ram.state = "cv_rest"
	ai.update(slinger,0.1)
	check(slinger.state == "cv_warn","other attacker can act during ram recovery")
	slinger.hurt(1,Vector2.RIGHT)
	check(slinger.state == "cv_rest","hit interrupts thorn windup")
	ram.state = "idle"
	ram.position = Vector2(10.5,8.5)*32
	p.position = Vector2(12.5,8.5)*32
	ram.state_time = 2
	ai.update(ram,0.1)
	check(ram.state == "idle","rock blocks enemy acquisition")
	ram.state = "cv_charge"
	ram.aim_dir = Vector2.RIGHT
	ram.position.x = 11*32-12
	ai.update(ram,0.1)
	check(ram.state == "cv_rest","charging into rock creates recovery window")
	ram.position = Vector2(5.5,5.5)*32
	p.position = ram.position+Vector2(195,0)
	ram.state = "idle"
	ram.state_time = 2
	p.attack_timer = 0
	p.bow_anim = 0
	p.sprinting = false
	ai.update(ram,0.1)
	check(ram.state == "idle","quiet walking does not alert ram at long range")
	p.sprinting = true
	ram.state_time = 2
	ai.update(ram,0.1)
	check(ram.state == "cv_warn","sprinting attracts ram from farther away")
	p.sprinting = false
	ram.queue_free()
	slinger.queue_free()
	await frames()
	# Cover blocks a precise arrow even if an enemy overlaps its final step.
	p.position = Vector2(10.5,8.5)*32
	var covered := foe("cv_slinger",Vector2(11.5,8.5)*32)
	var arrow: Node2D = load("res://scripts/entities/arrow.gd").new()
	arrow.world = world
	arrow.position = p.position
	arrow.direction = Vector2.RIGHT
	world.entities.add_child(arrow)
	arrow.set_physics_process(false)
	arrow._advance(50)
	check(covered.hp == covered.max_hp and arrow.state == "stuck","solid cover wins over enemy overlap for player arrows")
	reset()
	p.facing = Vector2.RIGHT
	p.combat.begin(p,false)
	p.combat.update(p,0.5)
	check(covered.hp == covered.max_hp,"long technique cannot hit through solid cover")
	world.spawn_projectile("cv_thorn",p.position,Vector2.RIGHT,150,1,"test")
	var thorn: Node2D = world.entities.get_child(world.entities.get_child_count()-1)
	thorn.set_process(false)
	thorn._process(0.4)
	check(thorn.is_queued_for_deletion(),"thorn cannot tunnel through a rock during a long frame")
	arrow.queue_free()
	covered.queue_free()
	await frames()
	var post: Node2D = get_first_node_in_group("combat_posts")
	post.set_process(false)
	p.position = post.position+Vector2(0,35)
	post.interact()
	check(gs.dialogue_open,"practice starts with instructions")
	world.dialogue._close()
	await frames()
	post.interact()
	check(post.running and post.foes.is_empty(),"exercise gives spawn countdown")
	p.position = post.SPAWNS[0]
	post._process(3)
	check(post.foes.is_empty(),"never spawn practice enemy on player")
	p.position = post.position+Vector2(0,35)
	post._process(1)
	check(post.foes.size() == 1,"first lesson isolates the ram")
	var xp: int = gs.hero_xp
	post.foes[0].hurt(999,Vector2.RIGHT)
	await frames()
	post._process(0.1)
	check(not post.running and post.lesson == 1 and gs.hero_xp == xp,"practice completes without XP farming")
	post.interact()
	post._process(3)
	check(post.foes.size() == 1 and post.foes[0].kind == "cv_slinger","second lesson isolates ranged enemy")
	post.interact()
	await frames()
	check(not post.running and get_nodes_in_group("enemies").is_empty(),"stop removes exercise enemies")
	post.lesson = 2
	post.interact()
	post._process(3)
	check(post.foes.size() == 3,"final lesson combines ram, slinger and shield warden")
	var shield: Node2D = post.foes[2]
	var ranged: Node2D = post.foes[1]
	shield.set_physics_process(false)
	ranged.set_physics_process(false)
	shield.player = p
	shield.position = Vector2(13.5,10.5)*32
	ranged.position = shield.position+Vector2(60,-30)
	p.position = shield.position+Vector2(0,100)
	shield.desired = Vector2.ZERO
	load("res://scripts/entities/living_enemy.gd").update(shield,0.1)
	check(shield.desired.x > 0,"shield warden moves across to screen ranged ally")
	post.stop()
	await frames()
	# Migrate a real old custom controls file without stealing its V / LT bindings.
	var config := ConfigFile.new()
	config.set_value("keyboard","attack",[event_key(KEY_V,false)])
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_LEFT; lt.axis_value = 1.0
	config.set_value("controller","bow",[lt])
	config.save("user://controls.cfg")
	controls._load_bindings()
	controls._apply_bindings()
	check(controls.action_label("attack","keyboard") == "V" and controls.action_label("technique","keyboard") == "G","old V binding preserved with free G modifier")
	check(controls.action_label("bow","controller") == "LT" and controls.action_label("technique","controller") == "RT","old LT binding preserved with free RT modifier")
	check(controls.rebind("technique","keyboard",event_key(KEY_Z),false) == "","technique can be rebound through normal control system")
	controls.reset_bindings("keyboard",false)
	controls.reset_bindings("controller",false)
	p.set_physics_process(true)
	p.position = Vector2(13.5,20.5)*32
	await frames(80)
	check(gs.map_id == "forest" and not world.is_solid(world.player.position),"yard exit returns to clear forest tile")
	world.player.position = Vector2(3.5,27.5)*32
	await frames(80)
	check(gs.map_id == "watchyard","forest entrance leads into practice yard")
	world.queue_free()
	await frames()
	print("COMBAT VARIETY OK" if failures == 0 else "COMBAT VARIETY FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
