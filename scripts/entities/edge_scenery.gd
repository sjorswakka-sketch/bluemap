extends Node2D
## A few slow water ripples: scenery without prompts, rewards or collisions.
var time:=0.0
const RIPPLE_PLACES:=[Vector2(30.5,17.5)*32,Vector2(33.5,18.5)*32,Vector2(32,16.5)*32]
func _process(delta: float):
	time+=delta;queue_redraw()
func _draw():
	for i in RIPPLE_PLACES.size():
		var phase:=fmod(time*0.13+i*0.31,1.0)
		var color:=Color(0.75,0.9,0.96,sin(phase*PI)*0.3)
		draw_arc(RIPPLE_PLACES[i],6+phase*16,PI*0.1,PI*0.8,12,color,1.2)
		draw_arc(RIPPLE_PLACES[i]+Vector2(0,3),6+phase*16,PI*1.1,PI*1.8,12,color,1.2)
