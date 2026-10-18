extends SceneTree
var AI: Script
const Maps:=preload("res://scripts/maps/registry.gd")
const Tiles:=preload("res://scripts/data/tiles.gd")
var Torch: Script
var Arrow: Script
var gs: Node
var world: Node2D
var p: Node2D
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
 print("  ok   " if ok else "  FAIL ",message)
 if not ok:failures+=1
func frames(n:=3):
 for i in n:await process_frame;await physics_frame
func enter(id: String):
 world.load_map(id,"start");await frames(8)
 p=world.player
 for n in get_nodes_in_group("enemies"):n.set_physics_process(false)
 p.set_physics_process(false);p.invuln=0;p.knockback=Vector2.ZERO
func foe(kind: String,at: Vector2) -> Node2D:
 var n: Node2D=world.spawn_enemy(kind,at);n.player=p;n.set_physics_process(false);n.set_meta("practice",true);return n
func reset_player():
 p.invuln=0;p.knockback=Vector2.ZERO;p.roll_timer=0;p.roll_cooldown=0;p.cooldown=0;p.combat.cancel();p.combat.recovery=0
 gs.movement.reset();gs.hp=gs.max_hp();gs.ended=false;paused=false
func arm(n: Node2D):
 n.state="idle";n.state_time=2;n.desired=Vector2.ZERO;AI.update(n,0.016)
