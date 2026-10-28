extends SceneTree
## Calls original resident methods, with exact typed numeric witnesses.
const Fixture=preload("res://tools/migration_resident_motion_fixture.gd")
const Roam=preload("res://scripts/core/npc_roam.gd")
const Memory=preload("res://scripts/core/world_memory.gd")
var Draw:Script
var Village:Script
var Supper:Script
var Remember:Script
var gs:Node
var world:Node2D
var cases:Array=[]
func _initialize():call_deferred("run")
func exact(v:Variant)->Variant:
 if v is float:return {"$f64":PackedFloat64Array([v]).to_byte_array().hex_encode()}
 if v is Vector2:return {"$v2":PackedFloat32Array([v.x,v.y]).to_byte_array().hex_encode()}
 if v is Vector2i:return [v.x,v.y]
 if v is Dictionary:
  var d:Dictionary={}
  for k:Variant in v:d[str(k)]=exact(v[k])
  return d
 if v is Array or v is PackedVector2Array:
  var a:Array=[]
  for x:Variant in v:a.append(exact(x))
  return a
 return v
func row(id:String,kind:String,inputs:Dictionary,before:Variant,expected:Variant):
 cases.append({"id":id,"kind":kind,"inputs":exact(inputs),"before":exact(before),"expected":exact(expected)})
func reset(map:String="village",day:float=.3,flow:bool=true,water:bool=true):
 gs.new_game();gs.set_process(false);gs.in_game=true;gs.map_id=map;gs.day_time=day;gs.dialogue_open=false;gs.flags={"op_new_adventure":true,"op_water":flow,"ra_water_wild":water};gs.ng_plus=0
 world.player.position=Vector2(2000,2000);world.player.velocity=Vector2.ZERO;world.map_data={"objects":[],"weather":""};world.solid_cells={};world.blocked_points=[]
func snap(a:Node,kind:String)->Dictionary:
 var d:Dictionary={"position":a.position,"velocity":a.velocity}
 if kind=="npc":d.merge({"anchor":a.roam_anchor,"goal":a.roam_goal,"wait":a.roam_wait});return d
 if kind=="cat":return {"position":a.position,"panic":a.route_panic,"calm":a.route_calm,"waiting":a.route_wait}
 d.time=a.time;d.path=a.path.duplicate()
 if kind=="memory":d.merge({"wait":a.wait,"index":a.index,"stuck":a.stuck,"rest":a.rest,"key":a.route_key})
 elif kind=="supper":d.merge({"wait":a.wait_time,"index":a.route_index,"task":a.task_index,"stuck":a.stuck,"evening":a.evening})
 else:d.merge({"wait":a.wait_time,"index":a.route_index,"bubble":a.bubble_time,"key":a.mode})
 return d
func actor(kind:String,role:String="")->Node2D:
 var a:Node2D=(Village if kind=="village" else Supper if kind=="supper" else Remember if kind=="memory" else load("res://scripts/entities/npc.gd")).new()
 a.process_mode=Node.PROCESS_MODE_DISABLED;a.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE;a.world=world
 if kind in ["npc","cat"]:a.setup("muis_bos" if kind=="cat" else "greta")
 else:a.role=role
 world.entities.add_child(a);a.position=Vector2(336,336);a.velocity=Vector2.ZERO
 if kind in ["npc","cat"]:a.roam_anchor=a.position;a.roam_goal=a.position;a.roam_wait=0
 return a
func make_grid(width:int,height:int,solid:Array)->AStarGrid2D:
 var g:=AStarGrid2D.new();g.region=Rect2i(0,0,width,height);g.cell_size=Vector2(32,32);g.offset=Vector2(16,16);g.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;g.update()
 for c:Vector2i in solid:g.set_point_solid(c)
 return g
