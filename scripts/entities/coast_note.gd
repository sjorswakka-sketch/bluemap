extends Node2D
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var obj: Dictionary={}
var key: String=""
var time:=0.0
func _ready():add_to_group("interactable")
func label() -> String:return tr("Strandsteen bij het uitzicht")
func interact():
	if not GameState.input_locked():
		GameState.say(label(),[tr("Aan de horizon ligt een verre kust. Hier hoor je alleen de wind en de zee."),tr("Je hoeft hier niets te verzamelen. De veerboot wacht aan de westelijke steiger; je kunt altijd terug.")])
func _process(delta: float):time+=delta;queue_redraw()
func _draw():
	DrawUtil.sprite(self,Art.tex("ce_props"),1,0,Vector2.ZERO,Vector2i(24,24),1.5)
	if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-24),time)
