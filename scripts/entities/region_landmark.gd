extends StaticBody2D
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var obj: Dictionary={}
var key: String=""
var time:=0.0
var lamp: PointLight2D
var cells:=Rect2i()
func _ready():
	add_to_group("region_landmarks");collision_layer=1
	var width: int=obj.cells[0];var height: int=obj.cells[1]
	cells=Rect2i(int(obj.pos[0])-width/2,int(obj.pos[1])-height+1,width,height)
	var rect:=Rect2(Vector2(cells.position)*32,Vector2(cells.size)*32)
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=rect.size;collider.shape=shape;collider.position=rect.get_center()-position;add_child(collider)
	for y in range(cells.position.y,cells.end.y):
		for x in range(cells.position.x,cells.end.x):world.solid_cells[Vector2i(x,y)]=true
	if obj.frame==0:
		add_to_group("interactable")
		lamp=PointLight2D.new();lamp.texture=Art.light_texture();lamp.texture_scale=1.2;lamp.color=Color("f2dba0");lamp.position=Vector2(0,-142);add_child(lamp)
func label() -> String:return tr("Vuurtoren van Lichtkaap")
func interact():
	if GameState.input_locked() or obj.frame!=0:return
	Sound.play("rg_bell",-19)
	GameState.say(tr("Vuurtoren van Lichtkaap"),[tr("De lens draait langzaam boven het water. De warme bundel volgt de boeien verderop op zee."),tr("Een verweerde plaat wijst naar het westelijke pad: Rietwenk Haven. Aan de zuidrand staat een bankje uit de wind.")])
func _process(delta: float):
	time+=delta
	if lamp!=null:lamp.energy=world.light_need()*0.6
	queue_redraw()
func _draw():
	DrawUtil.sprite(self,Art.tex("rg_landmarks"),int(obj.frame),0,Vector2(0,-72),Vector2i(128,128),2)
	if obj.frame==0:
		var at:=Vector2(0,-142);var angle:=-0.2+sin(time*.18)*.6
		var beam:=PackedVector2Array([at,at+Vector2.from_angle(angle-.08)*450,at+Vector2.from_angle(angle+.08)*260])
		draw_colored_polygon(beam,Color(1,.92,.64,world.light_need()*.14))
		if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-28),time)
