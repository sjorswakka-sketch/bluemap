extends Node2D
## Sparse landscape motion stays away from paths; no rewards or collision.
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var time:=0.0
var reeds: Array[Vector2]=[]
var details: Array[Vector3]=[]
func _ready():
	var points: Array={"river_mouth":[[9,8],[13,23],[8,31],[54,11],[63,26],[51,32]],"harbor":[[9,9],[20,25],[26,7],[62,9],[62,28]],"headland":[[14,15],[22,23],[28,12],[39,16],[46,30],[52,27]]}.get(GameState.map_id,[])
	for point: Array in points:
		var x: int=point[0];var y: int=point[1]
		if world.map_data.rows[y][x] in ["6","5"]:details.append(Vector3((x+.5)*32,(y+.5)*32,4 if GameState.map_id=="river_mouth" else 3 if GameState.map_id=="harbor" else 5))
	if GameState.map_id!="river_mouth":return
	for y in range(4,world.map_size.y-4,3):
		for x in range(3,world.map_size.x-3):
			if world.map_data.rows[y][x]!="6":continue
			if world.map_data.rows[y][x+1]=="8" and (x+y)%3==0:reeds.append(Vector2(x+.5,y+.5)*32)
func _process(delta: float):
	if is_queued_for_deletion() or GameState.map_id not in ["river_mouth","harbor","headland"]:return
	time+=delta
	var lift:=0.0
	for landmark in world.entities.get_children():
		if not landmark.is_in_group("region_landmarks") or landmark.is_queued_for_deletion():continue
		var offset: Vector2=world.player.position-landmark.position
		if offset.y>-24 and offset.y<210:
			lift=maxf(lift,84*clampf(1-(absf(offset.x)-80)/100,0,1)*clampf((210-offset.y)/80,0,1))
	world.player.camera.offset=world.player.camera.offset.lerp(Vector2(0,-lift),minf(1,delta*8))
	queue_redraw()
func _draw():
	for at in details:DrawUtil.sprite(self,Art.tex("rg_props"),int(at.z),0,Vector2(at.x,at.y),Vector2i(32,24),2)
	for at in reeds:
		DrawUtil.sprite(self,Art.tex("rg_props"),2,0,at+Vector2(sin(time+at.y)*1.5,-5),Vector2i(32,24),1.8)
	if GameState.map_id=="river_mouth":
		for y in [18.0*32,20.0*32]:
			draw_line(Vector2(22*32,y),Vector2(41*32,y),Color("c5b68c"),2)
			for x in range(22,42,3):draw_line(Vector2(x*32,y-4),Vector2(x*32,y+4),Color("6e6c53"),3)
	if GameState.map_id=="headland":
		for tile: Vector2 in [Vector2(67,20),Vector2(65,29)]:
			var at:=tile*32+Vector2(16,sin(time*1.2+tile.y)*2)
			draw_arc(at+Vector2(0,6),9,0,PI,12,Color(.6,.82,.82,.35),1)
			draw_line(at,at+Vector2(0,-12),Color("d3c59a"),2)
			draw_circle(at+Vector2(0,-11),3,Color("daa96c"))
	if GameState.map_id=="harbor":
		# Soft ripples below the pier; all working props are clustered at the quay.
		for i in 5:
			var at:=Vector2((41+i*2)*32,(35+sin(time*.5+i)*.15)*32)
			draw_line(at,at+Vector2(18,0),Color(.7,.87,.85,.2+.1*sin(time+i)),1.3)
