extends Node2D
## Cached native-pixel shorelines, organic paths and contact shadows.
## No colliders, random spawns or gameplay timers. Small textures are rebuilt only on terrain changes.
const Visual:=preload("res://scripts/core/pixel_landscape.gd")
const Tiles:=preload("res://scripts/data/tiles.gd")
const Art:=preload("res://scripts/core/art.gd")
const CHUNK:=512
var world: Node2D
var chunks: Array[Sprite2D]=[]
var water: Array[Vector3i]=[]
var canopies: Dictionary={}
var faded: Array[Node2D]=[]
var clock:=0.0
var frame:=-1
var pending:=false
var rebuilds:=0
func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	rebuild()
func refresh():
	if not pending:
		pending=true
		rebuild.call_deferred()
func edge(image: Image,origin: Vector2i,side: int,color: Color,water_edge: bool,seed: int):
	for i in 32:
		var depth:=2+(posmod(i*7+seed*3,11)/4) if not water_edge else 3
		var p:=origin+Vector2i(i,0) if side==0 else origin+Vector2i(0,i) if side==1 else origin+Vector2i(i,32-depth) if side==2 else origin+Vector2i(32-depth,i)
		var size:=Vector2i(1,depth) if side in [0,2] else Vector2i(depth,1)
		image.fill_rect(Rect2i(p,size),color)
		if water_edge:
			var rim:=origin+Vector2i(i,2) if side==0 else origin+Vector2i(2,i) if side==1 else origin+Vector2i(i,29) if side==2 else origin+Vector2i(29,i)
			image.set_pixelv(rim,Color("8db6a4") if i%7<4 else Color("608e86"))
func rebuild():
	if not is_instance_valid(world) or not is_inside_tree() or is_queued_for_deletion():return
	pending=false;rebuilds+=1
	for node in chunks:node.queue_free()
	chunks.clear();water.clear()
	for node: Node2D in canopies.values():
		if is_instance_valid(node):node.queue_free()
	canopies.clear();faded.clear()
	var rows: Array=world.map_data.rows
	var images: Dictionary={}
	for y in rows.size():
		for x in str(rows[y]).length():
			var cell:=Vector2i(x,y);var tile:=Visual.at(rows,cell)
			if tile in ["tree","pine","willow"]:
				var crown:=preload("res://scripts/entities/pixel_canopy.gd").new()
				crown.kind=["tree","pine","willow"].find(tile);crown.variant=Visual.atlas(tile,x,y).y;crown.position=Vector2(x*32+16,y*32+28)
				world.entities.add_child(crown);canopies[cell]=crown
			var wr:=Visual.water_row(tile)
			if wr>=0:water.append(Vector3i(x,y,wr))
			var chunk:=Vector2i(x/16,y/16)
			if not images.has(chunk):images[chunk]=Image.create_empty(CHUNK,CHUNK,false,Image.FORMAT_RGBA8)
			var image: Image=images[chunk];var origin:=Vector2i(x%16,y%16)*32
			var steps: Array[Vector2i]=[Vector2i.UP,Vector2i.LEFT,Vector2i.DOWN,Vector2i.RIGHT]
			for side in 4:
				var other:=Visual.at(rows,cell+steps[side])
				if tile in Visual.PATH and other in Visual.GRASS:
					edge(image,origin,side,Visual.green(other),false,x*3+y)
				elif wr>=0 and (Visual.ground(other) or other in ["tree","pine","willow","rock","reed","meer_reeds"]):
					edge(image,origin,side,Color("305d5a") if wr!=1 else Color("315968"),true,x+y)
			if Visual.ground(tile):
				var up:=Visual.at(rows,cell+Vector2i.UP)
				var left:=Visual.at(rows,cell+Vector2i.LEFT)
				if Tiles.is_solid_name(up) and up not in Visual.WATER:
					var depth:=8 if up in ["tree","pine","willow","roof"] else 5
					image.fill_rect(Rect2i(origin,Vector2i(32,depth)),Color(0.12,0.21,0.22,.22))
					image.fill_rect(Rect2i(origin+Vector2i(2,depth),Vector2i(30,2)),Color(0.12,0.21,0.22,.09))
				if Tiles.is_solid_name(left) and left not in Visual.WATER:
					image.fill_rect(Rect2i(origin,Vector2i(4,32)),Color(0.12,0.21,0.22,.13))
			if tile=="roof":
				if Visual.at(rows,cell+Vector2i.DOWN)!="roof":
					image.fill_rect(Rect2i(origin+Vector2i(0,27),Vector2i(32,5)),Color("553f39"))
					image.fill_rect(Rect2i(origin+Vector2i(0,27),Vector2i(32,1)),Color("d4a477"))
				if Visual.at(rows,cell+Vector2i.UP)!="roof":
					image.fill_rect(Rect2i(origin,Vector2i(32,3)),Color("d09b70"))
				if Visual.at(rows,cell+Vector2i.LEFT)!="roof":image.fill_rect(Rect2i(origin,Vector2i(2,32)),Color("d09b70"))
				if Visual.at(rows,cell+Vector2i.RIGHT)!="roof":image.fill_rect(Rect2i(origin+Vector2i(30,0),Vector2i(2,32)),Color("60423b"))
	for key: Vector2i in images:
		var node:=Sprite2D.new();node.centered=false;node.texture=ImageTexture.create_from_image(images[key]);node.position=Vector2(key)*CHUNK;add_child(node);chunks.append(node)
	queue_redraw()
func _process(delta: float):
	clock+=delta
	var next:=int(clock*6)
	if next!=frame:
		frame=next;queue_redraw();reveal_player()
func reveal_player():
	if not is_instance_valid(world.player) or not world.player.is_inside_tree():return
	for crown in faded:
		if is_instance_valid(crown):crown.modulate.a=1.0
	faded.clear()
	var points: Array[Vector2]=[world.player.position+Vector2(0,12)]
	for group in ["interactable","enemies"]:
		for actor in get_tree().get_nodes_in_group(group):
			if actor is Node2D and not actor.is_queued_for_deletion() and actor.position.distance_squared_to(world.player.position)<40000:
				points.append(actor.position)
	for foot: Vector2 in points:reveal_at(foot)

func reveal_at(foot: Vector2):
	var center:=Vector2i((foot/32).floor())
	for y in range(center.y-1,center.y+3):
		for x in range(center.x-1,center.x+2):
			var crown: Node2D=canopies.get(Vector2i(x,y))
			if crown!=null and Rect2(crown.position+Vector2(-25,-59),Vector2(50,54)).has_point(foot):
				crown.modulate.a=.48
				if not faded.has(crown):faded.append(crown)

func _draw():
	if not is_instance_valid(world.player) or not world.player.is_inside_tree():return
	var camera: Camera2D=world.player.camera
	var extent:=get_viewport_rect().size/camera.zoom*.5+Vector2(64,64)
	var visible_area:=Rect2(camera.get_screen_center_position()-extent,extent*2)
	var sheet:=Art.tex("pixel_water")
	for cell: Vector3i in water:
		var pos:=Vector2(cell.x,cell.y)*32
		if not visible_area.has_point(pos):continue
		# Neighboring tiles use a different phase; no synchronized wallpaper shimmer.
		var phase:=posmod(frame/3+cell.x*3+cell.y*7,4)
		draw_texture_rect_region(sheet,Rect2(pos,Vector2(32,32)),Rect2(phase*32,cell.z*32,32,32),Color(1,1,1,.7))
