extends "res://tests/coast_expedition_test.gd"
const Stock:=preload("res://scripts/core/stockroom.gd")
const Equipment:=preload("res://scripts/core/equipment.gd")
const Items:=preload("res://scripts/data/items.gd")
var Chest: Script
var messages: Array[String]=[]
var watched: Node
var watch:=false
var partial_seen:=false
var reentered:=false
var expected_coins:=0
var expected_items: Dictionary={}
func observe_transaction():
 if not watch:return
 if gs.coins!=expected_coins or not gs.flag(watched.unique_key):partial_seen=true
 for item: String in expected_items:
  if gs.count(item)!=expected_items[item]:partial_seen=true
 if not reentered:reentered=true;watched.interact()
func message(text: String):messages.append(text)
func chest_at(at: Vector2i) -> Node:
 for node in world.entities.get_children():
  if not node.is_queued_for_deletion() and node.get_script()==Chest and Vector2i(node.position/32)==at:return node
 return null
func extra_chest(contents: Array,key: String) -> Node:
 var node: Node=Chest.new();node.world=world;node.contents=contents.duplicate(true);node.unique_key=key;world.entities.add_child(node)
 return node
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 root.get_node("Lang").set_language("nl",false)
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.toast.connect(message)
 Chest=load("res://scripts/entities/chest.gd")
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 # Fenna already awards the same permanent coat as the unopened ridge chest.
 gs.give("gear_bastion_coat",1,true);check(Equipment.equip("gear_bastion_coat"),"Fenna's existing coat can be worn")
 gs.give("prof_branch",8,true);gs.give("hs_grape",6,true);gs.set_flag("lw_heat");gs.set_flag("old_chest_sentinel")
 await enter("player_home");p.set_physics_process(false)
 var stock: Node=get_nodes_in_group("stock_chests").filter(func(n):return not n.is_queued_for_deletion())[0]
 p.position=stock.position+Vector2(0,34)
 check(Stock.transfer("hs_grape",6,true,"home") and Stock.bulk(false,"home")==8 and gs.inventory=={"gear_bastion_coat":1},"an empty material bag still owns equipped permanent gear")
 var saved_stock: Dictionary=Stock.state().home.duplicate(true)
 gs.coins=10;gs.save_game(p.position)
 # Legacy duplicated gear normalizes to one, without changing old chest flags.
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH));data.inventory.gear_bastion_coat=9
 var file:=FileAccess.open(gs.SAVE_PATH,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
 check(gs.load_game() and gs.count("gear_bastion_coat")==1 and Equipment.equipped("chest")=="gear_bastion_coat" and gs.flag("old_chest_sentinel"),"legacy save keeps one owned coat, worn selection and unrelated flags")
 gs.in_game=true;await enter("ridgepass");p.set_physics_process(false)
 var ridge:=chest_at(Vector2i(26,3));check(ridge!=null,"the original upper-right mountain-pass chest exists")
 if ridge==null:world.queue_free();quit(1);return
 var ridge_key: String=ridge.unique_key;var original_contents: Array=ridge.contents.duplicate(true)
 check(gs.room("gear_bastion_coat")==0 and gs.room("prof_branch")==gs.NO_LIMIT,"unique ownership differs from ordinary unlimited material capacity")
 messages.clear();ridge.interact()
 check(ridge.opened and gs.flag(ridge_key) and gs.coins==85,"owned coat does not block the original seventy-five coins")
 check(gs.count("gear_bastion_coat")==1 and Equipment.equipped("chest")=="gear_bastion_coat" and Stock.state().home==saved_stock,"opening never duplicates gear, unequips it or consumes home stock")
 check(messages.any(func(text):return text.contains("Wachtharnas") and text.to_lower().contains("bezit")) and not messages.any(func(text):return text.to_lower().contains("tas is te vol")),"owned unique reward is described truthfully")
 check(ridge.contents==original_contents,"original chest contents remain unchanged")
 ridge.interact();check(gs.coins==85 and gs.count("gear_bastion_coat")==1,"repeat interaction cannot reclaim coins or unique gear")
 gs.save_game(p.position);check(gs.load_game() and gs.flag(ridge_key) and gs.coins==85 and Stock.state().home==saved_stock,"claimed chest, coins and home stock survive reload")
 gs.in_game=true;await enter("ridgepass");p.set_physics_process(false);ridge=chest_at(Vector2i(26,3));ridge.interact()
 check(ridge.opened and gs.coins==85 and gs.flag("old_chest_sentinel"),"revisited original chest remains claimed and old flags survive")
 # Actual stack limits remain all-or-nothing, even with an already-owned coat.
 gs.inventory.arrow=35;var full:=extra_chest([["gear_bastion_coat",1],["coins",12],["arrow",10]],"test_chest_full")
 var before: Dictionary=gs.inventory.duplicate(true);messages.clear();full.interact()
 check(not full.opened and not gs.flag(full.unique_key) and gs.inventory==before and gs.coins==85,"a genuinely full quiver leaves every reward and flag untouched")
 check(messages.any(func(text):return text.to_lower().contains("pijl")),"blocked ammunition explains the quiver limit")
 gs.take("arrow",5);full.interact()
 check(full.opened and gs.count("arrow")==40 and gs.count("gear_bastion_coat")==1 and gs.coins==97,"freeing actual ammunition room allows the entire remaining reward")
 # Two stacks in one chest must be checked together, not individually.
 gs.inventory.arrow=25;var split:=extra_chest([["arrow",10],["coins",4],["arrow",10]],"test_chest_split")
 split.interact();check(not split.opened and gs.count("arrow")==25 and gs.coins==97 and not gs.flag(split.unique_key),"aggregate preflight rejects two individually fitting stacks without partial loss")
 gs.take("arrow",5);split.interact();check(split.opened and gs.count("arrow")==40 and gs.coins==101,"aggregate stacks grant their full original amounts once room exists")
 # A chest containing only already-owned equipment still opens honestly.
 var owned_only:=extra_chest([["gear_bastion_coat",1]],"test_chest_owned_only");messages.clear();owned_only.interact()
 check(owned_only.opened and gs.flag(owned_only.unique_key) and gs.count("gear_bastion_coat")==1 and messages.any(func(text):return text.to_lower().contains("bezit")),"all-equipment duplicate chest is claimable without invented compensation")
 # New unique loot, coins and ordinary materials become visible atomically.
 gs.inventory.erase("gear_bronze_helm");watched=extra_chest([["gear_bronze_helm",1],["prof_branch",3],["coins",11]],"test_chest_atomic")
 expected_coins=112;expected_items={"gear_bronze_helm":1,"prof_branch":3};watch=true;gs.items_changed.connect(observe_transaction)
 watched.interact();watch=false;gs.items_changed.disconnect(observe_transaction)
 check(watched.opened and not partial_seen and reentered and gs.coins==112 and gs.count("gear_bronze_helm")==1 and gs.count("prof_branch")==3,"listeners see a complete claim and cannot reenter to duplicate loot")
 var old_hp: int=gs.hp;var hearts:=extra_chest([["heart_container",1],["potion",2]],"test_chest_hearts");hearts.interact()
 check(hearts.opened and gs.count("heart_container")==1 and gs.hp==old_hp+1 and gs.count("potion")==2,"atomic chest grants retain heart-container healing and ordinary consumables")
 gs.inventory.heart_container=3;var capped_hearts:=extra_chest([["heart_container",1],["coins",7]],"test_chest_capped_hearts");messages.clear();capped_hearts.interact()
 check(not capped_hearts.opened and not gs.flag(capped_hearts.unique_key) and gs.coins==112 and gs.count("heart_container")==3 and messages.any(func(text):return text.contains("maximum van 8 hartjes")),"a full heart-container limit keeps all loot and explains the actual health cap")
 check(Stock.state().home==saved_stock and gs.flag("old_chest_sentinel"),"all capacity cases preserve storage and unrelated legacy state")
 # A legacy three-region treasure hunt must finish through a real chest claim,
 # without waiting for the periodic achievement fallback or inventing new IDs.
 for id: String in ["forest","ruins","cave"]:
  var original: Dictionary=Maps.get_map(id)
  for index in original.objects.size():
   if original.objects[index].type=="chest":gs.set_flag("chest:%s:%d" % [id,index]);break
 gs.achievements.erase("chests_all");gs.meta_achievements.erase("chests_all");gs.check_achievements()
 check(not gs.achievements.has("chests_all"),"three original chest regions do not yet complete Treasure Hunter")
 await enter("inn");p.set_physics_process(false)
 var final_chest:=chest_at(Vector2i(12,7));check(final_chest!=null and not final_chest.opened,"the original inn chest is the remaining fourth-region reward")
 if final_chest!=null:
  gs._achievements_dirty=false;gs._achievement_timer=100.0
  var old_coins: int=gs.coins;var old_potions: int=gs.count("potion")
  final_chest.interact()
  check(gs._achievements_dirty and final_chest.opened and gs.flag(final_chest.unique_key) and gs.coins==old_coins+15 and gs.count("potion")==old_potions+1,"last original chest commits its loot and schedules achievement checking")
  gs._process(0.0)
  check(gs.achievements.has("chests_all"),"Treasure Hunter unlocks on the next active update without a periodic timeout")
  gs.save_game(p.position);check(gs.load_game() and gs.achievements.has("chests_all") and gs.flag(final_chest.unique_key),"Treasure Hunter and the final original chest remain earned after reload")
 world.queue_free();await frames();print("CHEST LOOT OK" if failures==0 else "CHEST LOOT FAILED "+str(failures));quit(0 if failures==0 else 1)
