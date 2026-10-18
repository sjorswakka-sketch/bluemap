extends SceneTree
## Test van de menu-polijsting: de glijdende tabmarkering, de zachte pagina-overgang bij een tabwissel,
## de muis-hover op tabbladen en sluitknop, en de gedeelde marges van de bladzijden.
##
##   sh tools/run_tests.sh /pad/naar/godot      (alle tests), of alleen deze:
##   XDG_DATA_HOME=.testdata godot --headless --fixed-fps 60 --path . -s tests/menu_polis_test.gd
##
## Zonder XDG_DATA_HOME schrijft de test in de echte opslagmap van het spel (en overschrijft hij je opgeslagen spel).

var failures := 0
var gs: Node
var world: Node
var menu: Node


func check(ok: bool, label: String) -> void:
	print("  ok   " if ok else "  FAIL ", label)
	if not ok:
		failures += 1


func frames(count := 3) -> void:
	for i in count:
		await process_frame


func move_mouse(local_at: Vector2) -> void:
	# Headless kun je de aanwijzer niet echt verplaatsen, dus voeren we de plaatselijke positie
	# rechtstreeks in (in het spel komt hij uit content.get_local_mouse_position()).
	menu.update_hover(local_at)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	gs = root.get_node("GameState")
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await frames(5)
	gs.new_game()
	gs.in_game = true
	await frames(3)
	menu = world.menu_ui

	test_layout()
	await test_transition()
	await test_hover()
	await test_inventory_bounds()

	world.queue_free()
	await frames(2)
	print("MENU-POLIS OK" if failures == 0 else "MENU-POLIS FAILED: %d" % failures)
	quit(1 if failures else 0)


# --- Deel 1: marges en indeling --------------------------------------------------------------------------

func test_layout() -> void:
	print("Marges en indeling")
	# De bladzijden beginnen allemaal op dezelfde kopregel en dezelfde inhoudslijn.
	check(menu.MARGIN == 24.0 and menu.HEADER_Y == 72.0, "de buitenmarge en kopregel zijn vastgelegd")
	check(menu.LIST_TOP == 108.0, "de lijsten beginnen op de vaste inhoudslijn")
	# Acht tabbladen passen naast elkaar zonder de sluitknop te raken.
	check(menu.tab_rect(7).end.x <= menu.CLOSE_RECT.position.x, "alle acht tabbladen blijven links van de sluitknop")
	var stride: float = menu._tab_stride()
	check(is_equal_approx(menu.tab_rect(1).position.x - menu.tab_rect(0).position.x, stride), "de tabbladen staan op gelijke afstand")
	# De deelpagina's hangen onder de pagina-laag, zodat ze meebewegen met de overgang.
	check(menu.progression_page.get_parent() == menu.page and menu.equipment_page.get_parent() == menu.page and menu.appearance_page.get_parent() == menu.page, "de deelpagina's zitten op de pagina-laag")


# --- Deel 2: de tabwissel-overgang ------------------------------------------------------------------------

func test_transition() -> void:
	print("De overgang bij een tabwissel")
	menu.open(0)
	await frames(2)
	check(menu.tab_anim < 1.0, "het menu faden in bij het openen")
	check(menu.page.modulate.a < 1.0 and menu.page.position.y > 0.0, "de bladzijde schuift zacht naar binnen")
	await frames(15) # ruim langer dan TAB_ANIM_TIME bij 60 fps
	check(menu.tab_anim == 1.0 and menu.page.modulate.a == 1.0 and menu.page.position.y == 0.0, "na de overgang staat alles stil op zijn plek")

	menu._set_tab(2) # kaart
	await frames(2)
	check(menu.tab == 2 and menu.tab_from == 0.0, "de markering glijdt van voorwerpen naar kaart")
	check(menu.tab_visual > 0.0 and menu.tab_visual < 2.0, "de markering is onderweg (%0.2f)" % menu.tab_visual)
	check(menu.page.modulate.a < 1.0, "de nieuwe bladzijde faden in")
	await frames(15)
	check(is_equal_approx(menu.tab_visual, 2.0) and menu.tab_anim == 1.0, "de markering landt precies op het nieuwe tabblad")
	menu.close()
	await frames(2)


# --- Deel 3: hover met de muis ----------------------------------------------------------------------------

