extends "res://tools/storage_preview.gd"
const Maps:=preload("res://scripts/maps/registry.gd")
func shot(id: String):root.get_texture().get_image().save_png("res://entrance_"+id+".png")
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-" ):quit(1);return
 await frames(5);DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED);RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1152,648)
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false);gs.day_time=.2
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(15)
 var survey: Dictionary={}
 for id: String in Maps.MAPS:survey[id]=Maps.get_map(id)
 var file:=FileAccess.open("res://entrance-map-survey.json",FileAccess.WRITE);file.store_string(JSON.stringify(survey));file.close()
 var shots: Array=[
 ["forest",Vector2(27,19),.55,"forest_whole"],
 ["forest",Vector2(7,26),1.7,"forest_old_training"],
 ["forest",Vector2(12,26),1.8,"forest_training_south_gate"],
 ["watchyard",Vector2(14,18),2.2,"training_south_inside"],
 ["village",Vector2(10,13),1.7,"village_double_doors"],
 ["village",Vector2(20,8),1.8,"temple_single_mouth"],
 ["lake",Vector2(32,8),1.8,"library_double_door"],
 ["harbor",Vector2(56,23),1.8,"workshop_double_door"],
 ["coast_workshop",Vector2(15,20),1.8,"workshop_double_return"],
 ["forest",Vector2(49,12),2.0,"ruin_single_stair"],
 ["forest",Vector2(48,32),2.0,"cave_single_mouth"],
 ["cave",Vector2(5,32),2.0,"cave_single_return"],
 ["cave",Vector2(5,8),2.0,"prismamine_single_stair"],
 ["prismamine",Vector2(36,7),1.7,"resonance_single_mouth"],
 ["resonance",Vector2(15,20),1.8,"resonance_single_return"],
 ["kruipmoeras",Vector2(24,18),1.8,"archive_single_mouth"],
 ["reedvault",Vector2(3,14),1.8,"archive_single_return"],
 ["river_mouth",Vector2(17,10),1.7,"hollow_single_mouth"],
 ["tidal_hollow",Vector2(3,29),1.7,"hollow_single_return"],
 ["temple",Vector2(12,20),1.8,"temple_single_return"],
 ["temple",Vector2(12,3),1.8,"depths_single_seal"],
 ["depths1",Vector2(7,26),1.8,"depths_single_return"],
 ["depths1",Vector2(22,4),1.8,"lower_depths_single_stair"],
 ["depths2",Vector2(13,20),1.8,"lower_depths_single_return"],
 ["ijsdal",Vector2(24,3),1.8,"mountain_double_road"],
 ["dauwbos",Vector2(44,30),1.8,"garden_double_path"]
 ]
 for entry: Array in shots:
  await enter(entry[0],entry[1],entry[2]);shot(entry[3])
 world.queue_free();world=null;await frames(8);print("ENTRANCE PREVIEW OK");quit()
