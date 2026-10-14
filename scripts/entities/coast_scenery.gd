extends Node2D
## Quiet coastline: a bounded number of wave marks, wind grass and distant gulls.
var time:=0.0
var world: Node2D
var waves: Array[Vector3]=[]
var grass: Array[Vector2]=[]
func _ready():
	for y in world.map_data.rows.size():
		var row: String=world.map_data.rows[y]
		for x in row.length():
			if row[x]=="8":
				var inward:=Vector2.ZERO
				for step: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var p:=Vector2i(x,y)+step
					if p.y>=0 and p.y<world.map_data.rows.size() and p.x>=0 and p.x<row.length() and world.map_data.rows[p.y][p.x] in ["4","5","6"]:
						inward+=Vector2(step)
				if inward!=Vector2.ZERO and (x+y)%2==0:waves.append(Vector3((x+0.5)*32,(y+0.5)*32,inward.angle()))
			elif row[x]=="6" and (x*3+y)%13==0:grass.append(Vector2(x+0.5,y+0.5)*32)
func _process(delta: float):time+=delta;queue_redraw()
func _draw():
	for i in waves.size():
		var wave:=waves[i]
		var inward:=Vector2.from_angle(wave.z)
		var phase:=fmod(time*0.15+i*0.21,1.0)
		var at:=Vector2(wave.x,wave.y)+inward*(phase*9-3)
		var side:=inward.orthogonal()*10
		draw_line(at-side,at+side,Color(0.75,0.92,0.90,sin(phase*PI)*0.5),1.3)
	for at in grass:
		var wind:=sin(time*1.3+at.x*0.02)*2
		draw_line(at+Vector2(-3,2),at+Vector2(-3+wind,-4),Color("93a476"),1)
		draw_line(at+Vector2(1,3),at+Vector2(1+wind,-5),Color("afba81"),1)
	# Three far-away gulls over sea, without prompts or rewards.
	for i in 3:
		var at:=Vector2(world.map_size.x*32-190+i*30,120+i*42)+Vector2(sin(time*0.25+i)*46,sin(time*0.9+i)*5)
		draw_polyline(PackedVector2Array([at+Vector2(-6,-2),at+Vector2(-2,-3),at,at+Vector2(2,-3),at+Vector2(6,-2)]),Color(0.9,0.94,0.88,0.65),1.2)
