extends RefCounted
## Native actor poses share the existing 32-world-pixel box and foot anchor.
const Manifest := preload("res://scripts/data/character_art.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
static func direction(motion: Vector2, previous := 0) -> int:
	if motion.length_squared()<1:return previous
	if absf(motion.y)>absf(motion.x):return 0 if motion.y>0 else 1
	return 2 if motion.x>0 else 3
static func frame(clock: float, moving: bool) -> int:
	return 1+int(clock*5)%2 if moving else 0
static func humanoid(sheet: String) -> bool:
	return sheet in Manifest.NPC_SHEETS
static func actor(canvas: CanvasItem,sheet: String,clock: float,motion: Vector2,row := 0,center := Vector2.ZERO,scale := 2.0,tint := Color.WHITE) -> void:
	if humanoid(sheet):
		DrawUtil.sprite(canvas,Art.tex(sheet),frame(clock,motion.length_squared()>1),row,center,Vector2i(16,16),scale,tint)
	else:
		DrawUtil.sprite(canvas,Art.tex(sheet),int(clock*1.6)%2,0,center,Vector2i(16,16),scale,tint)
