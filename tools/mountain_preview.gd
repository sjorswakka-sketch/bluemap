extends "res://tools/storage_preview.gd"
func shot(id: String):root.get_texture().get_image().save_png("res://mountain_"+id+".png")
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.2;root.get_node("Lang").set_language("nl",false)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(15);root.size=Vector2i(1152,864)
 await enter("steampeak",Vector2(36,32),.38);shot("overview")
 root.size=Vector2i(1152,648)
 for entry in [["ijsdal",Vector2(24,5),1.3,"north_entrance"],["steampeak",Vector2(35,57),1.3,"arrival"],["steampeak",Vector2(52,53),1.5,"lower_spring"],["steampeak",Vector2(28,35),1.3,"middle_terrace"],["steampeak",Vector2(42,18),1.5,"macaque_spring"],["steampeak",Vector2(28,11),1.4,"upper_stairs"],["steampeak",Vector2(41,7),1.5,"summit_geyser"]]:
  await enter(entry[0],entry[1],entry[2])
  for node in get_nodes_in_group("water_scenery"):
   if not node.is_queued_for_deletion():node.time=1.5;node.queue_redraw()
  await frames(4);shot(entry[3])
 world.queue_free();world=null;await frames(6);print("MOUNTAIN PREVIEW OK");quit()
