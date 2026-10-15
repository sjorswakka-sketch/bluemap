extends RefCounted
static func enrich(id: String,data: Dictionary):
 if id=="harbor":
  data.spawns["from_workshop"]=[55,23]
  data.objects.append({"type":"cw_station","role":"door","pos":[55,22],"travel_link":true,"to":"coast_workshop","spawn":"start"})
 if id=="river_mouth":
  data.objects.append({"type":"cw_station","role":"line","pos":[23,27],"landing":[41,27]})
  data.objects.append({"type":"cw_station","role":"line","pos":[41,27],"landing":[23,27]})
