extends SceneTree
## Uiterlijk: haarstijlen, ogen, kleding over de uitrusting, verf, opslag en het tabblad.

const Items := preload("res://scripts/data/items.gd")
const Shops := preload("res://scripts/data/shops.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Village := preload("res://scripts/maps/village.gd")
const Appearance := preload("res://scripts/core/appearance.gd")
const Data := preload("res://scripts/data/ext/uiterlijk.gd")

var failures := 0
var gs: Node


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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	await process_frame
	gs = root.get_node("GameState")
	gs.new_game()
	gs.in_game = true

	# --- data ---------------------------------------------------------------------
	check(Data.HAIR_M.size() == 45, "45 haarstijlen voor mannen")
	check(Data.HAIR_V.size() == 45, "45 haarstijlen voor vrouwen")
	check(Data.EYES.size() == 16, "16 oogstijlen")
	check(Data.HAIR_COLORS.size() == 16, "16 haarkleuren")
	check(Data.EYE_COLORS.size() == 12, "12 oogkleuren")
	check(Data.DYE_COLORS.size() == 20, "20 verfkleuren")
	check(Appearance.SLOTS.size() == 5, "5 kledingvakken naast de uitrusting")
	var signatures := {}
	var unique_params := true
	for gender: Dictionary in [Data.HAIR_M, Data.HAIR_V]:
		signatures.clear()
		for id: String in gender:
			var style: Dictionary = gender[id]
			var signature := "%s%d%d%d%d%s%s%s%d%d" % [style.get("bald", false), int(style.get("len", -1)), int(style.get("bangs", 0)), int(style.get("top", 0)), int(style.get("tail", 0)), style.get("bun", false), style.get("curl", false), style.get("vol", 0), int(style.get("spiky", 0)), int(style.get("sidetail", 0))]
			if signatures.has(signature):
				unique_params = false
				print("    dubbele stijlvorm:", id)
			signatures[signature] = true
	check(unique_params, "elke haarstijl tekent echt anders (unieke vorm per geslacht)")
	var icons := {}
	var icons_ok := true
	var slots_ok := true
	for id: String in Data.ITEMS:
		var info: Dictionary = Data.ITEMS[id]
		if Items.info(id).is_empty() or Items.info(id).get("type", "") != "cloth":
			slots_ok = false
			print("    geen geldig kledingvoorwerp:", id)
		if not Appearance.SLOTS.has(str(info.get("slot", ""))):
			slots_ok = false
			print("    onbekend kledingvak:", id)
		if icons.has(int(info["icon"])):
			icons_ok = false
		icons[int(info["icon"])] = true
	check(Data.ITEMS.size() == 24 and icons_ok, "24 kledingstukken met unieke pictogrammen")
	check(slots_ok, "alle kleding is type cloth met een geldig vak")

	# --- staat ---------------------------------------------------------------------
	var defaults := Appearance.normalize_appearance({})
	check(defaults["gender"] == "m" and Data.HAIR_M.has(defaults["hair"]) and Data.EYES.has(defaults["eyes"]), "standaard uiterlijk is geldig")
	var junk := Appearance.normalize_appearance({"gender": "x", "hair": "bestaat_niet", "hair_color": 99, "eyes": 7, "eye_color": -3})
	check(junk["gender"] == "m" and Data.HAIR_M.has(junk["hair"]) and junk["hair_color"] == 15 and junk["eyes"] == "rond" and junk["eye_color"] == 0, "oude of kapotte opslag valt terug op geldige waarden")
	var vrouw := Appearance.normalize_appearance({"gender": "v", "hair": "m_kort"})
	check(vrouw["gender"] == "v" and Data.HAIR_V.has(vrouw["hair"]), "geslachtswissel kiest een kapsel dat voor dat geslacht bestaat")

	gs.give("cloth_cape", 1, true)
	check(Appearance.worn("back").is_empty(), "bezit alleen draagt zichzelf niet")
	check(Appearance.wear("cloth_cape"), "cape aantrekken lukt")
	check(not Appearance.wear("cloth_straw_hat"), "een stuk dat je niet bezit kun je niet dragen")
	check(str(Appearance.worn("back").get("item", "")) == "cloth_cape", "cape zit in het rugvak")
	check(Appearance.dye("back", 8), "verven van een gedragen stuk lukt")
	check(int(Appearance.worn("back")["dye"]) == 8, "verfkleur onthouden")
	gs.give("cloth_scarf", 1, true)
	Appearance.wear("cloth_scarf")
	check(int(Appearance.worn("back")["dye"]) == 8, "het vak bewaart zijn verf bij een ander stuk")
	check(not Appearance.dye("hat", 3), "een leeg vak kun je niet verven")
	gs.take("cloth_scarf", 1)
	check(Appearance.worn("back").is_empty(), "weggehaalde kleding valt direct uit het vak")

	# opslag: uiterlijk en kleding overleven een save/load
	Appearance.set_gender("v")
	Appearance.set_hair("v_vlecht")
	Appearance.set_hair_color(5)
	Appearance.set_eyes("vonkel")
	Appearance.set_eye_color(2)
	Appearance.wear("cloth_cape")
	Appearance.dye("back", 3)
	check(gs.save_game(Vector2(100, 200)), "opslaan lukt")
	gs.new_game()
	check(gs.load_game(), "laden lukt")
	check(str(gs.appearance.get("gender", "")) == "v" and str(gs.appearance.get("hair", "")) == "v_vlecht", "geslacht en kapsel overleven opslag")
	check(int(gs.appearance.get("hair_color", -1)) == 5 and str(gs.appearance.get("eyes", "")) == "vonkel" and int(gs.appearance.get("eye_color", -1)) == 2, "kleuren en ogen overleven opslag")
	check(str(Appearance.worn("back").get("item", "")) == "cloth_cape" and int(Appearance.worn("back")["dye"]) == 3, "kleding en verf overleven opslag")

	# --- wereld: Vera en haar winkel ------------------------------------------------
	var village_seen := _reach(Village.DATA["rows"], Vector2i(19, 9))
	check(_next_to(village_seen, Village.DATA["rows"], Vector2i(26, 16)), "Vera de kleermaakster staat bereikbaar in het dorp")
	var shop: Node = null
	var world: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(10)
	world.fader.set_alpha(0.0)
	world.set_process(false)
	world.player.set_physics_process(false)
	shop = world.shop_ui
	gs.add_coins(500)
	shop.open("vera")
	await frames(6)
	check(shop.list.get_child_count() == 24, "Vera verkoopt alle 24 kledingstukken")
	await tap_pad(JOY_BUTTON_A)
	check(gs.count("cloth_straw_hat") == 1, "kopen bij Vera werkt")
	check(Appearance.worn("hat").is_empty(), "gekochte kleding trekt niet vanzelf aan")
	await tap_pad(JOY_BUTTON_B)
	await frames(2)

	# --- tabblad --------------------------------------------------------------------
	var menu: Node = world.menu_ui
	var page: Node = menu.appearance_page
	await tap_key(KEY_I)
	await tap_pad(JOY_BUTTON_LEFT_SHOULDER)
	check(menu.tab == 7 and page.visible and menu.TAB_COUNT == 8, "LB vanaf Voorwerpen opent het tabblad Uiterlijk")
	var before := str(gs.appearance.get("hair", ""))
	await tap_pad(JOY_BUTTON_DPAD_DOWN) # naar haarstijl
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(str(gs.appearance.get("hair", "")) != before, "pijltje verandert het kapsel")
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	await tap_pad(JOY_BUTTON_DPAD_LEFT)
	check(true, "kapsel bladeren zonder grensfouten")
	# kledingrij: rugvak (rij 6) — cape aan/uit en verven via de pagina
	for i in 3:
		await tap_pad(JOY_BUTTON_DPAD_DOWN)
	page.selected = 6
	check(page.slot_of_row(6) == "back", "rij 6 is het rugvak")
	Appearance.unwear("back") # de cape zit nog aan van de opslag-ronde
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(str(Appearance.worn("back").get("item", "")) != "", "pijltje trekt een kledingstuk aan")
	await tap_pad(JOY_BUTTON_A)
	check(page.dye_mode, "bevestigen opent de verfkleuren")
	var dye_before: int = int(Appearance.worn("back")["dye"])
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(int(Appearance.worn("back")["dye"]) == posmod(dye_before + 1, Data.DYE_COLORS.size()), "pijltje kiest een andere verfkleur")
	await tap_pad(JOY_BUTTON_A)
	check(not page.dye_mode, "bevestigen sluit de verfkleuren weer")
	# render-smoke: elke haarstijl, oogstijl en elk kledingstuk een keer echt tekenen
	Appearance.set_gender("m")
	for hair_id: String in Data.HAIR_M:
		Appearance.set_hair(hair_id)
		page.queue_redraw()
		await process_frame
	Appearance.set_gender("v")
	for hair_id: String in Data.HAIR_V:
		Appearance.set_hair(hair_id)
		page.queue_redraw()
		await process_frame
	for eyes_id: String in Data.EYES:
		Appearance.set_eyes(eyes_id)
		page.queue_redraw()
		await process_frame
	for item_id: String in Data.ITEMS:
		gs.give(item_id, 1, true)
		Appearance.wear(item_id)
		page.queue_redraw()
		await process_frame
	check(true, "alle haarstijlen, oogstijlen en kledingstukken tekenen zonder fouten")
	page.selected = 0
	await tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(str(gs.appearance.get("gender", "")) == "m", "geslacht wisselt via de pagina")
	var lang: Node = root.get_node("Lang")
	for locale: String in ["nl", "en"]:
		lang.set_language(locale, false)
		await frames(4)
		for index in menu.TAB_COUNT:
			var tab: Rect2 = menu.tab_rect(index)
			var width: float = ThemeDB.fallback_font.get_string_size(menu.tab_titles()[index], HORIZONTAL_ALIGNMENT_LEFT, -1, menu.TAB_FONT_SIZE).x
			check(width <= tab.size.x and tab.end.x < menu.CLOSE_RECT.position.x, "%s tab %d past in de balk" % [locale, index])
	lang.set_language("nl", false)
	await tap_pad(JOY_BUTTON_B)
	check(not menu.active and not paused and gs.ui_owners.is_empty(), "menu sluit netjes")
	world.queue_free()
	await frames()
	print("UITERLIJK OK" if failures == 0 else "UITERLIJK FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)


func _reach(rows: Array, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := p + d
			if seen.has(n) or n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= String(rows[n.y]).length():
				continue
			if Tiles.is_solid_char(String(rows[n.y])[n.x]):
				continue
			seen[n] = true
			queue.append(n)
	return seen


func _next_to(seen: Dictionary, rows: Array, pos: Vector2i) -> bool:
	if seen.has(pos):
		return true
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if seen.has(pos + d):
			return true
	return false
