extends "res://tests/coastal_adventures_test.gd"
func enemy(kind: String) -> Node2D:
 for n in get_nodes_in_group("enemies"):
  if not n.is_queued_for_deletion() and n.kind==kind:return n
 return null
func wait_state(e: Node,state: String,limit:=210):
 for i in limit:
  if e.state==state:return true
  await physics_frame
 check(false,"state reached "+state+" actual="+str(e.state));return false
func reset_enemy(e: Node,position: Vector2):
 e.position=e.home_position;e.state="ad_idle";e.state_time=1.3;e.ad_hit=false;e.knockback=Vector2.ZERO;e.player=p;e.set_physics_process(true)
 p.position=position;p.invuln=0;p.velocity=Vector2.ZERO
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await enter("tidal_hollow")
 var crab:=enemy("ad_crab");var wisp:=enemy("ad_wisp");var hp: int=gs.hp
 reset_enemy(crab,crab.home_position+Vector2(0,80));await wait_state(crab,"ad_warn")
 var aim: Vector2=crab.aim_dir
 await frames(25);check(gs.hp==hp,"crab gives warning before damage")
 p.position=crab.ad_origin+Vector2(140,0);await frames(48)
 check(gs.hp==hp and crab.aim_dir==aim and crab.state=="ad_rest","lateral dodge escapes frozen cone and exposes recovery")
 crab.set_physics_process(false);crab.state="ad_idle"
 reset_enemy(crab,crab.home_position+Vector2(0,75));await wait_state(crab,"ad_warn");await frames(65)
 check(gs.hp==hp-1,"actual crab swing damages exposed player once")
 crab.set_physics_process(false);crab.state="ad_idle";gs.hp=gs.max_hp();hp=gs.hp
 reset_enemy(wisp,wisp.home_position+Vector2(90,0));await wait_state(wisp,"ad_warn");await frames(105)
 check(gs.hp==hp,"standing in declared ring opening is safe")
 reset_enemy(wisp,wisp.home_position+Vector2(90,0));await wait_state(wisp,"ad_warn")
 p.position=wisp.ad_origin+Vector2(-90,0);await frames(105)
 check(gs.hp==hp-1,"crossing closed ring sector takes one hit")
 wisp.set_physics_process(false);gs.hp=gs.max_hp();hp=gs.hp;p.invuln=0
 # Both creatures together must take turns and never attack the safe gang.
 crab.position=Vector2(15,14)*32;crab.home_position=crab.position
 wisp.position=Vector2(19,14)*32;wisp.home_position=wisp.position
 reset_enemy(crab,Vector2(17,14)*32);reset_enemy(wisp,Vector2(17,14)*32)
 var overlap:=false;var crab_attacks:=0;var wisp_attacks:=0
 for i in 300:
  await physics_frame
  if crab.state=="ad_swing":crab_attacks+=1
  if wisp.state=="ad_pulse":wisp_attacks+=1
  if crab.state in ["ad_warn","ad_swing"] and wisp.state in ["ad_warn","ad_pulse"]:overlap=true
  p.invuln=2
 check(crab_attacks>0 and wisp_attacks>0,"both enemy patterns participate in combined encounter")
 check(not overlap,"combined room serializes attack warnings and active damage")
 p.position=Vector2(17,30)*32;p.invuln=0;hp=gs.hp;await frames(260)
 check(gs.hp==hp and crab.state=="ad_idle" and wisp.state=="ad_idle","leaving territory cancels both attacks and protects southern gang")
 check(crab.position.distance_to(crab.home_position)<5 and wisp.position.distance_to(wisp.home_position)<5,"creatures return home instead of following the escape route")
 crab.set_physics_process(false);wisp.set_physics_process(false)
 # Deliberate opt-in, two separately readable swings, escape, persistent victory.
 gs.set_flag("ad_wheel_done");await open("sluice");await select(1,true);await frames(5)
 var keeper:=enemy("ad_keeper");check(keeper!=null and gs.flag("ad_duel") and not gs.flag("ad_keeper_done"),"workwater choice creates optional challenge without premature reward")
 reset_enemy(keeper,keeper.home_position+Vector2(0,80));await wait_state(keeper,"ad_warn")
 await wait_state(keeper,"ad_swing");await wait_state(keeper,"ad_warn2")
 check(keeper.ad_combo==1,"keeper announces second distinct swing")
 p.position=keeper.ad_origin+Vector2(85,0);await wait_state(keeper,"ad_rest")
 check(keeper.state_time<0.2,"second swing gives long punish window")
 p.position=Vector2(47,30)*32;p.invuln=0;await frames(130)
 check(keeper.state=="ad_idle" and not gs.input_locked(),"retreat cancels challenge attacks without sealing exit")
 keeper.set_physics_process(false);var xp: int=gs.hero_xp
 keeper.hurt(99,Vector2.UP);await frames(8)
 check(gs.flag("ad_workwater") and gs.flag("ad_keeper_done") and gs.flag("ad_keeper_defeated") and gs.hero_xp==xp+66,"duel resolves once with enemy and story experience")
 await enter("tidal_hollow");check(enemy("ad_keeper")==null,"defeated keeper does not respawn")
 # New Game+ uses existing HP scaling and old saves do not need new fields.
 gs.ng_plus=2;var scaled: Node2D=world.spawn_enemy("ad_crab",Vector2(14,12)*32)
 check(scaled.hp==gs.ng_hp(6),"new enemies use existing New Game+ scaling");scaled.queue_free()
 world.queue_free();await frames()
 print("COASTAL COMBAT OK" if failures==0 else "COASTAL COMBAT FAILED "+str(failures));quit(0 if failures==0 else 1)
