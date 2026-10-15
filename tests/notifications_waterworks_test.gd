extends SceneTree
const Maps:=preload("res://scripts/maps/registry.gd")
const Water:=preload("res://scripts/core/marsh_waterworks.gd")
var world: Node2D
var gs: Node
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	print("  ok   " if ok else "  FAIL ",message)
	if not ok:failures+=1
func frames(n:=6):
	for i in n:await process_frame
func object(id: String) -> Node2D:
	for node in get_nodes_in_group("living_objects"):
		if not node.is_queued_for_deletion() and node.id==id:return node
	return null
func enter(id: String,spawn:="start"):
	world.load_map(id,spawn);world.player.set_physics_process(false);await frames(12)
func run():
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	gs=root.get_node("GameState");gs.new_game();gs.in_game=true;gs.set_process(false)
	world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(15)
	await enter("village")
	var p: Node2D=world.player;var hud: Node=world.hud
	hud.toast_queue.clear();hud.toast_time=0;hud.banner_time=0
	for locale in ["nl","en"]:
		root.get_node("Lang").set_language(locale,false);hud.item_receipts.entries.clear();hud.item_receipts.rebuild()
		gs.give("potion",3)
		check(hud.item_receipts.entries.size()==1 and hud.toast_queue.is_empty(),"item received routes to side feed in "+locale)
		var portal: Node2D
		for node in get_nodes_in_group("access_portals"):
			if not node.is_queued_for_deletion() and node.target_map=="lake":portal=node
		p.position=portal.rect.get_center()-Vector2(0,64);p.facing=Vector2.DOWN;p.target=null
		await frames(3);p.target=null
		hud._queue_toast("System notice");hud.toast_time=3;hud.banner_time=2;hud._refresh_access()
		check(hud.access_panel.visible and hud.access_text.text.contains("Zilvermeer" if locale=="nl" else "Silver Lake"),"doorway is immediately visible despite queued notices and banner in "+locale)
		for size in [Vector2i(960,540),Vector2i(1152,648),Vector2i(1600,900)]:
			root.size=size
			for i in 6:gs.give("potion",1)
			await frames(5);p.target=null;hud._refresh_access()
			check(hud.item_receipts.entries.size()<=4,"receipt burst is bounded at "+str(size.x))
			for entry in hud.item_receipts.entries:
				if entry.panel.visible:
					check(entry.panel.get_global_rect().end.x<=size.x and not entry.panel.get_global_rect().intersects(hud.access_panel.get_global_rect()),"side receipt stays on screen and clear of doorway at "+str(size.x))
		var left: float=hud.item_receipts.entries[-1].left
		gs.set_ui("receipt_probe",true);await frames(20)
		check(is_equal_approx(left,hud.item_receipts.entries[-1].left) and not hud.item_receipts.visible,"modal preserves receipt time and hides the feed")
		gs.set_ui("receipt_probe",false);hud.toast_queue.clear();hud.toast_time=0
	root.get_node("Lang").set_language("nl",false);root.size=Vector2i(1152,648)
	await enter("kruipmoeras");p=world.player
	check(world.is_solid(Vector2(17.5,16.5)*32),"western bridge gap is truly water before repair")
	object("lw_sluice_west").interact();await frames()
	check(gs.flag("lw_sluice_west") and not gs.flag("lw_drained"),"first west opening gives visible intermediate state without granting the quest")
	object("lw_sluice_east").interact();await frames()
	object("lw_sluice_east").interact();await frames(12)
	check(gs.flag("lw_drained") and not world.is_solid(Vector2(32.5,18.5)*32),"correct valve sequence exposes a broad physical eastern bank")
	check(world.is_solid(Vector2(17.5,16.5)*32),"drainage retains the western water channel so bridge repair matters")
	gs.give("lw_bridge_kit",1,true);object("lw_bridge_control").choose("bridge_kit");await frames(12)
	var complete:=true
	for y in range(16,18):
		for x in range(15,24):complete=complete and not world.is_solid(Vector2(x+.5,y+.5)*32)
	check(complete,"repaired bridge spans every tile from west bank to island")
	p.position=Vector2(15.5,16.5)*32;p.set_physics_process(true)
	Input.action_press("move_right")
	for i in 200:
		await physics_frame
		if p.position.x>=23.5*32:break
	Input.action_release("move_right");p.set_physics_process(false)
	check(p.position.x>=23.5*32,"actual movement crosses the whole repaired bridge")
	gs.save_game(p.position);gs.flags.clear();gs.load_game();await enter("kruipmoeras")
	check(gs.flag("lw_bridge") and not world.is_solid(Vector2(17.5,16.5)*32) and gs.flag("lw_sluice_west") and not gs.flag("lw_sluice_east"),"bridge and canonical visible gate states persist after reload")
	await enter("village","from_lake");p=world.player
	check(p.position.y>=40*32 and world.spawn_fits(p.position),"lake return arrives safely at the new southern approach")
	check(Maps.get_map("village").objects.filter(func(o):return o.type=="portal" and o.to=="lake").size()==1,"only one lake exit exists")
	p.position=Vector2(19.5,40.5)*32;p.set_physics_process(true);Input.action_press("move_down")
	for i in 240:
		await physics_frame
		if gs.map_id=="lake":break
	Input.action_release("move_down");await frames(85)
	check(gs.map_id=="lake","walking south through the new village exit actually reaches the lake")
	world.queue_free();world=null;await frames()
	if failures==0:print("NOTIFICATIONS WATERWORKS TEST OK")
	quit(0 if failures==0 else 1)
