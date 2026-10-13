extends RefCounted
## Existing slots keep their save keys; substitutions do not add crowding.
static func enrich(id: String, data: Dictionary) -> void:
	if id == "forest":
		data.spawns["from_watchyard"] = [4,21]
		for y in range(20,24):
			var row: String = data.rows[y]
			data.rows[y] = row.substr(0,2)+".,,.."+row.substr(7)
		data.objects.append({"type":"portal","pos":[3,22],"to":"watchyard","spawn":"start"})
		data.objects.append({"type":"combat_post","kind":"entrance","pos":[5,22]})
		data.objects.append({"type":"sign","pos":[2,23],"lines":["Oefenerf: stap in de gloed bij het vaandel."]})
		for object: Dictionary in data.objects:
			if object.type == "enemy" and object.pos == [28,15]: object.kind = "cv_slinger"
			if object.type == "enemy" and object.pos == [42,28]: object.kind = "cv_ram"
	if id == "ruins":
		var replaced := 0
		for object: Dictionary in data.objects:
			if object.type == "enemy" and object.kind == "skeleton" and replaced < 2:
				object.kind = "cv_slinger" if replaced == 0 else "cv_ram"
				replaced += 1
