extends RefCounted
const DrawUtil := preload("res://scripts/core/draw_util.gd")

static func noisy(p: Node2D) -> bool:
	return p.sprinting or p.roll_timer > 0 or p.attack_timer > 0 or p.bow_anim > 0 or p.combat.phase != ""

static func transition(foe: Node2D, state: String) -> void:
	foe.state = state
	foe.state_time = 0.0

static func slot_free(foe: Node2D) -> bool:
	for other: Node2D in foe.get_tree().get_nodes_in_group("enemies"):
		if other != foe and other.global_position.distance_to(foe.global_position) < 240 and other.state in ["cv_warn","cv_charge","lw_warn","lw_lunge","echo_warn","rf_warn","hb_root_warn","hb_root_hit","hb_moth_warn","hb_moth_dash"]:
			return false
	return true

static func update(foe: Node2D, _delta: float) -> void:
	var offset: Vector2 = foe.player.global_position - foe.global_position
	var dist := offset.length()
	var clear: bool = foe._clear_line(foe.global_position,foe.player.global_position)
	if foe.state == "cv_warn":
		if foe.state_time >= 0.85:
			if foe.data.behavior == "cv_ram": transition(foe,"cv_charge")
			else:
				# Keep the warned direction; cover can absorb the projectile.
				foe.world.spawn_projectile("cv_thorn",foe.global_position,foe.aim_dir,150,1,foe.data.name)
				Sound.play("cv_thorn",-8.0)
				transition(foe,"cv_rest")
		return
	if foe.state == "cv_charge":
		if foe.state_time > 0.45 or not foe._body_clear(foe.global_position,foe.global_position+foe.aim_dir*16):
			transition(foe,"cv_rest")
			foe.world.ring(foe.global_position,24,Color(0.9,0.7,0.45))
		else: foe.desired = foe.aim_dir * 205
		return
	if foe.state == "cv_rest":
		if foe.state_time > 1.3: transition(foe,"idle")
		return
	# Never acquire through walls. Sound increases range, but still needs sight.
	var range_px := 230.0 if noisy(foe.player) else 140.0
	if not clear or dist > range_px:
		foe.state_time = minf(foe.state_time,0.6)
		return
	if foe.data.behavior == "cv_slinger":
		if dist < 85: foe.desired = foe._free_direction(-offset.normalized()) * 34
		elif dist > 185: foe.desired = foe._free_direction(offset.normalized()) * 25
	else:
		if dist > 115: foe.desired = foe._free_direction(offset.normalized()) * 42
	if foe.state_time > 1.1 and dist > 24 and slot_free(foe):
		foe.aim_dir = offset.normalized()
		transition(foe,"cv_warn")
		Sound.play("cv_ready",-13.0,0.65)

static func draw(foe: Node2D, sheet: Texture2D, tint: Color) -> void:
	DrawUtil.ellipse(foe,Vector2(0,13),Vector2(12,4),Color(0,0,0,0.3))
	var frame := 2 if foe.state == "cv_warn" else (3 if foe.state in ["cv_charge","cv_rest"] else int(foe.t*5)%2)
	DrawUtil.sprite(foe,sheet,frame,0,Vector2.ZERO,Vector2i(24,24),2,tint)
	if foe.state == "cv_warn":
		var length := 110.0 if foe.data.behavior == "cv_ram" else 220.0
		# Stop the warning at solid cover, like the actual attack.
		var ray := PhysicsRayQueryParameters2D.create(foe.global_position,foe.global_position+foe.aim_dir*length,1)
		var hit: Dictionary = foe.get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): length = foe.global_position.distance_to(hit.position)
		for distance in range(16,int(length),8):
			if foe.world.is_solid(foe.global_position+foe.aim_dir*distance):
				length = distance
				break
		var side: Vector2 = foe.aim_dir.orthogonal()*9
		var color := Color(1,0.64,0.3,0.8)
		foe.draw_line(foe.aim_dir*16-side,foe.aim_dir*length-side,color,1.5)
		foe.draw_line(foe.aim_dir*16+side,foe.aim_dir*length+side,color,1.5)
		foe.draw_arc(Vector2(0,-27),7,-PI/2,-PI/2+TAU*minf(foe.state_time/0.85,1),24,color,2)
	elif foe.state == "cv_rest":
		foe.draw_arc(Vector2(0,-25),7,foe.t*3,foe.t*3+PI,12,Color(0.6,0.9,1),2)
