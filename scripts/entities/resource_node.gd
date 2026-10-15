extends Node2D
## Harvesting is a short, interruptible action. Only its successful completion
## awards materials or starts the saved cooldown; moving or opening a menu stops it.

const Professions := preload("res://scripts/core/professions.gd")
const Data := preload("res://scripts/data/ext/beroepen.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Util := preload("res://scripts/core/util.gd")
const Art := preload("res://scripts/core/art.gd")
const HARVEST_RANGE := 40.0

var world: Node
var obj: Dictionary = {}
var key := ""
var resource_id := ""
var kind := ""
var player: Node2D
var t := 0.0
var hint_wait := 0.0
var harvesting := false
var harvest_time := 0.0
var harvest_duration := 0.65
var harvest_map := ""
var harvest_origin := Vector2.ZERO
var next_strike := 0.0


func _ready() -> void:
	kind = obj.get("kind", "branches")
	resource_id = obj.get("id", key)
	add_to_group("interactable")
	add_to_group("profession_resources")


func _process(delta: float) -> void:
	t += delta
	hint_wait = maxf(hint_wait - delta, 0.0)
	if not is_instance_valid(player):
		player = Util.player(self)
	if harvesting:
		advance_harvest(delta)
	queue_redraw()


func interact() -> void:
	if GameState.input_locked() or hint_wait > 0.0 or harvesting:
		return
	if not is_instance_valid(player):
		player = Util.player(self)
	if not is_instance_valid(player) or global_position.distance_to(player.global_position) >= HARVEST_RANGE:
		return
	# One work action belongs to one prop. Repeated input cannot restart its
	# timer, and another nearby prop cannot take over the animation.
	if player.has_method("is_working") and player.is_working():
		return
	hint_wait = 0.25
	var reason := Professions.gather_reason(kind, resource_id)
	if reason != "":
		GameState.toast.emit(reason)
		Sound.play("error", -6.0)
		return
	harvesting = true
	harvest_time = 0.0
	harvest_duration = Professions.gather_duration(kind)
	harvest_map = GameState.map_id
	harvest_origin = player.global_position
	next_strike = 0.18
	if player.has_method("start_work_animation"):
		player.start_work_animation(Professions.gather_animation(kind), harvest_duration, global_position)
	queue_redraw()


func advance_harvest(delta: float) -> void:
	if not harvesting:
		return
	if GameState.input_locked() or GameState.map_id != harvest_map or not is_instance_valid(player):
		cancel_harvest()
		return
	if global_position.distance_to(player.global_position) >= HARVEST_RANGE \
			or player.global_position.distance_to(harvest_origin) > 4.0 \
			or (player.has_method("is_working") and not player.is_working()):
		cancel_harvest()
		return
	var reason := Professions.gather_reason(kind, resource_id)
	if reason != "":
		cancel_harvest()
		GameState.toast.emit(reason)
		return
	harvest_time = minf(harvest_time + maxf(delta, 0.0), harvest_duration)
	if harvest_time >= next_strike:
		next_strike += 0.42
		var animation := Professions.gather_animation(kind)
		Sound.play("hit" if animation == "mining" else ("step_wood" if animation == "woodcutting" else "step_grass"), -14.0, 1.15)
		if is_instance_valid(world):
			world.burst(global_position + Vector2(0, -7), Data.RESOURCES[kind]["color"], 3)
	if harvest_time >= harvest_duration:
		cancel_harvest()
		# gather() performs its own final tool/level/space check before committing.
		if Professions.gather(kind, resource_id):
			Sound.play("coin", -8.0)
			if is_instance_valid(world):
				world.burst(global_position, Data.RESOURCES[kind]["color"], 7)
		else:
			Sound.play("error", -6.0)
	queue_redraw()


func cancel_harvest() -> void:
	if not harvesting:
		return
	harvesting = false
	harvest_time = 0.0
	if is_instance_valid(player) and player.has_method("cancel_work_animation"):
		player.cancel_work_animation()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cancel_harvest()


func _exit_tree() -> void:
	cancel_harvest()


func _draw() -> void:
	if kind == "":
		return
	var wait := Professions.remaining(resource_id)
	var tint := Color(0.55, 0.55, 0.55, 0.4) if wait > 0.0 else Color.WHITE
	DrawUtil.ellipse(self, Vector2(0, 7), Vector2(11, 4), Color(0, 0, 0, 0.24))
	var frame: int = int(Data.RESOURCES[kind].get("frame",Data.RESOURCES.keys().find(kind)))
	var jostle := Vector2(sin(harvest_time * 34.0) * 1.5, -absf(sin(harvest_time * 17.0))) if harvesting else Vector2.ZERO
	draw_texture_rect_region(Art.tex(str(Data.RESOURCES[kind].get("sheet","resources_beroepen"))), Rect2(Vector2(-16, -24) + jostle, Vector2(32, 32)), Rect2(frame * 16, 0, 16, 16), tint)
	if wait <= 0.0:
		var color: Color = Data.RESOURCES[kind]["color"]
		draw_circle(Vector2(10, -18 + sin(t * 2.0) * 2.0), 1.5, color)
	if harvesting:
		var progress := clampf(harvest_time / harvest_duration, 0.0, 1.0)
		draw_rect(Rect2(-19, -33, 38, 5), Color(0.07, 0.1, 0.15, 0.95))
		draw_rect(Rect2(-18, -32, 36 * progress, 3), Data.RESOURCES[kind]["color"])
		DrawUtil.name_tag(self, Vector2(0, -39), tr(Data.TEXT["harvesting"]))
	elif is_instance_valid(player) and player.target == self and not GameState.input_locked():
		var label: String = tr(Data.RESOURCES[kind]["name"])
		if wait > 0.0:
			label = tr(Data.TEXT["depleted"]) % ceili(wait)
		DrawUtil.name_tag(self, Vector2(0, -28), label)
		if wait <= 0.0:
			var reason := Professions.gather_reason(kind, resource_id)
			if reason != "":
				DrawUtil.name_tag(self, Vector2(0, -41), reason)
			else:
				DrawUtil.prompt(self, Vector2(0, -42), t)
