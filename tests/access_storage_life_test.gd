extends "res://tests/coast_expedition_test.gd"
const Trail:=preload("res://scripts/data/trail_life.gd")
const ResourceData:=preload("res://scripts/data/ext/beroepen.gd")
const Stock:=preload("res://scripts/core/stockroom.gd")
const Prof:=preload("res://scripts/core/professions.gd")
const Items:=preload("res://scripts/data/items.gd")
func axis(value: float):
 var event:=InputEventJoypadMotion.new();event.axis=JOY_AXIS_RIGHT_Y;event.axis_value=value;event.device=0;Input.parse_input_event(event)
 await frames(2)
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 var kinds: Dictionary={};var categories: Dictionary={};var habitats:=0;var patches:=0
 for id: String in Maps.MAPS:
  var data: Dictionary=Maps.get_map(id)
  var animals:=0
  for obj: Dictionary in data.objects:
   if obj.get("trail_wildlife",false):
    animals+=1;var start: Array=data.spawns.start
    var reachable:=Trail.connected(data,Vector2i(start[0],start[1]),data.rows.size()*data.rows[0].length())
    check(reachable.has(Vector2i(obj.pos[0],obj.pos[1])),"wildlife reachable from main approach "+id)
    check(Trail.ground(data,Vector2i(obj.pos[0],obj.pos[1])),"wildlife on walkable ground "+id)
   if obj.type=="profession_resource" and obj.get("id","").begins_with("trail:"):
    patches+=1;kinds[obj.kind]=true
    var category: String=obj.get("wild_category",obj.kind.trim_prefix("trail_"))
    categories[category]=true
    if id=="village":check(not Rect2i(4,29,31,12).has_point(Vector2i(obj.pos[0],obj.pos[1])),"new verge does not overlap any existing or future crop cell")
    check(Trail.ground(data,Vector2i(obj.pos[0],obj.pos[1])) and ResourceData.RESOURCES.has(obj.kind),"collectible verge plant on floor "+id)
  if id in Trail.SETTLEMENTS:check(animals==0,"no added wild animals in town "+id)
  elif data.get("outdoor",false) or id in ["cave","ruins","prismamine","reedvault","tidal_hollow"]:
   habitats+=1;check(animals>0 or id in ["dorstvallei","kruipmoeras"],"wildlife present in natural area "+id)
  print("LIFE_MAP ",id," patches=",data.objects.filter(func(o):return o.type=="profession_resource").size()," animals=",animals)
 check(categories.size()==7 and kinds.size()>=7 and patches>=30 and habitats>=18,"varied six-category verges plus cave fungi across all natural regions")
 await enter("village","from_home");p.set_physics_process(false)
 check(get_nodes_in_group("stock_chests").filter(func(n):return not n.is_queued_for_deletion()).is_empty(),"outdoor duplicate chest removed without changing storage")
 for y in range(22,44):check(world.map_data.rows[y][19] in [",","="],"continuous south route at row "+str(y))
 var willem: Node2D
 for npc in get_nodes_in_group("npc"):
  if npc.npc_id=="willem":willem=npc
 check(willem!=null and Vector2i(willem.position/32)==Vector2i(25,12),"storyteller relocated to clear plaza edge")
 var starts: Dictionary={}
 for npc in get_nodes_in_group("npc"):
  if "roam_anchor" in npc:starts[npc.npc_id]=npc.position;npc.roam_wait=0
 p.position=Vector2(8.5,22.5)*32
 var moved: Dictionary={}
 for tick in range(900):
  for npc in get_nodes_in_group("npc"):
   if not "roam_anchor" in npc:continue
   check(npc.position.distance_to(npc.roam_anchor)<=46.1,"quest anchor bound") if tick==899 else null
   if starts.has(npc.npc_id) and starts[npc.npc_id].distance_to(npc.position)>2:moved[npc.npc_id]=true
  await frames(1)
 # An errand may finish back at its anchor. Check observed movement over the
 # whole interval instead of a random final-frame pose.
 print("NPC_ERRANDS_OBSERVED ",moved.keys())
 check(moved.size()>=5,"multiple quest residents carry out short nearby walks")
 if willem!=null:
  p.position=willem.position+Vector2(0,35);await frames(3);var before: Vector2=willem.position
  await frames(120);check(willem.position.distance_to(before)<.1,"NPC stops when approached for conversation")
  p._update_target();check(p.target==willem,"relocated storyteller remains targetable")
 await enter("forest_edge");p.set_physics_process(false)
 var node: Node2D
 for r in get_nodes_in_group("profession_resources"):
  if r.resource_id.begins_with("trail:"):node=r;break
 check(node!=null,"actual route has a collectible plant")
 if node!=null:
  var output: String=ResourceData.RESOURCES[node.kind].item;p.position=node.position+Vector2(0,25);await frames(3)
  var before: int=gs.count(output);node.interact();await frames(65)
  check(gs.count(output)>before and Prof.remaining(node.resource_id)>0,"real interaction awards item and starts persistent regrowth cooldown")
  var count: int=gs.count(output);node.interact();await frames(65);check(gs.count(output)==count,"depleted plant cannot duplicate rewards")
 await enter("player_home");p.set_physics_process(false);p.position=Vector2(10.5,6.5)*32
 for id: String in Items.ITEMS:
  if gs.inventory.size()<45:gs.give(id,2,true)
 for id: String in Items.ITEMS:
  if Stock.allowed(id) and Stock.state().home.size()<40:Stock.state().home[id]=3
 var ui: Node=load("res://scripts/ui/stock_ui.gd").new();ui.world=world;world.add_child(ui);ui.open();await frames(8)
 check(ui.bag.item_count>15 and ui.chest.item_count>15,"both storage lists exceed visible rows")
 ui.select_item(0,true);ui.bag.grab_focus();await tap(JOY_BUTTON_DPAD_DOWN,true)
 for i in 24:await tap(JOY_BUTTON_DPAD_DOWN,true)
 check(ui.bag.get_v_scroll_bar().value>0,"controller d-pad selection scrolls bag into view")
 await axis(1);await frames(180);await axis(0)
 check(ui.bag.get_selected_items()[0]==ui.bag.item_count-1 and ui.bag.get_v_scroll_bar().value>0,"right stick scrolls bag to final row")
 ui.deposit=false;ui.chest.grab_focus();ui.select_item(0,false)
 await axis(1);await frames(420);await axis(0)
 check(ui.chest.get_selected_items()[0]==ui.chest.item_count-1 and ui.chest.get_v_scroll_bar().value>0,"right stick scrolls chest to final row")
 await axis(-1);await frames(420);await axis(0)
 check(ui.chest.get_selected_items()[0]==0 and ui.chest.get_v_scroll_bar().value<1,"reverse right stick returns chest to first row")
 ui.close();await frames(3);check(not gs.input_locked(),"ledger closes without stuck modal input")
 world.queue_free();await frames();print("ACCESS STORAGE LIFE OK" if failures==0 else "ACCESS STORAGE LIFE FAILED "+str(failures));quit(0 if failures==0 else 1)
