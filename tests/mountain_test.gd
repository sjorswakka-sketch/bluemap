extends "res://tests/coast_expedition_test.gd"
const Mountain:=preload("res://scripts/maps/steampeak.gd")
const Water:=preload("res://scripts/core/water_features.gd")
const Enemies:=preload("res://scripts/data/enemies.gd")
const Art:=preload("res://scripts/core/art.gd")
func reachable(data: Dictionary) -> Dictionary:
 var start:=Vector2i(data.spawns.start[0],data.spawns.start[1]);var result: Dictionary={start:true};var queue: Array[Vector2i]=[start];var head:=0
 while head<queue.size():
  var at:=queue[head];head+=1
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i=at+step
   if next.x<0 or next.y<0 or next.y>=data.rows.size() or next.x>=data.rows[next.y].length() or result.has(next) or Tiles.is_solid_char(data.rows[next.y][next.x]):continue
   result[next]=true;queue.append(next)
 return result
func walk_portal(target_map: String,action: String) -> bool:
 # Exercise the real portal, fade and arrival. Stop input when travel starts;
 # never retain a scene-local body while a transition replaces map entities.
 release();p=world.player;p.set_physics_process(true)
 var origin: String=gs.map_id;var started:=false
 Input.action_press(action)
 for step in range(240):
  await physics_frame;await process_frame
  if gs.map_id==target_map or gs.transitioning:started=true;break
 release()
 for step in range(120):
  if gs.map_id==target_map and not gs.transitioning:break
  await frames(1)
 check(started and gs.map_id==target_map and not gs.transitioning,"actual walking crosses "+origin+" to "+target_map)
 if gs.map_id!=target_map or gs.transitioning:return false
 p=world.player;p.velocity=Vector2.ZERO
 check(world.spawn_fits(p.position),"actual portal arrival has clear feet in "+target_map)
 # Keep normal physics and portal processing active while standing still.
 await frames(90)
 var stayed: bool=gs.map_id==target_map and not gs.transitioning
 check(stayed,"arrival does not bounce back from "+target_map)
 p=world.player;p.set_physics_process(false)
 return stayed
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 var mountain: Dictionary=Maps.get_map("steampeak");var accessible:=reachable(mountain)
 check(mountain.rows.size()==64 and mountain.rows.all(func(row):return row.length()==72),"large mountain keeps consistent 72 by 64 grid")
 check(mountain.outdoor and mountain.weather=="snow" and mountain.mountain_terraces.size()==4,"four snowy elevation terraces")
 var wide_roads:=true
 for y in mountain.rows.size():
  for x in mountain.rows[y].length():
   if mountain.rows[y][x]!=",":continue
   var has_square:=false
   for dy in [-1,0]:
    for dx in [-1,0]:
     var corner:=Vector2i(x+dx,y+dy)
     if corner.x<0 or corner.y<0 or corner.x+1>=mountain.rows[y].length() or corner.y+1>=mountain.rows.size():continue
     if mountain.rows[corner.y].substr(corner.x,2)==",," and mountain.rows[corner.y+1].substr(corner.x,2)==",,":has_square=true
   if not has_square:wide_roads=false
 check(wide_roads,"all mountain roads and turns retain both lanes, including beside frozen runoff")
 for region: Dictionary in mountain.mountain_terraces:
  var bounds: Array=region.bounds
  check(accessible.keys().any(func(at):return Rect2i(bounds[0],bounds[1],bounds[2],bounds[3]).has_point(at)),"ascent reaches "+region.name)
 for flight: Array in mountain.mountain_stairs:
  check(flight[2]==2,"two-tile-wide stair aperture")
  for y in range(flight[1]-1,flight[1]+flight[3]+1):
   for x in range(flight[0],flight[0]+2):check(mountain.rows[y][x]=="," and accessible.has(Vector2i(x,y)),"stair landing and both lanes are connected "+str(Vector2i(x,y)))
 var springs:=0;var geysers:=0
 for feature: Dictionary in mountain.water_features:
  check(feature.count>=7 and feature.count%2==1,"natural water has odd area and at least seven tiles")
  if feature.kind=="hot_spring":springs+=1
  if feature.kind=="geyser":geysers+=1
  check(not feature.properties.irrigates,"mineral mountain sources are distinct from irrigation water")
  for bank: Array in feature.bank_rocks:check(Tiles.is_solid_char(mountain.rows[bank[1]][bank[0]]),"visible bank rocks align with actual solid terrain")
 check(springs==3 and geysers==2,"three restorative springs and two decorative geysers")
 var family: Array=mountain.objects.filter(func(o):return o.type=="enemy" and o.kind=="trail_macaque")
 check(family.size()==5 and family.all(func(o):return accessible.has(Vector2i(o.pos[0],o.pos[1]))),"five peaceful macaques live on accessible terraces")
 check(Enemies.info("trail_macaque").behavior=="animal" and Enemies.info("trail_macaque").damage==0,"macaques cannot harm player")
 check(Art.tex("pixel_snow_macaque").get_size()==Vector2(128,32) and Art.tex("snow_macaque").get_size()==Vector2(64,16),"original idle and walking pixel-art atlases")
 var valley: Dictionary=Maps.get_map("ijsdal")
 var north: Array=valley.objects.filter(func(o):return o.type=="portal" and o.to=="steampeak")
 check(north.size()==1 and north[0].pos==[24,0] and north[0].size==[2,2],"new entrance centered at north of IJsdal")
 for y in range(16):check(valley.rows[y].substr(24,2)==",,","two-lane northern valley approach "+str(y))
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await enter("steampeak");p.set_physics_process(false)
 for point: Array in mountain.spawns.values():check(world.spawn_fits(Vector2(point[0]+.5,point[1]+.5)*32),"safe mountain arrival and summit spawn")
 for flight: Array in mountain.mountain_stairs:
  for lane in range(2):
   p.position=Vector2(flight[0]+lane+.5,flight[1]+flight[3]+.5)*32;p.set_physics_process(true)
   await walk_to(Vector2(flight[0]+lane+.5,flight[1]-.5)*32,240)
   p.set_physics_process(false)
 p.position=Vector2(47.5,53.5)*32;p.velocity=Vector2.ZERO;gs.hp=maxi(1,gs.max_hp()-2)
 var scenery: Node=get_nodes_in_group("water_scenery").filter(func(n):return not n.is_queued_for_deletion())[0]
 scenery.set_process(false);var before: int=gs.hp
 scenery.rest_time=0;scenery._process(14);check(gs.hp==before,"resting at a mountain spring takes time")
 scenery._process(1.1);check(gs.hp==before+1,"quiet spring shore restores one heart")
 p.position=Vector2(15.5,34.5)*32;p.velocity=Vector2.ZERO;scenery.rest_time=0;before=gs.hp;scenery._process(16)
 check(gs.hp==before and scenery.rest_time==0,"decorative geysers do not heal or require interaction")
 check(world.ground.get_children().any(func(n):return n.get_script()!=null and n.get_script().resource_path.ends_with("mountain_scenery.gd")),"snow-capped cliff strata and stairs render on the ground layer")
 await enter("ijsdal","from_steampeak");check(world.spawn_fits(p.position),"return reaches northern IJsdal without immediate re-entry")
 if await walk_portal("steampeak","move_up"):
  await walk_portal("ijsdal","move_down")
 world.queue_free();await frames();print("MOUNTAIN OK" if failures==0 else "MOUNTAIN FAILED "+str(failures));quit(0 if failures==0 else 1)
