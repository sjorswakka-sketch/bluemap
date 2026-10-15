extends "res://scripts/entities/npc.gd"
const Region:=preload("res://scripts/core/coastal_region.gd")
var obj: Dictionary={}
func setup(id: String):
	super.setup(id)
	obj={"role":"routes","to":"coast","spawn":"from_island","routes":[{"to":"coast","spawn":"from_island"},{"to":"gull_island","spawn":"from_coast"},{"to":"tide_cove","spawn":"from_coast"}]} if id=="rg_ise" else {"role":"atlas"}
func interact():
	if GameState.input_locked():return
	GameState.note_talked(npc_id);Region.open(self,"rg_ise" if npc_id=="rg_ise" else "rg_raf")
func open_service(action: String):
	if GameState.input_locked() or is_queued_for_deletion() or GameState.map_id!="harbor" or position.distance_to(world.player.position)>64:return
	var group:="coast_routes" if action=="rg_routes" and npc_id=="rg_ise" else "coast_atlas" if action=="rg_atlas" and npc_id=="rg_raf" else ""
	if group=="":return
	for ui in get_tree().get_nodes_in_group(group):
		if not ui.is_queued_for_deletion() and ui.world==world:ui.open(self);return
func _draw():
	super._draw()
	if npc_id=="rg_raf":
		var hand:=Vector2(14+sin(t*2)*3,6)
		draw_line(Vector2(6,5),hand,Color("cfb18c"),2)
		draw_arc(Vector2(17,10),8,0.2,2.8,12,Color("b4bd9b"),1.2)
	else:
		draw_line(Vector2(13,9),Vector2(13+sin(t)*2,-11),Color("c4ac78"),2)
