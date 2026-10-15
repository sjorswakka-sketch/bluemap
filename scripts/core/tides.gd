extends RefCounted
## One saved world clock, no real-time wait or separate tide save format.
const PERIOD:=96.0
const BANK:=Rect2i(20,25,12,2)
static func phase(day_time: float) -> float:return fposmod(day_time*480.0,PERIOD)
static func state(day_time: float) -> String:
	var t:=phase(day_time)
	if t<48:return "low"
	if t<60:return "rising"
	if t<84:return "high"
	return "falling"
static func label(day_time: float) -> String:
	match state(day_time):
		"low":return TranslationServer.translate("Laagwater · zandbank open")
		"rising":return TranslationServer.translate("Opkomend water · verlaat de zandbank")
		"high":return TranslationServer.translate("Hoogwater · neem het hoge pad")
	return TranslationServer.translate("Aflopend water · hoog pad blijft open")
static func prepare(data: Dictionary,day_time: float):
	if state(day_time) in ["high","falling"]:set_bank(data,"8")
static func set_bank(data: Dictionary,character: String):
	for y in range(BANK.position.y,BANK.end.y):
		var row: String=data.rows[y]
		for x in range(BANK.position.x,BANK.end.x):row[x]=character
		data.rows[y]=row
