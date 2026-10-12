extends SceneTree
## Real physical input checks: grid, mouse, controller focus, one activation and modal cancellation.

const Items := preload("res://scripts/data/items.gd")
const Equipment := preload("res://scripts/core/equipment.gd")
const Gear := preload("res://scripts/data/ext/uitrusting.gd")
const Shops := preload("res://scripts/data/shops.gd")

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
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	await process_frame
	gs = root.get_node("GameState")
	controls = root.get_node("Controls")
	gs.new_game()
	gs.in_game = true
	gs.add_coins(2000)
	gs.give("bow", 1, true)
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(10)
	world.fader.set_alpha(0.0)
	world.set_process(false)
	world.player.set_physics_process(false)
	var menu: Node = world.menu_ui
	var page: Node = menu.equipment_page
	var shop: Node = world.shop_ui
	shop.open("tobias")
	await frames(6)
	check(shop.list.get_child_count() == 9, "Tobias shows old stock plus five new gear items")
	var last: Button = shop.list.get_child(8)
	for i in 7:
		await tap_pad(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() == last, "Controller reaches the last gear item through the expanded shop")
	var view: Rect2 = shop.scroll.get_global_rect()
	var row: Rect2 = last.get_global_rect()
	check(row.position.y >= view.position.y - 1 and row.end.y <= view.end.y + 1, "Focused ninth shop row scrolls fully into view")
	var money: int = gs.coins
	var ring_price := 0
	for offer: Dictionary in Shops.info("tobias").items:
		if offer.item == "gear_copper_ring":
			ring_price = offer.price
	await tap_pad(JOY_BUTTON_A)
	check(gs.count("gear_copper_ring") == 1 and gs.coins == money - ring_price, "Controller buys the visible new ring exactly once")
	check(Equipment.equipped("ring") == "", "Buying gear does not equip it automatically")
	var bounds: Rect2 = shop.panel.get_global_rect()
	check(bounds.position.y >= 0 and bounds.end.y <= shop.root.size.y, "Expanded shop remains within the viewport")
	await tap_pad(JOY_BUTTON_B)
	await tap_key(KEY_I)
	await tap_pad(JOY_BUTTON_LEFT_SHOULDER)
	check(menu.tab == 7 and menu.appearance_page.visible and menu.TAB_COUNT == 8, "LB opens the eighth appearance tab from inventory")
	await tap_pad(JOY_BUTTON_LEFT_SHOULDER)
	check(menu.tab == 6 and page.visible, "Another LB reaches the equipment tab")
	check(page.slots().size() == 7 and page.slot_rect(6).end.y <= page.size.y, "All five selectable slots and two automatic legacy positions are visible")
	await tap_pad(JOY_BUTTON_A)
	await tap_pad(JOY_BUTTON_A)
	await tap_pad(JOY_BUTTON_A)
	check(Equipment.equipped("head") == "" and not page.can_equip(), "Previewing an unowned helmet cannot equip it")
	gs.take("gear_copper_ring", 1)
	var layout_lang: Node = root.get_node("Lang")
	for locale: String in ["nl", "en"]:
		layout_lang.set_language(locale, false)
		for index in 5:
			page.select_slot(index)
			for option in page.alternatives().size():
				page.selected_item = option
				page.refresh()
				await frames(2)
				check(page.detail.get_content_height() <= page.detail.size.y, "%s unowned slot %d option %d height %d <= %d (width %d)" % [locale, index, option, page.detail.get_content_height(), page.detail.size.y, page.detail.size.x])
	layout_lang.set_language("nl", false)
	page.select_slot(0)
	gs.give("gear_copper_ring", 1, true)
	gs.give("gear_cloth_hood", 1, true)
	gs.give("gear_bronze_helm", 1, true)
	page.select_slot(0)
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	await tap_pad(JOY_BUTTON_DPAD_DOWN)
	check(page.candidate() == "gear_bronze_helm" and Equipment.equipped("head") == "", "Browsing owned alternatives does not change gear")
	await tap_pad(JOY_BUTTON_A)
	check(page.zone == 2 and Equipment.equipped("head") == "", "Confirming a candidate focuses the explicit equip button")
	await tap_pad(JOY_BUTTON_A)
	check(Equipment.equipped("head") == "gear_bronze_helm" and gs.movement.capacity() == 130, "Explicit controller equip applies the selected helmet bonus")
	check(gs.movement.stamina <= 100, "Equipping extra stamina does not refill it")
	await click(menu.content.position + page.position + page.item_rect(0).get_center())
	check(Equipment.equipped("head") == "gear_bronze_helm", "Mouse selection is also read-only")
	await click(menu.content.position + page.position + page.EQUIP_RECT.get_center())
	check(Equipment.equipped("head") == "gear_cloth_hood" and gs.movement.capacity() == 115, "Mouse equip swaps the slot bonus")
	check(gs.count("gear_bronze_helm") == 1 and gs.count("gear_cloth_hood") == 1, "Swapping preserves both inventory items")
	await click(menu.content.position + page.position + page.REMOVE_RECT.get_center())
	check(Equipment.equipped("head") == "" and gs.movement.capacity() == 100, "Visible remove button unequips without consuming an item")
	for id: String in Gear.ITEMS:
		gs.give(id, 1, true)
	for index in 5:
		await click(menu.content.position + page.position + page.slot_rect(index).get_center())
		await click(menu.content.position + page.position + page.item_rect(1).get_center())
		await click(menu.content.position + page.position + page.EQUIP_RECT.get_center())
		check(Equipment.equipped(page.slot_id()) == page.candidate(), "Mouse can equip the second item in slot %d" % index)
	check(gs.equipment.size() == 5, "All five distinct equipment positions can be active together")
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	await tap_pad(JOY_BUTTON_A)
	check(Equipment.equipped("ring") == "" and gs.count("gear_crystal_ring") == 1, "Controller reaches remove and leaves the ring in inventory")
	gs.give("boots", 1, true)
	var weapon: String = gs.weapon
	for index in [5, 6]:
		await click(menu.content.position + page.position + page.slot_rect(index).get_center())
		await tap_pad(JOY_BUTTON_A)
		check(page.alternatives().is_empty() and not page.can_remove(), "Legacy equipment position %d is read-only" % index)
	check(gs.weapon == weapon and gs.count("boots") == 1, "Browsing legacy positions preserves the sword and boots")
	await tap_pad(JOY_BUTTON_B)
	await tap_key(KEY_I)
	menu.selected = menu._owned().find("gear_cloth_hood")
	await tap_key(KEY_E)
	check(Equipment.equipped("head") == "gear_cloth_hood", "Existing inventory E action equips selectable gear")
	await click(menu.content.position + menu.tab_rect(6).get_center())
	check(page.visible and Equipment.equipped("head") == "gear_cloth_hood", "Mouse can return to the dedicated equipment overview")
	var lang: Node = root.get_node("Lang")
	for locale: String in ["nl", "en"]:
		lang.set_language(locale, false)
		await frames(4)
		for index in menu.TAB_COUNT:
			var tab: Rect2 = menu.tab_rect(index)
			var width: float = ThemeDB.fallback_font.get_string_size(menu.tab_titles()[index], HORIZONTAL_ALIGNMENT_LEFT, -1, menu.TAB_FONT_SIZE).x
			check(width <= tab.size.x and tab.end.x < menu.CLOSE_RECT.position.x, "%s tab %d fits eight-tab layout" % [locale, index])
		for index in 5:
			page.select_slot(index)
			for option in page.alternatives().size():
				page.selected_item = option
				page.refresh()
				await frames(2)
				check(page.detail.get_content_height() <= page.detail.size.y, "%s slot %d option %d comparison and source height %d <= %d (width %d)" % [locale, index, option, page.detail.get_content_height(), page.detail.size.y, page.detail.size.x])
		check(page.source_text("gear_cloth_hood").contains("Tobias"), "Tier-one source is derived from the real shop")
		check(page.source_text("gear_bronze_helm").contains("2") and page.source_text("gear_bronze_helm").contains("0/1"), "Tier-two source includes its actual crafting level and materials")
		if locale == "en":
			check(menu.tab_titles()[6] != "Uitrusting" and not page.detail.text.contains("Na wisselen:"), "Equipment interface is translated to English")
	lang.set_language("nl", false)
	await tap_pad(JOY_BUTTON_B)
	check(not menu.active and not paused and gs.ui_owners.is_empty(), "Equipment menu releases pause ownership on close")
	world.queue_free()
	await frames()
	print("EQUIPMENT UI OK" if failures == 0 else "EQUIPMENT UI FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
