extends "res://tests/coast_expedition_test.gd"
const Repairs:=preload("res://scripts/data/route_repairs.gd")
const Water:=preload("res://scripts/core/water_features.gd")
const ROAD:=",=9DAETn"
func broad(rows: Array,x: int,y: int) -> bool:
 for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.UP,Vector2i(-1,-1)]:
  var valid:=true
  for yy in range(y+offset.y,y+offset.y+2):
   for xx in range(x+offset.x,x+offset.x+2):
    if yy<0 or yy>=rows.size() or xx<0 or xx>=rows[yy].length() or not rows[yy][xx] in ROAD:valid=false
  if valid:return true
 return false
func deck_broad(rows: Array,x: int,y: int) -> bool:
 if broad(rows,x,y):return true
 # A shallow indoor channel can be just one tile long; both banks complete the crossing.
 for dx in [-1,0]:
  var left: int=x+dx
  if left<0 or left+1>=rows[y].length() or y<1 or y+1>=rows.size():continue
  if not rows[y][left] in "=9" or not rows[y][left+1] in "=9":continue
  if not Tiles.is_solid_char(rows[y-1][left]) and not Tiles.is_solid_char(rows[y-1][left+1]) and not Tiles.is_solid_char(rows[y+1][left]) and not Tiles.is_solid_char(rows[y+1][left+1]):return true
 return false
func anchor_groups(rows: Array,id: String) -> void:
 var surface: Dictionary={}
 for y in rows.size():
  for x in rows[y].length():
   if rows[y][x] in ROAD:surface[Vector2i(x,y)]=true
 while not surface.is_empty():
  var seed: Vector2i=surface.keys()[0]
  var road: Dictionary={seed:true};var queue: Array[Vector2i]=[seed];surface.erase(seed);var head:=0
  while head<queue.size():
   var at:=queue[head];head+=1
   for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    var next: Vector2i=at+delta
    if surface.has(next):surface.erase(next);road[next]=true;queue.append(next)
  var anchors: Dictionary={}
  for at: Vector2i in road:
   if road.has(at+Vector2i.RIGHT) and road.has(at+Vector2i.DOWN) and road.has(at+Vector2i(1,1)):anchors[at]=true
  if anchors.is_empty():continue # A doorway is intentionally only one tile deep.
  var first: Vector2i=anchors.keys()[0];var expected:=anchors.size();queue=[first];anchors.erase(first);head=0
  while head<queue.size():
   var at:=queue[head];head+=1
   for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    var next: Vector2i=at+delta
    if anchors.has(next):anchors.erase(next);queue.append(next)
  check(anchors.is_empty(),"two-wide road stays connected through every bend "+id+" "+str(seed)+" anchors "+str(expected))
