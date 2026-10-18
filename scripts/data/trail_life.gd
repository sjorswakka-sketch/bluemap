extends RefCounted
## Sparse, deterministic verge patches; no displaced objects or save slots.
const Tiles:=preload("res://scripts/data/tiles.gd")
const Resources:=preload("res://scripts/data/ext/beroepen.gd")
const KINDS:=["trail_herbs","trail_flowers","trail_nuts","trail_seeds","trail_roots","trail_fruit"]
const SETTLEMENTS:=["village","harbor"]
static var reachable_cache: Dictionary={}
static func ground(data: Dictionary,at: Vector2i) -> bool:
 return at.y>0 and at.y<data.rows.size()-1 and at.x>0 and at.x<data.rows[at.y].length()-1 and not Tiles.is_solid_char(data.rows[at.y][at.x])
static func clear(data: Dictionary,at: Vector2i,margin:=2,id:="") -> bool:
 if id=="tide_cove" and Rect2i(19,24,14,4).has_point(at):return false
 if not ground(data,at):return false
 for obj: Dictionary in data.objects:
  if not obj.get("enabled",true):continue
  var p:=Vector2i(obj.pos[0],obj.pos[1])
  var size: Array=obj.get("size",[1,1])
  if Rect2i(p,Vector2i(size[0],size[1])).grow(margin).has_point(at):return false
 for p: Array in data.spawns.values():
  if Vector2i(p[0],p[1]).distance_to(at)<3:return false
 return true
static func connected(data: Dictionary,start: Vector2i,limit:=10) -> Dictionary:
 var seen: Dictionary={};var queue: Array[Vector2i]=[]
 # Portals may sit at the edge or on a door tile. Search inward from their rim.
 for step in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
  var at: Vector2i=start+step
  if ground(data,at):seen[at]=0;queue.append(at)
 var head:=0
 while head<queue.size():
  var at:=queue[head];head+=1
  if seen[at]>=limit:continue
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i=at+step
   if not seen.has(next) and ground(data,next):seen[next]=int(seen[at])+1;queue.append(next)
 return seen
static func enrich(id: String,data: Dictionary):
 var underground: bool=id in ["cave","ruins","prismamine","reedvault","tidal_hollow"]
 if not data.get("outdoor",false) and not underground:return
 var cache_key:=id+":"+str(data.rows.hash())
 if not reachable_cache.has(cache_key):
  var start: Array=data.spawns.start
  reachable_cache[cache_key]=connected(data,Vector2i(start[0],start[1]),data.rows.size()*data.rows[0].length())
 var accessible: Dictionary=reachable_cache[cache_key]
 var exits: Array[Vector2i]=[]
 for obj: Dictionary in data.objects:
  if obj.get("enabled",true) and (obj.type=="portal" or obj.get("travel_link",false)):
   # Indoor doors are not an invitation to place vegetation through buildings.
   if obj.type=="portal" and obj.to in ["smithy","shop","inn","player_home","temple","library","arena_hall","coast_workshop"]:continue
   exits.append(Vector2i(obj.pos[0],obj.pos[1]))
 var occupied: Array[Vector2i]=[]
 for spec: Dictionary in Resources.resource_objects(id):occupied.append(Vector2i(spec.pos[0],spec.pos[1]))
 var patches:=0
 for entry in exits:
  var reach:=connected(data,entry)
  var added:=0
  for at: Vector2i in reach:
   if added>=2:break
   if reach[at]<3 or not accessible.has(at) or not clear(data,at,2,id):continue
   if data.rows[at.y][at.x] in [",","=","9","D","T","E","A"]:continue
   if occupied.any(func(other):return other.distance_to(at)<4):continue
   # Keep the actual route and its shoulders readable, never plant a dense wall.
   if id=="village" and at.x<33 and at.y<22:continue
   if id=="village" and Rect2i(4,29,31,12).has_point(at):continue
   var kind: String=KINDS[(patches+absi(id.hash())%KINDS.size())%KINDS.size()]
   if underground:kind="trail_fungi"
   data.objects.append({"type":"profession_resource","id":"trail:%s:%d:%d" % [id,at.x,at.y],"kind":kind,"pos":[at.x,at.y]})
   occupied.append(at);patches+=1;added+=1
 if id in SETTLEMENTS:return
 # Outdoor regions with local settlements protect every home and resident.
 var count:=0
 for obj: Dictionary in data.objects:
  if obj.type=="enemy" and obj.get("kind","") in ["zandhaas","woestijnvos","moerasvors","waterslang","trail_macaque"]:count+=1
 if count>=3:return
 var species: String="trail_moth" if underground or id in ["forest_edge"] else "trail_gull" if id in ["coast","gull_island","tide_cove","river_mouth","headland"] else "trail_fox" if id in ["forest","dauwbos"] else "trail_hare"
 for y in range(3,data.rows.size()-3,3):
  for x in range(3,data.rows[y].length()-3,3):
   if count>=3:return
   var at:=Vector2i(x,y)
   if not accessible.has(at) or not clear(data,at,3,id) or data.rows[y][x] in [",","=","9"]:continue
   var near_home:=false
   for ny in range(maxi(0,y-4),mini(data.rows.size(),y+5)):
    for nx in range(maxi(0,x-4),mini(data.rows[ny].length(),x+5)):
     if data.rows[ny][nx] in ["H","h","D","^","N"]:near_home=true
   if near_home:continue
   if occupied.any(func(other):return other.distance_to(at)<5):continue
   if not [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN].all(func(step):return ground(data,at+step)):continue
   data.objects.append({"type":"enemy","kind":species,"pos":[x,y],"patrol_radius":96.0,"trail_wildlife":true})
   occupied.append(at);count+=1
 # Narrow caves need a smaller, harmless night moth rather than a large animal.
 if count==0 and underground:
  for y in range(2,data.rows.size()-2):
   for x in range(2,data.rows[y].length()-2):
    var at:=Vector2i(x,y)
    if accessible.has(at) and clear(data,at,1,id) and ground(data,at+Vector2i.DOWN) and not occupied.any(func(other):return other.distance_to(at)<2):
     data.objects.append({"type":"enemy","kind":"trail_moth","pos":[x,y],"patrol_radius":48.0,"trail_wildlife":true});return
