extends RefCounted
## Saved active-time simulation. No offline catch-up, decay or mandatory upkeep.
const Layout:=preload("res://scripts/data/homestead_maps.gd")
const CROPS:={"grape":{"seed":"hs_seed","seconds":90.0,"output":"hs_grape","yield":3},"flower":{"seed":"hs_flower_seed","seconds":60.0,"output":"hs_flower_seed","yield":1}}
const JOBS:={"compost":{"input":"hs_manure","cost":2,"output":"hs_fertilizer","yield":3,"seconds":30.0},"wine_a":{"input":"hs_grape","cost":3,"output":"hs_wine","yield":1,"seconds":90.0},"wine_b":{"input":"hs_grape","cost":3,"output":"hs_wine","yield":1,"seconds":90.0}}
const FLOWERS:=[Vector2i(14,34),Vector2i(16,34),Vector2i(14,35)]
static var sources: Dictionary=Layout.water()
static var mode:=""
static var busy:=false
static var wet: Dictionary={}
static var dirty:=true
static var show_water:=false
static var flow: Dictionary={}
static func gs() -> Node:return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
static func key(cell: Vector2i) -> String:return str(cell.x)+","+str(cell.y)
static func cell(value: String) -> Vector2i:
 var parts:=value.split(",");return Vector2i(int(parts[0]),int(parts[1])) if parts.size()==2 else Vector2i(-1,-1)
static func garden(at: Vector2i) -> bool:return Rect2i(4,29,31,12).has_point(at) and at.x not in [20,21]
static func reset():mode="";dirty=true;wet.clear();flow.clear();show_water=false;busy=false
static func normalize(raw: Variant) -> Dictionary:
 var result: Dictionary={"cells":{},"jobs":{},"animal_due":{},"drops":{},"wild_due":0.0,"honey":0,"honey_time":0.0}
 if not raw is Dictionary:return result
 if raw.get("cells") is Dictionary:
  for id: Variant in raw.cells:
   if not id is String or not garden(cell(id)):continue
   var entry: Variant=raw.cells[id]
   if not entry is Dictionary or entry.get("kind") not in ["soil","channel"]:continue
   var clean: Dictionary={"kind":entry.kind}
   if entry.kind=="soil" and entry.get("crop","") in CROPS:
    var crop: String=entry.crop;clean["crop"]=crop;clean["growth"]=number(entry.get("growth"),0,CROPS[crop].seconds);clean["fertilized"]=entry.get("fertilized",false)==true
   result.cells[id]=clean
 if raw.get("jobs") is Dictionary:
  for id: String in JOBS:
   var j: Variant=raw.jobs.get(id)
   if j is Dictionary:result.jobs[id]={"batches":int(number(j.get("batches"),1,20)),"time":number(j.get("time"),0,JOBS[id].seconds)}
 for field in ["animal_due","drops"]:
  if not raw.get(field) is Dictionary:continue
  for id: Variant in raw[field]:
   if result[field].size()>=128:break
   if not id is String or id.length()>140:continue
   var value: Variant=raw[field][id]
   if field=="animal_due":result[field][id]=number(value,0,gs().play_time+90)
   elif value is Dictionary and value.get("map") is String and value.get("pos") is Array and value.pos.size()==2:
    if (value.pos[0] is float or value.pos[0] is int) and (value.pos[1] is float or value.pos[1] is int):result.drops[id]={"map":value.map,"pos":[number(value.pos[0],0,10000),number(value.pos[1],0,10000)]}
 result.wild_due=number(raw.get("wild_due"),0,gs().play_time+120)
 result.honey=int(number(raw.get("honey"),0,8));result.honey_time=number(raw.get("honey_time"),0,120)
 return result
static func number(value: Variant,low: float,high: float) -> float:
 return clampf(float(value),low,high) if (value is int or value is float) and is_finite(float(value)) else low
static func state() -> Dictionary:
 if not gs().homestead.has("cells"):gs().homestead=normalize({})
 return gs().homestead
static func irrigate():
 if not dirty:return
 dirty=false;wet.clear();flow.clear()
 var channels: Dictionary={};var source:=sources;var queue: Array[Vector2i]=[]
 for id: String in state().cells:
  if state().cells[id].kind=="channel":channels[cell(id)]=true
 for at: Vector2i in channels:
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   if source.has(at+step):wet[at]=true;flow[at]=at+step;queue.append(at);break
 var head:=0
 while head<queue.size():
  var at: Vector2i=queue[head];head+=1
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i=at+step
   if channels.has(next) and not wet.has(next):wet[next]=true;flow[next]=at;queue.append(next)
static func watered(at: Vector2i) -> bool:
 irrigate()
 for step in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
  if wet.has(at+step) or sources.has(at+step):return true
 return false
static func flowers() -> int:
 var n:=0;var data:=state()
 for at: Vector2i in FLOWERS:
  if not data.cells.has(key(at)):n+=1
 for id: String in data.cells:
  var e: Dictionary=data.cells[id]
  if e.get("crop","")=="flower" and e.growth>=CROPS.flower.seconds and cell(id).distance_to(Vector2i(15,32))<=5:n+=1
 return n
static func advance(delta: float):
 if delta<=0:return
 var data:=state();irrigate()
 for id: String in data.cells:
  var e: Dictionary=data.cells[id]
  if CROPS.has(e.get("crop","")) and watered(cell(id)):e.growth=minf(CROPS[e.crop].seconds,float(e.growth)+delta)
 for id: String in data.jobs:data.jobs[id].time=minf(JOBS[id].seconds,float(data.jobs[id].time)+delta)
 if flowers()>=3 and data.honey<8:
  data.honey_time+=delta
  while data.honey_time>=120 and data.honey<8:data.honey+=1;data.honey_time-=120
 elif data.honey>=8:data.honey_time=0.0
 for id: String in data.drops.keys():
  if gs().flag("hs_drop:"+id):
   data.drops.erase(id);gs().flags.erase("hs_drop:"+id);gs().save_requested.emit()
