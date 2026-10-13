extends RefCounted
## Twee aanvallen met een vaste, zichtbare aanloop en ruimte voor een tegenaanval.
const DrawUtil := preload("res://scripts/core/draw_util.gd")

static func update(foe: Node2D, delta: float) -> void:
	var to_player: Vector2 = foe.player.global_position - foe.global_position
	var distance := to_player.length()
	var charge: bool = foe.data["behavior"] == "echo_charge"
	match foe.state:
		"idle":
			if distance > float(foe.data["sight"]):
				foe._wander(delta)
				foe.state_time = 0.0
				return
			if charge:
				foe.desired = foe._free_direction(to_player.normalized()) * float(foe.data["speed"])
			else:
				var direction := -to_player.normalized() if distance < 105.0 else to_player.normalized() if distance > 185.0 else to_player.orthogonal().normalized()
				foe.desired = foe._free_direction(direction) * float(foe.data["speed"])
			if foe.state_time >= 1.35 and foe._clear_line(foe.global_position, foe.player.global_position):
				foe.state = "echo_warn"
				foe.state_time = 0.0
				foe.aim_dir = to_player.normalized()
				(Engine.get_main_loop() as SceneTree).root.get_node("Sound").play("mage_charge", -10.0, 0.8 if charge else 1.3)
		"echo_warn":
			# De laatste 0,35 seconde staat de richting vast: een echte ontwijkkans.
			if foe.state_time < 0.35:
				foe.aim_dir = to_player.normalized()
			if foe.state_time >= 0.7:
				foe.state_time = 0.0
				if charge:
					foe.state = "echo_dash"
					(Engine.get_main_loop() as SceneTree).root.get_node("Sound").play("dodge", -6.0, 0.7)
				else:
					for angle in [-0.45, 0.0, 0.45]:
						foe.world.spawn_projectile("prism_spark", foe.global_position, foe.aim_dir.rotated(angle), 115.0, 1, foe.data["name"])
					foe.state = "echo_rest"
					(Engine.get_main_loop() as SceneTree).root.get_node("Sound").play("mage_orb", -6.0, 1.2)
		"echo_dash":
			foe.desired = foe.aim_dir * 230.0
			if foe.state_time >= 0.48 or (foe.state_time > 0.06 and foe.get_slide_collision_count() > 0):
				foe.desired = Vector2.ZERO
				foe.state = "echo_rest"
				foe.state_time = 0.0
				foe.world.ring(foe.global_position, 22, Color(0.4, 0.9, 1.0))
		"echo_rest":
			if foe.state_time >= 0.95:
				foe.state = "idle"
				foe.state_time = 0.0

static func draw(foe: Node2D, sheet: Texture2D, tint: Color) -> void:
	var charge: bool = foe.data["behavior"] == "echo_charge"
	var color := Color(0.4, 0.95, 1.0) if charge else Color(0.95, 0.6, 1.0)
	DrawUtil.ellipse(foe, Vector2(0, 12), Vector2(10, 3.0), Color(0, 0, 0, 0.3))
	if foe.state == "echo_warn":
		var angles: Array = [0.0] if charge else [-0.45, 0.0, 0.45]
		for angle in angles:
			var direction: Vector2 = foe.aim_dir.rotated(angle)
			var end := direction * (112.0 if charge else 90.0)
			foe.draw_line(direction * 14, end, Color(0.04, 0.06, 0.12, 0.75), 7.0)
			foe.draw_line(direction * 14, end, Color(color, 0.55 + 0.4 * foe.state_time / 0.7), 3.0)
			foe.draw_arc(end, 5, 0, TAU, 12, color, 1.5)
	var frame: int = 2 if foe.state == "echo_warn" else 3 if foe.state == "echo_dash" else int(foe.t * 6.0) % 2
	var hover := Vector2.ZERO if charge else Vector2(0, -5 + sin(foe.t * 5) * 2)
	DrawUtil.sprite(foe, sheet, frame, 0, hover, Vector2i(16, 16), 2.0, tint)
	if foe.state == "echo_rest":
		foe.draw_arc(Vector2(0, -22), 6, foe.t * 4, foe.t * 4 + PI, 10, color, 1.5)
