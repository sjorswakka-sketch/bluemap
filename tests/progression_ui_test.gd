extends SceneTree
## Real physical input checks: grid, mouse, controller focus, one activation and modal cancellation.

const Items := preload("res://scripts/data/items.gd")
const Progression := preload("res://scripts/core/progression.gd")
const Professions := preload("res://scripts/core/professions.gd")
const Data := preload("res://scripts/data/ext/beroepen.gd")

var failures := 0
var gs: Node
var world: Node
var controls: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("  ok   " if ok else "  FAIL ", label)
	if not ok:
		failures += 1

func frames(count := 3) -> void:
	for i in count:
		await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap_key(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(3)

func pad(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func tap_pad(button: JoyButton) -> void:
	pad(button, true)
	await frames(3)
	pad(button, false)
	await frames(3)

func click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.relative = Vector2(40, 0)
	motion.screen_relative = motion.relative
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = button
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
		await frames(2)

func _run() -> void:
	await process_frame
	gs = root.get_node("GameState")
	controls = root.get_node("Controls")
	gs.new_game()
	gs.in_game = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(10)
	world.fader.set_alpha(0.0)
	world.set_process(false)
	world.player.set_physics_process(false)
	var menu: Node = world.menu_ui
	var page: Node = menu.progression_page
	var hud: Node = world.hud
	var lang: Node = root.get_node("Lang")
	check(menu.TAB_COUNT == 6 and menu.TAB_PROGRESSION == 5, "Progression appends a sixth tab without changing existing indices")
	check(hud.xp_bar.position.y >= hud.stamina_bar.position.y + hud.stamina_bar.size.y, "XP bar sits below stamina without overlap")
	check(not hud.xp_bar.get_rect().intersects(hud.clock.get_rect()), "XP bar does not overlap the clock")
	check(hud.xp_label().contains("1") and hud.xp_label().contains("0/50 XP"), "HUD shows initial hero level and actual XP threshold")
	await tap_key(KEY_I)
	await tap_pad(JOY_BUTTON_LEFT_SHOULDER)
	check(menu.active and menu.tab == 5 and page.visible and paused, "LB wraps from inventory to the visible progression page")
	await tap_pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(menu.tab == 0 and not page.visible, "RB wraps back to inventory and hides progression content")
	await tap_pad(JOY_BUTTON_LEFT_SHOULDER)
	var location: Vector2 = world.player.position
	for index in range(1, 11):
		await tap_pad(JOY_BUTTON_DPAD_DOWN)
		check(page.selected == index, "Controller selects progression row %d exactly once" % index)
	check(page.row_rect(10).end.y <= page.size.y, "All seven professions and four gear rows fit in the page")
	check(world.player.position == location, "Progression navigation cannot move the player")
	page.select(3)
	await frames(3)
	check(page.detail.get_v_scroll_bar().max_value > page.detail.size.y, "Long tool requirements expose a scrollable detail panel")
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(page.selected == 3 and page.detail.get_v_scroll_bar().value > 0, "Controller right scrolls long details without changing the selected category")
	await tap_pad(JOY_BUTTON_DPAD_LEFT)
	check(page.detail.get_v_scroll_bar().value == 0, "Controller left returns to the beginning of details")
	await click(menu.content.position + page.position + page.detail.position + Vector2(100, 100), MOUSE_BUTTON_WHEEL_DOWN)
	check(page.selected == 3 and page.detail.get_v_scroll_bar().value > 0, "Mouse wheel scrolls the detail under the pointer without changing its category")
	await click(menu.content.position + page.position + page.row_rect(2).get_center())
	check(page.selected == 2 and not controls.controller_active, "Mouse takes over and selects heart upgrades")
	for index in menu.TAB_COUNT:
		await click(menu.content.position + menu.tab_rect(index).get_center())
		check(menu.tab == index and page.visible == (index == 5), "Mouse tab %d selects the matching content" % index)
	page.select(0)
	var upgrade: Dictionary = page.weapon_upgrade()
	check(upgrade.weapon == "iron" and upgrade.coins == 40 and upgrade.materials == {"gel": 5}, "Iron requirements match Greta's real transaction")
	check(page.detail.text.contains("1 → 2") and page.detail.text.contains("34 → 38"), "Sword detail gives concrete damage and reach gains")
	gs.weapon = "iron"
	gs.items_changed.emit()
	check(page.weapon_upgrade().coins == 80 and page.weapon_upgrade().materials == {"shard": 2, "gel": 8}, "Crystal requirements follow the equipped sword")
	gs.weapon = "crystal"
	gs.items_changed.emit()
	check(page.weapon_upgrade().weapon == "star" and page.detail.text.contains("Vergeten Wachter"), "Crystal sword points to the existing post-story star reward")
	gs.weapon = "star"
	gs.items_changed.emit()
	check(page.weapon_upgrade().weapon == "" and page.detail.text.contains("sterkste"), "Best sword has a completed state rather than a phantom upgrade")
	page.select(1)
	check(page.detail.text.contains("18%") and page.detail.text.contains("0 / 60"), "Boots show the derived speed bonus and actual shop price")
	gs.give("boots", 1, true)
	check(page.detail.text.contains("Uitgerust") and not page.detail.text.contains("0 / 60"), "Purchasing boots refreshes the equipped state immediately")
	page.select(2)
	check(page.detail.text.contains("5 / 8") and page.detail.text.contains("Pim") and page.detail.text.contains("Muis"), "Hearts show real capacity and Pim's quest source")
	gs.give("heart_container", 3, true)
	check(page.detail.text.contains("Alle hartcontainers"), "Maximum heart capacity is marked complete")
	page.select(3)
	check(page.detail.text.contains("Stenen bijl") and page.detail.text.contains("Stenen pikhouweel") and page.detail.text.contains("80 munten"), "Tools explain first tools and the actual Tobias bow purchase")
	gs.give("prof_axe", 1, true)
	gs.give("prof_pickaxe", 1, true)
	check(page.detail.text.contains("IJzeren bijl") and page.detail.text.contains("Koperen pikhouweel") and page.detail.text.contains("Smeden niveau 3"), "Owned stone tools reveal their correct next recipes and levels")
	gs.give("prof_iron_axe", 1, true)
	gs.give("prof_copper_pickaxe", 1, true)
	gs.give("bow", 1, true)
	gs.give("fishing_rod", 1, true)
	check(not page.detail.text.contains("Volgende upgrade:") and page.detail.text.contains("Boog: in bezit"), "Best tools and bow show ownership without inventing further upgrades")
	page.select(4)
	Professions.add_xp("foraging", 30)
	check(page.detail.text.contains("Niveau 2 / 10"), "Profession XP refreshes an already open page")
	gs.add_hero_xp(Progression.threshold(2))
	check(hud.xp_label().contains("2") and hud.xp_label().contains("0/100 XP") and Progression.progress().next_reward == 15, "Hero level and next span update while a menu is open")
	for locale: String in ["en", "nl"]:
		lang.set_language(locale, false)
		await frames(4)
		for index in menu.TAB_COUNT:
			var rect: Rect2 = menu.tab_rect(index)
			var width: float = ThemeDB.fallback_font.get_string_size(menu.tab_titles()[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			check(width <= rect.size.x and rect.end.x < menu.CLOSE_RECT.position.x, "%s tab %d fits without clipping the close button" % [locale, index])
		check(page.heading.text == TranslationServer.translate(Data.SKILLS.foraging.name), "Selected skill refreshes in %s without losing selection" % locale)
		check(page.selected == 4 and page.visible, "Language refresh retains the progression selection")
		if locale == "en":
			check(menu.tab_titles()[5] != "Voortgang" and page.heading.text != "Kruidenzoeken", "Progression and data names have real English translations")
	gs.add_hero_xp(Progression.MAX_XP)
	check(hud.xp_label().contains("maximaal") and Progression.progress().needed == 0, "Maximum level has a stable label and no division by zero")
	await tap_pad(JOY_BUTTON_B)
	check(not menu.active and not paused and gs.ui_owners.is_empty(), "Controller B closes progression and releases the pause owner")
	world.queue_free()
	await frames()
	print("PROGRESSION UI OK" if failures == 0 else "PROGRESSION UI FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
