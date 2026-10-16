extends RefCounted
## Readable field feedback, shared by input, the world preview and the garden guide.
const Farm:=preload("res://scripts/core/homestead.gd")
static func crop_name(id: String) -> String:
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
 elif world.map_data.rows[at.y][at.x]!="." or not world.spawn_fits(Vector2(at)*32+Vector2(16,16)):
  reason=TranslationServer.translate("Houd deze plek vrij voor water, paden en voorwerpen.")
 elif action in ["soil","channel"]:
  if not e.is_empty():reason=TranslationServer.translate("Deze tegel is al bewerkt.")
 elif action in Farm.CROPS:
  if e.get("kind","")!="soil":reason=TranslationServer.translate("Bewerk eerst de grond.")
  elif e.has("crop"):reason=TranslationServer.translate("Hier groeit al iets.")
  elif Farm.gs().count(Farm.CROPS[action].seed)<1:reason=TranslationServer.translate("Je hebt geen passend zaad bij je.")
 elif action=="fertilize":
  if e.get("crop","")!="grape":reason=TranslationServer.translate("Meststof is bedoeld voor een druivenstok.")
  elif e.get("fertilized",false):reason=TranslationServer.translate("Deze stok is al bemest.")
  elif Farm.gs().count("hs_fertilizer")<1:reason=TranslationServer.translate("Maak eerst meststof op de mesthoop.")
 elif action=="harvest":
  if e.get("crop","")!="grape":reason=TranslationServer.translate("Richt op een druivenstok.")
  elif float(e.growth)<Farm.CROPS.grape.seconds:reason=TranslationServer.translate("Deze druiven zijn nog niet rijp.")
  elif Farm.gs().room("hs_grape")<(5 if e.get("fertilized",false) else 3):reason=TranslationServer.translate("Maak ruimte in je tas voor de volledige oogst.")
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
  var watered: bool=Farm.watered(at)
  var ready: bool=float(e.growth)>=Farm.CROPS[e.crop].seconds
  var stage: String=TranslationServer.translate("Rijp om te oogsten") if ready and e.crop=="grape" else TranslationServer.translate("In bloei") if ready else TranslationServer.translate("Groeit · nog %.0f s actieve speeltijd") % ceilf(Farm.CROPS[e.crop].seconds-float(e.growth)) if watered else TranslationServer.translate("Wacht op water · verdort niet")
  var detail: String=TranslationServer.translate("Opbrengst: %d druiven") % (5 if e.get("fertilized",false) else 3) if e.crop=="grape" else TranslationServer.translate("Voedt bijen binnen vijf tegels")
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