func run():
 var out:="";var args:=OS.get_cmdline_user_args()
 for i in args.size():
  if args[i]=="--output" and i+1<args.size():out=args[i+1]
 if out=="" or FileAccess.file_exists(out) or not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):push_error("Unsafe resident motion export");quit(1);return
 AudioServer.set_bus_mute(0,true);gs=root.get_node("GameState");gs.set_process(false);world=Fixture.new();world.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(world);current_scene=world
 Draw=load("res://scripts/core/character_draw.gd");Village=load("res://scripts/entities/village_actor.gd");Supper=load("res://scripts/entities/supper_actor.gd");Remember=load("res://scripts/entities/memory_actor.gd")
 # Routes call the actual three actor implementations at every discontinuity.
 for kind:String in ["village","supper","memory"]:
  var roles:Array=["gardener","courier"] if kind=="village" else ["joris","bo","nelle"] if kind=="supper" else Memory.PLACES.keys()
  for role:String in roles:
   for day:float in [.0,.12,.3,.52,.78,.7800000000000001,.95]:
    for flow:bool in [false,true]:
     for rest:bool in [false,true]:
      reset("village" if kind=="village" else "lake" if kind=="supper" else Memory.PLACES[role].map,day,flow,flow)
      var a:=actor(kind,role)
      if kind=="memory":a.rest=rest
      if kind=="supper":a.evening=rest
      row("route_%s_%s_%s_%s_%s"%[kind,role,PackedFloat64Array([day]).to_byte_array().hex_encode(),flow,rest],"route",{"actorKind":kind,"role":role,"map":gs.map_id,"day":day,"flow":flow,"water":flow,"rest":rest},null,a.route());a.free()
   if kind=="supper":
    reset("inn");var a:=actor(kind,role);row("route_inn_"+role,"route",{"actorKind":kind,"role":role,"map":"inn","day":.3,"flow":true,"water":true,"rest":false},null,a.route());a.free()
 # Exact AStar ordering, blocked starts/goals, detours, and symmetric ties.
 for layout:int in 9:
  var solid:Array=[]
  for x:int in 9:
   for y:int in 7:
    if layout>0 and ((x*17+y*13+layout*5)%11)<layout-1 and Vector2i(x,y) not in [Vector2i(0,0),Vector2i(8,6)]:solid.append(Vector2i(x,y))
  var grid:=make_grid(9,7,solid)
  for start:Vector2i in [Vector2i(0,0),Vector2i(4,3),Vector2i(8,6)]:
   for goal:Vector2i in [Vector2i(0,0),Vector2i(2,5),Vector2i(4,3),Vector2i(8,6)]:row("path_%d_%d_%d_%d_%d"%[layout,start.x,start.y,goal.x,goal.y],"path",{"width":9,"height":7,"solid":solid,"start":start,"goal":goal},null,grid.get_point_path(start,goal))
 # Actual safe() boundaries, object exclusions and half-open object rectangles.
 for label:String in ["clear","radius46","radius_over","npc26","npc_under","village_bank","tile_left","tile_bottom","object","disabled","ignored_npc","ignored_pickup","ignored_resource","ignored_trigger","rect_min","rect_max"]:
  reset();var a:=actor("npc");var p:=a.position;var others:Array=[]
  match label:
   "radius46":p+=Vector2(46,0)
   "radius_over":p+=Vector2(46.0001,0)
   "npc26","npc_under":
    var other:=actor("npc");other.position=p+Vector2(26 if label=="npc26" else 25.999,0);others.append(other)
   "village_bank":a.roam_anchor=Vector2(336,928);p=a.roam_anchor
   "tile_left":world.blocked_points=[p+Vector2(-8,0)]
   "tile_bottom":world.blocked_points=[p+Vector2(0,14)]
   _:
    if label not in ["clear","radius46","radius_over","npc26","npc_under","village_bank","tile_left","tile_bottom"]:
     world.map_data.objects=[{"type":label.trim_prefix("ignored_") if label.begins_with("ignored_") else "sign","pos":[10,10],"size":[1,1],"enabled":label!="disabled"}]
     if label=="rect_min":p=Vector2(306,336)
     if label=="rect_max":p=Vector2(366,336)
  var otherpos:Array=[]
  for other:Node2D in others:otherpos.append(other.position)
  row("safe_"+label,"safe",{"at":p,"anchor":a.roam_anchor,"map":gs.map_id,"objects":world.map_data.objects,"blockedPoints":world.blocked_points,"others":otherpos},null,Roam.safe(a,p))
  a.free()
  for other:Node in others:other.free()
 # Original motion branches, external path/collision boundaries explicitly taped.
 for kind:String in ["npc","village","supper","memory"]:
  for branch:String in ["wait","wait_cross","path_request","path_empty","arrive","last_arrive","move","blocked","stuck","mode_reset","locked","near","cat_excluded","choose","no_choices"]:
   reset("lake" if kind=="supper" else "mistgarden" if kind=="memory" else "village")
   var a:=actor(kind,"gardener" if kind in ["village","memory"] else "joris")
   var director:=Fixture.Director.new();world.add_child(director);director.grid=make_grid(40,36,[]);director.supplied=PackedVector2Array([a.position,a.position+Vector2(32,0)])
   var delta:=.125
   if kind!="npc":
    a.director=director
    if kind=="memory":a.route_key=str(a.route());a.wait=0
    else:a.wait_time=0
    if kind=="village":a.mode=str([true,false])
   else:a.roam_goal=a.position+Vector2(24,0)
   if branch in ["wait","wait_cross"]:
    a.set("roam_wait" if kind=="npc" else "wait" if kind=="memory" else "wait_time",.05 if branch=="wait_cross" else 2.0)
   if branch in ["arrive","last_arrive","move","blocked","stuck"]:
    if kind!="npc":a.path=PackedVector2Array([a.position] if branch=="last_arrive" else [a.position,a.position+Vector2(32,0)] if branch=="arrive" else [a.position+Vector2(32,17)])
   if branch=="stuck":
    if kind in ["memory","supper"]:a.stuck=.79 if kind=="memory" else .99
   if branch=="path_empty":director.supplied=PackedVector2Array()
   if branch=="mode_reset" and kind=="village":a.mode="old";a.path=PackedVector2Array([Vector2.ONE]);a.route_index=5
   if branch=="mode_reset" and kind=="memory":a.route_key="old";a.path=PackedVector2Array([Vector2.ONE]);a.index=5
   if branch=="mode_reset" and kind=="supper":gs.day_time=.9
   if branch=="locked":gs.dialogue_open=true;gs.ended=true
   if branch=="near":world.player.position=a.position+Vector2(61,0)
   if branch=="cat_excluded" and kind=="npc":a.npc_id="muis_bos"
   if branch in ["choose","no_choices"] and kind=="npc":
    a.roam_goal=a.position
    if branch=="no_choices":
     for step:Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:world.blocked_points.append(a.position+step*24+Vector2(-8,0))
   var blocking:StaticBody2D
   if branch in ["blocked","stuck"]:
    if kind=="npc":world.blocked_points=[a.position.move_toward(a.roam_goal,18*delta)+Vector2(-8,0)]
    else:
     a.path=PackedVector2Array([a.position+Vector2(32,0)])
     blocking=StaticBody2D.new();blocking.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE;blocking.position=a.position+Vector2(9,8);blocking.collision_layer=1;var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(4,200);shape.shape=box;blocking.add_child(shape);world.add_child(blocking)
     await physics_frame
   var before:=snap(a,kind);var supplied:PackedVector2Array=director.supplied.duplicate()
   seed(4401)
   if kind=="npc":Roam.update(a,delta)
   else:a._physics_process(delta)
   var after:=snap(a,kind)
   var choice:=0
   if kind=="npc" and before.goal==before.position and after.goal!=before.position:choice=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN].find((after.goal-before.position)/24)
   row("step_"+kind+"_"+branch,"step",{"actorKind":kind,"role":a.get("role") if kind!="npc" else "","id":a.get("npc_id") if kind=="npc" else "","map":gs.map_id,"day":gs.day_time,"flow":true,"water":true,"rest":false,"locked":gs.input_locked(),"delta":delta,"player":world.player.position,"supplied":supplied,"blockedPoints":world.blocked_points,"resolved":a.position,"resolvedVelocity":a.velocity,"drawWait":a.roam_wait if kind=="npc" and before.goal==before.position else 5.0,"drawChoice":choice},before,after)
   if is_instance_valid(blocking):blocking.free()
   a.free();director.free()
 # Pure animation functions use original directional tie and frame thresholds.
 for v:Vector2 in [Vector2.ZERO,Vector2(.999,0),Vector2(1,0),Vector2(-1,0),Vector2(0,-1),Vector2(0,1),Vector2(1,1),Vector2(1,-1),Vector2(-1,-1),Vector2(3,4)]:
  for t:float in [0.0,.199999999,.2,.4,1.7]:row("pose_%s_%s"%[PackedFloat32Array([v.x,v.y]).to_byte_array().hex_encode(),PackedFloat64Array([t]).to_byte_array().hex_encode()],"pose",{"velocity":v,"time":t,"previous":3},null,{"direction":Draw.direction(v,3),"frame":Draw.frame(t,v.length()>1)})
 # Actual dynamic occupancy algorithms; fresh grids clear departed occupants.
 for kind:String in ["memory","supper"]:
  for occupied:bool in [false,true]:
   reset("inn" if kind=="supper" else "mistgarden");world.map_size=Vector2i(40,36)
   var a:=actor(kind,"gardener" if kind=="memory" else "bo");a.position=Vector2(112,112)
   var director:Node2D=load("res://scripts/entities/world_memory.gd" if kind=="memory" else "res://scripts/entities/lake_supper.gd").new();director.process_mode=Node.PROCESS_MODE_DISABLED;director.world=world;world.add_child(director)
   if kind=="memory":director.actors={"gardener":a}
   var goal:=Vector2i(6,4);world.player.position=(Vector2(goal)+Vector2(.5,.5))*32 if occupied else Vector2(500,500)
   row("occupancy_"+kind+"_"+str(occupied),"occupancy",{"actorKind":kind,"width":40,"height":36,"solid":[],"actor":a.position,"goal":goal,"player":world.player.position,"others":[]},null,director.walk_path(a,goal))
   a.free();director.free()
 for label:String in ["clear","player","left_blocked","others","fallback","edge"]:
  reset("mistgarden");var director:Node2D=load("res://scripts/entities/world_memory.gd").new();director.process_mode=Node.PROCESS_MODE_DISABLED;director.world=world;world.add_child(director)
  var at:=Vector2i(6,4) if label!="edge" else Vector2i(0,0);var solid:Array=[];var others:Array=[]
  if label!="clear":world.player.position=(Vector2(at)+Vector2(.5,.5))*32
  if label=="left_blocked":solid=[at+Vector2i.LEFT]
  if label=="fallback":solid=[at,at+Vector2i.LEFT,at+Vector2i.RIGHT,at+Vector2i.DOWN,at+Vector2i.UP]
  director.grid=make_grid(40,36,solid);director.actors={}
  if label=="others":
   var other:=Node2D.new();other.position=(Vector2(at+Vector2i.LEFT)+Vector2(.5,.5))*32;world.entities.add_child(other);director.actors={"other":other};others=[other.position]
  row("spawn_"+label,"spawn",{"width":40,"height":36,"solid":solid,"at":at,"player":world.player.position,"others":others},null,director.safe_spawn(at))
  for other:Node in director.actors.values():other.free()
  director.free()
 var document:Dictionary={"schema":"bluemap.resident-motion.source-oracle.v1","engineVersion":Engine.get_version_info().string,"personalSavesUsed":false,"numericEncoding":"tagged-little-endian-ieee754-v1","randomPolicy":"original global random draws are explicit exogenous inputs; no cross-engine RNG sequence claim","physicsPolicy":"original collision-resolved position and velocity are explicit external boundaries; route, velocity, timers and decisions replay exactly","sourceMethods":["scripts/core/npc_roam.gd::safe","scripts/core/npc_roam.gd::update","scripts/entities/village_actor.gd::route","scripts/entities/village_actor.gd::_physics_process","scripts/entities/supper_actor.gd::route","scripts/entities/supper_actor.gd::_physics_process","scripts/entities/memory_actor.gd::route","scripts/entities/memory_actor.gd::_physics_process","scripts/entities/world_memory.gd::walk_path","scripts/entities/world_memory.gd::safe_spawn","scripts/entities/lake_supper.gd::walk_path","scripts/core/character_draw.gd::direction","scripts/core/character_draw.gd::frame"],"catalog":exact({"places":Memory.PLACES}),"cases":cases}
 var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(document,"\t",false,true)+"\n");f.close();print("MIGRATION RESIDENT MOTION EXPORT OK "+str(cases.size()));quit(0)
