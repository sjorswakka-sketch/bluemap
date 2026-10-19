extends "res://tests/coast_expedition_test.gd"
## Width is an authored gameplay distinction: a public door is broad, a dungeon
## mouth is narrow. Verify terrain and actual travel, rather than just metadata.
const Repairs:=preload("res://scripts/data/route_repairs.gd")
const Water:=preload("res://scripts/core/water_features.gd")

func actual_foot_clear(at: Vector2) -> bool:
 # The real player uses a radius-seven foot at y+8. spawn_fits intentionally
 # reserves a wider radius-eight save margin; that touches the water below a
 # perfectly traversable lower bridge lane and is inappropriate for this check.
 var foot:=CircleShape2D.new();foot.radius=7
 var query:=PhysicsShapeQueryParameters2D.new();query.shape=foot;query.collision_mask=1
 query.exclude=[p.get_rid()];query.transform=Transform2D(0,at+Vector2(0,8))
 return world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func portal_in(data: Dictionary,to: String) -> Dictionary:
 for obj: Dictionary in data.objects:
  if (obj.type=="portal" or obj.get("travel_link",false)) and obj.get("to","")==to:return obj
 return {}

func aperture(data: Dictionary,obj: Dictionary) -> void:
 for yy in range(obj.pos[1],obj.pos[1]+obj.size[1]):
  for xx in range(obj.pos[0],obj.pos[0]+obj.size[0]):
   check(not Tiles.is_solid_char(data.rows[yy][xx]),"aperture floor matches its real trigger "+str(Vector2i(xx,yy)))

func same_conditions(a: Array,b: Array) -> bool:
 # JSON numbers are floats; source conditions use ints. Compare each value so
 # a preserved item-count requirement is not mistaken for a changed lock.
 if a.size()!=b.size():return false
 for i in a.size():
  if a[i].size()!=b[i].size():return false
  for j in a[i].size():
   if a[i][j] is float or a[i][j] is int:
    if not (b[i][j] is float or b[i][j] is int) or not is_equal_approx(float(a[i][j]),float(b[i][j])):return false
   elif a[i][j]!=b[i][j]:return false
 return true

func terrain_policy() -> void:
 var narrow:=0;var broad:=0
 var survey: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/map-water-source.json"))
 for id: String in Maps.MAPS:
  var data: Dictionary=Maps.get_map(id)
  for obj: Dictionary in data.objects:
   if (obj.type!="portal" and not obj.get("travel_link",false)) or not obj.get("enabled",true):continue
   var key:=id+":"+str(obj.to);var expected: int=Repairs.ENTRY_WIDTHS.get(key,0)
   check(expected in [1,2],"every entrance has an explicit class "+key)
   check(obj.get("size",[1,1])[0]==expected,"authored entrance width "+key)
   check(Repairs.ENTRY_WIDTHS.get(str(obj.to)+":"+id,0)==expected,"reciprocal entrance class "+key)
   aperture(data,obj)
   if expected==1:narrow+=1
   else:broad+=1
   if survey.has(id):
    for old: Dictionary in survey[id].objects:
     if old.type=="portal" and old.to==obj.to:
      check(same_conditions(obj.get("requires",[]),old.get("requires",[])) and obj.get("spawn","start")==old.get("spawn","start") and obj.get("locked_text","")==old.get("locked_text",""),"locks and destination spawn survive resizing "+key)
  for key: String in Repairs.MOUTHS:
   if not key.begins_with(id+":"):continue
   var mouth: Dictionary=Repairs.MOUTHS[key]
   for cell: Array in mouth.jambs+mouth.back:
    check(Tiles.is_solid_char(data.rows[cell[1]][cell[0]]),"real stone blocks former side aperture "+key+" "+str(cell))
    check(not Water.wet(data.rows[cell[1]][cell[0]]),"mouth masonry is dry terrain "+key)
   var approach: Array=mouth.approach
   check(not Tiles.is_solid_char(data.rows[approach[1]][approach[0]]),"clear mouth approach "+key)
 check(narrow==18 and broad==52,"nine dungeon pairs and twenty-six broad pairs cover all seventy entrance directions")
 var hollow: Dictionary=Maps.get_map("tidal_hollow")
 for cell: Vector2i in [Vector2i(0,29),Vector2i(1,29),Vector2i(2,29),Vector2i(2,30)]:
  check(hollow.rows[cell.y][cell.x]=="0","dry western dungeon landing is stone rather than an incomplete bridge "+str(cell))
 for y in survey.tidal_hollow.rows.size():
  for x in survey.tidal_hollow.rows[y].length():
   if survey.tidal_hollow.rows[y][x]=="9" and not (x<3 and y in [29,30]):
    check(hollow.rows[y][x]=="9","actual central water bridge is preserved "+str(Vector2i(x,y)))
 # Existing wide security gates still cover their complete original corridor.
 for gate_data: Array in [["forest","ruin",[2,1]],["temple","arena",[4,1]],["depths1","depths",[3,1]],["depths2","guardian_door",[3,1]]]:
  var found:=false
  for obj: Dictionary in Maps.get_map(gate_data[0]).objects:
   if obj.type in ["gate","diepte_gate"] and obj.id==gate_data[1]:
    found=true;check(obj.size==gate_data[2],"wide independent progression gate still seals corridor "+gate_data[0])
  check(found,"original progression gate still present "+gate_data[0])