static func changed():dirty=true;gs().save_requested.emit()
static func near(role: String,unit: String="") -> bool:
 for node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("home_stations"):
  if not node.is_queued_for_deletion() and node.obj.role==role and (unit=="" or node.obj.get("unit","")==unit) and node.world.player.position.distance_to(node.position)<=68:return true
 return false
static func starter() -> bool:
 if busy or gs().flag("hs_supplies") or not (near("supplies") or near("guide")):return false
 var pack: Dictionary={"hs_hoe":1,"hs_seed":8,"hs_flower_seed":4}
 for item: String in pack:
  if gs().room(item)<pack[item]:return false
 busy=true;gs().set_flag("hs_supplies")
 for item: String in pack:gs().give(item,pack[item],true)
 busy=false;changed();return true
static func act(at: Vector2i,action: String,world: Node) -> bool:
 if busy or gs().input_locked() or not work_status(at,action,world).ok:return false
 var data:=state();var id:=key(at);var e: Dictionary=data.cells.get(id,{})
 busy=true;var ok:=false
 if action=="soil" and e.is_empty():data.cells[id]={"kind":"soil"};ok=true
 elif action=="channel" and e.is_empty():data.cells[id]={"kind":"channel"};ok=true
 elif action in CROPS and e.get("kind","")=="soil" and not e.has("crop") and gs().count(CROPS[action].seed)>0:
  e["crop"]=action;e["growth"]=0.0;e["fertilized"]=false;gs().take(CROPS[action].seed);ok=true
 elif action=="fertilize" and e.get("crop","")=="grape" and not e.get("fertilized",false) and gs().count("hs_fertilizer")>0:
  e.fertilized=true;gs().take("hs_fertilizer");ok=true
 elif action=="harvest":ok=harvest_cell(e)
 elif action=="fill" and not e.is_empty():
  var seed: String=CROPS[e.crop].seed if e.has("crop") else ""
  if seed=="" or gs().room(seed)>0:
   data.cells.erase(id)
   if seed!="":gs().give(seed,1,true)
   ok=true
 busy=false
 if ok:
  changed()
 return ok
static func harvest_cell(e: Dictionary) -> bool:
 if e.get("crop","")!="grape" or float(e.growth)<CROPS.grape.seconds:return false
 var count:=5 if e.get("fertilized",false) else 3
 if gs().room("hs_grape")<count:return false
 e.growth=0.0;e.fertilized=false;gs().give("hs_grape",count,true);gs().set_flag("hs_intro_harvest")
 load("res://scripts/core/professions.gd").add_xp("foraging",4);return true
static func harvest_all() -> int:
 if busy or gs().map_id not in ["village","player_home"] or not near("guide"):return 0
 busy=true;var n:=0
 for id: String in state().cells:
  if harvest_cell(state().cells[id]):n+=1
 busy=false
 if n>0:changed()
 return n
static func start_job(id: String,batches: int) -> bool:
 if busy or not JOBS.has(id) or batches<1 or batches>20 or state().jobs.has(id):return false
 if gs().map_id!="village" or not near("compost" if id=="compost" else "wine","" if id=="compost" else id):return false
 var job: Dictionary=JOBS[id]
 if load("res://scripts/core/stockroom.gd").available(job.input)<job.cost*batches:return false
 busy=true
 if not load("res://scripts/core/stockroom.gd").consume({job.input:job.cost*batches}):busy=false;return false
 state().jobs[id]={"batches":batches,"time":0.0};busy=false;changed();return true
static func collect(id: String) -> bool:
 if busy or gs().map_id!="village":return false
 if not near("hive" if id=="hive" else "compost" if id=="compost" else "wine","" if id in ["hive","compost"] else id):return false
 if id=="hive":
  var count: int=state().honey
  if count==0 or gs().room("hs_honey")<count:return false
  busy=true;state().honey=0;gs().give("hs_honey",count,true);busy=false;changed();return true
 if not state().jobs.has(id):return false
 var active: Dictionary=state().jobs[id];var recipe: Dictionary=JOBS[id];var count: int=active.batches*recipe.yield
 if float(active.time)<recipe.seconds or gs().room(recipe.output)<count:return false
 busy=true;state().jobs.erase(id);gs().give(recipe.output,count,true);load("res://scripts/core/professions.gd").add_xp("cooking",active.batches*3);busy=false;changed();return true
static func animal_drop(animal: Node):
 if animal.dead or animal.is_queued_for_deletion() or animal.has_meta("practice"):return
 var id: String=gs().map_id+":"+animal.kind+":"+key(Vector2i(animal.home_position/32))
 var data:=state()
 if data.drops.size()>=64 or gs().play_time<float(data.animal_due.get(id,0)):return
 data.animal_due[id]=gs().play_time+90
 var drop_id:=id+":"+str(int(gs().play_time*1000))
 data.drops[drop_id]={"map":gs().map_id,"pos":[animal.position.x,animal.position.y]}
 changed()
static func wild_grapes() -> bool:
 if busy or gs().map_id!="forest" or not near("wild_grape") or gs().play_time<float(state().wild_due) or gs().room("hs_grape")<3:return false
 busy=true;state().wild_due=gs().play_time+120;gs().give("hs_grape",3,true);load("res://scripts/core/professions.gd").add_xp("foraging",4);busy=false;changed();return true

static func work_status(at: Vector2i,action: String,world: Node) -> Dictionary:
 return load("res://scripts/core/garden_feedback.gd").status(at,action,world)
