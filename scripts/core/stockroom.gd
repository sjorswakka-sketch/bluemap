extends RefCounted
## Shared home stock; only nearby physical stores supply materials. No permanent gear leaves the bag.
const Items:=preload("res://scripts/data/items.gd")
const SLOTS:=48
const CAP:=999
const REACH:=176.0
static var busy:=false
static func gs() -> Node:return Engine.get_main_loop().root.get_node("GameState")
static func allowed(item: String) -> bool:
 return Items.ITEMS.has(item) and Items.info(item).get("type","") in ["material","use","ammo"]
static func normalize(raw: Variant) -> Dictionary:
 var out: Dictionary={"home":{},"favorites":{},"sort":0}
 if not raw is Dictionary:return out
 var home: Variant=raw.get("home",{})
 if home is Dictionary:
  for id: String in home:
   var n: Variant=home[id]
   if out.home.size()<SLOTS and allowed(id) and (n is float or n is int) and is_finite(float(n)) and float(n)>=1:out.home[id]=int(minf(CAP,float(n)))
 var favorites: Variant=raw.get("favorites",{})
 if favorites is Dictionary:
  for id: String in favorites:
   if Items.ITEMS.has(id) and favorites[id]==true:out.favorites[id]=true
 var order: Variant=raw.get("sort",0)
 if order is int or order is float:
  if is_finite(float(order)):out.sort=int(clampf(float(order),0,3))
 return out
static func state() -> Dictionary:
 if not gs().stockroom.has("home"):gs().stockroom=normalize(gs().stockroom)
 return gs().stockroom
static func favorite(item: String) -> bool:return state().favorites.get(item,false)==true
static func toggle_favorite(item: String):
 if not Items.ITEMS.has(item):return
 if favorite(item):state().favorites.erase(item)
 else:state().favorites[item]=true
 gs().save_requested.emit()
static func category(item: String) -> int:
 if item.begins_with("or_") and Items.info(item).get("type","")=="material":return 2
 if item.begins_with("hs_") and item not in ["hs_grape","hs_wine","hs_honey","hs_hoe"]:return 2
 match Items.info(item).get("type",""):
  "material":return 1
  "use":return 3
  "gear","weapon","cloth","ammo":return 4
 return 5
static func nearby_kind() -> String:
 var tree: SceneTree=Engine.get_main_loop()
 if gs().transitioning or gs().ended or not gs().in_game:return ""
 for node in tree.get_nodes_in_group("stock_chests"):
  if is_instance_valid(node) and not node.is_queued_for_deletion() and node.world==tree.current_scene and gs().map_id in ["village","player_home"] and is_instance_valid(node.world.player) and node.position.distance_to(node.world.player.position)<=REACH:return "home"
 for node in tree.get_nodes_in_group("coastal_workstations"):
  if not node.is_queued_for_deletion() and node.obj.role=="storage" and gs().map_id=="coast_workshop" and node.world==tree.current_scene and node.position.distance_to(node.world.player.position)<=96:return "coast"
 return ""
static func stock(kind: String) -> Dictionary:
 return gs().coastal_storage if kind=="coast" else state().home
static func count(item: String,kind: String="home") -> int:return int(stock(kind).get(item,0))
static func available(item: String) -> int:
 var kind:=nearby_kind()
 return gs().count(item)+(count(item,kind) if kind!="" else 0)
static func room(item: String,kind: String) -> int:
 if not allowed(item) or (kind=="coast" and Items.info(item).get("type","")!="material"):return 0
 var data:=stock(kind)
 var slots:=12 if kind=="coast" else SLOTS
 if not data.has(item) and data.size()>=slots:return 0
 return maxi(0,(99 if kind=="coast" else CAP)-count(item,kind))
static func movable(item: String,deposit: bool,kind: String) -> int:
 if kind not in ["home","coast"] or kind!=nearby_kind() or not allowed(item):return 0
 return mini(gs().count(item),room(item,kind)) if deposit else mini(count(item,kind),gs().room(item))
static func _remove(data: Dictionary,item: String,n: int):
 var left:=int(data.get(item,0))-n
 if left<=0:data.erase(item)
 else:data[item]=left
static func _notify(save: bool=true):
 # Every mutation is committed before synchronous UI/quest listeners run.
 gs().items_changed.emit()
 gs()._refresh_quests()
 if save:gs().save_requested.emit()
static func transfer(item: String,amount: int,deposit: bool,kind: String) -> bool:
 if busy or amount<=0 or amount>movable(item,deposit,kind):return false
 busy=true
 if deposit:_remove(gs().inventory,item,amount);stock(kind)[item]=count(item,kind)+amount
 else:_remove(stock(kind),item,amount);gs().inventory[item]=gs().count(item)+amount
 _notify();busy=false;return true
static func bulk(existing_only: bool,kind: String) -> int:
 if busy or kind!=nearby_kind() or kind=="":return 0
 busy=true
 var moved:=0
 for item: String in gs().inventory.keys():
  if favorite(item) or not allowed(item):continue
  if existing_only and count(item,kind)==0:continue
  if not existing_only and Items.info(item).get("type","")!="material":continue
  var n:=mini(gs().count(item),room(item,kind))
  if n>0:_remove(gs().inventory,item,n);stock(kind)[item]=count(item,kind)+n;moved+=n
 if moved>0:_notify()
 busy=false;return moved
static func consume(inputs: Dictionary) -> bool:
 if busy:return false
 for item: String in inputs:
  if int(inputs[item])<=0 or available(item)<int(inputs[item]):return false
 var kind:=nearby_kind()
 busy=true
 for item: String in inputs:
  var bag:=mini(gs().count(item),int(inputs[item]))
  _remove(gs().inventory,item,bag)
  if int(inputs[item])>bag:_remove(stock(kind),item,int(inputs[item])-bag)
 # Upgrades can consume worn gear; preserve the ordinary inventory reconciliation.
 load("res://scripts/core/equipment.gd").reconcile()
 load("res://scripts/core/appearance.gd").reconcile()
 _notify(false);busy=false;return true
static func ids(data: Dictionary,query: String="",filter: int=0,only_favorites: bool=false) -> Array[String]:
 var out: Array[String]=[]
 for id: String in data:
  if int(data[id])<=0 or not Items.ITEMS.has(id):continue
  if filter>0 and category(id)!=filter:continue
  if only_favorites and not favorite(id):continue
  var name: String=TranslationServer.translate(Items.info(id).name)
  if query.strip_edges()!="" and not (name.to_lower().contains(query.strip_edges().to_lower()) or id.to_lower().contains(query.strip_edges().to_lower())):continue
  out.append(id)
 var order: int=state().sort
 if order>0:
  out.sort_custom(func(a: String,b: String) -> bool:
   if order==1 and category(a)!=category(b):return category(a)<category(b)
   if order==3 and int(data[a])!=int(data[b]):return int(data[a])>int(data[b])
   var an: String=TranslationServer.translate(Items.info(a).name).to_lower()
   var bn: String=TranslationServer.translate(Items.info(b).name).to_lower()
   return a<b if an==bn else an<bn)
 return out
