extends RefCounted
## Append only: every old saved object slot and every existing route stays intact.
static func prop(data: Dictionary,role: String,pos: Array):
 data.objects.append({"type":"coast_adventure","role":role,"pos":pos})
static func enrich(id: String,data: Dictionary):
 match id:
  "gull_island":
   prop(data,"message",[29,11]);prop(data,"splinter",[26,28])
  "river_mouth":
   prop(data,"silt",[55,32])
   data.spawns["from_hollow"]=[16,12]
   data.objects.append({"type":"portal","pos":[16,9],"size":[2,2],"to":"tidal_hollow","spawn":"start"})
   prop(data,"entrance",[15,11])
  "harbor":
   prop(data,"record",[49,26]);prop(data,"buoy",[51,32]);prop(data,"harbor_wheel",[59,25])
  "headland":
   prop(data,"pilot",[12,25]);prop(data,"rock",[30,12]);prop(data,"grass",[45,17]);prop(data,"shelter",[47,34])
