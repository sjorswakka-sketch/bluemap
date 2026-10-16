extends "res://tests/coast_expedition_test.gd"
const Stock:=preload("res://scripts/core/stockroom.gd")
func ui() -> Node:
 for n in get_nodes_in_group("stock_ui"):
  if n.active and not n.is_queued_for_deletion():return n
 return null
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 root.size=Vector2i(1152,648);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12);p=world.player
 await enter("player_home");p.set_physics_process(false)
 var node: Node2D
 for n in get_nodes_in_group("stock_chests"):
  if not n.is_queued_for_deletion():node=n
 p.position=node.position+Vector2(0,34);p.facing=Vector2.UP;await frames(4);p._update_target()
 gs.give("hs_grape",24,true);gs.give("prof_branch",12,true);gs.give("potion",4,true)
 await tap(KEY_E)
 check(ui()!=null and gs.ui_owners.has("stockroom") and paused,"real chest interaction opens and pauses ledger")
 if ui()==null:quit(1);return
 var stock: Node=ui();stock.select_item(stock.bag_ids.find("hs_grape"),true);stock.bag.grab_focus()
 await tap(KEY_ENTER)
 check(Stock.count("hs_grape")==1 and gs.count("hs_grape")==23,"native ItemList Enter transfers one selected item")
 stock.select_item(stock.bag_ids.find("hs_grape"),true)
 await click(stock.transfer_buttons[1])
 check(Stock.count("hs_grape")==11,"native mouse transfers ten")
 stock.star.grab_focus();await tap(JOY_BUTTON_A,true)
 check(Stock.favorite("hs_grape"),"controller toggles persistent favorite")
 stock.bulk_buttons[0].grab_focus();await tap(JOY_BUTTON_A,true)
 check(gs.count("hs_grape")==13,"controller quick stack skips favorite")
 stock.keyboard.visible=false;stock.toggle_keyboard();await frames()
 var letters: Node=stock.keyboard.get_child(0)
 letters.get_child(6).grab_focus();await tap(JOY_BUTTON_A,true)
 check(stock.search.text=="G" and stock.bag_ids.has("hs_grape"),"controller on-screen keyboard searches names")
 stock.clear_search();stock.write_letter("zzzz")
 check(stock.bag.item_count==0 and stock.chest.item_count==0 and stock.selected=="","search empty state clears stale selection")
 stock.clear_search();stock.toggle_keyboard();stock.search.grab_focus()
 var key:=InputEventKey.new();key.keycode=KEY_I;key.physical_keycode=KEY_I;key.unicode=105;key.pressed=true;Input.parse_input_event(key);await frames()
 key.pressed=false;Input.parse_input_event(key);await frames()
 check(stock.search.text=="i" and ui()==stock and not world.menu_ui.active,"typing a game binding stays in native search field")
 stock.clear_search()
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size;stock.keyboard.visible=true;await frames(4)
   check(Rect2(Vector2.ZERO,Vector2(size)).encloses(stock.panel.get_global_rect()),"complete ledger and alphabet fit "+locale+str(size))
 root.get_node("Lang").set_language("nl",false);root.size=Vector2i(1152,648);stock.keyboard.visible=false
 await tap(JOY_BUTTON_B,true);check(ui()==null and not gs.input_locked(),"controller close returns world and releases input")
 await frames()
 world.menu_ui.open(0);await frames();await tap(KEY_C)
 check(ui()!=null and not world.menu_ui.active and gs.ui_owners.keys()==["stockroom"],"C in bag hands modal ownership to stock")
 if ui()!=null:ui().close()
 await frames();check(world.menu_ui.active and gs.ui_owners.keys()==["menu"],"closing bag ledger returns to same bag menu")
 world.menu_ui.close();await frames()
 await enter("forest");p.set_physics_process(false);world.menu_ui.open(0);await frames();await tap(JOY_BUTTON_RIGHT_STICK,true)
 check(ui()!=null and ui().last_near=="" and ui().bulk_buttons[0].disabled,"R3 opens remote read-only home stock")
 if ui()!=null:
  var before: int=Stock.count("hs_grape");ui().selected="hs_grape";ui().deposit=false;ui().move(1)
  check(Stock.count("hs_grape")==before,"remote UI cannot withdraw")
 world.load_map("village","from_home");await frames(8);p=world.player
 check(ui()==null and not gs.input_locked() and not world.menu_ui.active,"forced map change closes stale ledger without reopening old bag")
 world.queue_free();await frames();print("STOCK UI OK" if failures==0 else "STOCK UI FAILED "+str(failures));quit(0 if failures==0 else 1)
