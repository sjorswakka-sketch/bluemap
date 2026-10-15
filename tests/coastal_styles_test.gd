extends "res://tests/coast_expedition_test.gd"
var Equipment: Script
func clear_attacks():
 p.combat.cancel();p.combat.recovery=0;p.cooldown=0;p.bow_cooldown=0;p.roll_timer=0;p.invuln=0;p.knockback=Vector2.ZERO
func foe(at: Vector2) -> Node2D:
 var e: Node2D=world.spawn_enemy("cv_ram",at);e.set_meta("practice",true);e.set_physics_process(false);return e
func key(code: int,down:=true):
 var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down;Input.parse_input_event(e)
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true
 Equipment=load("res://scripts/core/equipment.gd")
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(10)
 await enter("watchyard");p.set_physics_process(false);p.position=Vector2(10.5,12.5)*32;p.facing=Vector2.RIGHT;root.get_node("Controls").mouse_aim_active=false
 for e in get_nodes_in_group("enemies"):e.queue_free()
 await frames()
 gs.give("gear_cw_anchor",1,true);gs.give("gear_cw_fan",1,true);Equipment.equip("gear_cw_anchor");gs.movement.reset()
 var stamina: float=gs.movement.stamina
 key(KEY_V);await frames();key(KEY_J);await frames();key(KEY_J,false);key(KEY_V,false);await frames()
 check(p.combat.phase=="prepare" and gs.movement.stamina==stamina-18,"real technique keybind starts guard and charges once")
 var hp: int=gs.hp
 p.hurt(p.position+Vector2(50,0),3,"early")
 check(gs.hp==hp-2 and p.combat.phase=="","preparation remains vulnerable after armor")
 clear_attacks();p.combat.begin(p,false);p.combat.update(p,.13)
 check(p.combat.phase=="guard","short preparation enters timed guard")
 hp=gs.hp;p.hurt(p.position+Vector2(50,0),3,"front")
 check(gs.hp==hp and p.combat.phase=="counter","real frontal hit is blocked and arms counter")
 var e:=foe(p.position+Vector2(48,0));var health: int=e.hp
 p.facing=Vector2.LEFT;await tap(KEY_J)
 check(e.hp==health-2 and p.combat.recovery>0,"ordinary attack input commits one counter along locked direction")
 await tap(KEY_J);check(e.hp==health-2,"recovery prevents repeated counter")
 e.queue_free();clear_attacks();p.facing=Vector2.RIGHT;p.combat.begin(p,false);p.combat.update(p,.13)
 hp=gs.hp;p.hurt(p.position+Vector2(-50,0),1,"rear")
 check(gs.hp==hp-1 and p.combat.phase=="","rear hit bypasses real guard and interrupts")
 gs.hp=gs.max_hp();clear_attacks();p.combat.begin(p,false);p.combat.update(p,.13);p.combat.update(p,.33)
 check(p.combat.phase=="" and p.combat.recovery>0,"missed guard expires into recovery")
 clear_attacks();p.combat.begin(p,false);gs.set_ui("style_test",true);p.combat.update(p,.2);gs.set_ui("style_test",false)
 check(p.combat.phase=="","menu cancels guard")
 clear_attacks();Equipment.equip("gear_cw_fan");gs.give("bow",1,true);gs.give("arrow",2,true);gs.movement.reset()
 stamina=gs.movement.stamina;p.combat.begin(p,true)
 check(p.combat.phase=="" and gs.movement.stamina==stamina and gs.count("arrow")==2,"insufficient fan ammunition spends no stamina or arrows")
 gs.give("arrow",1,true);p.combat.begin(p,true);check(p.combat.phase=="prepare" and gs.count("arrow")==3,"fan announces preparation before committing ammunition")
 p._roll();check(p.combat.phase=="" and gs.count("arrow")==3,"dodge cancels prepared fan without arrow loss")
 clear_attacks();p.combat.begin(p,true);Equipment.unequip("hands");p.combat.update(p,.7)
 check(p.combat.phase=="" and gs.count("arrow")==3,"equipment removal cancels uncommitted fan")
 # Controller modifier + trigger uses the same actions, without mouse aiming.
 clear_attacks();Equipment.equip("gear_cw_fan");p.facing=Vector2.RIGHT
 var axis:=InputEventJoypadMotion.new();axis.axis=JOY_AXIS_TRIGGER_LEFT;axis.axis_value=1;Input.parse_input_event(axis);await frames()
 var shot:=InputEventJoypadMotion.new();shot.axis=JOY_AXIS_TRIGGER_RIGHT;shot.axis_value=1;Input.parse_input_event(shot);await frames()
 check(root.get_node("Controls").controller_active and p.combat.phase=="prepare","controller LT + RT starts fan through existing bindings")
 shot.axis_value=0;Input.parse_input_event(shot);axis.axis_value=0;Input.parse_input_event(axis);await frames()
 var a:=foe(p.position+Vector2(130,0));var b:=foe(p.position+Vector2(120,50));var c:=foe(p.position+Vector2(120,-50))
 p.combat.update(p,.6);await frames(45)
 check(gs.count("arrow")==0 and a.hp==a.max_hp-1 and b.hp==b.max_hp-1 and c.hp==c.max_hp-1,"live fan pays three arrows and covers three separate directions")
 a.queue_free();b.queue_free();c.queue_free();await frames()
 clear_attacks();gs.give("arrow",3,true);p.combat.begin(p,true);world.load_map("harbor","start");p.combat.update(p,.7)
 check(p.combat.phase=="" and gs.count("arrow")==3,"forced map change cancels fan without committing arrows on new map")
 await frames(6)
 await enter("coast_workshop");p.set_physics_process(true)
 var inventory: Dictionary=gs.inventory.duplicate(true);var kills: int=gs.kills;var xp: int=gs.hero_xp
 var practice: Node2D=load("res://scripts/entities/coastal_practice.gd").new();practice.world=world;world.ground.add_child(practice);practice.start();await frames()
 p.position=Vector2(22.5,13.5)*32;check(p._lent_arrow() and get_nodes_in_group("coastal_targets").size()==3,"explicit workshop practice loans arrows as a local capability")
 clear_attacks();p.set_physics_process(false);p.facing=Vector2.UP;p._update_aim();gs.movement.reset();p.combat.begin(p,true);check(p.combat.phase=="prepare","borrowed-arrow practice really starts a fan")
 p.combat.update(p,.6);await frames(45)
 check(gs.inventory==inventory and gs.kills==kills and gs.hero_xp==xp,"training uses borrowed arrows without inventory grants, loot or XP")
 Equipment.equip("gear_cw_anchor");gs.movement.reset();clear_attacks();p.set_physics_process(true)
 var dummy: Node2D=get_nodes_in_group("coastal_targets")[1];p.position=dummy.position+Vector2(0,28);p.facing=Vector2.UP
 await frames(4);await tap(KEY_E);await frames(29);p.combat.begin(p,false);await frames(22)
 check(p.combat.phase=="counter" and gs.hp==gs.max_hp(),"actual training cue arms timed guard without health damage")
 await enter("harbor");check(not p._lent_arrow() and get_nodes_in_group("coastal_targets").is_empty(),"leaving workshop removes targets and lending")
 world.queue_free();await frames();print("COASTAL STYLES OK" if failures==0 else "COASTAL STYLES FAILED "+str(failures));quit(0 if failures==0 else 1)
