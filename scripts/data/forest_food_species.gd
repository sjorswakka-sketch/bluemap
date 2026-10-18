extends RefCounted
## Fixed species and sparse authored verges. Existing node IDs/indexes stay put.
const Food:=preload("res://scripts/data/ext/forest_food_species.gd")
const Trail:=preload("res://scripts/data/trail_life.gd")
const Legacy:=preload("res://scripts/data/ext/beroepen.gd")
const Placement:=preload("res://scripts/core/forage_placement.gd")
const Tiles:=preload("res://scripts/data/tiles.gd")
const LEGACY_SPECIES:={"berries":"blueberry","frostberries":"lingonberry","veenbessen":"cranberry","cactusfigs":"cactusfig"}
const FRUIT_POOLS:={
 "village":["blueberry","raspberry","blackberry"],
 "forest_edge":["blueberry","raspberry","wild_strawberry","rosehip"],
 "forest":["blueberry","blackberry","wild_apple","wild_pear","wild_plum"],
 "dauwbos":["blackcurrant","gooseberry","redcurrant","grape"],
 "mistgarden":["raspberry","wild_strawberry","blackcurrant"],
 "lake":["gooseberry","redcurrant","wild_pear"],
 "coast":["sea_buckthorn","rosehip","grape"],
 "river_mouth":["wild_plum","redcurrant","blackberry"],
 "gull_island":["grape","wild_strawberry"],
 "headland":["sea_buckthorn","rosehip"],
 "tide_cove":["grape","sea_buckthorn"],
 "ijsdal":["lingonberry"],"ridgepass":["lingonberry"],"steampeak":["lingonberry"],
 "dorstvallei":["cactusfig"],"sunwell":["cactusfig"],
 "kruipmoeras":["cranberry","blackcurrant"],"watchyard":["blueberry","rosehip"],
 "harbor":["sea_buckthorn","rosehip"]
}
const NUT_POOLS:={
 "village":["hazelnut","walnut"],
 "forest_edge":["hazelnut","butternut"],
 "forest":["hazelnut","walnut","chestnut"],
 "dauwbos":["beechnut","black_walnut"],
 "mistgarden":["hazelnut","butternut"],
 "lake":["hickory","walnut"],
 "coast":["pine_nut","coconut"],
 "river_mouth":["pecan","hickory"],
 "gull_island":["macadamia","coconut"],
 "headland":["pine_nut","almond"],
 "tide_cove":["cashew","macadamia"],
 "ijsdal":["cedar_nut"],"ridgepass":["cedar_nut"],"steampeak":["japanese_walnut","cedar_nut"],
 "dorstvallei":["almond","pistachio"],"sunwell":["pistachio"],
 "kruipmoeras":["walnut","hickory"],"watchyard":["hazelnut","beechnut"],
 "harbor":["pine_nut","almond"]
}
# One guaranteed, named site per species. Repeated verge nodes are converted
# in place rather than replaced by a denser new population.
const PLANS:={
 "forest_edge":["hazelnut","blueberry","raspberry"],
 "forest":["walnut","chestnut","wild_apple","blackberry"],
 "dauwbos":["beechnut","black_walnut","grape","blackcurrant"],
 "mistgarden":["butternut","gooseberry","wild_strawberry"],
 "lake":["hickory","redcurrant","wild_pear"],
 "coast":["pine_nut","coconut"],
 "river_mouth":["pecan","wild_plum"],
 "gull_island":["macadamia"],
 "tide_cove":["cashew"],
 "headland":["sea_buckthorn","rosehip"],
 "dorstvallei":["almond","cactusfig"],
 "sunwell":["pistachio"],
 "kruipmoeras":["cranberry"],
 "ijsdal":["lingonberry"],
 "ridgepass":["cedar_nut"],
 "steampeak":["japanese_walnut"]
}
const ANCHORS:={
 "forest_edge":[Vector2i(10,17),Vector2i(11,7),Vector2i(24,8)],
 "forest":[Vector2i(15,7),Vector2i(16,25),Vector2i(33,7),Vector2i(36,27)],
 "dauwbos":[Vector2i(12,10),Vector2i(32,14),Vector2i(10,28),Vector2i(32,22)],
 "mistgarden":[Vector2i(9,6),Vector2i(20,8),Vector2i(20,14)],
 "lake":[Vector2i(14,5),Vector2i(35,11),Vector2i(12,29)],
 "coast":[Vector2i(23,9),Vector2i(31,29)],
 "river_mouth":[Vector2i(23,28),Vector2i(49,24)],
 "gull_island":[Vector2i(30,12)],
 "tide_cove":[Vector2i(38,15)],
 "headland":[Vector2i(28,20),Vector2i(55,30)],
 "dorstvallei":[Vector2i(17,9),Vector2i(33,20)],
 "sunwell":[Vector2i(19,12)],
 "kruipmoeras":[Vector2i(31,24)],
 "ijsdal":[Vector2i(14,5)],
 "ridgepass":[Vector2i(22,16)],
 "steampeak":[Vector2i(53,34)]
}

