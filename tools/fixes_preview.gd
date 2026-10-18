extends "res://tools/storage_preview.gd"
const Items:=preload("res://scripts/data/items.gd")
func shot(id: String):root.get_texture().get_image().save_png("res://fixes_"+id+".png")
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.2
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(15);root.size=Vector2i(1152,648)
 await enter("village",Vector2(19.5,28.5),.85);shot("south_road_old_exit")
 await enter("village",Vector2(19.5,38),1.05);shot("south_road_lake_entrance")
 await enter("village",Vector2(25.5,13.5),1.9);shot("visible_storyteller")
 await enter("player_home",Vector2(10.5,6.5),2.0);shot("storage_inside_home")
 for id: String in Items.ITEMS:
  if gs.inventory.size()<44:gs.give(id,2,true)
  if Stock.allowed(id) and Stock.state().home.size()<40:Stock.state().home[id]=4
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=size
   var ui: Node=load("res://scripts/ui/stock_ui.gd").new();ui.world=world;world.add_child(ui);ui.open();await frames(8)
   var joy:=InputEventJoypadButton.new();joy.button_index=JOY_BUTTON_DPAD_DOWN;joy.pressed=true;Input.parse_input_event(joy);await frames();joy.pressed=false;Input.parse_input_event(joy)
   ui.select_item(ui.bag.item_count-1,true);ui.bag.grab_focus();await frames(8);shot("bag_last_row_"+locale+str(size.x))
   ui.controller_pane(false);ui.select_item(ui.chest.item_count-1,false);await frames(8);shot("chest_last_row_"+locale+str(size.x));ui.close();await frames()
 root.size=Vector2i(1152,648);root.get_node("Lang").set_language("nl",false)
 for entry in [["forest_edge",Vector2(30,16),1.6,"cascade_upstream"],["forest_edge",Vector2(17,10),1.8,"rain_puddle"],["village",Vector2(35,23),1.5,"village_source"],["ijsdal",Vector2(32,6),1.5,"hot_spring"],["sunwell",Vector2(29,7),1.5,"geyser"],["ridgepass",Vector2(24,12),1.5,"meltwater_pool"],["forest_edge",Vector2(12,15),1.5,"quiet_foraging"],["forest",Vector2(7,9),1.5,"forest_wildlife"]]:
  await enter(entry[0],entry[1],entry[2])
  for node in world.ground.get_children():
   if node.get_script()!=null and node.get_script().resource_path.ends_with("water_scenery.gd"):node.time=1.5;node.queue_redraw()
  await frames(3);shot(entry[3])
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648)]:
   root.size=size;await enter("harbor",Vector2(40,19),1.0)
   world.menu_ui.open(world.menu_ui.TAB_MAP);await frames(10);shot("harbor_legend_"+locale+str(size.x));world.menu_ui.close();await frames()
 world.queue_free();world=null;await frames(6);print("FIXES PREVIEW OK");quit()
