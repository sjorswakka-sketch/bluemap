extends RefCounted
## Bounded material storage; a whole transfer commits before inventory signals.
const SLOTS:=12
const CAP:=99
static var busy:=false
static func gs() -> Node:return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
static func allowed(item: String) -> bool:
 var items: Script=load("res://scripts/data/items.gd")
 return items.ITEMS.has(item) and items.info(item).get("type","")=="material"
static func normalize(raw: Variant) -> Dictionary:
 var result: Dictionary={}
 if not raw is Dictionary:return result
 for item: Variant in raw:
  if result.size()>=SLOTS:break
  if not item is String or not allowed(item):continue
  var value: Variant=raw[item]
  if (value is int or value is float) and is_finite(float(value)) and float(value)>=1:result[item]=int(clampf(float(value),1,CAP))
 return result
static func count(item: String) -> int:return int(gs().coastal_storage.get(item,0))
static func room(item: String) -> int:
 if not allowed(item):return 0
 if count(item)==0 and gs().coastal_storage.size()>=SLOTS:return 0
 return maxi(0,CAP-count(item))
static func available(item: String,deposit: bool) -> int:return gs().count(item) if deposit else count(item)
static func movable(item: String,deposit: bool) -> int:
 return mini(available(item,deposit),room(item) if deposit else gs().room(item)) if allowed(item) else 0
static func transfer(item: String,amount: int,deposit: bool) -> bool:
 if gs().map_id!="coast_workshop" or gs().ended or gs().transitioning or busy or amount<=0 or movable(item,deposit)<amount:return false
 busy=true
 if deposit:
  gs().coastal_storage[item]=count(item)+amount
  gs().take(item,amount)
 else:
  var left:=count(item)-amount
  if left>0:gs().coastal_storage[item]=left
  else:gs().coastal_storage.erase(item)
  gs().give(item,amount,true)
 gs().save_requested.emit();busy=false
 return true
static func set_furniture(kind: String,mode: int) -> bool:
 if gs().map_id!="coast_workshop" or gs().ended or gs().transitioning:return false
 if kind=="shelf" and gs().count("cw_shelf")>0 and mode in [0,1]:
  gs().flags["cw_shelf_placed"]=mode==1
 elif kind=="lamp" and gs().count("cw_lamp")>0 and mode in [0,1,2]:
  gs().flags["cw_lamp_on"]=mode>0;gs().flags["cw_lamp_sea"]=mode==2
 else:return false
 # False flags must not be serialized: legacy flag loading treats keys as true.
 for flag: String in ["cw_shelf_placed","cw_lamp_on","cw_lamp_sea"]:
  if gs().flags.has(flag) and not gs().flags[flag]:gs().flags.erase(flag)
 gs().save_requested.emit();return true