static func kind_for(map_id: String,at: Vector2i,resource_id: String,old_kind:="") -> String:
 if old_kind not in ["trail_fruit","trail_nuts"]:return old_kind
 var choices: Array=(NUT_POOLS if old_kind=="trail_nuts" else FRUIT_POOLS).get(map_id,[])
 if choices.is_empty():return old_kind
 var index:=absi((map_id+":"+resource_id+":"+str(at)).hash())%choices.size()
 return "ff_"+str(choices[index])

static func decorate(map_id: String,obj: Dictionary) -> void:
 if obj.type!="profession_resource":return
 var old_kind: String=str(obj.get("kind",""))
 obj.kind=kind_for(map_id,Vector2i(obj.pos[0],obj.pos[1]),str(obj.get("id","")),old_kind)
 var species: String=LEGACY_SPECIES.get(obj.kind,"")
 if str(obj.kind).begins_with("ff_"):species=str(obj.kind).trim_prefix("ff_")
 if Food.SPECIES.has(species):
  obj["species"]=species;obj["wild_category"]=Food.SPECIES[species].category

static func road_distance(data: Dictionary) -> Dictionary:
 var seen: Dictionary={};var queue: Array[Vector2i]=[]
 for y in data.rows.size():
  for x in data.rows[y].length():
   if data.rows[y][x] in [",","=","9"]:
    var at:=Vector2i(x,y);seen[at]=0;queue.append(at)
 var limit:=9
 if queue.is_empty():
  # Some natural clearings and oasis bowls intentionally have no paved road.
  # Their fixed gathering sites still follow the reachable arrival clearing.
  var start: Array=data.spawns.start
  var at:=Vector2i(start[0],start[1]);seen[at]=0;queue.append(at)
  limit=data.rows.size()*data.rows[0].length()
 var head:=0
 while head<queue.size():
  var at:=queue[head];head+=1
  if int(seen[at])>=limit:continue
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i=at+step
   if not seen.has(next) and Trail.ground(data,next):seen[next]=int(seen[at])+1;queue.append(next)
 if limit>9:
  for at: Vector2i in seen:seen[at]=mini(9,int(seen[at]))
 return seen

static func clear(data: Dictionary,at: Vector2i,map_id: String) -> bool:
 if not Trail.ground(data,at) or not Trail.clear(data,at,1,map_id) or not Placement.canopy_clear(data,at):return false
 if data.rows[at.y][at.x] not in [".","z","f","a","e","L","U","j","s","4","5","6"]:return false
 for y in range(maxi(0,at.y-3),mini(data.rows.size(),at.y+4)):
  for x in range(maxi(0,at.x-3),mini(data.rows[y].length(),at.x+4)):
   if data.rows[y][x] in ["H","h","D","^","N"]:return false
 for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
  if not Trail.ground(data,at+step):return false
 return true

static func enrich(map_id: String,data: Dictionary) -> void:
 for obj: Dictionary in data.objects:
  decorate(map_id,obj)
  if obj.type=="profession_resource" and str(obj.get("kind","")).begins_with("ff_"):
   Placement.relocate(data,obj,map_id,Legacy.resource_objects(map_id))
 if not PLANS.has(map_id) or data.objects.any(func(o):return str(o.get("id","")).begins_with("forestfood:")):return
 var start: Array=data.spawns.start
 var reach:=Trail.connected(data,Vector2i(start[0],start[1]),data.rows.size()*data.rows[0].length())
 var distances:=road_distance(data)
 var occupied: Array[Vector2i]=[];var present: Dictionary={}
 for obj: Dictionary in Legacy.resource_objects(map_id):
  decorate(map_id,obj);occupied.append(Vector2i(obj.pos[0],obj.pos[1]))
  if Food.SPECIES.has(str(obj.get("species",""))):present[obj.species]=true
 for obj: Dictionary in data.objects:
  if obj.type!="profession_resource":continue
  occupied.append(Vector2i(obj.pos[0],obj.pos[1]))
  if Food.SPECIES.has(str(obj.get("species",""))):present[obj.species]=true
 var candidates: Array[Vector2i]=[]
 for y in range(3,data.rows.size()-3):
  for x in range(3,data.rows[y].length()-3):
   var at:=Vector2i(x,y)
   if reach.has(at) and distances.has(at) and int(distances[at])>=2 and int(distances[at])<=9 and clear(data,at,map_id):candidates.append(at)
 for index in PLANS[map_id].size():
  var species: String=PLANS[map_id][index]
  if present.has(species):continue
  var anchor: Vector2i=ANCHORS[map_id][index]
  var chosen:=Vector2i(-1,-1);var best:=INF
  for at in candidates:
   if occupied.any(func(other):return other.distance_to(at)<4.0):continue
   var score:=float(at.distance_squared_to(anchor))+float(distances[at])*3.0
   if score<best:best=score;chosen=at
  if chosen.x<0:continue
  data.objects.append({"type":"profession_resource","id":"forestfood:%s:%s" % [map_id,species],"kind":"ff_"+species,"pos":[chosen.x,chosen.y],"species":species,"wild_category":Food.SPECIES[species].category})
  occupied.append(chosen);present[species]=true
