extends RefCounted
## Private yard state: no map/object reordering, no crop loss, no remote production.
const Data:=preload("res://scripts/data/yard_catalog.gd")
const Stock:=preload("res://scripts/core/stockroom.gd")
const Tiles:=preload("res://scripts/data/tiles.gd")
const MAX_PATHS:=80
const MAX_FENCES:=40
static var busy:=false
static var _map: Dictionary={}
static var _fixed: Dictionary={}
static var _base_reach: Dictionary={}
static func gs() -> Node:return Engine.get_main_loop().root.get_node("GameState")
static func key(at: Vector2i) -> String:return str(at.x)+","+str(at.y)
static func cell(value: String) -> Vector2i:
 var p:=value.split(",")
 if p.size()!=2 or not p[0].is_valid_int() or not p[1].is_valid_int():return Vector2i(-99,-99)
 return Vector2i(int(p[0]),int(p[1]))
static func defaults() -> Dictionary:
 var stations: Dictionary={}
 for id: String in Data.UNITS:stations[id]=Data.UNITS[id].start.duplicate()
 return {"stations":stations,"paths":{},"fences":{},"owned":Data.OWNED.duplicate(),"extensions":[]}
static func map_data() -> Dictionary:
 if _map.is_empty():_map=load("res://scripts/maps/registry.gd").get_map("village")
 return _map
static func terrain(at: Vector2i) -> String:
 var rows: Array=map_data().rows
 return rows[at.y][at.x] if at.y>=0 and at.y<rows.size() and at.x>=0 and at.x<rows[at.y].length() else "#"
static func unit_of(obj: Dictionary) -> String:
 if obj.type!="home_station":return ""
 return obj.get("unit","") if obj.get("role","") in ["wine","hive"] else "compost" if obj.get("role","")=="compost" else ""
static func anchor(id: String,data: Dictionary={}) -> Vector2i:
 var value: Array=(state() if data.is_empty() else data).stations.get(id,[])
 return Vector2i(int(value[0]),int(value[1])) if value.size()==2 else Vector2i(-999,-999)
static func bounds(at: Vector2i) -> Rect2i:return Rect2i(at-Vector2i.ONE,Vector2i(3,3))
static func fixed() -> Dictionary:
 if not _fixed.is_empty():return _fixed
 var specs: Array=map_data().objects.duplicate(true)
 specs.append_array(load("res://scripts/data/ext/beroepen.gd").resource_objects("village"))
 for obj: Dictionary in specs:
  if unit_of(obj)!="":continue
  var at:=Vector2i(obj.pos[0],obj.pos[1]);var r:=Rect2i(at,Vector2i.ONE)
  if obj.type=="npc":r=r.grow(1)
  for y in range(r.position.y,r.end.y):
   for x in range(r.position.x,r.end.x):_fixed[Vector2i(x,y)]=true
 return _fixed
static func reserved(at: Vector2i) -> bool:
 return Rect2i(6,21,4,4).has_point(at) or Rect2i(17,30,9,3).has_point(at) or Rect2i(17,36,9,3).has_point(at) or Rect2i(17,39,6,4).has_point(at) or at in [Vector2i(9,27),Vector2i(6,24)]
static func owned_cell(at: Vector2i,extensions: Array) -> bool:
 for r: Rect2i in Data.BASE_PLOTS:
  if r.has_point(at):return true
 for id: String in extensions:
  if Data.EXTENSIONS.has(id) and Data.EXTENSIONS[id].rect.has_point(at):return true
 return false
static func plots() -> Array[Rect2i]:
 var out: Array[Rect2i]=[]
 out.assign(Data.BASE_PLOTS)
 for e: Dictionary in Data.EXTENSIONS.values():out.append(e.rect)
 return out
static func on_plot(at: Vector2i) -> bool:
 for r: Rect2i in plots():
  if r.has_point(at):return true
 return false
static func farm_cells() -> Dictionary:return gs().homestead.get("cells",{})
static func cells_in(r: Rect2i) -> Array[Vector2i]:
 var out: Array[Vector2i]=[]
 for y in range(r.position.y,r.end.y):
  for x in range(r.position.x,r.end.x):out.append(Vector2i(x,y))
 return out
