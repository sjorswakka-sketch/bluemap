extends Node2D
## Eenzelfde interactietoets, verschillende spelregels per apparaat.
const Living := preload("res://scripts/core/living_world.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
var world: Node2D
var obj: Dictionary = {}
var key := ""
var kind := ""
var id := ""
var time := 0.0
var active := false
var elapsed := 0.0
var warning := 0.0
var foes: Array[Node2D] = []
var light: PointLight2D
var encounter_spawned := false

func _ready() -> void:
	kind = obj.get("kind", "")
	id = obj.get("id", "")
	add_to_group("living_objects")
	add_to_group("interactable")
	if kind in ["forge", "brazier", "sluice", "bridge", "board"]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var collider := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(40 if kind == "forge" else 24, 12)
		collider.shape = box
		collider.position = Vector2(0, 6)
		body.add_child(collider)
		add_child(body)
	light = PointLight2D.new()
	light.texture = Art.light_texture()
	light.texture_scale = 0.9
	light.color = Color(1, 0.65, 0.25) if kind == "brazier" else Color(0.35, 0.85, 1)
	add_child(light)

func label() -> String:
	match kind:
		"mirror": return tr("Prismaspiegel")
		"core": return tr("Prismakern")
		"forge": return tr("Prismabank")
		"rune": return tr("Verborgen bosrune")
		"brazier": return tr("Vuurkorf")
		"sluice": return (tr("Westelijke sluis") if id=="lw_sluice_west" else tr("Oostelijke sluis"))+" · "+(tr("open") if GameState.flag(id) else tr("dicht"))
		"bridge": return tr("De oude lier")
	return tr("Herstelbord")

func interact() -> void:
	if GameState.input_locked() or active:
		return
	match kind:
		"board":
			GameState.start_quest("prisma_herstel")
			GameState.say(label(), [tr("De drie spiegels horen één lichtpad te vormen: oost, zuid, west. Draai ze naar hun ontvangers en activeer daarna de kern."), tr("Greta zoekt deze kern voor haar oude werkplaats. Aardingspoeder uit de bibliotheek biedt een rustige oplossing; de bewakers verslaan kan ook.")])
		"mirror":
			GameState.start_quest("prisma_herstel")
			if GameState.flag("lw_mine"):
				return
			Living.turn(id)
			Sound.play("door", -9.0, 1.2)
			GameState.set_flag("lw_beams", Living.beams_ready())
			GameState.save_requested.emit()
		"core":
			GameState.start_quest("prisma_herstel")
			if GameState.flag("lw_mine"):
				GameState.toast.emit(tr("De kern is stabiel. Greta wacht bij haar prismabank."))
			elif not Living.beams_ready():
				GameState.toast.emit(tr("Volg het lichtpad: richt eerst alle drie de spiegels op de ontvangers."))
			else:
				GameState.set_flag("lw_beams")
				Living.open(self, obj["talk"])
		"forge":
			if not GameState.flag("lw_mine"):
				GameState.start_quest("prisma_herstel")
				GameState.say("Greta", [tr("Mijn prismabank mist zijn kern. Zoek in de Prismamijn, via de Echo-grot. Een ijzeren zwaard opent die zijroute.")])
			else:
				if Living.mark("lw_workshop"):
					GameState.start_quest("prisma_herstel")
					GameState.finish_quest("prisma_herstel")
					GameState.start_quest("lichtwerk")
					world.burst(global_position, Color(0.5, 0.9, 1), 20)
					GameState.save_requested.emit()
				Living.open(self, obj["talk"])
		"rune":
			_rune()
		"brazier":
			GameState.start_quest("warmte")
			if GameState.flag(id):
				GameState.toast.emit(tr("Dit huis blijft warm. De bewoners zijn terug."))
			elif GameState.flag(id + "_fuel"):
				begin()
			else:
				Living.open(self, obj["talk"])
		"sluice":
			GameState.start_quest("wilgentwijgen")
			if GameState.flag("lw_drained"):
				GameState.toast.emit(tr("De waterstand is veilig. De sluizen blijven zo staan."))
				return
			GameState.set_flag(id + "_seen")
			GameState.set_flag(id, not GameState.flag(id))
			if GameState.flag("lw_sluice_west_seen") and GameState.flag("lw_sluice_east_seen") and GameState.flag("lw_sluice_west") and not GameState.flag("lw_sluice_east"):
				Living.mark("lw_drained")
				GameState.toast.emit(tr("Het water zakt. De oostelijke oever en het Rietarchief vallen droog."))
			else:
				GameState.toast.emit(tr("Sluis: open") if GameState.flag(id) else tr("Sluis: dicht"))
			Sound.play("door", -5.0, 0.7)
			GameState.save_requested.emit()
		"bridge":
			GameState.start_quest("wilgentwijgen")
			if GameState.flag("lw_bridge"):
				GameState.toast.emit(tr("De oversteek is hersteld. Vertel het aan Mees in het oostelijke rietland."))
			else:
				Living.open(self, obj["talk"])

func choose(action: String) -> void:
	if active:
		return
	match action:
		"core_fight", "core_powder":
			if kind != "core" or GameState.flag("lw_mine") or not Living.beams_ready(): return
			if action == "core_powder":
				if not pay("lw_powder", 1): return
				finish()
			else: begin()
		"buy_lantern":
			if kind != "forge" or not GameState.flag("lw_workshop") or GameState.coins < 40 or GameState.count("lw_lens") < 1 or GameState.count("lw_lantern") > 0: return
			GameState.take("lw_lens")
			GameState.add_coins(-40)
			GameState.give("lw_lantern", 1, true)
			Living.lantern_made()
		"bridge_kit", "bridge_resin", "bridge_fight":
			if kind != "bridge" or GameState.flag("lw_bridge"): return
			if not GameState.flag("lw_drained"):
				GameState.toast.emit(tr("Eerst de waterdruk verlagen: west open, oost dicht. Je materialen blijven in je tas."))
				return
			if action == "bridge_fight": begin()
			elif pay("lw_bridge_kit" if action == "bridge_kit" else "lw_resin", 1): finish()
		"heat_wood", "heat_food", "heat_prism":
			if kind != "brazier" or GameState.flag(id): return
			if not GameState.flag(id + "_fuel"):
				if action == "heat_prism" and not GameState.flag("lw_workshop"): return
				if action == "heat_wood" and not pay("prof_branch", 3): return
				if action == "heat_food" and not pay("prof_winter_gloed", 1): return
				Living.mark(id + "_fuel")
			begin()

func pay(item: String, amount: int) -> bool:
	if GameState.count(item) < amount: return false
	GameState.take(item, amount)
	return true

func _rune() -> void:
	if GameState.flag("lw_forest"):
		GameState.toast.emit(tr("Het licht stroomt weer door de wortels."))
		return
	if GameState.count("lw_lantern") == 0:
		GameState.say(label(), [tr("Onder de mist zitten tekens. Een prismalantaarn uit Greta’s herstelde werkplaats kan ze onthullen.")])
		return
	GameState.start_quest("mistsporen")
	if not GameState.flag("lw_clues"):
		GameState.set_flag(id + "_read")
		var clue := tr("Eerst drinkt het WATER het licht. Zoek de andere tekens bij de wortels en de oostelijke steen.")
		if id == "lw_root": clue = tr("Dan draagt de WORTEL het licht. Zoek de andere tekens bij de vijver en de oostelijke steen.")
		if id == "lw_star": clue = tr("Ten slotte wijst de STER naar de tuin. De volgorde is water, wortel, ster.")
		GameState.say(label(), [clue])
		if GameState.flag("lw_water_read") and GameState.flag("lw_root_read") and GameState.flag("lw_star_read"):
			Living.mark("lw_clues")
		return
	var expected := "lw_star" if GameState.flag("lw_sequence_2") else "lw_root" if GameState.flag("lw_sequence_1") else "lw_water"
	if id != expected:
		GameState.set_flag("lw_sequence_1", false)
		GameState.set_flag("lw_sequence_2", false)
		GameState.toast.emit(tr("De lichtkring dooft. Probeer opnieuw: water, wortel, ster."))
	elif id == "lw_water": Living.mark("lw_sequence_1")
	elif id == "lw_root": Living.mark("lw_sequence_2")
	elif Living.mark("lw_forest"):
		GameState.give("gear_scout_coat", 1, true)
		GameState.finish_quest("mistsporen")
		GameState.toast.emit(tr("De mist wijkt! De Dauwtuin in het zuidoosten is open. Je ontving een verkennersjas."))
		world.ring(global_position, 100, Color(0.4, 1, 0.8))
		Sound.play("quest")
	GameState.save_requested.emit()

func spawn_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if kind == "core":
		result.assign([Vector2(27.5,7.5)*32, Vector2(35.5,8.5)*32])
	elif kind == "bridge":
		result.assign([Vector2(14.5,22.5)*32, Vector2(18.5,23.5)*32])
	else:
		for offset in [Vector2(-3,3),Vector2(3,3)]:
			result.append(global_position + offset * 32)
	return result

func begin() -> void:
	if active: return
	active = true
	elapsed = 0.0
	warning = 2.0
	encounter_spawned = false
	GameState.toast.emit(tr("Een beweging in de verte… let op de gemarkeerde plekken."))

func finish() -> void:
	active = false
	match kind:
		"core":
			if not Living.mark("lw_mine"): return
			GameState.give("lw_lens", 1, true)
			GameState.toast.emit(tr("De mijn is stabiel. Neem de lens naar de prismabank in Greta’s smederij."))
		"bridge":
			if not Living.mark("lw_bridge"): return
			GameState.toast.emit(tr("De brug ligt weer! Handelaren gebruiken de korte route. Mees wacht op het goede nieuws."))
		"brazier":
			if not Living.mark(id): return
			if GameState.flag("lw_heat_west") and GameState.flag("lw_heat_east"):
				Living.mark("lw_heat")
			GameState.toast.emit(tr("Het huis is warm. De bewoners keren terug."))
	world.ring(global_position, 80, Color(0.55, 1, 0.7))
	Sound.play("quest", -4)
	GameState.save_requested.emit()

func _process(delta: float) -> void:
	time += delta
	light.energy = (0.6 + 0.12 * sin(time * 3)) if kind == "brazier" and (active or GameState.flag(id)) or kind == "forge" and GameState.flag("lw_workshop") or kind == "rune" and GameState.count("lw_lantern") > 0 else 0.0
	queue_redraw()
	if not active or GameState.input_locked() or GameState.hp <= 0: return
	if not encounter_spawned:
		warning = maxf(warning - delta, 0)
		if warning > 0: return
		for at in spawn_positions():
			if at.distance_to(world.player.global_position) < 64: return
		var types := ["lw_warden", "lw_singer"] if kind == "core" else ["lw_warden", "lw_stalker"] if kind == "brazier" else ["lw_stalker", "lw_singer"]
		var positions := spawn_positions()
		for i in types.size():
			var foe: Node2D = world.spawn_enemy(types[i], positions[i])
			if kind == "brazier" and i == 0: foe.defend_target = self
			foes.append(foe)
		encounter_spawned = true
	for i in range(foes.size() - 1, -1, -1):
		if not is_instance_valid(foes[i]) or foes[i].dead: foes.remove_at(i)
	if kind == "brazier":
		var clear: bool = world.player.global_position.distance_to(global_position) < 180
		for foe in foes:
			if foe.global_position.distance_to(global_position) < 52: clear = false
		if clear: elapsed = minf(20, elapsed + delta)
		if elapsed < 20: return
	if foes.is_empty(): finish()

func _draw() -> void:
	var gold := Color(1, 0.75, 0.3)
	var cyan := Color(0.4, 0.9, 1)
	DrawUtil.ellipse(self, Vector2(0, 9), Vector2(15, 5), Color(0, 0, 0, 0.3))
	match kind:
		"mirror":
			var direction := Vector2.from_angle(Living.direction(id) * PI / 2)
			var receiver := Vector2(obj["receiver"][0], obj["receiver"][1]) * 32 + Vector2(16, 16) - global_position
			draw_arc(receiver, 9, 0, TAU, 20, gold, 2)
			draw_line(Vector2.ZERO, direction * receiver.length(), Color(cyan, 0.7), 3)
			draw_rect(Rect2(-12, -12, 24, 24), Color(0.18, 0.23, 0.35))
			draw_line(Vector2(-9, 8).rotated(direction.angle()), Vector2(9, -8).rotated(direction.angle()), cyan, 5)
			draw_circle(direction * 15, 3, gold)
		"core":
			var lit := Living.beams_ready() or GameState.flag("lw_mine")
			var tint := cyan if lit else Color(0.37, 0.42, 0.58)
			var bob := sin(time * 2) * 3
			DrawUtil.ellipse(self, Vector2(0, 5), Vector2(22, 9), Color(0.22, 0.26, 0.35))
			draw_arc(Vector2(0, -8), 24, time, time + PI * 1.5, 32, Color(tint, 0.65), 2)
			var tip := Vector2(0, -35 + bob)
			var base := Vector2(0, 2 + bob)
			var middle := Vector2(0, -14 + bob)
			draw_colored_polygon(PackedVector2Array([tip, Vector2(13, -14 + bob), base, middle]), tint)
			draw_colored_polygon(PackedVector2Array([tip, middle, base, Vector2(-13, -14 + bob)]), tint.darkened(0.3))
			draw_line(tip, middle, Color(0.8, 1, 1), 2)
			if lit:
				for i in 3:
					draw_circle(Vector2.from_angle(time + i * TAU / 3) * 24 + Vector2(0, -8), 2, gold)
		"brazier":
			draw_rect(Rect2(-13, -3, 26, 13), Color(0.22, 0.28, 0.35))
			if active or GameState.flag(id):
				for i in 3:
					var x := (i - 1) * 7.0
					draw_colored_polygon(PackedVector2Array([Vector2(x-6, 0), Vector2(x+sin(time*6+i)*3, -24-i*3), Vector2(x+6, 0)]), gold if i == 1 else Color(1, 0.35, 0.1))
			if active:
				draw_rect(Rect2(-22, -38, 44, 5), Color(0.1, 0.15, 0.2))
				draw_rect(Rect2(-22, -38, 44 * elapsed / 20, 5), gold)
		"sluice":
			draw_line(Vector2(0, -18), Vector2(0, 12), Color(0.45, 0.3, 0.15), 6)
			draw_arc(Vector2(0, -9), 13, 0, TAU, 20, gold, 3)
			for i in 4:
				var angle: float = i * PI / 2 + (PI / 4 if GameState.flag(id) else 0)
				draw_line(Vector2(0, -9), Vector2(0, -9) + Vector2.from_angle(angle)*12, gold, 2)
		"rune":
			draw_circle(Vector2(0, -5), 14, Color(0.2, 0.28, 0.3))
			if GameState.count("lw_lantern") > 0 or GameState.flag("lw_forest"):
				var tint := Color(0.5, 1, 0.7) if GameState.flag("lw_forest") else cyan
				if id == "lw_water":
					for y in [-8, -2, 4]: draw_polyline(PackedVector2Array([Vector2(-9,y),Vector2(-3,y-3),Vector2(3,y+1),Vector2(9,y-2)]),tint,2)
				elif id == "lw_root":
					draw_line(Vector2(0,-14),Vector2(0,3),tint,2)
					for x in [-8,0,8]: draw_line(Vector2(0,-3),Vector2(x,6),tint,2)
				else:
					for i in 4: draw_line(Vector2.ZERO,Vector2.from_angle(i*PI/2)*11+Vector2(0,-5),tint,2)
		"forge":
			draw_rect(Rect2(-22, -8, 44, 20), Color(0.35, 0.24, 0.17))
			draw_rect(Rect2(-24, -12, 48, 6), Color(0.6, 0.42, 0.22))
			draw_colored_polygon(PackedVector2Array([Vector2(0,-32),Vector2(9,-19),Vector2(0,-10),Vector2(-9,-19)]),cyan if GameState.flag("lw_workshop") else Color(0.25,0.3,0.35))
		"bridge":
			draw_rect(Rect2(-17,-8,34,17),Color(0.45,0.29,0.15))
			draw_arc(Vector2(0,-11),12,0,TAU,18,gold,3)
			draw_line(Vector2(-17,-11),Vector2(17,-11),gold,3)
		_:
			draw_rect(Rect2(-15,-18,30,24),Color(0.4,0.28,0.16))
			for y in [-12,-6,0]: draw_line(Vector2(-10,y),Vector2(10,y),gold,1)
	if active and not encounter_spawned:
		for at in spawn_positions():
			draw_arc(at-global_position,24,0,TAU,24,gold,2)
	if is_instance_valid(world.player) and world.player.target == self and not active:
		DrawUtil.name_tag(self, Vector2(0, -42), label())
		DrawUtil.prompt(self, Vector2(0, -59), time)
