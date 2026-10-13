extends RefCounted
const Living := preload("res://scripts/core/living_world.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")

static func update(foe: Node2D, delta: float) -> void:
	var offset: Vector2 = foe.player.global_position - foe.global_position
	var distance := offset.length()
	if foe.guard_broken > 0:
		return
	match foe.data["behavior"]:
		"lw_guard":
			# Interpose between the player and a nearby vulnerable ranged ally.
			# Event targets (braziers etc.) retain priority.
			if not is_instance_valid(foe.defend_target) and distance < 260:
				var nearest := 150.0
				for ally: Node2D in foe.get_tree().get_nodes_in_group("enemies"):
					var separation := foe.global_position.distance_to(ally.global_position)
					if ally != foe and not ally.dead and ally.data.behavior in ["lw_support","cv_slinger"] and separation < nearest and foe._clear_line(foe.global_position,ally.global_position):
						nearest = separation
						var screen: Vector2 = ally.global_position + (foe.player.global_position-ally.global_position).normalized()*45
						offset = screen - foe.global_position
						distance = offset.length()
			if is_instance_valid(foe.defend_target):
				offset = foe.defend_target.global_position - foe.global_position
				distance = offset.length()
			if distance > 320:
				foe._wander(delta)
				return
			foe.aim_dir = foe.aim_dir.slerp((foe.player.global_position-foe.global_position).normalized(), minf(1, delta * 2.5))
			if distance > 24: foe.desired = foe._free_direction(offset.normalized()) * 37
		"lw_flank":
			if Living.light_at(foe.global_position):
				foe.desired = foe._free_direction(-offset.normalized()) * 60
				foe.state = "idle"
				foe.state_time = 0
				return
			if distance > 300:
				foe._wander(delta)
			elif foe.state == "lw_lunge":
				foe.desired = foe.aim_dir * 175
				if foe.state_time > 0.28:
					foe.state = "lw_rest"
					foe.state_time = 0
			elif foe.state == "lw_warn":
				if foe.state_time > 0.65:
					foe.state = "lw_lunge"
					foe.state_time = 0
			elif foe.state == "lw_rest":
				if foe.state_time > 0.9:
					foe.state = "idle"
					foe.state_time = 0
			else:
				var move := offset.normalized() if distance > 105 else (offset.orthogonal().normalized() + offset.normalized() * 0.2).normalized()
				foe.desired = foe._free_direction(move) * 58
				if foe.state_time > 1.6 and distance < 155 and foe._clear_line(foe.global_position, foe.player.global_position):
					foe.state = "lw_warn"
					foe.state_time = 0
					foe.aim_dir = offset.normalized()
		"lw_support":
			if foe.state == "lw_song":
				if foe.state_time > 1.0:
					for ally: Node2D in foe.get_tree().get_nodes_in_group("enemies"):
						if ally != foe and not ally.dead and ally.global_position.distance_to(foe.global_position) < 160 and foe._clear_line(foe.global_position, ally.global_position):
							ally.hp = mini(ally.hp + 1, ally.max_hp)
					foe.world.ring(foe.global_position, 160, Color(0.4, 1, 0.65))
					foe.state = "idle"
					foe.state_time = 0
			else:
				if distance < 100: foe.desired = foe._free_direction(-offset.normalized()) * 35
				elif distance > 210 and distance < 400: foe.desired = foe._free_direction(offset.normalized()) * 25
				if foe.state_time > 4 and distance < 350:
					foe.state = "lw_song"
					foe.state_time = 0

static func blocks(foe: Node2D, direction: Vector2) -> bool:
	return foe.data["behavior"] == "lw_guard" and foe.guard_broken <= 0 and direction.normalized().dot(foe.aim_dir) < -0.45

static func draw(foe: Node2D, sheet: Texture2D, tint: Color) -> void:
	DrawUtil.ellipse(foe, Vector2(0, 12), Vector2(10, 3), Color(0,0,0,0.3))
	var frame := 2 if foe.state in ["lw_warn", "lw_song"] else int(foe.t * 5) % 2
	DrawUtil.sprite(foe, sheet, frame, 0, Vector2.ZERO, Vector2i(16,16),2,tint)
	if foe.data["behavior"] == "lw_guard":
		if foe.guard_broken > 0:
			foe.draw_arc(Vector2(0,-25),8,foe.t*5,foe.t*5+PI,12,Color(1,0.8,0.25),2)
		else:
			foe.draw_arc(Vector2.ZERO,18,foe.aim_dir.angle()-0.9,foe.aim_dir.angle()+0.9,16,Color(0.7,0.9,1),4)
	if foe.state == "lw_warn":
		foe.draw_line(foe.aim_dir*15,foe.aim_dir*60,Color(1,0.65,0.35),3)
	if foe.state == "lw_song":
		foe.draw_arc(Vector2.ZERO,24+foe.state_time*28,0,TAU,30,Color(0.3,1,0.55),2)
		for ally: Node2D in foe.get_tree().get_nodes_in_group("enemies"):
			if ally != foe and ally.global_position.distance_to(foe.global_position) < 160:
				foe.draw_line(Vector2.ZERO,ally.global_position-foe.global_position,Color(0.4,1,0.65,0.35),1)
