extends "res://tools/storage_preview.gd"
const Maps:=preload("res://scripts/maps/registry.gd")
const Items:=preload("res://scripts/data/items.gd")
const Gear:=preload("res://scripts/core/equipment.gd")
func shot(id: String):root.get_texture().get_image().save_png("res://forage_"+id+".png")
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.2
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(15);root.size=Vector2i(1152,648)
 await enter("ridgepass",Vector2(26,6),1.8)
 var chest: Node2D
 for node in get_nodes_in_group("interactable"):
  if node.get_script()!=null and node.get_script().resource_path.ends_with("chest.gd") and node.contents.any(func(stack):return stack[0]=="gear_bastion_coat"):chest=node
 if chest==null:
  for node in get_nodes_in_group("interactable"):
   if node.get_script()!=null and node.get_script().resource_path.ends_with("chest.gd") and node.contents.any(func(stack):return stack[0].begins_with("gear_") and stack[0]!="coins"):chest=node;break
 if chest!=null:
  for stack: Array in chest.contents:
   if stack[0].begins_with("gear_"):gs.give(stack[0],1,true);Gear.equip(stack[0])
  world.player.position=chest.position+Vector2(0,28);await frames(5);chest.interact();await frames(5);shot("ridge_chest_already_owned")
 for id in ["forest_edge","forest","dauwbos","lake","coast","kruipmoeras","ijsdal","steampeak"]:
  var data: Dictionary=Maps.get_map(id)
  var nodes: Array=data.objects.filter(func(o):return o.type=="profession_resource" and (str(o.get("kind","")).begins_with("ff_") or str(o.get("kind","")).begins_with("flower_")))
  if nodes.is_empty():continue
  var at: Array=nodes[0].pos
  await enter(id,Vector2(at[0]+.5,at[1]+1.5),2.2);shot(id+"_specific_plants")
 for item: String in Items.ITEMS:
  if Stock.allowed(item):gs.give(item,2,true);Stock.state().home[item]=4
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648)]:
   root.size=size;await enter("forest",Vector2(15,12),1.2)
   for item in ["flower_foxglove","ff_japanese_walnut","ff_sea_buckthorn","winter_cauliflower"]:
    world.menu_ui.open(0);world.menu_ui.selected=world.menu_ui._owned().find(item);world.menu_ui.page.queue_redraw();await frames(8);shot(item+"_"+locale+str(size.x));world.menu_ui.close();await frames()
   await enter("player_home",Vector2(10.5,6.5),2)
   var ui: Node=load("res://scripts/ui/stock_ui.gd").new();ui.world=world;world.add_child(ui);ui.open()
   var joy:=InputEventJoypadButton.new();joy.button_index=JOY_BUTTON_DPAD_DOWN;joy.pressed=true;Input.parse_input_event(joy);await frames(2);joy.pressed=false;Input.parse_input_event(joy)
   ui.controller_pane(true);ui.select_item(ui.bag.item_count-1,true);await frames(8);shot("full_species_bag_"+locale+str(size.x))
   ui.controller_pane(false);ui.select_item(ui.chest.item_count-1,false);await frames(8);shot("full_species_stock_"+locale+str(size.x));ui.close();await frames()
 world.queue_free();world=null;await frames(6);print("FORAGE PREVIEW OK");quit()
