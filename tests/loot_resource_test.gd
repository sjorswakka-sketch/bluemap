extends SceneTree
## Magnet behavior and harvest transactions, without touching a real save.

const Professions := preload("res://scripts/core/professions.gd")
const Items := preload("res://scripts/data/items.gd")

class FakePlayer extends Node2D:
	var target: Node2D
	var work_active := false
	var animation := ""
	func start_work_animation(kind: String, _duration: float, _target_position: Vector2) -> void:
		work_active = true
		animation = kind
	func cancel_work_animation() -> void:
		work_active = false
	func is_working() -> bool:
		return work_active

class FakeWorld extends Node2D:
	func burst(_pos: Vector2, _color: Color, _amount: int) -> void:
		pass
	func damage_number(_pos: Vector2, _label: String, _color: Color) -> void:
		pass
	func shake(_amount: float) -> void:
		pass

var failures := 0
var gs: Node
var world: FakeWorld
var player: FakePlayer
var pickup_script: Script
var resource_script: Script


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("  ok   " if ok else "  FAIL ", label)
	if not ok:
		failures += 1


func make_pickup(item: String, flag_name := "") -> Node2D:
	var node: Node2D = pickup_script.new()
	node.item = item
	node.unique_key = flag_name
	node.world = world
	node.player = player
	node.position = Vector2(50, 0)
	node.age = 1.0
	world.add_child(node)
	node.set_process(false)
	return node


func make_resource(kind: String, id: String) -> Node2D:
	var node: Node2D = resource_script.new()
	node.world = world
	node.obj = {"kind": kind, "id": id}
	node.position = player.position + Vector2(0, -24)
	world.add_child(node)
	node.player = player
	node.set_process(false)
	return node


func restart(node: Node) -> void:
	node.hint_wait = 0.0
	player.work_active = false
	node.interact()


