extends RefCounted
## Pure layout rules also validate foreign saves. All service approaches stay open.
const Catalog:=preload("res://scripts/data/house_catalog.gd")
const Stock:=preload("res://scripts/core/stockroom.gd")
const ROOM:=Rect2i(2,2,10,10)
const MAX_PIECES:=12
const MAX_SOLID:=26
const FIXED:=[Rect2i(7,3,1,2),Rect2i(9,7,1,2),Rect2i(10,5,1,1)]
static var busy:=false
static func gs() -> Node:return Engine.get_main_loop().root.get_node("GameState")
static func defaults() -> Dictionary:
 var owned: Dictionary={}
 for kind: String in Catalog.PIECES:owned[kind]=int(Catalog.START_OWNED.get(kind,0))
 return {"owned":owned,"layout":Catalog.DEFAULT_LAYOUT.duplicate(true),"floor":0,"wall":0,"light":0}
static func number(value: Variant,fallback: int,limit: int) -> int:
 if not (value is int or value is float) or not is_finite(float(value)):return fallback
 return int(clampf(float(value),0,limit))
static func normalize(raw: Variant) -> Dictionary:
 var out:=defaults()
 if not raw is Dictionary:return out
 for key in ["floor","wall","light"]:out[key]=number(raw.get(key,0),0,2 if key=="light" else 3)
 var owned: Variant=raw.get("owned",{})
 if owned is Dictionary:
  for kind: String in Catalog.PIECES:
   out.owned[kind]=maxi(int(out.owned.get(kind,0)),number(owned.get(kind,0),0,Catalog.PIECES[kind].cap))
 var layout: Variant=raw.get("layout",null)
 if layout is Dictionary and layout_reason(layout,out.owned)=="":
  out.layout={}
  for id: String in layout:
   var e: Dictionary=layout[id]
   out.layout[id]={"kind":str(e.kind),"cell":[int(e.cell[0]),int(e.cell[1])],"tint":int(e.get("tint",0))}
 return out
static func state() -> Dictionary:
 if not gs().personal_home.has("layout"):gs().personal_home=normalize(gs().personal_home)
 return gs().personal_home
static func rect(entry: Dictionary) -> Rect2i:
 var cell: Array=entry.cell
 return Rect2i(Vector2i(int(cell[0]),int(cell[1])),Catalog.PIECES[entry.kind].size)
static func world_position(entry: Dictionary) -> Vector2:
 var r:=rect(entry)
 return Vector2(r.position)*32+Vector2(r.size.x*16,r.size.y*32-16)
static func fixed_cells() -> Dictionary:
 var cells: Dictionary={}
 for r: Rect2i in FIXED:
  for y in range(r.position.y,r.end.y):
   for x in range(r.position.x,r.end.x):cells[Vector2i(x,y)]=true
 return cells
static func reserved(at: Vector2i) -> bool:
 return (at.x in [6,7] and at.y>=6) or (at.y==5 and at.x>=6) or at in [Vector2i(10,6),Vector2i(9,9)]
static func layout_reason(layout: Dictionary,owned: Dictionary) -> String:
 if layout.size()>MAX_PIECES:return TranslationServer.translate("Er passen maximaal twaalf meubels; berg eerst iets op.")
 var used:=fixed_cells();var counts: Dictionary={};var solid:=0
 for id: Variant in layout:
  if not id is String or not layout[id] is Dictionary:return TranslationServer.translate("Ongeldige meubelgegevens.")
  var e: Dictionary=layout[id]
  if not e.get("kind","") is String or not Catalog.PIECES.has(e.get("kind","")):return TranslationServer.translate("Onbekend meubel.")
  var kind: String=e.kind
  if not Catalog.PIECES[kind].get("base",false):
   var suffix: String=id.trim_prefix(kind+":")
   if not id.begins_with(kind+":") or not suffix.is_valid_int() or int(suffix)<1 or int(suffix)>int(Catalog.PIECES[kind].cap):return TranslationServer.translate("Ongeldige meubelgegevens.")
  var cell: Variant=e.get("cell",null)
  if not cell is Array or cell.size()!=2:return TranslationServer.translate("Ongeldige meubelpositie.")
  for n: Variant in cell:
   if not (n is int or n is float) or not is_finite(float(n)) or float(n)<2 or float(n)>11 or float(n)!=floor(float(n)):return TranslationServer.translate("Plaats binnen de kamer.")
  var tint: Variant=e.get("tint",0)
  if not (tint is int or tint is float) or not is_finite(float(tint)) or float(tint)<0 or float(tint)>2 or float(tint)!=floor(float(tint)):return TranslationServer.translate("Ongeldige meubelkleur.")
  if Catalog.PIECES[kind].get("base",false) and id!=kind:return TranslationServer.translate("Een basismeubel kan maar één keer worden geplaatst.")
  counts[kind]=int(counts.get(kind,0))+1
  if int(counts[kind])>int(owned.get(kind,0)):return TranslationServer.translate("Dit meubel is nog niet in je meubelvoorraad.")
  var area:=rect(e)
  if not ROOM.encloses(area):return TranslationServer.translate("Plaats binnen de kamer.")
  if Catalog.PIECES[kind].get("floor",false):continue
  for y in range(area.position.y,area.end.y):
   for x in range(area.position.x,area.end.x):
    var at:=Vector2i(x,y)
    if reserved(at):return TranslationServer.translate("Houd de deur en de gemarkeerde looproute vrij.")
    if used.has(at):return TranslationServer.translate("Hier staat al iets; laat meubels naast elkaar passen.")
    used[at]=true;solid+=1
 if solid>MAX_SOLID:return TranslationServer.translate("Laat meer open vloer over; berg eerst een groot meubel op.")
 for kind in ["bed","table","shelf"]:
  if not layout.has(kind) or layout[kind].get("kind","")!=kind:return TranslationServer.translate("Bed, tafel en boekenkast blijven aanwezig; je kunt ze wel verplaatsen.")
 # A complete flood fill prevents islands and unreachable corners, beyond the marked route.
 var start:=Vector2i(6,10);var seen: Dictionary={start:true};var queue: Array[Vector2i]=[start];var i:=0
 while i<queue.size():
  var at:=queue[i];i+=1
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i=at+step
   if ROOM.has_point(next) and not used.has(next) and not seen.has(next):seen[next]=true;queue.append(next)
 if seen.size()!=ROOM.size.x*ROOM.size.y-used.size():return TranslationServer.translate("Er raakt een hoek afgesloten; houd de kamer verbonden met de deur.")
 var bed:=rect(layout.bed);var reachable:=false
 for at in [Vector2i(bed.position.x-1,bed.end.y-1),Vector2i(bed.end.x,bed.end.y-1),Vector2i(bed.position.x,bed.end.y)]:
  if seen.has(at):reachable=true
 if not reachable:return TranslationServer.translate("Laat een bereikbare plek naast of voor het bed vrij.")
 return ""