func state_geometry() -> void:
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player;p.set_physics_process(false)
 for state in range(4):
  gs.set_flag("lw_drained",bool(state&1));gs.set_flag("lw_bridge",bool(state&2));await enter("kruipmoeras");p.set_physics_process(false)
  for y in [11,12,13,14,18,19,20]:
   check(world.map_data.rows[y][23]=="=" and world.map_data.rows[y][24]=="=","marsh main bridges stay two wide in state "+str(state)+" row "+str(y))
  for cells: Array in Water.components(world.map_data.rows):check(cells.size()>=7 and cells.size()%2==1,"marsh water remains odd after bridge widening, state "+str(state))
 gs.set_flag("lw_forest")
 await enter("dauwbos");p.set_physics_process(false);anchor_groups(world.map_data.rows,"dauwbos-restored")
 for y in [30,31]:
  for x in range(39,45):check(world.map_data.rows[y][x]==",","restored garden road fills entire two-wide portal approach")
 for state in range(4):
  gs.set_flag("lw_heat_west",bool(state&1));gs.set_flag("lw_heat_east",bool(state&2));await enter("ijsdal");p.set_physics_process(false)
  anchor_groups(world.map_data.rows,"ijsdal-heat-"+str(state))
  for y in world.map_data.rows.size():
   for x in world.map_data.rows[y].length():
    if world.map_data.rows[y][x]==",":check(broad(world.map_data.rows,x,y),"heat route stays broad "+str(state)+" "+str(Vector2i(x,y)))
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 var survey: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/map-water-source.json"))
 for id: String in Maps.MAPS:
  var data: Dictionary=Maps.get_map(id)
  anchor_groups(data.rows,id)
  for y in data.rows.size():
   for x in data.rows[y].length():
    if data.rows[y][x]==",":check(broad(data.rows,x,y),"road has two-tile shoulder "+id+" "+str(Vector2i(x,y)))
    if data.rows[y][x] in "=9" and not (id=="village" and Vector2i(x,y)==Vector2i(28,28)):
     check(deck_broad(data.rows,x,y),"main bridge has a two-tile deck "+id+" "+str(Vector2i(x,y)))
  for o: Dictionary in data.objects:
   if o.type!="portal" or not o.get("enabled",true):continue
   check(o.get("size",[1,1])[0]>=2,"all real transitions have two-wide apertures "+id+" → "+o.to)
   for y in range(o.pos[1],o.pos[1]+o.size[1]):
    for x in range(o.pos[0],o.pos[0]+o.size[0]):
     check(not Tiles.is_solid_char(data.rows[y][x]),"full entrance aperture is clear "+id+" "+str(Vector2i(x,y)))
  # Stable indices preserve collected keys and opened chests from existing saves.
  if survey.has(id):
   var index:=0
   for old: Dictionary in survey[id].objects:
    if old.get("id","").begins_with("trail:") or old.get("trail_wildlife",false) or old.type=="profession_resource":break
    check(data.objects[index].type==old.type,"saved object slot stays stable "+id+" "+str(index))
    if old.type=="chest":
     var actual: Array=data.objects[index].contents
     check(actual.size()==old.contents.size(),"same saved chest stack count "+id+" "+str(index))
     for stack in mini(actual.size(),old.contents.size()):
      check(actual[stack][0]==old.contents[stack][0] and int(actual[stack][1])==int(old.contents[stack][1]),"saved chest contents stay stable "+id+" "+str(index)+" stack "+str(stack))
    index+=1
 var estuary: Dictionary=Maps.get_map("river_mouth")
 var coast: Dictionary=estuary.objects.filter(func(o):return o.type=="portal" and o.to=="coast")[0]
 check(coast.pos==[14,44] and coast.size==[2,2],"estuary exit centred on both pier columns")
 for y in [44,45]:
  check(estuary.rows[y][13]=="3" and estuary.rows[y][14]=="9" and estuary.rows[y][15]=="9","pier has two boardwalk tiles and sea beside it "+str(y))
 var forest: Dictionary=Maps.get_map("forest")
 for y in [17,18]:
  for x in [24,25]:check(forest.rows[y][x]=="=","all four forest water crossing tiles are bridge")
 var dew: Dictionary=forest.objects.filter(func(o):return o.type=="portal" and o.to=="dauwbos")[0]
 check(dew.pos==[10,0] and dew.size==[2,2],"Dew Woods begins at true north end of first north road")
 for y in range(0,17):check(forest.rows[y][10]=="," and forest.rows[y][11]==",","northbound forest road stays straight "+str(y))
 check(forest.spawns.from_dauwbos==[10,3],"north arrival stays outside portal")
 check(forest.objects[4].pos==[8,4],"original key chest sits beside road, same saved slot")
 var lake: Dictionary=Maps.get_map("lake")
 for y in [8,9]:
  for x in range(32,44):check(lake.rows[y][x]==",","library road reaches eastern passage "+str(Vector2i(x,y)))
 var village: Dictionary=Maps.get_map("village")
 var south: Dictionary=village.objects.filter(func(o):return o.type=="portal" and o.to=="lake")[0]
 check(south.pos==[18,42] and south.size==[2,2],"south passage centred on two-wide road")
 for y in [41,42]:
  for x in [20,21]:check(village.rows[y][x]=="=","home canal bridge spans both water columns")
 # Gate masonry is retained; broadening never cuts around the old ruin lock.
 for y in [15,16]:
  for x in [46,47,50,51,52]:check(forest.rows[y][x]=="W","ruin entrance keeps gate sidewalls")
 check(Maps.get_map("ijsdal").rows[16][17]=="H","road no longer cuts a decorative house facade")
 await state_geometry()
 check(failures==0,"all calm road geometry checks")
 print("ROUTE WIDTH TEST OK" if failures==0 else "ROUTE WIDTH TEST FAILED")
 quit(0 if failures==0 else 1)
