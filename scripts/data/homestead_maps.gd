extends RefCounted
## Append-only objects; old coordinates and collection slots stay stable.
static func water() -> Dictionary:
 var result: Dictionary={}
 for y in range(22,29):result[Vector2i(36,y)]=true;result[Vector2i(37,y)]=true
 for y in range(24,27):
  for x in range(34,38):result[Vector2i(x,y)]=true
 for x in range(20,38):result[Vector2i(x,28)]=true
 for y in range(29,43):
  if y not in [31,37]:result[Vector2i(20,y)]=true;result[Vector2i(21,y)]=true
 result.erase(Vector2i(28,28))
 result.erase(Vector2i(20,41));result.erase(Vector2i(20,42))
 for entry: Array in preload("res://scripts/data/water_layouts.gd").CHANGES.get("village",[]):
  var at:=Vector2i(entry[0],entry[1])
  if entry[2]=="~":result[at]=true
  else:result.erase(at)
 return result
static func put(data: Dictionary,cell: Vector2i,value: String):
 var row: String=data.rows[cell.y];row[cell.x]=value;data.rows[cell.y]=row
static func enrich(id: String,data: Dictionary):
 if id=="village":
  # The lake exit follows the enlarged village to its southern edge.
  for y in range(26,44):
   if y>=data.rows.size():data.rows.append("##....................................##" if y<43 else "########################################")
   for x in range(4,17):
    if y<43:put(data,Vector2i(x,y),".")
  for y in range(22,32):put(data,Vector2i(7,y),",");put(data,Vector2i(8,y),",")
  for cell in water():put(data,cell,"~")
  for y in [31,37]:
   for x in range(18,24):put(data,Vector2i(x,y),"=")
  put(data,Vector2i(28,28),"=")
  for y in range(22,44):
   for x in [18,19]:put(data,Vector2i(x,y),",")
  # Remove the old map-edge tree wall and keep a green verge beside the path.
  for y in [26,27]:
   for x in range(16,24):put(data,Vector2i(x,y),"," if x in [18,19] else ".")
  for x in range(18,24):put(data,Vector2i(x,31),"=" if x in [20,21] else ",")
  for y in range(41,44):
   for x in [18,19]:put(data,Vector2i(x,y),",")
  for y in range(41,44):
   put(data,Vector2i(20,y),"=" if y<43 else ",")
  for obj: Dictionary in data.objects:
   if obj.type=="portal" and obj.to=="lake":obj.pos=[19,42]
   elif obj.type=="sign" and obj.pos==[18,24]:obj.pos=[17,40]
   elif obj.type=="npc" and obj.get("id","")=="willem":obj.pos=[25,12]
  data.spawns["from_lake"]=[19,40]
  data.spawns["from_home"]=[7,22];data.spawns["home_altar"]=[9,24]
  data.objects.append_array([
   {"type":"portal","pos":[7,21],"to":"player_home","spawn":"start"},
   {"type":"savepoint","pos":[9,23],"spawn":"home_altar","name":"Bij je eigen huis"},
   {"type":"home_station","pos":[7,15],"role":"compost"},
   {"type":"home_station","pos":[6,23],"role":"guide"},
   {"type":"home_station","pos":[4,25],"role":"wine","unit":"wine_a"},
   {"type":"home_station","pos":[12,25],"role":"wine","unit":"wine_b"},
   {"type":"home_station","pos":[15,32],"role":"hive","unit":"hive"},
   {"type":"home_station","pos":[36,21],"role":"fall"}])
 if id=="player_home":data.objects.append({"type":"stock_chest","pos":[10,5]})
 if id=="village":data.objects.append({"type":"stock_chest","pos":[9,26],"enabled":false})
 if id=="forest":
  data.objects.append({"type":"home_station","pos":[7,6],"role":"wild_grape"})
 # A small spring bowl in the quiet Bosrand, away from the main path and its exits.
 if id=="forest_edge":
  for cell in [Vector2i(16,7),Vector2i(17,7),Vector2i(16,8),Vector2i(17,8),Vector2i(30,21),Vector2i(31,21)]:put(data,cell,"~")
  data.objects.append({"type":"home_station","pos":[30,21],"role":"fall"})
