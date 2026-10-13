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
