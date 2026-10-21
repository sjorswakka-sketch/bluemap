extends "res://scripts/ui/dialogue_box.gd"
## Observe node identities while executing the untouched original dialogue callbacks.
var story_id := ""
func _enter(talk_id: String) -> void:
 story_id=talk_id
 super._enter(talk_id)
func _close() -> void:
 story_id=""
 super._close()
