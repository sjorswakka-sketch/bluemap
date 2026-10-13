extends SceneTree
## Test van de doorgangen-polis: elke doorgang tussen twee buitengebieden heeft een wegwijzer in de
## buurt die het doelgebied noemt, en elke doorgang heeft een zichtbare gloed (portal.gd).
##
##   sh tools/run_tests.sh /pad/naar/godot      (alle tests), of alleen deze:
##   XDG_DATA_HOME=.testdata godot --headless --fixed-fps 60 --path . -s tests/doorgangen_test.gd
##
## Zonder XDG_DATA_HOME schrijft de test in de echte opslagmap van het spel (en overschrijft hij je opgeslagen spel).

const Maps := preload("res://scripts/maps/registry.gd")

## Doorgangen tussen gebouwen hebben al een deur of poort in het plaatje; alleen doorgangen tussen
## twee BUITENgebieden vragen een wegwijzer.
const MAX_SIGN_DISTANCE := 4 # tegels (Chebyshev)

var failures := 0
var gs: Node
var world: Node2D


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	gs = root.get_node("GameState")
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await frames(3)

	test_signs()
	await test_glow()

	world.queue_free()
	await frames(2)
	print("DOORGANGEN OK" if failures == 0 else "DOORGANGEN FAILED: %d" % failures)
	quit(1 if failures else 0)


# --- Deel 1: wegwijzers bij elke doorgang tussen buitengebieden ---------------------------------------------

func test_signs() -> void:
	print("Wegwijzers bij doorgangen")
	for map_id: String in Maps.MAPS:
		var def: Dictionary = Maps.get_map(map_id)
		if not def.get("outdoor", false):
			continue
		for obj: Dictionary in def["objects"]:
			if obj["type"] != "portal" or not Maps.MAPS.has(obj["to"]):
				continue
			var target: Dictionary = Maps.get_map(obj["to"])
			if not target.get("outdoor", false):
				continue # een gebouw heeft al een deur in het plaatje
			var px := int(obj["pos"][0])
			var py := int(obj["pos"][1])
			var found := ""
			for other: Dictionary in def["objects"]:
				if other["type"] != "sign":
					continue
				var distance := maxi(absi(int(other["pos"][0]) - px), absi(int(other["pos"][1]) - py))
				if distance <= MAX_SIGN_DISTANCE and String(other["lines"][0]).contains(target["name"]):
					found = String(other["lines"][0])
			check(found != "", "%s -> %s heeft een wegwijzer (%s)" % [def["name"], target["name"], found])


# --- Deel 2: de gloed op de doorgangen -----------------------------------------------------------------------

func test_glow() -> void:
	print("De gloed op de doorgangen")
	gs.new_game()
	gs.in_game = true
	world.load_map("forest", "start")
	await frames(5)
	# De doorgangen herken je aan hun script (rechtstreeks preloaden van entity-scripts mag niet in tests).
	var portals: Array = []
	for child: Node in world.entities.get_children():
		if str(child.get_script().resource_path).ends_with("portal.gd"):
			portals.append(child)
	check(portals.size() >= 4, "het Fluisterbos heeft vier doorgangen (%d)" % portals.size())
	var positions_ok := true
	for portal: Node in portals:
		positions_ok = positions_ok and portal.position == portal.rect.position and portal.rect.size.x > 0
	check(positions_ok, "elke doorgang staat op zijn eigen plek (voor de y-sortering van de gloed)")
