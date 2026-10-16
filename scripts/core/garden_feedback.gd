extends RefCounted
## Readable field feedback, shared by input, the world preview and the garden guide.
const Farm:=preload("res://scripts/core/homestead.gd")
static func crop_name(id: String) -> String:
 if Farm.Crops.NAMES.has(id):return TranslationServer.translate(Farm.Crops.NAMES[id])
 return TranslationServer.translate("Druivenstok") if id=="grape" else TranslationServer.translate("Bloemen")
static func status(at: Vector2i,action: String,world: Node) -> Dictionary:
 var reason:=""
 var e: Dictionary=Farm.state().cells.get(Farm.key(at),{})
 if Farm.gs().map_id!="village" or not Farm.garden(at):
  reason=TranslationServer.translate("Werk binnen je eigen tuin.")
 elif Farm.gs().count("hs_hoe")==0:
  reason=TranslationServer.translate("Haal eerst je gratis tuinhak bij het tuinbord.")
 elif world.player.position.distance_to(Vector2(at)*32+Vector2(16,16))>68:
  reason=TranslationServer.translate("Kom iets dichterbij.")
 elif load("res://scripts/core/yard.gd").blocks_work(at):
  reason=TranslationServer.translate("Hier ligt je erfinrichting; berg die eerst op via Erf inrichten.")
 elif Farm.Crops.tree_cover(at,Farm.state().cells).x>=0 and Farm.Crops.tree_cover(at,Farm.state().cells)!=at:
  reason=TranslationServer.translate("Laat de kroonruimte rond de appelboom vrij; water kan buiten de kroon aansluiten.")
 elif e.get("crop","")=="apple" and action in ["harvest","fertilize","fill"]:
  reason=Farm.harvest_reason(e) if action=="harvest" else TranslationServer.translate("Deze boom is al bemest.") if action=="fertilize" and e.get("fertilized",false) else TranslationServer.translate("Maak eerst meststof op de mesthoop.") if action=="fertilize" and Farm.gs().count("hs_fertilizer")<1 else TranslationServer.translate("Maak ruimte in je tas voor het boompje.") if action=="fill" and Farm.gs().room("or_apple_seed")<1 else ""
 elif world.map_data.rows[at.y][at.x]!="." or not world.spawn_fits(Vector2(at)*32+Vector2(16,16)):
  reason=TranslationServer.translate("Houd deze plek vrij voor water, paden en voorwerpen.")
 elif action in ["soil","channel"]:
  if not e.is_empty():reason=TranslationServer.translate("Deze tegel is al bewerkt.")
 elif action in Farm.CROPS:
  if e.get("kind","")!="soil":reason=TranslationServer.translate("Bewerk eerst de grond.")
  elif e.has("crop"):reason=TranslationServer.translate("Hier groeit al iets.")
  elif Farm.gs().count(Farm.CROPS[action].seed)<1:reason=TranslationServer.translate("Je hebt geen passend zaad bij je.")
  elif action=="apple":reason=load("res://scripts/core/orchard.gd").canopy_reason(at,world,Farm.state().cells)
  elif Farm.Crops.NAMES.has(action):reason=load("res://scripts/core/orchard.gd").patch_reason(at)
 elif action=="fertilize":
  if not Farm.CROPS.get(e.get("crop",""),{}).has("bonus"):reason=TranslationServer.translate("Kies een oogstbaar gewas om te bemesten.")
  elif e.get("fertilized",false):reason=TranslationServer.translate("Deze stok is al bemest.")
  elif Farm.gs().count("hs_fertilizer")<1:reason=TranslationServer.translate("Maak eerst meststof op de mesthoop.")
 elif action=="harvest":
  reason=Farm.harvest_reason(e)
 elif action=="fill":
  if e.is_empty():reason=TranslationServer.translate("Deze grond is al hersteld.")
  elif e.has("crop") and Farm.gs().room(Farm.CROPS[e.crop].seed)<1:reason=TranslationServer.translate("Maak ruimte in je tas voor het zaad.")
 else:reason=TranslationServer.translate("Kies een tuinhandeling.")
 return {"ok":reason=="","reason":reason}
static func cell_text(at: Vector2i) -> String:
 var e: Dictionary=Farm.state().cells.get(Farm.key(at),{})
 if e.get("kind","")=="channel":
  return TranslationServer.translate("Kanaal aangesloten · water stroomt door.") if Farm.wet.has(at) else TranslationServer.translate("Droog kanaal · verbind met de beek of een gevuld kanaal.")
 if e.has("crop"):
  var watered: bool=Farm.crop_watered(at,e)
  var ready: bool=float(e.growth)>=Farm.Crops.duration(e)
  var stage: String=TranslationServer.translate("Rijp om te oogsten") if ready and e.crop!="flower" else TranslationServer.translate("In bloei") if ready else TranslationServer.translate("Groeit · nog %.0f s actieve speeltijd") % ceilf(Farm.Crops.duration(e)-float(e.growth)) if watered else TranslationServer.translate("Wacht op water · verdort niet")
  var detail: String=TranslationServer.translate("Opbrengst: %d druiven") % (5 if e.get("fertilized",false) else 3) if e.crop=="grape" else TranslationServer.translate("Voedt bijen binnen vijf tegels")
  if Farm.Crops.NAMES.has(e.crop):
   detail=TranslationServer.translate("Opbrengst: %d × %s") % [Farm.Crops.amount(e),TranslationServer.translate(load("res://scripts/data/items.gd").info(Farm.CROPS[e.crop].output).name)]
   detail+=" · "+(TranslationServer.translate("Zaad komt terug; daarna opnieuw planten") if Farm.CROPS[e.crop].get("annual",false) else TranslationServer.translate("Groeit na oogsten opnieuw aan"))
   if Farm.CROPS[e.crop].get("bees",false) and ready:detail+=" · "+TranslationServer.translate("Voedt bijen binnen vijf tegels")
  return crop_name(e.crop)+" · "+stage+"\n"+detail
 if e.get("kind","")=="soil":
  return TranslationServer.translate("Landbouwgrond · water aangesloten") if Farm.watered(at) else TranslationServer.translate("Landbouwgrond · leid water naar een aangrenzende tegel")
 return TranslationServer.translate("Vrije tuingrond")
static func guide_step() -> int:
 if Farm.gs().flag("hs_intro_harvest"):return 4
 var soil:=false;var water:=false;var planted:=false
 for id: String in Farm.state().cells:
  var e: Dictionary=Farm.state().cells[id]
  if e.get("kind","")!="soil":continue
  soil=true
  if Farm.watered(Farm.cell(id)):
   water=true
   if e.get("crop","")=="grape":planted=true
 if planted:return 3
 if water:return 2
 if soil:return 1
 return 0
static func guide_text() -> String:
 if Farm.gs().count("hs_hoe")==0:return TranslationServer.translate("Tuinhulp · Haal eerst je gratis hak en zaden bij het tuinbord.")
 match guide_step():
  0:return TranslationServer.translate("Tuinhulp 1/4 · Bewerk één vak grond bij de beek.")
  1:return TranslationServer.translate("Tuinhulp 2/4 · Graaf vanaf de beek een kanaal tot naast je grond.")
  2:return TranslationServer.translate("Tuinhulp 3/4 · Plant druiven op je bewaterde grond.")
  3:return TranslationServer.translate("Tuinhulp 4/4 · Ga gerust op pad en oogst zodra je druiven rijp zijn.")
 return TranslationServer.translate("Eerste oogst gelukt · je kunt je tuin op eigen tempo uitbreiden.")