func movement_into(key: String,expect_travel:=true) -> void:
 var split:=key.split(":");var source: String=split[0];var target: String=split[1]
 await enter(source)
 var mouth: Dictionary=Repairs.MOUTHS[key]
 var goal: Vector2=(Vector2(mouth.pos[0],mouth.pos[1])+Vector2(mouth.size[0],mouth.size[1])*.5)*32
 p.position=(Vector2(mouth.approach[0],mouth.approach[1])+Vector2(.5,.5))*32
 p.velocity=Vector2.ZERO;await frames(4)
 check(world.spawn_fits(p.position),"player's full foot collider fits mouth approach "+key)
 var found:=false
 for portal in get_nodes_in_group("access_portals"):
  if portal.is_queued_for_deletion() or portal.world!=world or portal.target_map!=target:continue
  found=true
  check(portal.rect==Rect2(Vector2(mouth.pos[0],mouth.pos[1])*32,Vector2(mouth.size[0],mouth.size[1])*32),"runtime trigger exactly matches narrow mouth "+key)
 check(found,"actual portal entity exists "+key)
 for cell: Array in mouth.jambs:
  check(world.is_solid((Vector2(cell[0],cell[1])+Vector2(.5,.5))*32),"runtime collision closes old side opening "+key+" "+str(cell))
  check(world.spawn_fits(world.safe_spawn_position((Vector2(cell[0],cell[1])+Vector2(.5,.5))*32)),"old save on new jamb resolves to safe floor "+key+" "+str(cell))
 p.set_physics_process(true)
 var delta: Vector2=goal-p.position
 var action: String="move_right" if absf(delta.x)>absf(delta.y) and delta.x>0 else "move_left" if absf(delta.x)>absf(delta.y) else "move_down" if delta.y>0 else "move_up"
 Input.action_press(action)
 # Read the map id before touching p: successful travel frees the old player.
 for i in 90:
  await physics_frame
  if gs.map_id!=source:break
 release();await frames(24);p=world.player
 if expect_travel:
  check(gs.map_id==target,"actual movement crosses one-tile mouth "+key)
  check(world.spawn_fits(p.position),"safe arrival after one-tile travel "+key)
  var arrived: String=gs.map_id;await frames(10)
  check(gs.map_id==arrived,"narrow mouth arrival never bounces "+key)
 else:check(gs.map_id==source,"locked one-tile mouth cannot be bypassed "+key)