func _run() -> void:
	gs = root.get_node("GameState")
	# Entity scripts use autoloads and must load after the SceneTree has them.
	pickup_script = load("res://scripts/entities/pickup.gd")
	resource_script = load("res://scripts/entities/resource_node.gd")
	gs.new_game()
	gs.in_game = false
	world = FakeWorld.new()
	root.add_child(world)
	player = FakePlayer.new()
	world.add_child(player)
	player.add_to_group("player")
	var kinds := {"coin": true, "heart": true}
	for item: String in Items.ITEMS:
		kinds[item] = true
	var all_magnetic := true
	for item: String in kinds:
		var pickup := make_pickup(item)
		pickup._process(0.1)
		all_magnetic = all_magnetic and pickup.position.x < 50.0 and not pickup.is_queued_for_deletion()
		pickup.free()
	check(all_magnetic, "Every registered ground item, coin and full-health heart is magnetic")
	var coin := make_pickup("coin")
	var coins_before: int = gs.coins
	var recursive := func() -> void: coin._collect()
	gs.items_changed.connect(recursive)
	coin._collect()
	coin._collect()
	gs.items_changed.disconnect(recursive)
	check(gs.coins == coins_before + 1 and coin.is_queued_for_deletion(), "Synchronous inventory listeners and repeated pickup cannot duplicate coins")
	await process_frame

	var arrow := make_pickup("arrow", "loot_test_arrow")
	gs.give("arrow", int(Items.info("arrow")["max"]), true)
	arrow._process(0.3)
	check(arrow.position == player.position and not arrow.is_queued_for_deletion() and not gs.flag("loot_test_arrow"), "Full stacks attract without losing the pickup or setting its unique flag")
	gs.take("arrow", 1)
	arrow._process(0.01)
	check(arrow.is_queued_for_deletion() and gs.flag("loot_test_arrow") and gs.room("arrow") == 0, "A waiting item collects exactly when inventory has space")
	await process_frame

	var heart := make_pickup("heart")
	gs.hp = gs.max_hp()
	heart._process(0.3)
	check(heart.position == player.position and not heart.is_queued_for_deletion(), "Full-health hearts follow and remain available")
	gs.hp -= 1
	heart._process(0.01)
	check(gs.hp == gs.max_hp() and heart.is_queued_for_deletion(), "Following heart heals once after damage")
	await process_frame

	var material := make_pickup("prof_herb", "loot_test_material")
	gs.transitioning = true
	material._process(0.2)
	check(material.position.x == 50.0 and not gs.flag("loot_test_material"), "Magnet and collection stop during transitions")
	gs.transitioning = false
	material._process(0.3)
	check(gs.count("prof_herb") == 1 and gs.flag("loot_test_material"), "Profession materials use the same magnetic collection path")
	await process_frame

	gs.new_game()
	gs.in_game = false
	var ore := make_resource("copper", "forest:copper_west")
	restart(ore)
	check(not ore.harvesting and not player.work_active and gs.count("prof_copper_ore") == 0, "Missing pickaxe rejects mining before animation")
	gs.give("prof_axe", 1, true)
	restart(ore)
	check(not ore.harvesting, "An axe does not satisfy a mining requirement")
	gs.give("prof_pickaxe", 1, true)
	restart(ore)
	check(ore.harvesting and player.animation == "mining" and gs.count("prof_copper_ore") == 0 and Professions.remaining(ore.resource_id) == 0.0, "Valid mining starts animation without early rewards or cooldown")
	ore.advance_harvest(0.4)
	var progress: float = ore.harvest_time
	ore.interact()
	check(is_equal_approx(ore.harvest_time, progress), "Repeated interaction cannot restart or duplicate an ongoing harvest")
	var other := make_resource("branches", "village:twigs_west")
	other.interact()
	check(not other.harvesting, "A second resource cannot steal an active work animation")
	other.free()
	gs.take("prof_pickaxe")
	ore.advance_harvest(2.0)
	check(not ore.harvesting and gs.count("prof_copper_ore") == 0 and Professions.xp("mining") == 0 and Professions.remaining(ore.resource_id) == 0.0, "Tool removed mid-animation cancels without materials, XP or cooldown")
	gs.give("prof_pickaxe", 1, true)
	restart(ore)
	player.position += Vector2(5, 0)
	ore.advance_harvest(2.0)
	check(not ore.harvesting and gs.count("prof_copper_ore") == 0, "Moving away cancels harvesting without a reward")
	player.position -= Vector2(5, 0)
	restart(ore)
	paused = true
	check(not ore.harvesting and not player.work_active, "Opening a paused menu immediately cancels the work")
	paused = false
	restart(ore)
	player.cancel_work_animation()
	ore.advance_harvest(2.0)
	check(not ore.harvesting and gs.count("prof_copper_ore") == 0, "Attack, roll or damage cancellation prevents the final award")
	restart(ore)
	gs.map_id = "cave"
	ore.advance_harvest(2.0)
	check(not ore.harvesting and gs.count("prof_copper_ore") == 0, "A map change cancels the old harvest")
	gs.map_id = "village"
	restart(ore)
	ore.advance_harvest(2.0)
	ore.advance_harvest(2.0)
	check(gs.count("prof_copper_ore") == 2 and Professions.xp("mining") == 10 and Professions.remaining(ore.resource_id) > 175, "Completed mining commits materials, XP and cooldown exactly once")
	restart(ore)
	check(not ore.harvesting, "A depleted node cannot start a new work action")
	ore.free()

	var iron := make_resource("iron", "cave:iron_entry")
	gs.give("prof_copper_pickaxe", 1, true)
	restart(iron)
	check(not iron.harvesting, "Advanced pickaxe still requires mining level two")
	Professions.add_xp("mining", 30)
	restart(iron)
	check(iron.harvesting, "Correct advanced tool and skill allow iron mining")
	gs.professions["xp"]["mining"] = 0
	iron.advance_harvest(2.0)
	check(not iron.harvesting and gs.count("prof_iron_ore") == 0 and Professions.remaining(iron.resource_id) == 0.0, "Skill requirement is rechecked before committing")
	iron.free()

	var stump := make_resource("stump", "forest:birch_west")
	restart(stump)
	check(stump.harvesting and player.animation == "woodcutting", "Woodcutting uses its own animation with the equipped axe")
	stump.advance_harvest(2.0)
	check(gs.count("prof_log") == 2, "Completed woodcutting gives the normal axe yield")
	stump.free()
	var herb := make_resource("herbs", "village:herbs_south")
	restart(herb)
	check(herb.harvesting and player.animation == "foraging", "Foraging requires no tool and uses a gathering animation")
	herb.advance_harvest(1.0)
	check(gs.count("prof_herb") == 2, "Completed foraging gives its materials")
	herb.free()

	world.free()
	print("LOOT RESOURCE OK" if failures == 0 else "LOOT RESOURCE FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
