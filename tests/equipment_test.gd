extends SceneTree
## Echte uitrusting: kiezen, effecten, verwerving en veilige opslagmigratie.

const Equipment := preload("res://scripts/core/equipment.gd")
const Data := preload("res://scripts/data/ext/uitrusting.gd")
const Items := preload("res://scripts/data/items.gd")
const Shops := preload("res://scripts/data/shops.gd")
const Professions := preload("res://scripts/core/professions.gd")
const Recipes := preload("res://scripts/data/ext/beroepen.gd")

class FakeWorld extends Node2D:
	func burst(_pos: Vector2, _color: Color, _amount: int) -> void:
		pass

var failures := 0
var gs: Node
var changes := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("  ok   " if ok else "  FAIL ", label)
	if not ok:
		failures += 1


func _on_equipment() -> void:
	changes += 1


func _run() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):
		push_error("Use tools/run_tests.py for isolated saves")
		quit(1)
		return
	gs = root.get_node("GameState")
	gs.in_game = false
	gs.equipment_changed.connect(_on_equipment)
	_test_selection()
	_test_stamina()
	_test_armor()
	await _test_magnet()
	await _test_acquisition()
	_test_save()
	_test_new_game_plus()
	print("EQUIPMENT OK" if failures == 0 else "EQUIPMENT FAILED: %d" % failures)
	quit(1 if failures else 0)


func give_all() -> void:
	for item: String in Data.ITEMS:
		gs.give(item, 1, true)


func _test_selection() -> void:
	gs.new_game()
	check(Equipment.SLOTS.keys() == ["head", "chest", "hands", "neck", "ring"] and Data.ITEMS.size() == 24 and Data.ITEMS.has("gear_cw_anchor") and Data.ITEMS.has("gear_cw_fan"), "Five slots, existing gear, regional crafting chains and two coastal hand-slot choices")
	check(not Equipment.equip("gear_cloth_hood") and not Equipment.equip("boots") and not Equipment.unequip("head"), "Missing and legacy items cannot be equipped in a new slot")
	for item: String in Data.ITEMS:
		var info := Items.info(item)
		var expected_sheet := "rf_gear" if item in ["gear_rf_keepsake","gear_rf_cord"] else "items_equipment"
		if item in ["gear_ra_grip","gear_ra_compass"]: expected_sheet="ra_items"
		if item.begins_with("gear_pg_"): expected_sheet="pg_gear"
		if item.begins_with("gear_cw_"): expected_sheet="cw_items"
		check(info.get("slot", "") == Equipment.slot_of(item) and info.get("max", 0) == 1 and info.get("sheet", "") == expected_sheet, "Registered gear data: " + item)
		check(not Equipment.stats_text(item).is_empty(), "Each item exposes its actual effect: " + item)
	give_all()
	check(gs.equipment.is_empty() and Equipment.bonus("stamina_max") == 0 and gs.attack_cooldown_multiplier() == 1.0, "Ownership never equips or grants effects automatically")
	check(Equipment.owned("head") == ["gear_cloth_hood", "gear_bronze_helm"] and Equipment.owned("unknown").is_empty(), "Owned gear is ordered and limited to the requested slot")
	var inventory: Dictionary = gs.inventory.duplicate()
	changes = 0
	check(Equipment.equip("gear_novice_gloves") and is_equal_approx(gs.attack_cooldown_multiplier(), 0.92), "Choosing novice gloves applies their sword cooldown effect")
	check(Equipment.equip("gear_smith_gloves") and is_equal_approx(gs.attack_cooldown_multiplier(), 0.84), "Replacement applies only the stronger gloves, never both")
	check(not Equipment.equip("gear_smith_gloves") and changes == 2, "Choosing the same item again changes nothing")
	check(gs.inventory == inventory, "Choosing and replacing gear never consumes an item")
	check(Equipment.unequip("hands") and gs.attack_cooldown_multiplier() == 1.0 and gs.inventory == inventory, "Removing gear leaves the owned item and removes its effect")
	Equipment.equip("gear_smith_gloves")
	gs.take("gear_smith_gloves")
	check(Equipment.equipped("hands") == "" and not gs.equipment.has("hands") and gs.attack_cooldown_multiplier() == 1.0, "Taking away a worn item removes its effect immediately")
	gs.equipment = {"head": "gear_novice_gloves", "chest": 3, "hands": "not_real", "ring": {"bonuses": {"magnet_range": INF}}, "extra": "gear_copper_ring"}
	check(Equipment.bonus("attack_cooldown_reduction") == 0 and Equipment.bonus("magnet_range") == 0 and Equipment.bonus("unknown") == 0, "Malformed selections and injected bonuses grant no effects")
	Equipment.reconcile()
	check(gs.equipment.is_empty(), "Reconciliation removes wrong slots and malformed selection values")
	check(Equipment.normalize_owned({"gear_cloth_hood": INF, "gear_bronze_helm": "99", "gear_copper_ring": -4, "gear_crystal_ring": 999999}) == {"gear_crystal_ring": 1}, "Gear ownership normalization rejects invalid counts and caps valid ownership")