static func place_reason(at: Vector2i,data: Dictionary,farm: Dictionary,solid: bool) -> String:
 if not owned_cell(at,data.extensions):return TranslationServer.translate("Kies je bestaande erf of ontsluit eerst deze bouwruimte.")
 if terrain(at)!="." or fixed().has(at) or (solid and reserved(at)):return TranslationServer.translate("Houd water, gebouwen, bruggen en bestaande doorgangen vrij.")
 if farm.has(key(at)):return TranslationServer.translate("Hier ligt landbouwgrond of een kanaal; je tuin wordt niet overschreven.")
 return ""
static func used(data: Dictionary,group: String) -> int:
 var n:=0
 for kind: String in data.paths.values():
  if kind==group:n+=1
 for kind: String in data.fences.values():
  if Data.PIECES[kind].group==group:n+=1
 return n
static func walk_blocked(data: Dictionary) -> Dictionary:
 var out:=fixed().duplicate()
 for id: String in Data.UNITS:
  var at:=anchor(id,data)
  if at.x<0:continue
  out[at]=true
  if id=="compost":out[at+Vector2i.LEFT]=true
 for id: String in data.fences:
  if not Data.PIECES[data.fences[id]].get("gate",false):out[cell(id)]=true
 return out
static func reachable(data: Dictionary) -> Dictionary:
 var blocked:=walk_blocked(data);var start:=Vector2i(7,22);blocked.erase(start)
 var seen: Dictionary={start:true};var queue: Array[Vector2i]=[start];var head:=0
 while head<queue.size():
  var at:=queue[head];head+=1
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i=at+step
   if next.x<0 or next.x>=40 or next.y<0 or next.y>=44 or seen.has(next) or blocked.has(next):continue
   if Tiles.is_solid_name(Tiles.CHARS.get(terrain(next),"grass")):continue
   seen[next]=true;queue.append(next)
 return seen
static func layout_reason(data: Dictionary,farm: Dictionary,baseline: Dictionary={}) -> String:
 if data.paths.size()>MAX_PATHS or data.fences.size()>MAX_FENCES:return TranslationServer.translate("Laat ruimte over: maximaal tachtig padtegels en veertig hek- of poortdelen.")
 for group: String in Data.SUPPLIES:
  if used(data,group)>int(data.owned.get(group,0)):return TranslationServer.translate("Maak eerst meer delen voor deze hele rij.")
 var station_areas: Dictionary={}
 for id: String in Data.UNITS:
  var at:=anchor(id,data)
  if at.x<0:continue
  var r:=bounds(at);station_areas[id]=r
  var original:=false
  for unit: String in Data.UNITS:
   if data.stations[id]==Data.UNITS[unit].start:original=true
  var untouched: bool=original and ((baseline.is_empty() and data.stations[id]==Data.UNITS[id].start) or (not baseline.is_empty() and baseline.stations[id]==data.stations[id]))
  for c: Vector2i in cells_in(r):
   if not original:
    var reason:=place_reason(c,data,farm,true)
    if reason!="":return reason
   elif not untouched and farm.has(key(c)):return TranslationServer.translate("De oude werkplek is inmiddels bewerkt; kies vrije grond.")
 for a: String in station_areas:
  for b: String in station_areas:
   if a!=b and station_areas[a].grow(1).intersects(station_areas[b]):return TranslationServer.translate("Laat een tegel vrije ruimte tussen de werkplekken.")
 for field in ["paths","fences"]:
  for id: String in data[field]:
   var at:=cell(id);var kind: String=data[field][id]
   var reason:=place_reason(at,data,farm,field=="fences")
   if reason!="":return reason
   for r: Rect2i in station_areas.values():
    if r.has_point(at):return TranslationServer.translate("Laat de zichtbare ruimte rond de werkplek vrij.")
   if field=="paths" and data.fences.has(id) and not Data.PIECES[data.fences[id]].get("gate",false):return TranslationServer.translate("Leg een poortje op het pad, geen gesloten hek.")
 if _base_reach.is_empty():_base_reach=reachable(defaults())
 var seen:=reachable(data);var blocked:=walk_blocked(data)
 for at: Vector2i in _base_reach:
  if on_plot(at) and not blocked.has(at) and not seen.has(at):return TranslationServer.translate("Dit sluit een stuk erf af; laat een poortje of doorgang open.")
 for at in [Vector2i(9,27),Vector2i(6,24),Vector2i(19,40),Vector2i(18,31),Vector2i(23,31),Vector2i(18,37),Vector2i(23,37)]:
  if _base_reach.has(at) and not seen.has(at):return TranslationServer.translate("De woning, opslag, beekbruggen en meerroute moeten bereikbaar blijven.")
 return ""