func broad_entry_lanes(entries: Array) -> void:
 for door: Array in entries:
  for lane in 2:
   var source: String=door[0];var target: String=door[1];var approach: String=door[2]
   await enter(source)
   # Retain every solid prop while making moving residents deterministic.
   for npc in get_nodes_in_group("npc"):npc.set_physics_process(false);npc.set_process(false)
   var spec:=portal_in(world.map_data,target)
   var key:=source+":"+target
   var portal: Node
   for candidate in get_nodes_in_group("access_portals"):
    if not candidate.is_queued_for_deletion() and candidate.world==world and candidate.target_map==target:portal=candidate;break
   check(portal!=null,"public door or open trail has a real portal "+key)
   if portal==null:continue
   var available: bool=portal.available();var original: Array=portal.conditions.duplicate(true)
   var horizontal: bool=approach in ["west","east"]
   check(spec.size[1 if horizontal else 0]==2,"entrance has two lanes perpendicular to movement "+key)
   var at: Vector2
   var action: String
   match approach:
    "south":at=Vector2(spec.pos[0]+lane+.5,spec.pos[1]+spec.size[1]+1.5);action="move_up"
    "north":at=Vector2(spec.pos[0]+lane+.5,spec.pos[1]-1.5);action="move_down"
    "west":at=Vector2(spec.pos[0]-1.5,spec.pos[1]+lane+.5);action="move_right"
    "east":at=Vector2(spec.pos[0]+spec.size[0]+1.5,spec.pos[1]+lane+.5);action="move_left"
   p.position=at*32;p.velocity=Vector2.ZERO
   await frames(4)
   check(actual_foot_clear(p.position),"real foot collider fits broad approach "+key+" lane "+str(lane))
   p.set_physics_process(true);Input.action_press(action)
   var entered:=false
   for i in 100:
    await physics_frame
    if gs.map_id!=source:break
    if not available and portal.rect.has_point(p.position):entered=true;break
   release();await frames(24);p=world.player
   if available:
    check(gs.map_id==target,"actual straight movement activates broad entrance "+key+" lane "+str(lane))
    check(world.spawn_fits(p.position),"safe broad entrance arrival "+key+" lane "+str(lane))
   else:
    check(gs.map_id==source and entered and portal.message_cooldown>0,"both broad lanes reach the original locked prompt "+key+" lane "+str(lane))
    check(same_conditions(portal.conditions,original),"approach test preserves original quest lock "+key)

func ordinary_door_lanes() -> void:
 await broad_entry_lanes([
  ["village","smithy","south"],["village","shop","south"],["village","inn","south"],
  ["village","player_home","south"],["lake","fisher_hut","south"],["lake","library","south"],
  ["village","arena_hall","south"],["arena_hall","arena","south"],
  ["arena_hall","village","north"],["arena","arena_hall","north"],
  ["smithy","village","north"],["shop","village","north"],["inn","village","north"],
  ["player_home","village","north"],["fisher_hut","lake","north"],
  ["library","lake","north"],["coast_workshop","harbor","north"]
 ])
 var village: Dictionary=Maps.get_map("village")
 for move: Dictionary in Repairs.PROPS.village:
  if move.type!="wereld_lantaarn":continue
  check(village.objects.filter(func(obj):return obj.type=="wereld_lantaarn" and obj.pos==move.pos).size()==1,"same lamp now stands on the clear verge "+str(move.pos))

func horizontal_trail_lanes() -> void:
 gs.set_flag("lw_forest");gs.set_flag("lw_heat")
 # Every horizontal open-area approach is covered in both terrain rows. Tall
 # north/south portals are tested along their two x-columns elsewhere.
 await broad_entry_lanes([
  ["forest","forest_edge","east"],["forest_edge","forest","west"],
  ["forest_edge","village","east"],["village","forest_edge","west"],
  ["dauwbos","dorstvallei","west"],["dauwbos","mistgarden","west"],
  ["ijsdal","ridgepass","west"],["lake","coast","west"],["coast","lake","east"],
  ["river_mouth","harbor","west"],["harbor","river_mouth","east"],
  ["harbor","headland","west"],["headland","harbor","east"],
  ["gull_island","tide_cove","west"],["tide_cove","gull_island","east"]
 ])

