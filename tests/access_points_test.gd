extends "res://tests/coast_expedition_test.gd"
## Geometry uses native foot-shape queries, not just a flood fill over grass tiles.
class TravelRecorder:
 extends Node
 var calls: Array=[]
 func travel(map_id: String,spawn: String):calls.append([map_id,spawn])
var report: Array=[]
const Access:=preload("res://scripts/core/access_points.gd")
var portal_script: Script
var query:=PhysicsShapeQueryParameters2D.new()
var foot:=CircleShape2D.new()
func portals() -> Array:
 return world.entities.get_children().filter(func(n):return n.get_script()==portal_script and not n.is_queued_for_deletion())
func freeze_geometry():
 p.set_physics_process(false);p.invuln=999
 for n in world.entities.get_children():
  if n==p:continue
  n.set_process(false);n.set_physics_process(false)
  if n.get_script()!=null and n.get_script().resource_path.ends_with("gate.gd"):
   n.collision_layer=0
 for n in world.ground.find_children("*","Node",true,false):n.set_process(false);n.set_physics_process(false)
func grid() -> AStarGrid2D:
 var result:=AStarGrid2D.new();result.region=Rect2i(Vector2i.ZERO,world.map_size*2);result.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;result.update()
 query.exclude=[p.get_rid()];query.collision_mask=1;query.shape=foot
 var space:=world.get_world_2d().direct_space_state
 for y in result.region.size.y:
  for x in result.region.size.x:
   var at:=Vector2(x,y)*16;query.transform=Transform2D(0,at+Vector2(0,8))
   var valid: bool=at.x>=8 and at.y>=8 and at.x<world.map_size.x*32-8 and at.y<world.map_size.y*32-8 and not world.is_solid(at+Vector2(0,8)) and space.intersect_shape(query,1).is_empty()
   result.set_point_solid(Vector2i(x,y),not valid)
 return result
func route(g: AStarGrid2D,target: Node) -> PackedVector2Array:
 var changed: Array[Vector2i]=[]
 for other in portals():
  if other==target:continue
  for y in range(int(other.rect.position.y/16),ceili(other.rect.end.y/16)):
   for x in range(int(other.rect.position.x/16),ceili(other.rect.end.x/16)):
    var at:=Vector2i(x,y)
    if g.is_in_boundsv(at) and not g.is_point_solid(at):g.set_point_solid(at);changed.append(at)
 var start:=Vector2i((p.position/16).round());var best:=PackedVector2Array()
 for y in range(int(target.rect.position.y/16),ceili(target.rect.end.y/16)):
  for x in range(int(target.rect.position.x/16),ceili(target.rect.end.x/16)):
   var at:=Vector2i(x,y)
   if not target.rect.grow(-4).has_point(Vector2(at)*16) or not g.is_in_boundsv(at) or g.is_point_solid(at) or g.is_point_solid(start):continue
   var candidate:=g.get_id_path(start,at)
   if not candidate.is_empty() and (best.is_empty() or candidate.size()<best.size()):
    best.clear()
    for point in candidate:best.append(Vector2(point)*16)
 for at in changed:g.set_point_solid(at,false)
 return best
func walk_every_entrance():
 for entry: Dictionary in report:
  await enter(entry.from);freeze_geometry();await frames(2)
  var portal: Node
  for n in portals():
   if n.target_map==entry.to and n.rect.position==Vector2(entry.pos[0],entry.pos[1])*32:portal=n;break
  if portal==null:check(false,"live door exists "+entry.from+" → "+entry.to);continue
  var path:=route(grid(),portal)
  if path.is_empty():check(false,"route still exists "+entry.from+" → "+entry.to);continue
  # Progression locks have their own tests. Walk the open physical route here.
  portal.conditions=[];portal.set_process(true);p.set_physics_process(true);p.invuln=999
  for goal in path:
   for i in 28:
    if gs.transitioning:break
    var delta: Vector2=goal-p.position
    release()
    if delta.length()<3:break
    if absf(delta.x)>2:Input.action_press("move_right" if delta.x>0 else "move_left")
    if absf(delta.y)>2:Input.action_press("move_down" if delta.y>0 else "move_up")
    await physics_frame;await process_frame
   if gs.transitioning:break
  release()
  for i in 80:
   if not gs.transitioning:break
   await frames(1)
  await frames(4);p=world.player
  var arrived: bool=gs.map_id==entry.to and not gs.transitioning and world.spawn_fits(p.position)
  check(arrived,"actual walking enters and arrives clear "+entry.from+" → "+entry.to)
  entry["walked"]=arrived
  entry["arrival"]=[p.position.x/32,p.position.y/32]
  entry["actual_map"]=gs.map_id