static func normalize(raw: Variant,farm: Dictionary={}) -> Dictionary:
 var out:=defaults()
 if not raw is Dictionary:return out
 if raw.get("extensions") is Array:
  for id: Variant in raw.extensions:
   if id is String and Data.EXTENSIONS.has(id) and id not in out.extensions:out.extensions.append(id)
 if raw.get("owned") is Dictionary:
  for group: String in Data.SUPPLIES:
   var value: Variant=raw.owned.get(group,0)
   if (value is int or value is float) and is_finite(float(value)):out.owned[group]=maxi(int(out.owned[group]),int(clampf(float(value),0,Data.SUPPLIES[group].cap)))
 if raw.get("stations") is Dictionary:
  for id: String in Data.UNITS:
   var value: Variant=raw.stations.get(id,Data.UNITS[id].start)
   if value is Array and value.is_empty():out.stations[id]=[];continue
   if value is Array and value.size()==2:
    if (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float):
     if is_finite(float(value[0])) and is_finite(float(value[1])) and float(value[0])>=0 and float(value[0])<40 and float(value[1])>=0 and float(value[1])<44:out.stations[id]=[int(value[0]),int(value[1])]
 # Repair optional pieces one by one; malformed data never deletes a crop or work-in-progress job.
 if layout_reason(out,farm,defaults())!="":
  for id: String in Data.UNITS:
   if out.stations[id]!=Data.UNITS[id].start:out.stations[id]=[]
 for field in ["paths","fences"]:
  if not raw.get(field) is Dictionary:continue
  var limit: int=MAX_PATHS if field=="paths" else MAX_FENCES
  for id: Variant in raw[field]:
   if out[field].size()>=limit:break
   if not id is String or not raw[field][id] is String:continue
   var kind: String=raw[field][id];var at:=cell(id)
   if not Data.PIECES.has(kind) or Data.PIECES[kind].get("path",false)!=(field=="paths") or key(at)!=id:continue
   var candidate:=out.duplicate(true);candidate[field][id]=kind
   # Connectivity is checked after all fence pieces, so a complete saved gate can reconnect its enclosure.
   if place_reason(at,candidate,farm,field=="fences")=="":out[field][id]=kind
 if layout_reason(out,farm,out)!="":out.paths={};out.fences={}
 return out
static func state() -> Dictionary:
 if not gs().yard.has("stations"):gs().yard=defaults()
 return gs().yard
static func blocks_work(at: Vector2i) -> bool:
 var data:=state()
 if data.paths.has(key(at)) or data.fences.has(key(at)):return true
 for id: String in Data.UNITS:
  if data.stations[id]!=Data.UNITS[id].start and anchor(id,data).x>=0 and bounds(anchor(id,data)).has_point(at):return true
 return false
static func flower_count_at(at: Vector2i,farm: Dictionary) -> int:
 if at.x<0:return 0
 var n:=0
 for c: Vector2i in Data.WILD_FLOWERS:
  if c.distance_to(at)<=5 and not farm.has(key(c)):n+=1
 for id: String in farm:
  var e: Dictionary=farm[id]
  if e.get("crop","")=="flower" and float(e.get("growth",0))>=60 and cell(id).distance_to(at)<=5:n+=1
 return n
static func surface(at: Vector2i) -> String:
 var kind: String=state().paths.get(key(at),"")
 return "yard_boards" if kind=="boards" else "path" if kind!="" else ""
static func material_reason(cost: Dictionary) -> String:
 if gs().map_id!="village" or gs().transitioning or gs().ended:return TranslationServer.translate("Richt je erf buiten bij je woning in.")
 for item: String in cost:
  if Stock.available(item)<int(cost[item]):return TranslationServer.translate("Je mist materialen; tas en bereikbare huisvoorraad tellen mee.")
 return ""