func test_hover() -> void:
	print("Hover met de muis")
	menu.open(0)
	await frames(3)
	move_mouse(menu.tab_rect(3).get_center())
	check(menu.hover_tab == 3, "het tabblad onder de muis licht op")
	move_mouse(menu.CLOSE_RECT.get_center())
	check(menu.hover_close and menu.hover_tab == -1, "de sluitknop licht op")
	move_mouse(Vector2(500, 300))
	check(menu.hover_tab == -1 and not menu.hover_close, "weg van de knoppen dooft de hover weer")
	menu.close()
	await frames(2)


# --- Native font bounds -------------------------------------------------------------------------
func test_inventory_bounds() -> void:
	check(not menu.INVENTORY_DETAIL_RECT.intersects(menu.USE_RECT) and not menu.USE_RECT.intersects(menu.INVENTORY_STATS_RECT),"inventory card, action and summary have separate space")
	# Dummy text rendering reports placeholder metrics (e.g. 3x font height).
	# The same suite runs these full checks with the real native renderer.
	if DisplayServer.get_name()=="headless":
		print("INVENTORY BOUNDS: native renderer required for actual font metrics")
		return
	var items: Script=preload("res://scripts/data/items.gd")
	var products: Array=preload("res://scripts/data/ext/forest_food_species.gd").SPECIES.values().map(func(s):return s.item)
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	world.load_map("forest","start");await frames(8)
	var font:=ThemeDB.fallback_font
	var issues: Array[String]=[]
	var checked:=0;var source_cases:=0;var body_fonts: Dictionary={}
	for locale in ["nl","en"]:
		root.get_node("Lang").set_language(locale,false)
		for viewport_size in [Vector2i(960,540),Vector2i(1152,648)]:
			root.size=viewport_size;menu.open(0);await frames(12)
			for id: String in items.ITEMS:
				var plan: Dictionary=menu.inventory_detail_layout(font,id);checked+=1
				var context: String=locale+str(viewport_size.x)+" "+id
				if not plan.fits:issues.append(context+" card exceeds detail region")
				var previous: float=menu.INVENTORY_DETAIL_RECT.position.y
				var forage: bool=id.begins_with("flower_") or id.begins_with("winter_") or id in products
				for block: Dictionary in plan.blocks:
					if not menu.INVENTORY_DETAIL_RECT.encloses(block.rect):issues.append(context+" paragraph exceeds card")
					if block.rect.position.y<previous:issues.append(context+" paragraphs overlap")
					if block.rect.end.y>menu.USE_RECT.position.y-8:issues.append(context+" text reaches action button")
					if forage and block.tag=="source":
						source_cases+=1
						if block.size!=16 or not block.text.contains("("):issues.append(context+" source coordinates unreadable")
					if forage and block.tag=="description":body_fonts[block.size]=true
					previous=block.rect.end.y
			var transform: Transform2D=menu.content.get_global_transform()
			for area: Rect2 in [menu.INVENTORY_DETAIL_RECT,menu.USE_RECT,menu.INVENTORY_STATS_RECT]:
				if not Rect2(Vector2.ZERO,Vector2(viewport_size)).encloses(transform*area):issues.append(locale+str(viewport_size.x)+" card outside viewport")
			var previous: float=menu.INVENTORY_STATS_RECT.position.y
			for block: Dictionary in menu.inventory_stat_layout(font):
				if not menu.INVENTORY_STATS_RECT.encloses(block.rect) or block.rect.position.y<previous:issues.append(locale+" summary rows overlap or overflow")
				if block.rect.end.y>=menu.SIZE.y-16-font.get_ascent(16):issues.append(locale+" summary reaches footer")
				if font.get_string_size(block.text,HORIZONTAL_ALIGNMENT_LEFT,-1,block.size).x>block.rect.size.x:issues.append(locale+" summary exceeds column width")
				previous=block.rect.end.y
			menu.close();await frames(2)
	root.get_node("Lang").set_language("nl",false)
	check(checked==items.ITEMS.size()*4,"all inventory items measured in NL/EN at 960 and 1152")
	check(source_cases==256,"all64forages retain source coordinates in both languages and viewports")
	check(issues.is_empty(),"actual inventory font bounds: "+str(issues.slice(0,8)))
	var proof: Dictionary={"items":items.ITEMS.size(),"item_cases":checked,"source_cases":source_cases,"new_body_fonts":body_fonts.keys(),"issues":issues,"viewports":[960,1152],"locales":["nl","en"],"renderer":DisplayServer.get_name()}
	FileAccess.open("res://inventory-layout-proof.json",FileAccess.WRITE).store_string(JSON.stringify(proof," "))
	print("INVENTORY BOUNDS PROOF ",JSON.stringify(proof))
