extends RefCounted
## One geometry definition for the visible pool, water state, bridge, tests and scenery.
const BRIDGE:=Rect2i(16,16,7,2)
const ISLAND:=Rect2i(22,15,6,3)
const LOW_SHORE:=Rect2i(27,16,7,4)
static func put(data: Dictionary,cell: Vector2i,value: String):
	var row: String=data.rows[cell.y];row[cell.x]=value;data.rows[cell.y]=row
static func prepare(data: Dictionary):
	# A calm central island and a clear western landing, retaining all saved object slots.
	for y in range(ISLAND.position.y,ISLAND.end.y):
		for x in range(ISLAND.position.x,ISLAND.end.x):put(data,Vector2i(x,y),"U")
	for y in range(15,19):
		for x in [14,15]:put(data,Vector2i(x,y),"U")
	for y in range(BRIDGE.position.y,BRIDGE.end.y):
		for x in range(BRIDGE.position.x,BRIDGE.end.x):put(data,Vector2i(x,y),"F" if x<22 else "U")
	for x in [16,17,18]:put(data,Vector2i(x,19),"U")
static func changes(rows: Array,drained: bool,repaired: bool) -> Dictionary:
	var result: Dictionary={}
	if drained:
		for y in range(LOW_SHORE.position.y,LOW_SHORE.end.y):
			for x in range(LOW_SHORE.position.x,LOW_SHORE.end.x):
				if rows[y][x] in ["F","R","j"]:result[Vector2i(x,y)]="2"
		for y in [14,15]:
			for x in [31,32,33]:
				if rows[y][x] in ["F","R","j"]:result[Vector2i(x,y)]="2"
	if repaired:
		for y in range(BRIDGE.position.y,BRIDGE.end.y):
			for x in range(BRIDGE.position.x,BRIDGE.end.x):result[Vector2i(x,y)]="="
	return result
