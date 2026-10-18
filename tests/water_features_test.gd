extends "res://tests/coast_expedition_test.gd"
const Water:=preload("res://scripts/core/water_features.gd")
const Farm:=preload("res://scripts/core/homestead.gd")
const Layout:=preload("res://scripts/data/homestead_maps.gd")
func check_water(id: String,data: Dictionary):
 var components:=Water.components(data.rows)
 for cells: Array in components:check(cells.size()>=7 and cells.size()%2==1,"odd water body of at least seven tiles "+id+" "+str(cells.size()))
 var total:=0
 for feature: Dictionary in data.water_features:
  total+=feature.count;check(feature.count==feature.cells.size() and Water.TYPES.has(feature.kind),"typed body matches real geometry "+id)
 check(total==data.water_cells.size(),"water metadata matches actual surface "+id)
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 var types: Dictionary={}
 var inventory: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/map-water-source.json"))
 for id: String in Maps.MAPS:
  var data: Dictionary=Maps.get_map(id);check_water(id,data)
  for feature: Dictionary in data.water_features:types[feature.kind]=true
  for object: Dictionary in inventory.get(id,{"objects":[]}).objects:
   if object.type!="profession_resource" or object.get("id","").begins_with("trail:"):continue
   var x: int=object.pos[0];var y: int=object.pos[1]
   var tiles: Script=load("res://scripts/data/tiles.gd")
   if not tiles.is_solid_char(inventory[id].rows[y][x]):check(not tiles.is_solid_char(data.rows[y][x]),"existing resource stays on accessible ground "+id+str(object.pos))
 check(types.size()==10,"all ten geographically placed water classes exist")
 check(Water.wet("8"),"flooded tidal shores count as water, dry sand and bridges do not")
 check(Water.irrigates("canal") and Water.irrigates("stream") and not Water.irrigates("sea") and not Water.irrigates("geyser"),"freshwater supply distinct from salt and mineral water")
 check(not Water.properties("river","river_mouth").irrigates,"brackish estuary differs from fresh upstream river")
 var edge: Dictionary=Maps.get_map("forest_edge")
 var fall: Dictionary=edge.objects.filter(func(o):return o.type=="home_station" and o.get("role","")=="fall")[0]
 check(fall.pos==[31,15] and Water.wet(edge.rows[15][31]),"forest cascade sits on upstream lip of basin")
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 for state in range(4):
  gs.set_flag("lw_drained",bool(state&1));gs.set_flag("lw_bridge",bool(state&2));await enter("kruipmoeras");p.set_physics_process(false)
  check_water("marsh-state-"+str(state),world.map_data)
  if state&2:check(not world.is_solid(Vector2(20.5,16.5)*32),"repaired bridge survives contour cleanup")
 for day in [.03,.14,.03]:
  gs.day_time=day;await enter("tide_cove");p.set_physics_process(false);p.position=Vector2(18.5,13.5)*32
  await frames(5);check_water("tide-state-"+str(day),world.map_data)
 gs.day_time=.03;await enter("tide_cove");p.set_physics_process(false);p.position=Vector2(18.5,13.5)*32
 gs.day_time=.14;await frames(5);check_water("tide-live-change",world.map_data)
 gs.set_flag("ad_wheel_done");await enter("tidal_hollow");p.set_physics_process(false);check_water("tidal-wheel-open",world.map_data)
 await enter("village","from_home");p.set_physics_process(false)
 check(world.map_data.water_cells.size()==Layout.water().size(),"irrigation sources remain exactly the visible village water")
 for at: Vector2i in Layout.water():check(world.map_data.water_cells.get(at,"")=="canal","visible source is actual fresh canal")
 gs.give("hs_hoe",1,true);p.position=Vector2(19.5,35.5)*32
 await frames(8)
 var water_hint: Node=get_nodes_in_group("water_scenery").filter(func(n):return not n.is_queued_for_deletion())[0]
 if water_hint.info.visible:check(not water_hint.info.get_global_rect().intersects(world.hud.opening_hint.get_global_rect()),"water caption leaves controller and keyboard footer clear")
 Farm.mode="channel";await frames(8)
 for garden in get_nodes_in_group("homesteads"):
  if not garden.is_queued_for_deletion() and garden.panel!=null and garden.panel.visible:check(not water_hint.info.visible or not water_hint.info.get_global_rect().intersects(garden.panel.get_global_rect()),"garden instructions take priority over water caption")
 Farm.mode=""
 check(not Farm.act(Vector2i(19,34),"soil",world),"public south road stays free of new crop fields")
 check(Farm.act(Vector2i(19,34),"channel",world) and world.spawn_fits(Vector2(19.5,34.5)*32),"irrigation can cross the south road without obstructing walking")
 gs.homestead.cells={"19,34":{"kind":"channel"},"18,34":{"kind":"channel"},"17,34":{"kind":"soil","crop":"carrot","growth":0.0,"fertilized":false}}
 Farm.dirty=true;Farm.irrigate();check(Farm.watered(Vector2i(17,34)),"existing narrow channel still feeds crop after map cleanup")
 Farm.advance(5);check(gs.homestead.cells["17,34"].growth==5,"actual crops grow from connected village canal")
 await enter("ijsdal");p.set_physics_process(false);p.position=Vector2(31.5,4.5)*32;p.velocity=Vector2.ZERO
 for enemy in get_nodes_in_group("enemies"):enemy.queue_free()
 await frames(3);gs.hp=maxi(1,gs.max_hp()-2)
 var scenery: Node
 for node in world.ground.get_children():
  if node.get_script()!=null and node.get_script().resource_path.ends_with("water_scenery.gd"):scenery=node
 check(scenery!=null,"typed water scenery spawned")
 if scenery!=null:
  scenery.set_process(false);var before: int=gs.hp
  scenery._process(14);check(gs.hp==before,"warm spring does not heal instantly")
  scenery._process(1.1);check(gs.hp==before+1,"quiet warm spring rest restores one heart after fifteen seconds")
  p.velocity=Vector2(20,0);scenery._process(15);check(gs.hp==before+1 and scenery.rest_time==0,"walking interrupts thermal rest")
 world.queue_free();await frames();print("WATER FEATURES OK" if failures==0 else "WATER FEATURES FAILED "+str(failures));quit(0 if failures==0 else 1)