func feedback_cases():
 await enter("village");freeze_geometry()
 p.position=Vector2(7.5,22.5)*32;p.facing=Vector2.UP;p._update_target()
 var home:=Access.nearby(world);check(home.get("title","").contains("Je eigen huis") and not home.get("locked",true),"home entrance names its real destination")
 p.position=Vector2(30.5,23.25)*32;p.facing=Vector2.UP;p._update_target()
 check(world.spawn_fits(p.position),"closed-home feedback is reached from actual free ground")
 check(Access.nearby(world).get("title","")=="Deze woning is gesloten.","unused facade is explicitly a closed home")
 p.position=Vector2(19.5,7.5)*32;p.facing=Vector2.UP;p._update_target()
 var locked:=Access.nearby(world);check(locked.get("locked",false) and locked.get("detail","").contains("verzegeld"),"locked temple explains original progression condition")
 p.position=Vector2(7.5,17.5)*32;check(not Access.visible(world,Vector2(7.5,21.5)*32,false),"solid house walls hide entrances behind them")
 p.position=Vector2(7.5,22.5)*32;p.facing=Vector2.UP;p._update_target()
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for dimensions in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=dimensions
   world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;await frames(6)
   check(world.hud.access_panel.visible and Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(world.hud.access_panel.get_global_rect()),"entry feedback fits "+locale+str(dimensions))
 await enter("player_home");freeze_geometry();p.position=Vector2(7,12.5)*32;p.facing=Vector2.DOWN;p._update_target()
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for dimensions in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=dimensions;world.hud.toast_queue.clear();world.hud.toast_time=0;world.hud.banner_time=0;await frames(6)
   var actor_screen: Vector2=p.get_global_transform_with_canvas().origin
   check(world.hud.access_panel.visible and not world.hud.access_panel.get_global_rect().intersects(Rect2(actor_screen-Vector2(40,40),Vector2(80,80))),"edge-camera entry hint leaves character clear "+locale+str(dimensions))
 gs.set_ui("access_test",true);await frames(3);check(not world.hud.access_panel.visible,"entry feedback yields to modal screens");gs.set_ui("access_test",false)
 root.get_node("Lang").set_language("nl",false)
func edge_cases():
 await enter("village");freeze_geometry()
 var recorder:=TravelRecorder.new();root.add_child(recorder)
 var probe: Node2D=portal_script.new();probe.world=recorder;probe.player=p;probe.target_map="shop";probe.target_spawn="start";probe.rect=Rect2(240,240,32,32);world.entities.add_child(probe);probe.set_process(false)
 p.position=Vector2(224,256);probe._process(.3);p.velocity=Vector2(235,0);p.position=Vector2(288,256);probe._process(.3)
 check(recorder.calls.size()==1,"rolling across a narrow portal during a long frame still enters once")
 probe.queue_free();await frames(2)
 probe=portal_script.new();probe.world=recorder;probe.player=p;probe.target_map="shop";probe.rect=Rect2(240,240,32,32);world.entities.add_child(probe);probe.set_process(false);recorder.calls.clear()
 p.position=Vector2(224,240);probe._process(.3);p.position=Vector2(288,240);probe._process(.3)
 check(recorder.calls.is_empty(),"touching a doorway edge does not enter")
 p.position=Vector2(128,256);probe._process(.016);p.position=Vector2(640,256);probe._process(.016)
 check(recorder.calls.is_empty(),"distant teleport does not activate crossed doorways")
 probe.conditions=[["flag","access_probe_open"]];p.position=Vector2(224,256);probe._process(.3);p.position=Vector2(288,256);probe._process(.3)
 check(recorder.calls.is_empty(),"swept entry respects the same progression lock")
 gs.flags["access_probe_open"]=true;p.position=Vector2(224,256);probe._process(.3)
 check(recorder.calls.size()==1,"opening the original lock enables swept entry")
 recorder.calls.clear();gs.transitioning=true;p.position=Vector2(256,256);probe._process(.3);gs.transitioning=false;probe._process(.016)
 check(recorder.calls.is_empty(),"arrival during fade cannot immediately bounce back")
 probe.queue_free();recorder.queue_free();await frames(2)
 p.roll_timer=.3;p.roll_dir=Vector2.DOWN;p.velocity=Vector2(0,235);p.knockback=Vector2(100,0);p.attack_timer=.2;p.bow_anim=.2
 world.load_map("player_home","start");await frames(2);p=world.player;p.set_physics_process(false)
 check(p.roll_timer==0 and p.knockback==Vector2.ZERO and p.attack_timer==0 and p.bow_anim==0,"arrival cancels carried roll and combat movement")
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 portal_script=load("res://scripts/entities/portal.gd");foot.radius=7
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 # The opened seal is an ordinary progression state, unlike forcing a path through it.
 gs.flags["diepte_opened"]=true
 for id: String in Maps.MAPS:
  await enter(id);freeze_geometry();await frames(2)
  var g:=grid();var list:=portals()
  check(world.spawn_fits(p.position),"safe actual arrival "+id)
  for portal in list:
   var valid: bool=Maps.MAPS.has(portal.target_map) and Maps.get_map(portal.target_map).spawns.has(portal.target_spawn)
   check(valid,"destination and explicit spawn exist "+id+" → "+portal.target_map)
   var path:=route(g,portal)
   var entry: Dictionary={"from":id,"to":portal.target_map,"spawn":portal.target_spawn,"pos":[portal.rect.position.x/32,portal.rect.position.y/32],"requirements":portal.conditions,"path_points":path.size()}
   report.append(entry)
   check(not path.is_empty(),"physical route from arrival to doorway "+id+" → "+portal.target_map)
 await walk_every_entrance()
 await feedback_cases()
 await edge_cases()
 var out:=FileAccess.open("res://access_audit.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
 world.queue_free();await frames(4);print("ACCESS POINTS OK" if failures==0 else "ACCESS POINTS FAILED "+str(failures));quit(0 if failures==0 else 1)
