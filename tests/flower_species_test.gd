extends "res://tests/coast_expedition_test.gd"
const Placement:=preload("res://scripts/core/forage_placement.gd")
const Flowers:=preload("res://scripts/data/flower_species.gd")
const FlowerData:=preload("res://scripts/data/ext/flower_species.gd")
const Resources:=preload("res://scripts/data/ext/beroepen.gd")
const Items:=preload("res://scripts/data/items.gd")
const Art:=preload("res://scripts/core/art.gd")
const Prof:=preload("res://scripts/core/professions.gd")
const Trail:=preload("res://scripts/data/trail_life.gd")
const Catalog:=preload("res://scripts/core/forage_catalog.gd")
const WinterItems:=preload("res://scripts/data/ext/winter_greens.gd")
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 check(FlowerData.ITEMS.size()==16 and FlowerData.RESOURCES.size()==16,"sixteen specific wildflower species with their own harvests")
 check(Art.tex("flower_plants").get_size()==Vector2(512,32) and Art.tex("flower_items").get_size()==Vector2(256,16),"native 32-pixel plants and 16-pixel item art")
 var art_hashes: Dictionary={};var item_hashes: Dictionary={}
 for i in range(16):
  art_hashes[hash(Art.tex("flower_plants").get_image().get_region(Rect2i(i*32,0,32,32)).get_data())]=true
  item_hashes[hash(Art.tex("flower_items").get_image().get_region(Rect2i(i*16,0,16,16)).get_data())]=true
 check(art_hashes.size()==16 and item_hashes.size()==16,"every flower has its own plant silhouette and inventory bouquet")
 var fixture: Dictionary={"objects":[{"type":"sign","pos":[2,3],"lines":["legacy"]},{"type":"profession_resource","kind":"trail_flowers","id":"trail:forest:5:5","pos":[5,5]},{"type":"profession_resource","kind":"herbs","id":"legacy_quest_herb","pos":[8,8]},{"type":"home_station","role":"hive","pos":[11,11]}]}
 var original: Dictionary=fixture.duplicate(true)
 Flowers.enrich("forest",fixture)
 check(fixture.objects.size()==original.objects.size() and fixture.objects[1].id==original.objects[1].id and fixture.objects[1].pos==original.objects[1].pos,"replacement keeps original array slot, cooldown ID and position")
 check(fixture.objects[0]==original.objects[0] and fixture.objects[2]==original.objects[2] and fixture.objects[3]==original.objects[3],"quest herbs, props and player production are untouched")
 var seen: Dictionary={};var nodes:=0
 for map_id: String in Maps.MAPS:
  var data: Dictionary=Maps.get_map(map_id)
  var start: Array=data.spawns.start
  var accessible:=Trail.connected(data,Vector2i(start[0],start[1]),data.rows.size()*data.rows[0].length())
  for obj: Dictionary in data.objects:
   if obj.type!="profession_resource":continue
   check(obj.get("kind","")!="trail_flowers","no generic wildflower plant remains "+map_id)
   if not FlowerData.RESOURCES.has(obj.get("kind","")):continue
   nodes+=1;seen[obj.kind]=true
   check(obj.kind==Flowers.kind_for(map_id,data),"species has its deliberate regional habitat "+map_id)
   check(Resources.RESOURCES.has(obj.kind) and Items.ITEMS.has(FlowerData.RESOURCES[obj.kind].item),"species is registered for real gathering "+obj.kind)
   check(obj.id.begins_with("trail:") and obj.wild_category=="flower","original explicit verge ID remains stable "+obj.id)
   var at:=Vector2i(obj.pos[0],obj.pos[1])
   check(Placement.canopy_clear(data,at),"specific flower is fully visible outside rendered tree canopy "+obj.id)
   check(accessible.has(at) and Trail.ground(data,at) and data.rows[at.y][at.x] not in [",","=","9"],"flower grows on a reachable open verge "+obj.id)
   if map_id=="village":
    check(not Rect2i(4,29,31,12).has_point(at),"wild flowers do not intrude into editable garden")
    check(obj.pos==[28,12],"old village flower stays on visible north street verge with same saved ID")
  var before: Dictionary=data.duplicate(true);Flowers.enrich(map_id,data)
  check(data==before,"flower enrichment is idempotent and adds no clutter "+map_id)
 check(nodes==17 and seen.size()==16,"all sixteen species replace exactly seventeen existing flower patches")
 for kind: String in FlowerData.RESOURCES:
  var item: String=FlowerData.RESOURCES[kind].item
  check(FlowerData.ITEMS[item].type=="material" and int(FlowerData.ITEMS[item].sell)>0 and item not in Prof.CONSUMABLES,"wildflower has material and trade use rather than accidental food behavior "+kind)
  check(float(FlowerData.RESOURCES[kind].cooldown)==180.0,"original flower regrowth duration retained "+kind)
 check(Items.ITEMS.has("trail_flower"),"old generic flower stacks remain valid in existing saves")
 for item_id: String in FlowerData.ITEMS.keys()+WinterItems.ITEMS.keys():
  var places:=Catalog.locations(item_id)
  check(Catalog.known(item_id) and not places.is_empty(),"field guide has real flower/winter locations "+item_id)
  for place: Dictionary in places:
   var map: Dictionary=Maps.get_map(place.map)
   var objects: Array=map.objects.duplicate();objects.append_array(Resources.resource_objects(place.map))
   check(objects.any(func(obj):return obj.type=="profession_resource" and obj.pos==place.pos and Resources.RESOURCES.get(obj.get("kind",""),{}).get("item","")==item_id),"field guide coordinate points at the actual harvest "+item_id)
  var source: String=Catalog.source(item_id,places[0].map)
  check(source.contains("(%d, %d)" % [int(places[0].pos[0])+1,int(places[0].pos[1])+1]),"field guide text uses one-based display coordinates "+item_id)
  var first: Array=Catalog.locations(item_id);first[0].pos=[-99,-99]
  check(Catalog.locations(item_id)[0].pos!=[-99,-99],"callers cannot alter cached find locations "+item_id)
 check(not Catalog.known("unknown_flower") and Catalog.locations("unknown_flower").is_empty(),"field guide rejects unknown items")
 root.get_node("Lang").set_language("nl",false);var dutch:=Catalog.source("flower_bluebell","forest")
 root.get_node("Lang").set_language("en",false);var english:=Catalog.source("flower_bluebell","forest")
 check(dutch.contains("Fluisterbos") and english.contains("Whispering Woods"),"cached field guide changes language immediately")
 root.get_node("Lang").set_language("nl",false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await enter("forest");p.set_physics_process(false)
 var actual: Node2D
 for node in get_nodes_in_group("profession_resources"):
  if FlowerData.RESOURCES.has(node.kind):actual=node;break
 check(actual!=null,"actual game scene instantiates specific flowers")
 if actual!=null:
  p.position=actual.position+Vector2(0,24);await frames(3)
  var item: String=FlowerData.RESOURCES[actual.kind].item;var id: String=actual.resource_id
  var before: int=gs.count(item);var before_xp: int=Prof.xp("foraging")
  actual.interact();await frames(65)
  check(gs.count(item)==before+2 and Prof.xp("foraging")==before_xp+4,"real timed picking grants the specific flower and foraging XP")
  check(Prof.remaining(id)>150,"picking starts the existing saved regrowth timer")
  gs.give("trail_flower",3,true);check(gs.save_game(p.position),"flower harvest saved in isolated directory")
  gs.professions={};gs.inventory={}
  check(gs.load_game() and gs.count(item)==before+2 and gs.count("trail_flower")==3 and Prof.remaining(id)>150,"real save reload retains specific flowers, old flower stacks and regrowth")
  var after: int=gs.count(item);actual.interact();await frames(65)
  check(gs.count(item)==after,"reloaded depleted flower cannot duplicate its harvest")
 world.queue_free();await frames();print("FLOWER SPECIES OK" if failures==0 else "FLOWER SPECIES FAILED "+str(failures));quit(0 if failures==0 else 1)
