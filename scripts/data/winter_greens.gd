extends RefCounted
## Winter roots grow on reachable, sheltered snow verges. Fixed species IDs keep
## saved regrowth stable even when an approach path is repaired later.
const Tiles := preload("res://scripts/data/tiles.gd")
const Trail := preload("res://scripts/data/trail_life.gd")
const Resources := preload("res://scripts/data/ext/beroepen.gd")
const PLANS := {
 "ijsdal": ["kale","broccoli","cauliflower","sprouts","beet","carrot","parsnip","leek"],
 "ridgepass": ["savoy","red_cabbage","spinach","lambs_lettuce","purslane","swede"],
 "steampeak": ["celeriac","salsify","kale","sprouts","carrot","parsnip","leek","savoy","spinach","lambs_lettuce","purslane","swede"],
}
const ANCHORS := {
 "ijsdal": [Vector2i(18,27),Vector2i(30,7),Vector2i(36,8),Vector2i(30,25),Vector2i(19,21),Vector2i(28,29),Vector2i(20,10),Vector2i(37,17)],
 "ridgepass": [Vector2i(7,16),Vector2i(8,9),Vector2i(19,9),Vector2i(20,16),Vector2i(26,11),Vector2i(6,4)],
 "steampeak": [Vector2i(12,52),Vector2i(57,52),Vector2i(21,36),Vector2i(52,36),Vector2i(24,19),Vector2i(48,19),Vector2i(28,7),Vector2i(44,7),Vector2i(24,55),Vector2i(47,55),Vector2i(30,35),Vector2i(40,20)],
}
static func path_distance(data: Dictionary) -> Dictionary:
 var seen: Dictionary={}
 var queue: Array[Vector2i]=[]
 for y in range(data.rows.size()):
  for x in range(data.rows[y].length()):
   if data.rows[y][x] in [",","=","9"]:
    var at:=Vector2i(x,y);seen[at]=0;queue.append(at)
 var head:=0
 while head<queue.size():
  var at:=queue[head];head+=1
  if int(seen[at])>=7:continue
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i=at+step
   if not seen.has(next) and Trail.ground(data,next):
    seen[next]=int(seen[at])+1;queue.append(next)
 return seen

static func clear(data: Dictionary,at: Vector2i) -> bool:
 if data.rows[at.y][at.x] not in ["z","f"]:return false
 if not Trail.clear(data,at,2):return false
 # Farm-like clearings beside homes belong to their occupants. Leave water
 # banks, cliffs and travel apertures open rather than hiding them in crops.
 for y in range(maxi(0,at.y-3),mini(data.rows.size(),at.y+4)):
  for x in range(maxi(0,at.x-3),mini(data.rows[y].length(),at.x+4)):
   if data.rows[y][x] in ["H","h","D","^","N"]:return false
 for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
  if not Trail.ground(data,at+step):return false
 return true

static func enrich(id: String,data: Dictionary):
 if not PLANS.has(id):return
 if data.objects.any(func(obj):return str(obj.get("id","")).begins_with("winter:")):return
 var start: Array=data.spawns.start
 var reach:=Trail.connected(data,Vector2i(start[0],start[1]),data.rows.size()*data.rows[0].length())
 var distances:=path_distance(data)
 var occupied: Array[Vector2i]=[]
 for obj: Dictionary in Resources.resource_objects(id):
  occupied.append(Vector2i(obj.pos[0],obj.pos[1]))
 for obj: Dictionary in data.objects:
  if obj.type=="profession_resource":occupied.append(Vector2i(obj.pos[0],obj.pos[1]))
 var candidates: Array[Vector2i]=[]
 for y in range(3,data.rows.size()-3):
  for x in range(3,data.rows[y].length()-3):
   var at:=Vector2i(x,y)
   if reach.has(at) and distances.has(at) and int(distances[at])>=2 and int(distances[at])<=7 and clear(data,at):
    candidates.append(at)
 for index in PLANS[id].size():
  var kind: String="winter_"+str(PLANS[id][index])
  var anchor: Vector2i=ANCHORS[id][index]
  var chosen:=Vector2i(-1,-1)
  var best:=INF
  for at in candidates:
   if occupied.any(func(other):return other.distance_to(at)<4.0):continue
   var score:=float(at.distance_squared_to(anchor))+float(distances[at])*2.0
   if score<best:best=score;chosen=at
  if chosen.x<0:continue
  data.objects.append({"type":"profession_resource","id":"winter:%s:%s" % [id,PLANS[id][index]],"kind":kind,"pos":[chosen.x,chosen.y]})
  occupied.append(chosen)