func cover(at: Vector2) -> StaticBody2D:
 var b:=StaticBody2D.new();b.collision_layer=1;b.position=at
 var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(10,70);shape.shape=rect
 b.add_child(shape);world.entities.add_child(b);return b
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 AI=load("res://scripts/entities/habitat_enemy.gd");Torch=load("res://scripts/entities/torch.gd");Arrow=load("res://scripts/entities/arrow.gd")
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);await frames(10)
 # Data and saved slots: the enrichment changes exactly four enemy kinds.
 var changes:=0
 for kind in ["hb_root","hb_moth"]:
  for drop: Array in load("res://scripts/data/enemies.gd").info(kind).drops:
   check(drop[0] in ["coin","heart"] or load("res://scripts/data/items.gd").ITEMS.has(drop[0]),"new drop refers to real existing item "+str(drop[0]))
 for id: String in Maps.MAPS:
  var before: Dictionary=Maps.get_map(id);var after:=before.duplicate(true)
  # Reconstruct only the pre-habitat kinds, maintaining every other 0.18 field.
  for pair: Array in preload("res://scripts/data/habitat_maps.gd").REPLACEMENTS.get(id,[]):
   for obj: Dictionary in before.objects:
    if obj.type=="enemy" and Vector2i(obj.pos[0],obj.pos[1])==pair[0]:obj.kind="slime" if id=="forest" else "bat"
  for i in after.objects.size():
   if before.objects[i]!=after.objects[i]:
    var old: Dictionary=before.objects[i].duplicate();old.kind=after.objects[i].kind
    check(old==after.objects[i] and after.objects[i].get("enabled",true),"only enemy kind changed at original slot "+id+str(i));changes+=1
  if id=="forest":check(after.objects.filter(func(o):return o.type=="enemy" and not o.get("trail_wildlife",false) and o.get("enabled",true)).size()==18,"forest stays at eighteen occupied enemy places")
  if id=="forest_edge":check(after.objects.filter(func(o):return not o.get("trail_wildlife",false) and not o.get("id","").begins_with("trail:") and not o.get("id","").begins_with("forestfood:")).size()==5 and after.objects.filter(func(o):return o.type=="enemy" and not o.get("trail_wildlife",false)).is_empty(),"Bosrand scenic waterfall adds no encounters")
 check(changes==4,"exactly four replacements")
 for name in ["hb_root","hb_moth"]:
  var texture: Texture2D=load("res://assets/"+name+".png")
  check(texture.get_height()==24 and texture.get_width()==(120 if name=="hb_root" else 144),"original animated sheet "+name)
 await enter("forest")
 check(get_nodes_in_group("enemies").filter(func(n):return n.kind=="hb_root").size()==2,"both root replacements really spawn after route preparation")
 for n in get_nodes_in_group("enemies"):
  if n.kind=="hb_root":
   check(not world.is_solid(n.position+Vector2(0,8)) and not AI.protected(n,n.position),"root placement on free nonarrival floor")
 await enter("cave")
 check(get_nodes_in_group("enemies").filter(func(n):return n.kind=="hb_moth").size()==2,"both moth replacements really spawn after route preparation")
 check(get_nodes_in_group("enemies").filter(func(n):return n.kind=="rf_listener").size()==3,"quiet listening path retains its original listeners")
 for n in get_nodes_in_group("enemies"):
  if n.kind=="hb_moth":
   check(not world.is_solid(n.position+Vector2(0,8)) and not AI.protected(n,n.position),"moth placement away from arrival and rest")
 # Controlled encounters use existing open practice floor, with real physics bodies.
 await enter("watchyard")
 for n in get_nodes_in_group("enemies"):n.queue_free()
 await frames()
 var at:=Vector2(8.5,12.5)*32
 var root_foe:=foe("hb_root",at)
 p.position=at+Vector2(64,0);arm(root_foe)
 check(root_foe.state=="hb_root_warn" and root_foe.habitat_length>=64,"root locks its actual ground strip")
 var locked: Vector2=root_foe.aim_dir
 var hp: int=gs.hp
 root_foe.state_time=1;AI.update(root_foe,0.016)
 check(gs.hp==hp,"full warning has no early damage")
 p.position=at+Vector2(64,24);root_foe.state_time=1.11;AI.update(root_foe,0.016);AI.update(root_foe,0.016)
 check(gs.hp==hp and root_foe.aim_dir==locked,"side step clears fixed strip")
 p.position=at+Vector2(64,0);AI.update(root_foe,0.016)
 check(gs.hp==hp-1,"damage inside warned footprint")
 p.invuln=0;AI.update(root_foe,0.016)
 check(gs.hp==hp-1,"one root hit per attack")
 root_foe.state_time=0.19;AI.update(root_foe,0.016)
 check(root_foe.state=="hb_rest","root has long vulnerable recovery")
 var old_hp: int=root_foe.hp;root_foe.hurt(1,Vector2.LEFT)
 check(root_foe.hp==old_hp-1,"ordinary blade damages exposed recovery")
 root_foe.hp=root_foe.max_hp;arm(root_foe);old_hp=root_foe.hp
 root_foe.hurt(1,Vector2.LEFT)
 check(root_foe.hp==old_hp and root_foe.state=="hb_root_warn","closed bark blocks ordinary strike without cancelling warning")
 root_foe.break_guard();root_foe.hurt(1,Vector2.LEFT)
 check(root_foe.hp==old_hp-1 and root_foe.state=="hb_rest","technique interrupts and opens bark")
 # Real arrow flight, with the existing armor and precision path.
 var arrow: Node2D=Arrow.new();arrow.world=world;arrow.position=at+Vector2(60,4);arrow.direction=Vector2.LEFT;world.entities.add_child(arrow)
 arm(root_foe);old_hp=root_foe.hp;root_foe.guard_broken=0
 arrow._advance(64)
 check(arrow.state=="bounce" and root_foe.hp==old_hp,"ordinary flying arrow bounces off bark")
 arrow.queue_free()
 arrow=Arrow.new();arrow.world=world;arrow.precise=true;arrow.damage=1;arrow.position=at+Vector2(60,4);arrow.direction=Vector2.LEFT;world.entities.add_child(arrow)
 arrow._advance(64)
 check(root_foe.hp==old_hp-1 and root_foe.state=="hb_rest","real precise arrow opens bark")
 # Physical cover blocks both acquisition and the full-width strip.
 var wall:=cover(at+Vector2(40,8));await frames()
 root_foe.guard_broken=0;arm(root_foe)
 check(root_foe.state=="idle","root cannot acquire through real cover")
 root_foe.aim_dir=Vector2.RIGHT;root_foe.habitat_origin=at+Vector2(0,8)
 check(AI.clipped_length(root_foe,100,12)<36,"whole strip stops before solid body")
 wall.queue_free();await frames()
 # Roll protection is tested through the real player hurt rule, no permanent invulnerability.
 reset_player();p.position=at+Vector2(60,0);arm(root_foe)
 p.facing=Vector2.DOWN;p._roll();root_foe.state_time=1.11;AI.update(root_foe,0.016);AI.update(root_foe,0.016)
 check(gs.hp==gs.max_hp() and p.roll_timer>0,"real roll avoids root strike during safe window")
 reset_player()
 # Three real melee techniques retain different range/angle/damage opportunities.
 root_foe.queue_free();await frames()
 for weapon: String in ["wood","iron","crystal"]:
  gs.weapon=weapon;p.position=at;p.facing=Vector2.RIGHT;root.get_node("Controls").mouse_aim_active=false
  var n:=foe("hb_root",at+Vector2(44,0));n.state="hb_root_warn";n.state_time=0
  p.combat.begin(p,false);p.combat.update(p,0.5)
  check(n.hp<n.max_hp and n.state=="hb_rest","real "+weapon+" technique opens root")
  n.queue_free();reset_player();await frames()
 # An actual defeat resolves the existing material pickup and bestiary registration.
 var defeated:=foe("hb_root",at+Vector2(40,0));defeated.remove_meta("practice")
 defeated.data=defeated.data.duplicate(true);defeated.data.drops=[["prof_branch",1.0,1]];defeated.state="hb_rest"
 var before_kills: int=gs.kills
 defeated.hurt(99,Vector2.LEFT);await frames()
 check(gs.kills==before_kills+1 and gs.kills_by.get("hb_root",0)==1,"real defeat registers new kind")
 var found_drop:=false
 for pickup in get_nodes_in_group("pickups"):
  if pickup.item=="prof_branch":found_drop=true
 check(found_drop,"real defeat spawns existing branch pickup")
 # Moth responds to visible light, fixed flames and walls without touching damage.
 var moth:=foe("hb_moth",at)
 p.position=at+Vector2(48,0);p.light.enabled=false;moth.state_time=2;AI.update(moth,0.016)
 check(moth.state=="idle" and moth.desired==Vector2.ZERO,"unlit player causes no ambient moth attack")
 p.light.enabled=true;p.light.energy=1;arm(moth)
 check(moth.state=="hb_moth_warn","player lamp attracts short announced dive")
 var aim: Vector2=moth.aim_dir
 p.position=at+Vector2(48,25);moth.state_time=0.86;AI.update(moth,0.016)
 for i in 28:moth._physics_process(1.0/60.0)
 check(gs.hp==gs.max_hp() and moth.aim_dir==aim,"side step avoids actual moth movement")
 reset_player();moth.position=at;arm(moth);p.position=at+Vector2(48,0);arm(moth)
 moth.state_time=0.86;AI.update(moth,0.016)
 for i in 28:moth._physics_process(1.0/60.0)
 check(gs.hp==gs.max_hp()-1,"moth damages only within warned dive")
 reset_player();moth.position=at;p.position=at+Vector2(48,0);arm(moth)
 moth.hurt(1,Vector2.LEFT);check(moth.state=="hb_rest","ordinary hit interrupts moth warning")
 moth.knockback=Vector2.ZERO;moth.position=at
 var torch: Node2D=Torch.new();torch.world=world;torch.position=at+Vector2(0,-70);world.entities.add_child(torch)
 await frames();torch.light.enabled=true;torch.light.energy=1
 var target: Dictionary=AI.light_target(moth);check(target.get("fixed",false),"existing visible torch distracts instead of player lamp")
 arm(moth);check(moth.state=="idle" and moth.habitat_distracted,"flame stops aggressive preparation")
 p.position=torch.position
 for i in 150:moth._physics_process(1.0/60.0)
 check(gs.hp==gs.max_hp() and moth.position.distance_to(torch.position)<35,"moth settles near flame without touch damage")
 # Terrain/body cover also prevents attraction.
 torch.light.enabled=false;moth.position=at;p.position=at+Vector2(64,0)
 wall=cover(at+Vector2(40,8));await frames();arm(moth)
 check(moth.state=="idle" and AI.light_target(moth).is_empty(),"moth cannot follow light through wall")
 wall.queue_free();torch.queue_free();await frames()
 # Shared preparation budget with old foes in both directions.
 var ram:=foe("cv_ram",at+Vector2(70,40));ram.state="cv_warn"
 moth.state="idle";moth.state_time=2;p.position=at+Vector2(48,0);AI.update(moth,0.016)
 check(moth.state=="idle","moth waits while nearby old enemy prepares")
 ram.state="idle";moth.state="hb_moth_warn";moth.state_time=0
 check(not load("res://scripts/entities/combat_enemy.gd").slot_free(ram),"old ram also waits for new warning")
 ram.queue_free();moth.queue_free();await frames()
 # Rest and arrival immunity plus territory bounds: actual maps.
 await enter("cave")
 var n:=foe("hb_moth",Vector2(21.5,13.5)*32)
 p.position=Vector2(21.5,9.5)*32;arm(n)
 check(AI.protected(n,p.position) and n.state=="idle","altar rest cannot attract an attack")
 p.position=n.home_position+Vector2(170,0);arm(n)
 check(n.state=="idle","player outside territory cannot drag moth along route")
 for i in 200:n._physics_process(1.0/60.0)
 check(n.position.distance_to(n.home_position)<12,"moth returns without growing territory")
 n.queue_free()
 gs.set_flag("chest:forest:4");gs.kills_by["hb_root"]=1;gs.kills_by["hb_moth"]=2
 var saved:=p.position;gs.save_game(saved);gs.kills_by.clear();gs.flags.clear()
 check(gs.load_game() and gs.kills_by.get("hb_root")==1 and gs.kills_by.get("hb_moth")==2 and gs.flag("chest:forest:4"),"existing save format keeps new bestiary and old collection flags")
 gs.new_game();check(gs.kills_by.is_empty(),"new game resets new encounter history")
 world.queue_free();await frames()
 print("HABITAT OK" if failures==0 else "HABITAT FAILED "+str(failures))
 quit(0 if failures==0 else 1)
