extends Node2D
## Iets op de grond: munt, hartje, drankje, kristal of een ander voorwerp.

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Items := preload("res://scripts/data/items.gd")
const Equipment := preload("res://scripts/core/equipment.gd")

const PICKUP_RANGE := 16.0
const MAGNET_RANGE := 54.0
const FULL_WARNING_FRAMES := 200 # "vol"-melding hooguit eens per ruim 3 seconden (zolang een melding in beeld staat)

static var _last_full_warning := -FULL_WARNING_FRAMES

var item := "coin"
var unique_key := "" # vlag die onthoudt dat dit voorwerp al is opgepakt (kristallen, sleutels)
var world: Node
var toss := Vector2.ZERO
var t := randf() * TAU
var age := 0.0
var player: Node2D
var collected := false


func _ready() -> void:
	add_to_group("pickups")


func _process(delta: float) -> void:
	t += delta * 3.0
	age += delta
	if age < 0.4:
		position += toss * delta
		toss *= 0.9
	if not is_instance_valid(player):
		player = Util.player(self)
	if player and not GameState.ended and not GameState.input_locked():
		var dist := player.global_position.distance_to(global_position)
		# Every dropped item follows the same magnet rule, even when it cannot
		# be collected yet. Full hearts and capped stacks remain available.
		if age > 0.25 and dist < magnet_range():
			global_position = global_position.move_toward(player.global_position, 170.0 * delta)
		if age > 0.2 and player.global_position.distance_to(global_position) < PICKUP_RANGE:
			_collect()
	queue_redraw()


func magnet_range() -> float:
	return MAGNET_RANGE + Equipment.bonus("magnet_range")


func _collect() -> void:
	if collected or is_queued_for_deletion():
		return
	# Claim before inventory signals fire: synchronous listeners cannot award
	# a coin or a unique object twice before queue_free takes effect.
	if item == "heart" and GameState.hp >= GameState.max_hp():
		return
	if item != "coin" and item != "heart" and GameState.room(item) <= 0:
		_warn_full(Items.info(item))
		return
	collected = true
	match item:
		"coin":
			GameState.add_coins(1)
			Sound.play("coin", -4.0)
		"heart":
			GameState.heal(1)
			Sound.play("heart", -3.0)
		_:
			var info := Items.info(item)
			if info.get("type", "") == "ammo":
				# Pijlen vallen vaak een voor een: geen melding maar een klein plusje.
				GameState.give(item, 1, true)
				Sound.play("select", -2.0, 1.3)
				world.damage_number(global_position + Vector2(0, -14), "+1", Color(1.0, 0.9, 0.6))
			else:
				GameState.give(item)
				Sound.play("crystal" if info.get("type", "") == "crystal" else "chest", -2.0)
			if info.get("type", "") == "crystal":
				world.shake(3.0)
	if unique_key != "":
		GameState.set_flag(unique_key)
	world.burst(global_position, Color(1, 0.95, 0.6), 8)
	queue_free()


func _warn_full(info: Dictionary) -> void:
	if Engine.get_process_frames() - _last_full_warning < FULL_WARNING_FRAMES:
		return
	_last_full_warning = Engine.get_process_frames()
	Sound.play("error", -3.0)
	GameState.toast.emit(GameState.full_text(item))


func _draw() -> void:
	var bob := Vector2(0, sin(t) * 2.0)
	DrawUtil.ellipse(self, Vector2(0, 11), Vector2(6, 2.5), Color(0, 0, 0, 0.25))
	match item:
		"coin":
			DrawUtil.sprite(self, Art.tex("coin"), int(t * 1.3) % 4, 0, bob)
		"heart":
			DrawUtil.sprite(self, Art.tex("heart"), 0, 0, bob)
		_:
			var info := Items.info(item)
			if info.get("type", "") == "crystal":
				draw_circle(bob, 15.0 + sin(t * 2.0) * 1.5, Color(0.3, 0.7, 1.0, 0.18))
			DrawUtil.sprite(self, Art.tex(Items.sheet_of(item)), int(info["icon"]), 0, bob)
