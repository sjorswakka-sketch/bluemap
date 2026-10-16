extends RefCounted
const Farm:=preload("res://scripts/core/homestead.gd")
const Data:=preload("res://scripts/data/orchard_catalog.gd")
const Yard:=preload("res://scripts/core/yard.gd")
static var busy:=false
static func gs() -> Node:return Engine.get_main_loop().root.get_node("GameState")
static func canopy_reason(at: Vector2i,world: Node,cells: Dictionary) -> String:
 var trees:=0
 for e: Dictionary in cells.values():
  if e.get("crop","")=="apple":trees+=1
 if trees>=12:return TranslationServer.translate("Laat ruimte over: maximaal twaalf appelbomen in je tuin.")
 for y in range(at.y-1,at.y+2):
  for x in range(at.x-1,at.x+2):
   var c:=Vector2i(x,y)
   if not Farm.garden(c) or Yard.terrain(c)!="." or Yard.reserved(c) or Yard.fixed().has(c):return TranslationServer.translate("Een appelboom heeft drie bij drie tegels vrije kroonruimte buiten de looproutes nodig.")
   if Data.tree_cover(c,cells).x>=0:return TranslationServer.translate("Laat de kronen van appelbomen vrij van elkaar.")
   if c!=at and cells.has(Farm.key(c)):return TranslationServer.translate("Houd de kroonruimte vrij van gewassen en kanalen; leg water op twee tegels van de stam.")
   if Yard.blocks_work(c):return TranslationServer.translate("Houd paden en erfwerk vrij van de boomkroon.")
   for unit: String in Yard.Data.UNITS:
    var anchor:=Yard.anchor(unit)
    if anchor.x>=0 and Yard.bounds(anchor).has_point(c):return TranslationServer.translate("Houd paden en erfwerk vrij van de boomkroon.")
   if not world.spawn_fits(Vector2(c)*32+Vector2(16,16)) and c!=at:return TranslationServer.translate("Houd paden en erfwerk vrij van de boomkroon.")
 return ""
static func patch_reason(at: Vector2i) -> String:
 for unit: String in Yard.Data.UNITS:
  var anchor:=Yard.anchor(unit)
  if anchor.x>=0 and Yard.bounds(anchor).has_point(at):return TranslationServer.translate("Plant nieuwe gewassen buiten de zichtbare ruimte rond je werkplekken.")
 return ""
static func supply_reason() -> String:
 if gs().ended or gs().transitioning or gs().map_id not in ["village","player_home"] or not (Farm.near("guide") or Farm.near("supplies")):return TranslationServer.translate("Haal zaden en stekken bij je tuingids of de voorraad in je huis.")
 return ""
static func starter() -> bool:
 if busy or gs().flag("or_starter") or supply_reason()!="":return false
 for item: String in Data.STARTER:
  if gs().room(item)<Data.STARTER[item]:return false
 busy=true;gs().set_flag("or_starter")
 for item: String in Data.STARTER:gs().give(item,Data.STARTER[item],true)
 gs().save_requested.emit();busy=false;return true
static func buy_reason(crop: String,n: int) -> String:
 if not Data.PRICES.has(crop) or n not in [1,5]:return TranslationServer.translate("Kies een beschikbare teelt.")
 var reason:=supply_reason()
 if reason!="":return reason
 if gs().coins<int(Data.PRICES[crop])*n:return TranslationServer.translate("Je hebt te weinig munten voor dit zaad.")
 if gs().room(Data.CROPS[crop].seed)<n:return TranslationServer.translate("Maak ruimte in je tas voor de zaden of stekken.")
 return ""
static func buy(crop: String,n: int) -> bool:
 if busy or buy_reason(crop,n)!="":return false
 busy=true;gs().add_coins(-int(Data.PRICES[crop])*n);gs().give(Data.CROPS[crop].seed,n,true);gs().save_requested.emit();busy=false;return true
static func sync(world: Node):
 if not is_instance_valid(world) or not world.is_inside_tree() or gs().map_id!="village":return
 var remaining: Dictionary={}
 for n in Engine.get_main_loop().get_nodes_in_group("orchard_trees"):
  if n.world==world and not n.is_queued_for_deletion():remaining[n.cell]=n
 for id: String in Farm.state().cells:
  if Farm.state().cells[id].get("crop","")!="apple":continue
  var at:=Farm.cell(id)
  if remaining.has(at):remaining.erase(at);continue
  var n: Node2D=load("res://scripts/entities/orchard_tree.gd").new();n.world=world;n.cell=at;world.entities.add_child(n)
 for n: Node in remaining.values():n.get_parent().remove_child(n);n.queue_free()
