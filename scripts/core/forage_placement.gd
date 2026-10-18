extends RefCounted
## Match the rendered 48x64 tree canopy, not just its solid 32px trunk tile.
const Tiles:=preload("res://scripts/data/tiles.gd")
const Trail:=preload("res://scripts/data/trail_life.gd")
static func canopy_clear(data: Dictionary,at: Vector2i) -> bool:
 if not data.has("rows"):return true
 var plant:=Rect2(Vector2(at)*32+Vector2(0,-8),Vector2(32,32)).grow(2)
 for y in range(maxi(0,at.y-2),mini(data.rows.size(),at.y+3)):
  for x in range(maxi(0,at.x-2),mini(data.rows[y].length(),at.x+3)):
   if data.rows[y][x] not in ["#","P","Y"]:continue
   # pixel_landscape places a canopy at (16,28), pixel_canopy draws (-24,-58).
   var canopy:=Rect2(Vector2(x*32-8,y*32-30),Vector2(48,64))
   if canopy.intersects(plant):return false
 return true
static func safe(data: Dictionary,at: Vector2i,obj: Dictionary,map_id: String,legacy: Array) -> bool:
 if not Trail.ground(data,at) or not canopy_clear(data,at):return false
 if data.rows[at.y][at.x] not in [".","z","f","a","e","L","U","j","s","4","5","6"]:return false
 if map_id=="tide_cove" and Rect2i(19,24,14,4).has_point(at):return false
 if map_id=="village" and Rect2i(4,29,31,12).has_point(at):return false
 for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
  var next: Vector2i=at+step
  if not Trail.ground(data,next):return false
  if step==Vector2i.UP and data.rows[next.y][next.x] in [",","=","9"]:return false
 for other: Dictionary in data.objects:
  if other==obj or not other.get("enabled",true):continue
  var p:=Vector2i(other.pos[0],other.pos[1]);var size: Array=other.get("size",[1,1])
  if Rect2i(p,Vector2i(size[0],size[1])).grow(1).has_point(at):return false
  if other.type=="profession_resource" and p.distance_to(at)<3.0:return false
 for other: Dictionary in legacy:
  if str(other.get("id",""))==str(obj.get("id","")):continue
  if Vector2i(other.pos[0],other.pos[1]).distance_to(at)<3.0:return false
 for spawn: Array in data.spawns.values():
  if Vector2i(spawn[0],spawn[1]).distance_to(at)<2:return false
 return true
static func relocate(data: Dictionary,obj: Dictionary,map_id: String,legacy: Array) -> bool:
 var origin:=Vector2i(obj.pos[0],obj.pos[1])
 if canopy_clear(data,origin):return true
 var start: Array=data.spawns.start
 var reachable:=Trail.connected(data,Vector2i(start[0],start[1]),data.rows.size()*data.rows[0].length())
 for radius in range(1,11):
  var candidates: Array[Vector2i]=[]
  for y in range(origin.y-radius,origin.y+radius+1):
   for x in range(origin.x-radius,origin.x+radius+1):
    var at:=Vector2i(x,y)
    if absi(x-origin.x)+absi(y-origin.y)!=radius or not reachable.has(at):continue
    if safe(data,at,obj,map_id,legacy):candidates.append(at)
  if not candidates.is_empty():
   candidates.sort_custom(func(a,b):return a.distance_squared_to(origin)<b.distance_squared_to(origin))
   var at:=candidates[0];obj.pos=[at.x,at.y]
   return true
 return false