func vertical_trail_clearance() -> void:
 # Check the remaining north/south trail landings against native fixed bodies
 # once per map. Their common travel logic is covered by the walking tests;
 # both individual lanes still need a clear direct approach, including shores.
 for entry: Array in [
  ["forest","watchyard","south"],["watchyard","forest","north"],
  ["forest","dauwbos","south"],["dauwbos","forest","north"],
  ["dauwbos","ijsdal","south"],["ijsdal","dauwbos","north"],
  ["dorstvallei","dauwbos","north"],["mistgarden","dauwbos","north"],
  ["dorstvallei","sunwell","south"],["sunwell","dorstvallei","north"],
  ["ridgepass","ijsdal","north"],["ijsdal","steampeak","south"],
  ["steampeak","ijsdal","north"],["village","lake","north"],
  ["lake","village","south"],["lake","kruipmoeras","north"],
  ["kruipmoeras","lake","south"],["coast","river_mouth","south"],
  ["river_mouth","coast","north"]
 ]:
  await enter(entry[0]);p.set_physics_process(false)
  for npc in get_nodes_in_group("npc"):npc.set_physics_process(false);npc.set_process(false)
  var spec:=portal_in(world.map_data,entry[1]);var key: String=entry[0]+":"+entry[1]
  var rect:=Rect2(Vector2(spec.pos[0],spec.pos[1])*32,Vector2(spec.size[0],spec.size[1])*32)
  check(spec.size[0]==2,"vertical trail has two columns across movement "+key)
  var south: bool=entry[2]=="south"
  for lane in 2:
   var start:=Vector2(spec.pos[0]+lane+.5,spec.pos[1]+spec.size[1]+.5 if south else spec.pos[1]-.5)*32
   var direction:=Vector2.UP if south else Vector2.DOWN
   for distance: int in [0,8,16,24]:
    check(actual_foot_clear(start+direction*distance),"native foot sweep clears fixed props in both vertical lanes "+key+" lane "+str(lane)+" step "+str(distance))
   check(rect.has_point(start+direction*24),"both vertical lanes reach their real trigger "+key+" lane "+str(lane))

func actual_travel() -> void:
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await movement_into("cave:prismamine",false)
 await movement_into("village:temple",false)
 gs.set_weapon("iron")
 for flag: String in ["game_completed","diepte_opened","gate_temple","gate_ruin","gate_depths","lw_drained"]:gs.set_flag(flag)
 for key: String in Repairs.MOUTHS:await movement_into(key)
 await ordinary_door_lanes()
 await horizontal_trail_lanes()
 await vertical_trail_clearance()
 # All four waterworks states retain the same one-cell archive stair and keep
 # both bridge columns; opening the lock never changes a portal into a broad one.
 for state in range(4):
  gs.set_flag("lw_drained",bool(state&1));gs.set_flag("lw_bridge",bool(state&2));await enter("kruipmoeras")
  var entry:=portal_in(world.map_data,"reedvault")
  check(entry.pos==[24,17] and entry.size==[1,1],"archive mouth stays one tile in waterworks state "+str(state))
  for y in [18,19,20]:check(world.map_data.rows[y][23]=="=" and world.map_data.rows[y][24]=="=","broad archive bridge survives narrow stair state "+str(state))
  for cells: Array in Water.components(world.map_data.rows):check(cells.size()>=7 and cells.size()%2==1,"water classification stays odd and natural in archive state "+str(state))
 world.queue_free();await frames(5)

func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 var started:=Time.get_ticks_msec()
 terrain_policy()
 await actual_travel()
 print("ENTRY WIDTH RUNTIME MS=",Time.get_ticks_msec()-started)
 print("ENTRY WIDTH TEST OK" if failures==0 else "ENTRY WIDTH TEST FAILED")
 quit(0 if failures==0 else 1)
