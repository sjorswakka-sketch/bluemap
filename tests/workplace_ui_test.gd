extends "res://tests/homestead_test.gd"
const Identity:=preload("res://scripts/core/craft_identity.gd")
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
 root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1152,648)
 world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(14);p=world.player
 await enter("village");p.set_physics_process(false)
 gs.give("hs_hoe",1,true);gs.give("hs_grape",12,true);gs.give("hs_manure",8,true)
 for role in ["guide","wine","compost","hive"]:
  await open(role);await frames(5)
  check(ui().role_card!=null and ui().role_card.role==role,"workplace diagram matches real station "+role)
  if role=="wine":
   check(ui().buttons[0].text.contains("Vul vat"),"wine action describes filling a barrel")
   var old: int=gs.count("hs_grape")
   await click(ui().buttons[0]);await frames(3)
   check(gs.count("hs_grape")==old-3 and Farm.state().jobs.has("wine_a"),"native wine button still commits exact ingredients")
   check(ui().buttons[0].text=="Wijn bottelen" and ui().buttons[0].disabled,"unready wine clearly shows disabled bottling")
  elif role=="compost":
   check(ui().buttons[0].text.contains("compost"),"compost uses a specific mixing action")
  elif role=="hive":check(ui().buttons[0].text=="Honing uit de kast halen","hive uses its own collection action")
  await close_ui()
 var craft: Node=world.crafting_ui
 await tap(KEY_C);await frames(5)
 check(craft.active,"native profession shortcut opens journal")
 var inventory: Dictionary=gs.inventory.duplicate(true)
 var titles: Dictionary={}
 for i in craft.Data.SKILLS.size():
  var id: String=craft.Data.SKILLS.keys()[i]
  var choices: Array=craft.skill_list.get_children().filter(func(n):return n is Button)
  choices[i].grab_focus();await tap(JOY_BUTTON_A,true);await frames(6)
  check(craft.selected_skill==id and craft.title_label.text==Identity.title(id) and craft.recipes_button.text==Identity.tab(id),"controller selects the matching profession identity "+id)
  if id=="fishing":check(craft.rows.get_children().filter(func(n):return n is Button).size()==3,"fishing journal shows actual catch references instead of an empty recipe list")
  titles[craft.title_label.text]=true
  check(craft.profession_banner.get_global_rect().end.x<=craft.panel.get_global_rect().end.x,"profession artwork stays inside panel "+id)
  check(gs.inventory==inventory,"viewing profession never consumes materials "+id)
 check(titles.size()==7,"all seven professions have distinct readable headings")
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for dimensions in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=dimensions
   for id: String in craft.Data.SKILLS:
    craft.selected_skill=id;craft._populate();await frames(6)
    check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(craft.panel.get_global_rect()),"profession panel fits "+id+locale+str(dimensions))
    check(craft.profession_banner.get_global_rect().end.y<=craft.scroll.get_global_rect().position.y,"profession header leaves recipe list clear "+id+locale+str(dimensions))
 await tap(JOY_BUTTON_B,true);check(not craft.active and not gs.input_locked(),"B closes differentiated journal cleanly")
 root.get_node("Lang").set_language("nl",false)
 await enter("player_home");p.set_physics_process(false)
 for locale in ["nl","en"]:
  root.get_node("Lang").set_language(locale,false)
  for dimensions in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
   root.size=dimensions;await open("bed");await frames(5)
   check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(ui().panel.get_global_rect()),"rest panel fits "+locale+str(dimensions));await close_ui()
 world.queue_free();await frames(5);print("WORKPLACE UI OK" if failures==0 else "WORKPLACE UI FAILED "+str(failures));quit(0 if failures==0 else 1)