func _test_stamina() -> void:
	gs.new_game()
	give_all()
	gs.movement.stamina = 40.0
	Equipment.equip("gear_cloth_hood")
	check(gs.movement.capacity() == 115.0 and gs.movement.stamina == 40.0, "Wearing a cap raises capacity without granting free energy")
	Equipment.equip("gear_bronze_helm")
	check(gs.movement.capacity() == 130.0 and gs.movement.stamina == 40.0, "A helmet replaces the cap's bonus without refilling stamina")
	gs.movement.stamina = 125.0
	Equipment.equip("gear_cloth_hood")
	check(gs.movement.stamina == 115.0, "Choosing a smaller capacity clamps excess stamina")
	Equipment.unequip("head")
	check(gs.movement.stamina == 100.0 and gs.movement.capacity() == 100.0, "Unequipping restores the base capacity and clamps current energy")
	Equipment.equip("gear_bronze_helm")
	check(gs.movement.stamina == 100.0, "Repeated equip/unequip cannot refill the extra capacity")
	Equipment.equip("gear_copper_amulet")
	check(is_equal_approx(gs.movement.regen_rate(), 28.75), "Copper amulet increases actual regeneration by fifteen percent")
	Equipment.equip("gear_crystal_amulet")
	check(is_equal_approx(gs.movement.regen_rate(), 32.5), "Crystal amulet replaces the lower tier at thirty percent")
	gs.movement.reset()
	gs.movement.advance(6.5, true)
	check(gs.movement.stamina == 0.0 and gs.movement.exhausted and gs.movement.recovery_threshold() == 32.5, "Larger capacity supports actual extra sprint time and a proportional recovery threshold")
	gs.movement.advance(0.8, false)
	check(gs.movement.stamina == 0.0, "Gear does not bypass the existing recovery delay")
	gs.movement.advance(0.5, false)
	check(gs.movement.stamina == 16.25 and gs.movement.exhausted, "Actual recovery uses the equipped amulet rate")
	gs.movement.advance(0.5, false)
	check(gs.movement.stamina == 32.5 and gs.movement.can_sprint(), "Exhaustion ends at one quarter of equipped capacity")
	gs.movement.stamina = 110.0
	gs.give("prof_tonic", 2, true)
	check(Professions.use_item("prof_tonic") and gs.movement.stamina == 130.0 and gs.count("prof_tonic") == 1, "Tonic fills the expanded capacity instead of treating one hundred as full")
	check(not Professions.use_item("prof_tonic") and gs.count("prof_tonic") == 1, "Tonic is still preserved when the expanded bar is full")
	gs.take("gear_bronze_helm")
	check(gs.movement.capacity() == 100.0 and gs.movement.stamina == 100.0, "Removing an owned worn helmet clamps stamina immediately")
	gs.movement.stamina = INF
	gs.movement.clamp_capacity()
	check(gs.movement.stamina == 0.0, "Invalid transient stamina never creates an infinite reserve")


func _test_armor() -> void:
	gs.new_game()
	give_all()
	var max_hp: int = gs.max_hp()
	var hp: int = gs.hp
	Equipment.equip("gear_leather_armor")
	check(gs.hp == hp and gs.max_hp() == max_hp and gs.damage_after_armor(3) == 2, "Armor reduces heavy damage without changing hearts")
	gs.hurt(3)
	check(gs.hp == hp - 2, "Actual damage applies leather armor exactly once")
	hp = gs.hp
	Equipment.equip("gear_iron_armor")
	check(gs.hp == hp and gs.max_hp() == max_hp and gs.damage_after_armor(4) == 2 and gs.damage_after_armor(1) == 1 and gs.damage_after_armor(2) == 1, "Stronger armor replaces weaker protection but never makes a positive hit harmless")
	gs.hurt(0)
	gs.hurt(-10)
	check(gs.hp == hp and gs.damage_after_armor(0) == 0 and gs.damage_after_armor(-5) == 0, "Nonpositive damage neither hurts nor grants hearts")
	gs.hurt(4)
	check(gs.hp == hp - 2, "Iron armor protects against an actual heavy hit")
	hp = gs.hp
	Equipment.unequip("chest")
	check(gs.hp == hp and gs.max_hp() == max_hp and gs.damage_after_armor(3) == 3, "Removing armor keeps current hearts and restores incoming damage")


