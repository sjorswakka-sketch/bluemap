extends "res://tools/storage_preview.gd"
const Maps:=preload("res://scripts/maps/registry.gd")
func shot(id: String):root.get_texture().get_image().save_png("res://mountain_routes_"+id+".png")
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.2
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(15);root.size=Vector2i(1152,648)
 for entry in [["village",Vector2(7.8,22.5),2.0,"home_double_door"],["village",Vector2(10,12),1.6,"smith_shop_doors"],["village",Vector2(31,11),1.8,"inn_double_door"],["village",Vector2(34,6),1.8,"arena_double_door"],["lake",Vector2(9,7),1.8,"fisher_double_door"],["river_mouth",Vector2(14.8,42),1.4,"estuary_jetty"],["kruipmoeras",Vector2(24,14),1.4,"island_bridges"],["forest",Vector2(24.5,18),1.6,"forest_full_bridge"],["forest",Vector2(11,5),1.3,"dew_woods_north"],["dauwbos",Vector2(25,32),1.3,"dew_woods_south_return"],["lake",Vector2(35,8.5),1.5,"library_east_path"],["village",Vector2(20.5,40),1.8,"village_complete_bridge"],["kruipmoeras",Vector2(18,15),1.3,"walkable_marsh_verges"],["ijsdal",Vector2(25,5),1.3,"mountain_north_entrance"],["steampeak",Vector2(36,32),.3,"mountain_whole"],["steampeak",Vector2(36,53),1.0,"mountain_lower_terrace"],["steampeak",Vector2(35,36),1.0,"mountain_middle_terrace"],["steampeak",Vector2(37,20),1.15,"mountain_high_terrace"],["steampeak",Vector2(36,8),1.25,"mountain_summit"]]:
  await enter(entry[0],entry[1],entry[2])
  if entry[3]=="mountain_whole":
   world.player.position=Vector2(36,32)*32
   var cam: Camera2D=world.player.camera;cam.limit_left=-100000;cam.limit_top=-100000;cam.limit_right=100000;cam.limit_bottom=100000;cam.reset_smoothing();await frames(5)
  for node in get_nodes_in_group("water_scenery"):node.time=1.5;node.queue_redraw()
  await frames(3);shot(entry[3])
 for id in ["ijsdal","ridgepass","steampeak"]:
  var data:=Maps.get_map(id)
  var node: Dictionary=data.objects.filter(func(o):return o.type=="profession_resource" and o.get("id","").begins_with("winter:"))[0]
  await enter(id,Vector2(node.pos[0]+.5,node.pos[1]+1.5),2);shot(id+"_winter_forage")
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for size in [Vector2i(960,540),Vector2i(1152,648)]:
   root.size=size;await enter("steampeak",Vector2(36,32),.3);world.menu_ui.open(world.menu_ui.TAB_MAP);await frames(10);shot("mountain_map_"+locale+str(size.x));world.menu_ui.close();await frames()
 root.size=Vector2i(1152,648);root.get_node("Lang").set_language("nl",false)
 gs.set_flag("lw_heat_east",true);gs.set_flag("lw_heat_west",true)
 await enter("ijsdal",Vector2(40.5,8),1.5);shot("restored_valley_east")
 await enter("ijsdal",Vector2(36,14),1.5);shot("restored_valley_junction")
 gs.set_flag("lw_forest",true);await enter("dauwbos",Vector2(41,30.5),1.5);shot("restored_dew_route")
 for state in range(4):
  gs.set_flag("lw_drained",bool(state&1));gs.set_flag("lw_bridge",bool(state&2))
  await enter("kruipmoeras",Vector2(23.5,16),1.1);shot("marsh_state_"+str(state))
 world.queue_free();world=null;await frames(6);print("MOUNTAIN ROUTES PREVIEW OK");quit()
