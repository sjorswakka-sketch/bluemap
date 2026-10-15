extends "res://tests/coast_expedition_test.gd"
var Styles: Script
var Equipment: Script
func reset_style(bow:=false):
 p.combat.cancel();p.combat.recovery=0;p.combat.profile=Styles.profile(bow);p.combat.ranged=bow;p.combat.direction=Vector2.RIGHT;p.combat.elapsed=0.1
func foe(at: Vector2) -> Node2D:
 var e: Node2D=world.spawn_enemy("cv_ram",at);e.set_physics_process(false);e.set_meta("practice",true);return e
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true
 Styles=load("res://scripts/entities/coastal_styles.gd");Equipment=load("res://scripts/core/equipment.gd")
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(10)
 await enter("watchyard");p.set_physics_process(false);p.position=Vector2(10.5,12.5)*32
 for e in get_nodes_in_group("enemies"):e.queue_free()
 await frames()
 gs.give("gear_cw_anchor",1,true);gs.give("gear_cw_fan",1,true)
 check(Styles.profile(false).is_empty(),"owning a stance does not change combat")
 Equipment.equip("gear_cw_anchor");reset_style();p.combat.phase="prepare"
 check(not Styles.block(p.combat,p,p.position+Vector2(50,0)),"guard preparation has no invulnerability")
 p.combat.phase="guard"
 check(not Styles.block(p.combat,p,p.position+Vector2(-50,0)),"rear attack bypasses guard")
 check(not Styles.block(p.combat,p,p.position+Vector2(0,50)),"side attack bypasses guard")
 check(Styles.block(p.combat,p,p.position+Vector2(50,0)) and p.combat.phase=="counter","timely frontal guard arms one counter")
 check(not Styles.block(p.combat,p,p.position+Vector2(50,0)),"counter window cannot block a second hit")
 var front:=foe(p.position+Vector2(48,0));var side:=foe(p.position+Vector2(0,36))
 var hp: int=front.hp
 check(Styles.counter(p.combat,p) and front.hp==hp-2 and side.hp==side.max_hp,"counter is a directed thrust, not circular damage")
 check(not Styles.counter(p.combat,p) and front.hp==hp-2,"counter cannot repeat")
 reset_style();p.combat.phase="guard";p.combat.elapsed=.33
 check(not Styles.block(p.combat,p,p.position+Vector2(50,0)),"late guard does not block")
 reset_style();p.combat.phase="counter"
 var wall:=StaticBody2D.new();wall.collision_layer=1
 var collider:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(10,70);collider.shape=rect;wall.add_child(collider);wall.position=p.position+Vector2(25,0);world.entities.add_child(wall);await frames()
 hp=front.hp;Styles.counter(p.combat,p);check(front.hp==hp,"counter respects solid cover")
 wall.queue_free();front.queue_free();side.queue_free();await frames()
 Equipment.equip("gear_cw_fan");reset_style(true);p.combat.phase="prepare";gs.give("bow",1,true);gs.give("arrow",2,true)
 check(not Styles.arrows_ready(p) and not Styles.release_fan(p.combat,p) and gs.count("arrow")==2,"fan rejects partial ammunition without loss")
 gs.give("arrow",1,true)
 var a:=foe(p.position+Vector2(130,0));var b:=foe(p.position+Vector2(120,50));var c:=foe(p.position+Vector2(120,-50))
 check(Styles.release_fan(p.combat,p) and gs.count("arrow")==0,"fan commits exactly three arrows")
 await frames(42)
 check(a.hp==a.max_hp-1 and b.hp==b.max_hp-1 and c.hp==c.max_hp-1,"three real light arrows cover separate targets")
 reset_style(true);gs.give("arrow",3,true);Equipment.unequip("hands")
 check(not Styles.release_fan(p.combat,p) and gs.count("arrow")==3,"removing stance invalidates uncommitted fan")
 check(gs.kills==0 and gs.hero_xp==0,"prototype practice grants no kills or experience")
 world.queue_free();await frames();print("COASTAL STYLE PROTOTYPE OK" if failures==0 else "COASTAL STYLE PROTOTYPE FAILED "+str(failures));quit(0 if failures==0 else 1)