static func make(group: String) -> bool:
 if busy or not Data.SUPPLIES.has(group):return false
 var info: Dictionary=Data.SUPPLIES[group]
 if int(state().owned[group])+int(info.amount)>int(info.cap) or material_reason(info.cost)!="":return false
 busy=true
 if not Stock.consume(info.cost):busy=false;return false
 state().owned[group]+=int(info.amount);gs().save_requested.emit();busy=false;return true
static func expand(id: String) -> bool:
 if busy or not Data.EXTENSIONS.has(id) or id in state().extensions or material_reason(Data.EXTENSIONS[id].cost)!="":return false
 busy=true
 if not Stock.consume(Data.EXTENSIONS[id].cost):busy=false;return false
 state().extensions.append(id);gs().save_requested.emit();busy=false;return true
static func actor_reason(data: Dictionary,at: Vector2) -> String:
 var foot:=at+Vector2(0,8)
 for id: String in Data.UNITS:
  var anchor_cell:=anchor(id,data)
  if anchor_cell.x<0:continue
  var pos:=Vector2(anchor_cell)*32+Vector2(16,21)-Vector2(12 if id=="compost" else 0,0)
  var size:=Vector2(60,36) if id=="compost" else Vector2(25,14)
  if Rect2(pos-size/2,size).grow(8).has_point(foot):return TranslationServer.translate("Je staat te dichtbij; loop eerst naar het vrije erfpad.")
 for id: String in data.fences:
  var kind: String=data.fences[id]
  if Data.PIECES[kind].get("gate",false):continue
  var vertical: bool=kind.ends_with("_v")
  var pos:=Vector2(cell(id))*32+(Vector2(24,16) if vertical else Vector2(16,24))
  var size:=Vector2(6,28) if vertical else Vector2(28,6)
  if Rect2(pos-size/2,size).grow(9).has_point(foot):return TranslationServer.translate("Je staat te dichtbij; loop eerst naar het vrije erfpad.")
 return ""
static func schema_ok(data: Dictionary) -> bool:
 for id: String in Data.UNITS:
  var value: Variant=data.stations.get(id)
  if not value is Array or value.size() not in [0,2]:return false
  if value.size()==2:
   for v: Variant in value:
    if not v is int or v<0 or v>=44:return false
   if value[0]>=40:return false
 if data.stations.size()!=Data.UNITS.size():return false
 for field in ["paths","fences"]:
  for id: Variant in data[field]:
   if not id is String or key(cell(id))!=id:return false
   var kind: Variant=data[field][id]
   if not kind is String or not Data.PIECES.has(kind) or Data.PIECES[kind].get("path",false)!=(field=="paths"):return false
 return true
static func apply(draft: Dictionary,world: Node) -> bool:
 if busy or not is_instance_valid(world) or world!=Engine.get_main_loop().current_scene or gs().map_id!="village" or gs().transitioning or gs().ended:return false
 var next:=state().duplicate(true)
 for key_name in ["stations","paths","fences"]:
  if not draft.get(key_name) is Dictionary:return false
  next[key_name]=draft[key_name].duplicate(true)
 if not schema_ok(next):return false
 if layout_reason(next,farm_cells(),state())!="" or actor_reason(next,world.player.position)!="":return false
 busy=true;gs().yard=next;sync(world);gs().save_requested.emit();busy=false;return true
static func sync(world: Node):
 for n in Engine.get_main_loop().get_nodes_in_group("home_stations"):
  if n.world==world and not n.is_queued_for_deletion() and unit_of(n.obj)!="":n.refresh_yard()
 for n in Engine.get_main_loop().get_nodes_in_group("yard_fences"):
  if n.world==world:n.get_parent().remove_child(n);n.queue_free()
 for id: String in state().fences:
  var n: StaticBody2D=load("res://scripts/entities/yard_fence.gd").new();n.world=world;n.cell=cell(id);n.kind=state().fences[id];world.entities.add_child(n)
 for n in Engine.get_main_loop().get_nodes_in_group("yard_scenery"):
  if n.world==world:n.queue_redraw()
