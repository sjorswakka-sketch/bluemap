extends RefCounted
const Tiles:=preload("res://scripts/data/tiles.gd")
const Layout:=preload("res://scripts/data/water_layouts.gd")
const TYPES:={
 "river":{"name":"Rivier","fresh":true,"irrigates":true,"flow":1.1,"color":Color("659faa"),"detail":"Stromend zoet water dat naar de kust afwatert."},
 "puddle":{"name":"Plas","fresh":true,"irrigates":true,"flow":0.0,"color":Color("91aba3"),"detail":"Een ondiepe regenkom met stilstaand zoet water."},
 "stream":{"name":"Beek","fresh":true,"irrigates":true,"flow":.65,"color":Color("7fb9b4"),"detail":"Een smalle zoetwaterloop vanuit hoger bosgebied."},
 "lake":{"name":"Meer","fresh":true,"irrigates":true,"flow":.08,"color":Color("688fae"),"detail":"Diep, rustig zoet water. Visplekken blijven aan de bestaande oevers."},
 "sea":{"name":"Zee","fresh":false,"irrigates":false,"flow":.3,"color":Color("6e9fae"),"detail":"Zout getijdenwater; niet geschikt voor landbouwirrigatie."},
 "marsh":{"name":"Moeras","fresh":true,"irrigates":false,"flow":.04,"color":Color("849b79"),"detail":"Ondiep veenwater tussen riet en modder. Gebruik de droge paden en bruggen."},
 "canal":{"name":"Kanaal","fresh":true,"irrigates":true,"flow":.5,"color":Color("83bdbb"),"detail":"Aangevoerd zoet water. Sluit je smalle irrigatiegreppels langs de oever aan."},
 "geyser":{"name":"Geiser","fresh":false,"irrigates":false,"flow":.0,"color":Color("b2c9c0"),"detail":"Een warme mineraalbron in de aardbreuk. De waterstraal barst regelmatig uit; geen irrigatiewater."},
 "hot_spring":{"name":"Warmwaterbron","fresh":true,"irrigates":false,"flow":.03,"color":Color("9ebfb2"),"detail":"Warme kwel langs de besneeuwde breuklijn. Stilstaan aan de oever herstelt langzaam hartjes."},
 "pool":{"name":"Poel","fresh":true,"irrigates":true,"flow":.02,"color":Color("8eae9b"),"detail":"Een beschutte zoetwaterkom, gevoed door regen of kwel."}
}
const ESTUARY_DETAIL:="Brak mondingswater: rivier en zee komen hier samen. Niet geschikt voor landbouwirrigatie."
static func properties(kind: String,id: String) -> Dictionary:
 var result: Dictionary=TYPES[kind].duplicate()
 if kind=="river" and id=="river_mouth":result.fresh=false;result.irrigates=false;result.detail=ESTUARY_DETAIL
 return result
static func wet(c: String) -> bool:return c in ["~","F","3","8"]
static func inside(rows: Array,p: Vector2i) -> bool:return p.y>=0 and p.y<rows.size() and p.x>=0 and p.x<rows[p.y].length()
static func components(rows: Array) -> Array:
 var unseen: Dictionary={};var result: Array=[]
 for y in rows.size():
  for x in rows[y].length():
   if wet(rows[y][x]):unseen[Vector2i(x,y)]=true
 while not unseen.is_empty():
  var first: Vector2i=unseen.keys()[0];var queue: Array[Vector2i]=[first];var seen: Dictionary={first:true};var cells: Array[Vector2i]=[];var head:=0
  while head<queue.size():
   var at:=queue[head];head+=1
   if wet(rows[at.y][at.x]):cells.append(at);unseen.erase(at)
   for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    var next: Vector2i=at+step
    if seen.has(next) or not inside(rows,next):continue
    if wet(rows[next.y][next.x]) or rows[next.y][next.x] in ["=","9"]:seen[next]=true;queue.append(next)
  result.append(cells)
 return result
static func enrich(id: String,data: Dictionary):
 for entry: Array in Layout.CHANGES.get(id,[]):
  var row: String=data.rows[entry[1]];row[entry[0]]=entry[2];data.rows[entry[1]]=row
 # A cascade belongs at the upstream, northern lip of its basin, never its outlet.
 for obj: Dictionary in data.objects:
  if id=="forest_edge" and obj.type=="home_station" and obj.get("role","")=="fall":obj.pos=[31,15]
 describe(id,data)
static func describe(id: String,data: Dictionary):
 data["water_features"]=[];data["water_cells"]={}
 for cells: Array in components(data.rows):
  var kind: String="canal" if id=="village" else "river" if id=="river_mouth" else "sea" if id in ["coast","gull_island","tide_cove","harbor","headland","tidal_hollow"] else "lake" if id=="lake" else "marsh" if id=="kruipmoeras" else "stream" if id=="forest" else "puddle" if id=="forest_edge" and cells.size()<12 else "pool"
  for special: Dictionary in Layout.FEATURES.get(id,[]):
   if cells.has(Vector2i(special.at[0],special.at[1])):kind=special.kind
  var north: Vector2i=cells[0]
  for at: Vector2i in cells:
   if at.y<north.y or (at.y==north.y and at.x<north.x):north=at
   data.water_cells[at]=kind
  data.water_features.append({"properties":properties(kind,id),"kind":kind,"cells":cells,"north":north,"count":cells.size()})
static func nearest(world: Node,range_px:=56.0) -> Dictionary:
 var best: Dictionary={};var distance:=range_px
 var origin:=Vector2i(world.player.position/32)
 var candidates: Array[Vector2i]=[]
 for y in range(origin.y-2,origin.y+3):
  for x in range(origin.x-2,origin.x+3):
   var cell:=Vector2i(x,y)
   if world.map_data.get("water_cells",{}).has(cell):candidates.append(cell)
 for at: Vector2i in candidates:
  var here: float=world.player.position.distance_to((Vector2(at)+Vector2(.5,.5))*32)
  if here<distance:
   distance=here;var kind: String=world.map_data.water_cells[at];best={"kind":kind,"at":at,"distance":here}
 return best
static func context(world: Node) -> Dictionary:
 var near:=nearest(world)
 if near.is_empty():return {}
 var spec: Dictionary=properties(near.kind,Engine.get_main_loop().root.get_node("GameState").map_id)
 return {"title":TranslationServer.translate(spec.name),"detail":TranslationServer.translate(spec.detail),"locked":false,"rect":Rect2(Vector2(near.at)*32,Vector2(32,32))}
static func irrigates(kind: String) -> bool:return TYPES.get(kind,{}).get("irrigates",false)
