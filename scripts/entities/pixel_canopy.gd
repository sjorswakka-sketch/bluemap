extends Node2D
## Taller original canopy; sorting follows the trunk, fading only reveals actors behind leaves.
var variant:=0
var kind:=0
const Art:=preload("res://scripts/core/art.gd")
func _draw():
	draw_texture_rect_region(Art.tex("pixel_canopies"),Rect2(-24,-58,48,64),Rect2(variant*48,kind*64,48,64))