func _test_magnet() -> void:
	gs.new_game()
	gs.give("gear_copper_ring", 1, true)
	gs.give("gear_crystal_ring", 1, true)
	var world := FakeWorld.new()
	root.add_child(world)
	var player := Node2D.new()
	world.add_child(player)
	var pickup: Node2D = load("res://scripts/entities/pickup.gd").new()
	pickup.player = player
	pickup.world = world
	pickup.item = "heart" # full hearts attract without being consumed
	pickup.age = 1.0
	pickup.position = Vector2(64, 0)
	world.add_child(pickup)
	pickup.set_process(false)
	pickup._process(0.05)
	check(pickup.position.x == 64.0 and pickup.magnet_range() == 54.0, "Owning rings alone leaves magnetic range unchanged")
	Equipment.equip("gear_copper_ring")
	pickup._process(0.05)
	check(pickup.position.x < 64.0 and pickup.magnet_range() == 66.0, "Copper ring really attracts items beyond the ordinary range")
	pickup.position.x = 74.0
	pickup._process(0.05)
	check(pickup.position.x == 74.0, "Copper ring cannot reach the stronger ring's range")
	Equipment.equip("gear_crystal_ring")
	pickup._process(0.05)
	check(pickup.position.x < 74.0 and pickup.magnet_range() == 78.0 and not pickup.collected, "Crystal ring extends attraction to seventy-eight pixels without consuming a full heart")
	gs.take("gear_crystal_ring")
	pickup.position.x = 64.0
	pickup._process(0.05)
	check(pickup.position.x == 64.0 and pickup.magnet_range() == 54.0, "Removed ring stops affecting existing ground items immediately")
	world.queue_free()
	await process_frame


func _test_acquisition() -> void:
	gs.new_game()
	gs.coins = 500
	var shop: Node = load("res://scripts/ui/shop_ui.gd").new()
	root.add_child(shop)
	shop.open("tobias")
	var bought := 0
	var index := 0
	for entry: Dictionary in Shops.info("tobias")["items"]:
		if Equipment.slot_of(entry["item"]) != "":
			var before: int = gs.coins
			shop._buy(entry, index)
			check(gs.count(entry["item"]) == 1 and gs.coins == before - entry["price"] and gs.equipment.is_empty(), "Shop purchase creates owned but unworn gear: " + entry["item"])
			shop._buy(entry, index)
			check(gs.count(entry["item"]) == 1 and gs.coins == before - entry["price"], "A duplicate gear purchase never charges again: " + entry["item"])
			bought += 1
		index += 1
	check(bought == 5, "All five entry-tier items are obtainable at Tobias")
	shop.close()
	shop.queue_free()
	await process_frame
	for recipe_id: String in ["bronze_helm", "iron_armor", "smith_gloves", "crystal_amulet", "crystal_ring"]:
		gs.new_game()
		var recipe: Dictionary = Recipes.RECIPES[recipe_id]
		for item: String in recipe["inputs"]:
			check(item != "shard" and not Items.CRYSTALS.has(item), "Gear crafting preserves scarce story materials: " + recipe_id)
			gs.give(item, recipe["inputs"][item], true)
		var before: Dictionary = gs.inventory.duplicate()
		gs.map_id = recipe["station"]
		check(not Professions.craft(recipe_id) and gs.inventory == before, "Skill level is required before crafting: " + recipe_id)
		Professions.add_xp(recipe["skill"], Professions.threshold(recipe["level"]))
		gs.map_id = "village"
		check(not Professions.craft(recipe_id) and gs.inventory == before, "Correct workshop is required: " + recipe_id)
		gs.map_id = recipe["station"]
		check(Professions.craft(recipe_id) and gs.count(recipe["output"]) == 1 and gs.equipment.is_empty(), "Crafting creates real owned but unworn gear: " + recipe_id)
		for item: String in recipe["inputs"]:
			check(gs.count(item) == 0, "Crafting consumes the precise materials for: " + recipe_id)
		before = gs.inventory.duplicate()
		check(not Professions.craft(recipe_id) and gs.inventory == before, "An owned advanced item cannot be crafted twice: " + recipe_id)
		check(Equipment.equip(recipe["output"]), "Crafted item can actually be equipped: " + recipe_id)


