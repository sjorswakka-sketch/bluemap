extends RefCounted
## Applied last: preserve 0.17 thinning, slot order and all outdoor route geometry.
const REPLACEMENTS := {
 "forest": [[Vector2i(12,5),"hb_root"],[Vector2i(43,6),"hb_root"]],
 "cave": [[Vector2i(31,12),"hb_moth"],[Vector2i(37,13),"hb_moth"]]
}
static func enrich(id: String, data: Dictionary) -> void:
 for replacement: Array in REPLACEMENTS.get(id,[]):
  for obj: Dictionary in data.objects:
   if obj.type=="enemy" and obj.get("enabled",true) and Vector2i(obj.pos[0],obj.pos[1])==replacement[0]:
    obj.kind=replacement[1]
