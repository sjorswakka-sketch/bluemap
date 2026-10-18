extends "res://tests/coast_expedition_test.gd"
const Placement:=preload("res://scripts/core/forage_placement.gd")
const Food:=preload("res://scripts/data/forest_food_species.gd")
const Species:=preload("res://scripts/data/ext/forest_food_species.gd")
const Resources:=preload("res://scripts/data/ext/beroepen.gd")
const Prof:=preload("res://scripts/core/professions.gd")
const Items:=preload("res://scripts/data/items.gd")
const Trail:=preload("res://scripts/data/trail_life.gd")
const Art:=preload("res://scripts/core/art.gd")
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 var fruit:=0;var nuts:=0;var plant_art: Dictionary={};var icons: Dictionary={}
 check(Species.SPECIES.size()==32,"exactly sixteen named fruits and sixteen named nuts")
 check(Art.tex("forest_food_plants").get_size()==Vector2(1024,32) and Art.tex("forest_food_items").get_size()==Vector2(512,16),"native 32px plants and 16px icons have all 32 frames")
 var found: Dictionary={};var total:=0
 for species: String in Species.SPECIES:
  var spec: Dictionary=Species.SPECIES[species]
  if spec.category=="fruit":fruit+=1
  else:nuts+=1
  check(Resources.RESOURCES.has(spec.kind) and Items.ITEMS.has(spec.item),"species has a real resource and inventory item "+species)
  check(spec.item in Prof.CONSUMABLES and Items.ITEMS[spec.item].type=="use","species can be eaten through existing food UI "+species)
  plant_art[hash(Art.tex("forest_food_plants").get_image().get_region(Rect2i(spec.frame*32,0,32,32)).get_data())]=true
  icons[hash(Art.tex("forest_food_items").get_image().get_region(Rect2i(spec.frame*16,0,16,16)).get_data())]=true
 check(fruit==16 and nuts==16,"both requested groups have sixteen distinct species")
 check(plant_art.size()==32 and icons.size()==32,"all species have unique authored plant and inventory art")
 for map_id: String in Maps.MAPS:
  var data: Dictionary=Maps.get_map(map_id);var again: Dictionary=Maps.get_map(map_id)
  var plants: Array=data.objects.filter(func(o):return str(o.get("id","")).begins_with("forestfood:"))
  check(plants==again.objects.filter(func(o):return str(o.get("id","")).begins_with("forestfood:")),"fixed species locations survive repeated map composition "+map_id)
  for obj: Dictionary in data.objects:
   if obj.type=="profession_resource":
    check(obj.kind not in ["trail_fruit","trail_nuts"],"no generic fruit or nut node remains "+str(obj.id))
    if str(obj.kind).begins_with("ff_"):check(Placement.canopy_clear(data,Vector2i(obj.pos[0],obj.pos[1])),"specific food patch is visible outside rendered tree canopy "+str(obj.id))
  if not Food.PLANS.has(map_id):
   check(plants.is_empty(),"no added crops inside buildings, villages, caves or challenge rooms "+map_id);continue
  var actual_nodes: Array=data.objects.filter(func(o):return o.type=="profession_resource")+Resources.resource_objects(map_id)
  var existing: Dictionary={};var available: Dictionary={}
  for source: Dictionary in actual_nodes:
   var copy: Dictionary=source.duplicate(true);Food.decorate(map_id,copy)
   var species_id: String=str(copy.get("species",""))
   if not Species.SPECIES.has(species_id):continue
   found[species_id]=true;available[species_id]=true
   if not str(copy.id).begins_with("forestfood:"):existing[species_id]=true
  var missing:=0
  for species_id: String in Food.PLANS[map_id]:
   check(available.has(species_id),"every planned species has a fixed existing or new site "+map_id+" "+species_id)
   if not existing.has(species_id):missing+=1
  check(plants.size()==missing,"only species absent from existing verges need new plants "+map_id)
  check(plants.size()<=4,"each area retains space and quiet "+map_id)
  var start: Array=data.spawns.start
  var reach:=Trail.connected(data,Vector2i(start[0],start[1]),data.rows.size()*data.rows[0].length())
  var old_nodes: Array=Resources.resource_objects(map_id)
  for plant: Dictionary in plants:
   total+=1;found[plant.species]=true
   var at:=Vector2i(plant.pos[0],plant.pos[1])
   check(reach.has(at) and Food.clear(data.duplicate(true).merged({"objects":data.objects.filter(func(o):return o!=plant)},true),at,map_id),"species is on reachable ground clear of travel and quest props "+plant.id)
   check(plant.species in Food.PLANS[map_id] and Resources.RESOURCES[plant.kind].wild_category==plant.wild_category,"site has meaningful biome and group metadata "+plant.id)
   for other: Dictionary in plants+old_nodes:
    if plant==other:continue
    check(at.distance_to(Vector2i(other.pos[0],other.pos[1]))>=4.0,"species has clear harvesting space "+plant.id)
  print("FOREST_FOOD_MAP ",map_id," ",plants.map(func(o):return [o.species,o.pos]))
 check(found.size()==32 and total<=32,"all 32 species really exist, reusing existing shrubs before adding more")
 var fixtures: Array=[
  {"type":"profession_resource","id":"trail:forest:8:5","kind":"trail_fruit","pos":[8,5]},
  {"type":"profession_resource","id":"trail:forest:17:22","kind":"trail_nuts","pos":[17,22]},
  {"type":"profession_resource","id":"forest:berries_west","kind":"berries","pos":[10,21]},
 ]
 for obj: Dictionary in fixtures:
  var old: Dictionary=obj.duplicate(true);Food.decorate("forest",obj)
  check(obj.id==old.id and obj.pos==old.pos,"converting an old node retains saved cooldown ID and position")
  if old.kind=="berries":check(obj.kind=="berries" and Resources.RESOURCES[obj.kind].item=="prof_berry","legacy berry kind and recipe item remain compatible")
  else:check(obj.kind.begins_with("ff_"),"generic old node becomes a fixed real species")
 for legacy: String in Food.LEGACY_SPECIES:
  check(Resources.RESOURCES[legacy].sheet=="forest_food_plants","legacy specific plant gets its own art "+legacy)
 check(Items.ITEMS.prof_berry.get("species","")=="blueberry" and Items.ITEMS.trail_nut.get("species","")=="hazelnut" and Items.ITEMS.hs_grape.get("species","")=="grape","old inventory IDs retain meaning instead of disappearing")
 for legacy_id: String in Species.ITEM_OVERRIDES:
  for field: String in Species.ITEM_OVERRIDES[legacy_id]:
   check(Items.info(legacy_id).get(field)==Species.ITEM_OVERRIDES[legacy_id][field],"legacy inventory metadata overrides actual item info "+legacy_id+" "+field)
 for species: String in Species.SPECIES:
  var spec: Dictionary=Species.SPECIES[species]
  gs.give(spec.item,1,true);gs.hp=2;gs.movement.stamina=10
  check(Prof.use_item(spec.item) and gs.count(spec.item)==0 and gs.hp==3 and gs.movement.stamina>10,"actual food grants heart and stamina "+species)
  check(int(Items.ITEMS[spec.item].get("sell",0))>0,"fruit or nut can be sold "+species)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await enter("forest_edge");p.set_physics_process(false)
 var node: Node2D
 for candidate in get_nodes_in_group("profession_resources"):
  if str(candidate.resource_id).begins_with("forestfood:"):node=candidate;break
 check(node!=null,"native world instantiates named food shrubs")
 if node!=null:
  p.position=node.position+Vector2(0,24);await frames(3)
  var item: String=Resources.RESOURCES[node.kind].item;var before: int=gs.count(item)
  node.interact();await frames(65)
  check(gs.count(item)==before+2 and Prof.remaining(node.resource_id)>170,"real timed harvest grants the correct species and starts regrowth")
  var resource_id: String=node.resource_id;var remaining:=Prof.remaining(resource_id)
  check(gs.save_game(p.position),"harvest save uses isolated game directory")
  gs.professions={};gs.inventory={}
  check(gs.load_game() and gs.count(item)==before+2 and Prof.remaining(resource_id)>remaining-3,"real save/reload preserves species harvest and exact known cooldown")
 world.queue_free();await frames()
 print("FOREST FOOD SPECIES OK" if failures==0 else "FOREST FOOD SPECIES FAILED "+str(failures))
 quit(0 if failures==0 else 1)
