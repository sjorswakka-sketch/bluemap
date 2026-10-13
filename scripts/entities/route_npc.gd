extends RefCounted
const Route := preload("res://scripts/core/first_route.gd")
static func update(npc: Node2D, delta: float) -> void:
	if npc.npc_id!="muis_bos": return
	var player: Node2D=npc.world.player
	var distance:=npc.position.distance_to(player.position)
	if distance<105 and Route.loud(player):
		npc.route_panic=2.5
		npc.route_wait=false
		npc.route_calm=0
	if npc.route_panic>0:
		npc.route_panic=maxf(0,npc.route_panic-delta)
		var next: Vector2=npc.position.move_toward(Vector2(10.5,31.5)*32,42*delta)
		if not npc.world.is_solid(next) and next.distance_to(player.position)>24: npc.position=next
	elif npc.route_wait:
		if distance>56 or player.velocity.length()>5 or player.attack_timer>0:
			npc.route_wait=false
			npc.route_calm=0
		else:
			var before: float=npc.route_calm
			npc.route_calm=minf(2,npc.route_calm+delta)
			if before<2 and npc.route_calm>=2:
				(Engine.get_main_loop() as SceneTree).root.get_node("Sound").play("rf_purr",-8)
static func draw(npc: Node2D) -> void:
	if npc.npc_id=="muis_bos" and (npc.route_wait or npc.route_panic>0):
		var color:=Color("eaba80") if npc.route_panic>0 else Color("98dca5")
		npc.draw_rect(Rect2(-15,-20,30,4),Color("273c43"))
		npc.draw_rect(Rect2(-14,-19,28*(1.0 if npc.route_panic>0 else npc.route_calm/2),2),color)
	if npc.npc_id=="wilfred" and Route.gs().flag("rf_memorial"):
		for i in 3:
			npc.draw_circle(Vector2(-12+i*12,-22+sin(npc.t+i)*4),1.5,Color("edd9a8"))