static func candidate(layout: Dictionary,id: String,kind: String,at: Vector2i,tint: int) -> Dictionary:
 var next:=layout.duplicate(true);next[id]={"kind":kind,"cell":[at.x,at.y],"tint":tint};return next
static func next_id(kind: String,layout: Dictionary) -> String:
 if Catalog.PIECES[kind].get("base",false):return kind
 for i in range(1,int(state().owned.get(kind,0))+1):
  var id:=kind+":"+str(i)
  if not layout.has(id):return id
 return ""
static func unlocked(kind: String) -> bool:
 if not Catalog.PIECES.has(kind):return false
 var info: Dictionary=Catalog.PIECES[kind]
 var found: bool=not info.has("item") or gs().count(info.get("item",""))>0
 if info.get("item","")=="crystal_bos" and (gs().flag("gate_temple") or gs().flag("game_completed")):found=true
 return (not info.has("flag") or gs().flag(info.flag)) and found
static func make_reason(kind: String) -> String:
 if gs().map_id!="player_home" or gs().transitioning or gs().ended:return TranslationServer.translate("Richt je woning binnen in je eigen huis in.")
 if not Catalog.PIECES.has(kind):return TranslationServer.translate("Onbekend meubel.")
 var info: Dictionary=Catalog.PIECES[kind]
 if int(state().owned.get(kind,0))>=int(info.cap):return TranslationServer.translate("Je hebt al genoeg van dit meubel.")
 if not unlocked(kind):return TranslationServer.translate(info.get("hint","Nog niet ontdekt."))
 for item: String in info.cost:
  if Stock.available(item)<int(info.cost[item]):return TranslationServer.translate("Je mist materialen; je tas en bereikbare kist tellen mee.")
 return ""
static func make(kind: String) -> bool:
 if busy or make_reason(kind)!="":return false
 busy=true
 var cost: Dictionary=Catalog.PIECES[kind].cost
 if not cost.is_empty() and not Stock.consume(cost):busy=false;return false
 state().owned[kind]=int(state().owned.get(kind,0))+1
 gs().save_requested.emit();busy=false;return true
static func player_reason(layout: Dictionary,player_position: Vector2) -> String:
 for e: Dictionary in layout.values():
  if Catalog.PIECES[e.kind].get("floor",false):continue
  var bounds:=Rect2(Vector2(rect(e).position)*32,Vector2(rect(e).size)*32).grow(8)
  if bounds.has_point(player_position):return TranslationServer.translate("Je staat te dichtbij; loop eerst naar het vrije middenpad.")
 return ""
static func apply(draft: Dictionary,world: Node) -> bool:
 if busy or not is_instance_valid(world) or world!=Engine.get_main_loop().current_scene or gs().map_id!="player_home" or gs().transitioning or gs().ended:return false
 for key in ["layout","floor","wall","light"]:
  if not draft.has(key):return false
 if not draft.layout is Dictionary:return false
 if layout_reason(draft.get("layout",{}),state().owned)!="" or player_reason(draft.layout,world.player.position)!="":return false
 busy=true
 var next:=state().duplicate(true)
 for key in ["layout","floor","wall","light"]:next[key]=draft[key].duplicate(true) if draft[key] is Dictionary else draft[key]
 gs().personal_home=normalize(next);sync(world);gs().save_requested.emit();busy=false;return true
static func sync(world: Node):
 for n in Engine.get_main_loop().get_nodes_in_group("home_stations"):
  if not n.is_queued_for_deletion() and n.world==world and n.obj.role in ["bed","table","shelf"]:n.refresh_home()
 for n in Engine.get_main_loop().get_nodes_in_group("house_furniture"):
  if n.world==world:
   n.get_parent().remove_child(n);n.queue_free()
 for id: String in state().layout:
  var e: Dictionary=state().layout[id]
  if Catalog.PIECES[e.kind].get("base",false) or Catalog.PIECES[e.kind].get("floor",false):continue
  var n: StaticBody2D=load("res://scripts/entities/house_furniture.gd").new();n.world=world;n.entry=e.duplicate(true);world.entities.add_child(n)
 for n in Engine.get_main_loop().get_nodes_in_group("personal_house"):
  if n.world==world:n.queue_redraw()
