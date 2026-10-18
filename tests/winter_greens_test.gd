extends "res://tests/coast_expedition_test.gd"
const Winter:=preload("res://scripts/data/winter_greens.gd")
const WinterItems:=preload("res://scripts/data/ext/winter_greens.gd")
const Resources:=preload("res://scripts/data/ext/beroepen.gd")
const Prof:=preload("res://scripts/core/professions.gd")
const Items:=preload("res://scripts/data/items.gd")
const Trail:=preload("res://scripts/data/trail_life.gd")
const Art:=preload("res://scripts/core/art.gd")

func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 var kinds: Dictionary={}
 var plant_art: Dictionary={};var icon_art: Dictionary={}
 check(WinterItems.ITEMS.size()==16,"sixteen distinct frost-hardy vegetables")
 check(Art.tex("winter_plants").get_size()==Vector2(512,32) and Art.tex("winter_items").get_size()==Vector2(256,16),"native pixel sheets have sixteen correctly sized frames")
 for i in range(16):
  var pixels:=Art.tex("winter_plants").get_image().get_region(Rect2i(i*32,0,32,32)).get_data()
  var icon_pixels:=Art.tex("winter_items").get_image().get_region(Rect2i(i*16,0,16,16)).get_data()
  plant_art[hash(pixels)]=true;icon_art[hash(icon_pixels)]=true
 check(plant_art.size()==16 and icon_art.size()==16,"all sixteen plants and inventory icons have unique silhouettes")
 check(Resources.RESOURCES.keys().slice(0,8)==["branches","stones","herbs","berries","mushrooms","stump","copper","iron"],"legacy atlas frame order remains unchanged")
 for map_id: String in Maps.MAPS:
  var data: Dictionary=Maps.get_map(map_id)
  var cold: bool=data.get("outdoor",false) and data.get("weather","")=="snow"
  var plants: Array=data.objects.filter(func(obj):return str(obj.get("id","")).begins_with("winter:"))
  if cold:check(not plants.is_empty(),"every snowy outdoor environment has winter forage "+map_id)
  if not Winter.PLANS.has(map_id):
   check(plants.is_empty(),"winter vegetables stay in their proper climate "+map_id)
   continue
  check(plants.size()==Winter.PLANS[map_id].size(),"all authored winter verges placed "+map_id)
  var again: Dictionary=Maps.get_map(map_id)
  check(plants==again.objects.filter(func(obj):return str(obj.get("id","")).begins_with("winter:")),"placement and species IDs are deterministic "+map_id)
  var start: Array=data.spawns.start
  var reach:=Trail.connected(data,Vector2i(start[0],start[1]),data.rows.size()*data.rows[0].length())
  var others: Array=Resources.resource_objects(map_id)
  for plant: Dictionary in plants:
   kinds[plant.kind]=true
   var at:=Vector2i(plant.pos[0],plant.pos[1])
   check(reach.has(at) and Winter.clear(data.duplicate(true).merged({"objects":data.objects.filter(func(obj):return obj!=plant)},true),at),"reachable sheltered snow verge "+plant.id)
   check(data.rows[at.y][at.x] in ["z","f"],"no winter crop overlaps path, water or cliff "+plant.id)
   for other: Dictionary in plants+others:
    if other==plant:continue
    check(at.distance_to(Vector2i(other.pos[0],other.pos[1]))>=4.0,"forage leaves quiet open space "+plant.id)
  print("WINTER_MAP ",map_id," nodes=",plants.size()," pos=",plants.map(func(obj):return [obj.id,obj.pos]))
 check(kinds.size()==16,"all sixteen vegetable species are actually available in the world")
 for item_id: String in WinterItems.ITEMS:
  check(Items.ITEMS.has(item_id) and item_id in Prof.CONSUMABLES,"winter food registered in inventory and profession menu "+item_id)
  gs.give(item_id,1,true);gs.hp=2;gs.movement.stamina=10.0
  var stamina_before: float=gs.movement.stamina
  check(Prof.use_item(item_id) and gs.count(item_id)==0 and gs.hp==3 and gs.movement.stamina>stamina_before,"winter food restores hearts and stamina "+item_id)
  check(int(Items.ITEMS[item_id].sell)>0,"winter harvest can be sold "+item_id)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await enter("ijsdal")
 p.set_physics_process(false)
 var actual: Node2D
 for node in get_nodes_in_group("profession_resources"):
  if node.resource_id.begins_with("winter:"):actual=node;break
 check(actual!=null,"actual snowy scene creates interactable winter plants")
 if actual!=null:
  p.position=actual.position+Vector2(0,24);await frames(3)
  var kind: String=actual.kind;var item: String=Resources.RESOURCES[kind].item
  var before: int=gs.count(item)
  actual.interact();await frames(8);p.position+=Vector2(8,0);await frames(55)
  check(gs.count(item)==before and Prof.remaining(actual.resource_id)==0,"moving cancels winter picking without awarding or consuming the node")
  p.position=actual.position+Vector2(0,24);await frames(3);actual.interact();await frames(65)
  check(gs.count(item)==before+2 and Prof.remaining(actual.resource_id)>200,"timed winter picking grants food and starts saved regrowth")
  var id: String=actual.resource_id
  var other_data: Dictionary=Maps.get_map("forest_edge")
  var trail_nodes: Array=other_data.objects.filter(func(obj):return str(obj.get("id","")).begins_with("trail:"))
  check(not trail_nodes.is_empty(),"existing trail forage available for persistence regression")
  var trail_id: String=trail_nodes[0].id if not trail_nodes.is_empty() else ""
  if trail_id!="":gs.professions.cooldowns[trail_id]=gs.play_time+180.0
  check(gs.save_game(p.position),"winter harvest save written only in isolated user directory")
  var saved_count: int=gs.count(item);gs.professions={};gs.inventory={}
  check(gs.load_game() and gs.count(item)==saved_count and Prof.remaining(id)>200,"real save reload keeps winter harvest and regrowth")
  if trail_id!="":check(Prof.remaining(trail_id)>150,"real save reload also keeps existing trail regrowth")
  var bad:=Prof.normalize({"cooldowns":{id:999999.0,"winter:ijsdal:invented":300.0,"winter:unknown:kale":300.0,"trail:forest_edge:999:999":300.0,"trail:forest_edge:1:1":300.0}},100.0)
  check(bad.cooldowns.size()==1 and is_equal_approx(float(bad.cooldowns[id]),340.0),"normalization bounds known timers and rejects fake species or coordinates")
  var again_before: int=gs.count(item);actual.interact();await frames(65)
  check(gs.count(item)==again_before,"saved depleted winter plant cannot duplicate food")
  gs.play_time+=241.0;p.position=actual.position+Vector2(0,24);await frames(3);actual.interact();await frames(65)
  check(gs.count(item)==again_before+2,"winter crop regrows after active play cooldown")
 world.queue_free();await frames();print("WINTER GREENS OK" if failures==0 else "WINTER GREENS FAILED "+str(failures));quit(0 if failures==0 else 1)