func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _test_save() -> void:
	gs.new_game()
	give_all()
	for item: String in ["gear_bronze_helm", "gear_iron_armor", "gear_smith_gloves", "gear_crystal_amulet", "gear_crystal_ring"]:
		Equipment.equip(item)
	var selected: Dictionary = gs.equipment.duplicate()
	check(gs.save_game(Vector2.ZERO), "Equipment saves through the existing save path")
	gs.equipment = {}
	gs.inventory = {}
	check(gs.load_game() and gs.equipment == selected and gs.inventory.size() == Data.ITEMS.size() and gs.movement.capacity() == 130.0 and gs.attack_cooldown_multiplier() == 0.84, "Saved choices and their effects survive a full reload")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH))
	data.erase("equipment")
	_write_save(data)
	check(gs.load_game() and gs.equipment.is_empty() and Equipment.bonus("armor") == 0 and gs.inventory.size() == Data.ITEMS.size(), "An old save starts unequipped without losing owned items")
	data["equipment"] = {"head": "gear_smith_gloves", "hands": [], "chest": "unknown", "ring": {"bonuses": {"magnet_range": 999}}, "neck": "gear_crystal_amulet", "unknown_slot": "gear_bronze_helm"}
	data["inventory"].erase("gear_crystal_amulet")
	data["inventory"]["gear_cloth_hood"] = "999"
	data["inventory"]["gear_bronze_helm"] = 999999
	_write_save(data)
	check(gs.load_game() and gs.equipment.is_empty() and Equipment.bonus("magnet_range") == 0 and gs.count("gear_cloth_hood") == 0 and gs.count("gear_bronze_helm") == 1, "Malformed saves cannot equip wrong, missing or unknown items, inject bonuses or duplicate gear")
	for raw: Variant in [null, "head", ["gear_bronze_helm"], true, 14]:
		data["equipment"] = raw
		_write_save(data)
		check(gs.load_game() and gs.equipment.is_empty(), "Invalid equipment container defaults to empty: " + str(raw))
	gs.new_game()
	check(gs.equipment.is_empty() and gs.inventory.is_empty() and gs.movement.capacity() == 100.0, "A normal new game resets gear ownership and choices")


func _test_new_game_plus() -> void:
	if FileAccess.file_exists(gs.NG_META_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.NG_META_PATH))
	gs.new_game()
	give_all()
	Equipment.equip("gear_cloth_hood")
	Equipment.equip("gear_smith_gloves")
	Equipment.equip("gear_crystal_ring")
	var selected: Dictionary = gs.equipment.duplicate()
	gs.set_flag("game_completed")
	gs.record_completion()
	check(gs.new_game_plus() and gs.equipment == selected and gs.inventory.size() == Data.ITEMS.size() and gs.movement.capacity() == 115.0, "New Game+ retains all owned alternatives and the exact chosen equipment")
	for item: String in Data.ITEMS:
		check(gs.count(item) == 1, "New Game+ carries one copy: " + item)
	Equipment.unequip("head")
	gs.set_flag("game_completed")
	gs.record_completion()
	gs.new_game_plus()
	check(Equipment.equipped("head") == "" and gs.count("gear_cloth_hood") == 1 and gs.count("gear_bronze_helm") == 1 and gs.inventory.size() == Data.ITEMS.size(), "Intentional unequipping survives repeated rounds without losing or duplicating alternatives")
	gs.save_meta({"completed": true, "rounds": 1, "weapon": "wood", "hearts": 0, "boots": false})
	check(gs.new_game_plus() and gs.equipment.is_empty() and gs.inventory.is_empty(), "Old metadata without equipment is still supported")
	var config := ConfigFile.new()
	config.set_value("ng", "completed", true)
	config.set_value("ng", "gear_items", {"gear_bronze_helm": INF, "gear_iron_armor": "bad", "gear_crystal_ring": 900, "unknown": 1})
	config.set_value("ng", "equipment", {"head": "gear_bronze_helm", "ring": "gear_crystal_ring"})
	config.save(gs.NG_META_PATH)
	check(gs.new_game_plus() and gs.inventory == {"gear_crystal_ring": 1} and gs.equipment == {"ring": "gear_crystal_ring"} and gs.movement.capacity() == 100.0, "Corrupt metadata is filtered before preserving ownership and effects")
