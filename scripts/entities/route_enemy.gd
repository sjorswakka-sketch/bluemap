extends RefCounted
const Route := preload("res://scripts/core/first_route.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
static func update(foe: Node2D, delta: float) -> void:
	var offset: Vector2=foe.player.global_position-foe.global_position
	var distance:=offset.length()
	if foe.state=="rf_warn":
		if foe.state_time>=0.85:
			foe.state="rf_jump"
			foe.state_time=0
	elif foe.state=="rf_jump":
		foe.desired=foe.aim_dir*185
		if foe.state_time>=0.32:
			foe.state="rf_rest"
			foe.state_time=0
	elif foe.state=="rf_rest":
		if foe.state_time>=1.5:
			foe.state="idle"
			foe.state_time=0
	else:
		var disturbed: bool=distance<115 if foe.data.behavior=="rf_ambush" else (distance<170 and Route.loud(foe.player))
		# Aanraken of een treffer wekt hem ook, maar stil langs hem lopen niet.
		disturbed=disturbed or distance<28 or foe.flash>0
		if disturbed and foe.state_time>0.8 and foe._clear_line(foe.global_position,foe.player.global_position):
			foe.aim_dir=offset.normalized()
			foe.state="rf_warn"
			foe.state_time=0
			if distance<200:
				(Engine.get_main_loop() as SceneTree).root.get_node("Sound").play("rf_rustle" if foe.data.behavior=="rf_ambush" else "rf_low",-10)
static func draw(foe: Node2D, sheet: Texture2D, tint: Color) -> void:
	DrawUtil.ellipse(foe,Vector2(0,12),Vector2(11,3),Color(0,0,0,0.3))
	var frame:=0 if foe.state=="idle" else (2 if foe.state=="rf_jump" else 1)
	DrawUtil.sprite(foe,sheet,frame,0,Vector2(0,-sin(minf(1,foe.state_time/0.32)*PI)*8 if foe.state=="rf_jump" else 0),Vector2i(16,16),2,tint)
	if foe.state=="rf_warn":
		foe.draw_line(foe.aim_dir*18,foe.aim_dir*65,Color("efb86e"),3)
		foe.draw_arc(Vector2(0,-20),6,-PI/2,-PI/2+TAU*minf(1,foe.state_time/0.85),20,Color("ffe2a0"),2)
	elif foe.state=="idle" and foe.data.behavior=="rf_listen":
		foe.draw_arc(Vector2(0,-16),4+sin(foe.t*2),PI,TAU,10,Color("91becd"),1)
