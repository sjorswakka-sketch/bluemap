extends Control
## A field atlas: geography is authored; routes and discovery come from the game.
const Atlas := preload("res://scripts/core/world_atlas.gd")
const Pages := preload("res://scripts/ui/menu_pages.gd")
const PAPER := Color("d9d1ad")
const INK := Color("344d48")
const GOLD := Color("e3bd66")
const CURRENT := Color("ef8b70")
const VISITED := Color("4daca6")
const ORIGIN := Vector2(6,6)
const DETAIL := Rect2(632,0,320,382)
const ROW_TOP := 86.0
const ROW_HEIGHT := 29.0
const VISIBLE_ROWS := 7
var selected_region := "village"
var selected_locale := 0
var locale_scroll := 0
var focus_locales := false
var time := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if visible:
		time+=delta
		queue_redraw()

func open_current() -> void:
	selected_region=Atlas.current_region()
	if selected_region=="":selected_region="village"
	selected_locale=maxi(Atlas.locales(selected_region).find(Atlas.gs().map_id),0)
	focus_locales=false
	_follow_selection()
	queue_redraw()

func selected_map() -> String:
	var ids:=Atlas.locales(selected_region)
	return ids[clampi(selected_locale,0,ids.size()-1)]

func _follow_selection() -> void:
	var count:=Atlas.locales(selected_region).size()
	selected_locale=clampi(selected_locale,0,maxi(count-1,0))
	locale_scroll=clampi(locale_scroll,0,maxi(count-VISIBLE_ROWS,0))
	if selected_locale<locale_scroll:locale_scroll=selected_locale
	if selected_locale>=locale_scroll+VISIBLE_ROWS:locale_scroll=selected_locale-VISIBLE_ROWS+1

func navigate(action: String) -> void:
	if focus_locales:
		if action=="ui_left":focus_locales=false
		elif action in ["ui_up","ui_down"]:
			selected_locale+=-1 if action=="ui_up" else 1
			_follow_selection()
	else:
		var directions: Dictionary={"ui_up":Vector2.UP,"ui_down":Vector2.DOWN,"ui_left":Vector2.LEFT,"ui_right":Vector2.RIGHT}
		var next:=Atlas.neighbor(selected_region,directions.get(action,Vector2.ZERO))
		if next!=selected_region:
			selected_region=next;selected_locale=0;locale_scroll=0
	queue_redraw()

func confirm() -> void:
	focus_locales=true
	queue_redraw()

## True means the locale list consumed Back; false lets the menu show its local map.
func back() -> bool:
	if not focus_locales:return false
	focus_locales=false
	queue_redraw()
	return true

func pointer(at: Vector2) -> void:
	if DETAIL.has_point(at):
		var index:=locale_scroll+floori((at.y-ROW_TOP)/ROW_HEIGHT)
		if at.y>=ROW_TOP and at.y<ROW_TOP+VISIBLE_ROWS*ROW_HEIGHT and index<Atlas.locales(selected_region).size():
			selected_locale=index;focus_locales=true;_follow_selection()
	else:
		var closest:=22.0;var picked:=""
		for id: String in Atlas.REGIONS:
			var distance: float=at.distance_to(Atlas.REGIONS[id].at+ORIGIN)
			if distance<closest:closest=distance;picked=id
		if picked!="":
			selected_region=picked;selected_locale=0;locale_scroll=0;focus_locales=false
	queue_redraw()

func _poly(points: Array,color: Color) -> void:
	var shape:=PackedVector2Array()
	for p: Vector2 in points:shape.append(p+ORIGIN)
	draw_colored_polygon(shape,color)

func _shape(points: Array,color: Color,line: Color=Color.TRANSPARENT) -> void:
	_poly(points,color)
	if line.a>0:
		var path:=PackedVector2Array()
		for p: Vector2 in points:path.append(p+ORIGIN)
		path.append(points[0]+ORIGIN)
		draw_polyline(path,line,1.0,true)

func _line(points: Array,color: Color,width: float=1.0) -> void:
	var path:=PackedVector2Array()
	for p: Vector2 in points:path.append(p+ORIGIN)
	draw_polyline(path,color,width,true)

func _word(at: Vector2,text: String,font_size: int,color: Color,width: float=-1) -> void:
	draw_string(ThemeDB.fallback_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)

func _text(at: Vector2,text: String,font_size: int,color: Color,width: float) -> float:
	return Pages.text(self,ThemeDB.fallback_font,at,text,font_size,color,width)

## Bound long gate explanations to their own area, keeping the current location readable.
static func hint_lines(text: String) -> Array[String]:
	var lines: Array[String]=[]
	var line:=""
	var words:=text.replace("\n"," ").split(" ",false)
	var font:=ThemeDB.fallback_font
	for index in words.size():
		var candidate:=line+(" " if line!="" else "")+words[index]
		if line!="" and font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x>288:
			lines.append(line);line=words[index]
			if lines.size()==3:
				var last:=lines[2]
				while last.length()>0 and font.get_string_size(last+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,14).x>288:last=last.left(-1)
				lines[2]=last+"…"
				return lines
		else:line=candidate
	if line!="":lines.append(line)
	return lines

func hint_layout(text: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var font:=ThemeDB.fallback_font
	var baseline:=334.0
	for line: String in hint_lines(text):
		result.append({"text":line,"at":Vector2(648,baseline),"bottom":baseline+font.get_descent(14)})
		baseline+=font.get_height(14)
	return result

func _draw() -> void:
	if not Atlas.REGIONS.has(selected_region):return
	_draw_geography()
	_draw_routes()
	_draw_regions()
	_draw_details()
	_draw_legend()

func _draw_geography() -> void:
	draw_rect(Rect2(0,0,612,382),Color("708f91"))
	# Sparse engraved sea strokes sit beneath the continuous mainland and islands.
	for row in range(12,374,24):
		for column in range(12+(row%3)*7,606,42):
			draw_line(Vector2(column,row),Vector2(column+12,row),Color("8da8a2"),1)
	var mainland: Array=[Vector2(193,6),Vector2(312,4),Vector2(333,23),Vector2(389,18),Vector2(428,38),Vector2(442,80),Vector2(426,108),Vector2(434,137),Vector2(404,176),Vector2(373,207),Vector2(397,219),Vector2(448,215),Vector2(480,195),Vector2(543,190),Vector2(565,209),Vector2(563,236),Vector2(536,252),Vector2(483,252),Vector2(458,271),Vector2(415,276),Vector2(389,262),Vector2(346,267),Vector2(332,294),Vector2(308,323),Vector2(270,324),Vector2(249,291),Vector2(216,300),Vector2(208,332),Vector2(178,363),Vector2(90,365),Vector2(66,338),Vector2(77,309),Vector2(62,277),Vector2(72,244),Vector2(67,205),Vector2(90,176),Vector2(163,178),Vector2(191,159),Vector2(194,125),Vector2(207,98),Vector2(191,64)]
	# Offset shadow and two subtle contour lines suggest an old engraved coastline.
	var shadow: Array=[]
	for p: Vector2 in mainland:shadow.append(p+Vector2(2,4))
	_shape(shadow,Color("4e777b"))
	_shape(mainland,Color("b9ba8b"),Color("536e60"))
	_shape([Vector2(202,7),Vector2(309,6),Vector2(330,26),Vector2(388,22),Vector2(420,43),Vector2(397,77),Vector2(356,94),Vector2(319,116),Vector2(244,106),Vector2(209,91),Vector2(198,56)],Color("d2d6c0"))
	_shape([Vector2(337,96),Vector2(403,88),Vector2(427,116),Vector2(409,152),Vector2(383,172),Vector2(352,151)],Color("cbb581"))
	_shape([Vector2(202,114),Vector2(255,104),Vector2(313,120),Vector2(349,157),Vector2(326,202),Vector2(302,228),Vector2(238,231),Vector2(204,209),Vector2(181,176)],Color("8aab88"))
	_shape([Vector2(84,306),Vector2(135,308),Vector2(183,324),Vector2(171,355),Vector2(100,357),Vector2(77,335)],Color("8b9c7b"))
	_shape([Vector2(246,284),Vector2(275,264),Vector2(320,268),Vector2(330,291),Vector2(307,316),Vector2(274,315)],Color("d1c291"))
	_shape([Vector2(394,303),Vector2(425,290),Vector2(458,299),Vector2(472,322),Vector2(459,344),Vector2(420,349),Vector2(396,336)],Color("bbbc90"),Color("536e60"))
	_shape([Vector2(487,308),Vector2(512,296),Vector2(541,299),Vector2(561,318),Vector2(552,339),Vector2(521,346),Vector2(494,337)],Color("c8bb91"),Color("536e60"))
	# The lake and estuary are recognizable shapes without inventing global rivers.
	_shape([Vector2(88,262),Vector2(102,252),Vector2(134,254),Vector2(149,265),Vector2(147,290),Vector2(132,300),Vector2(104,295),Vector2(91,283)],Color("779b9a"),Color("5e8180"))
	_line([Vector2(286,238),Vector2(285,257),Vector2(294,271),Vector2(301,295),Vector2(321,309)],Color("789c9b"),7)
	# Terrain illustrations are deterministic and only sharpen where exploration is confirmed.
	for id: String in Atlas.REGIONS:
		var p: Vector2=Atlas.REGIONS[id].at
		var known:=Atlas.region_state(id)>0
		_draw_biome(p,str(Atlas.REGIONS[id].biome),known)
		if not known:
			for j in 3:
				var cloud:=p+Vector2((j-1)*14,-5+(j%2)*5)
				draw_circle(cloud+ORIGIN,19,Color(0.85,0.84,0.74,0.48))
	# Compass and compact discovery ribbon leave the mountainous north unobstructed.
	draw_rect(Rect2(12,10,166,24),Color(0.15,0.24,0.23,0.85))
	_word(Vector2(21,27),tr("%d / %d plekken bezocht") % [Atlas.visited_count(),Atlas.Maps.MAPS.size()],13,PAPER,150)
	_line([Vector2(31,46),Vector2(31,72)],INK,1)
	_line([Vector2(22,59),Vector2(40,59)],INK,1)
	_poly([Vector2(31,42),Vector2(27,56),Vector2(35,56)],INK)
	_word(Vector2(32,44),tr("N"),12,INK)
	draw_rect(Rect2(0,0,612,382),Color("c7c3a1"),false,2)

func _draw_biome(p: Vector2,biome: String,known: bool) -> void:
	var dark:=Color("5e7662") if known else Color("8d9b82")
	var light:=Color("e2dfc5") if known else Color("c8cbb2")
	match biome:
		"peak","snow","ridge","canyon":
			for j in 3:
				var at:=p+Vector2((j-1)*19,-12+abs(j-1)*7)
				_poly([at+Vector2(-16,9),at+Vector2(0,-17),at+Vector2(18,9)],dark)
				_poly([at+Vector2(-6,-7),at+Vector2(0,-17),at+Vector2(7,-6),at+Vector2(2,-9),at+Vector2(-2,-5)],light)
			if biome=="peak" and known:
				for j in 2:_line([p+Vector2(20+j*7,-17),p+Vector2(17+j*7,-23),p+Vector2(20+j*7,-28)],Color("9aa498"),1)
		"forest","mist","edge","garden":
			for j in 7:
				var at:=p+Vector2((j%4)*13-21,(j/4)*17-18)
				_line([at+Vector2(0,5),at+Vector2(0,10)],dark)
				_poly([at+Vector2(-7,5),at+Vector2(0,-9),at+Vector2(7,5)],dark)
		"town","port":
			for j in 3:
				var at:=p+Vector2((j-1)*17,-8+(j%2)*4)
				draw_rect(Rect2(at+Vector2(-5,-3)+ORIGIN,Vector2(11,10)),light)
				_poly([at+Vector2(-8,-3),at+Vector2(0,-10),at+Vector2(8,-3)],dark)
		"dunes":
			for j in 4:_line([p+Vector2(-30+j*15,3),p+Vector2(-19+j*15,-8),p+Vector2(-8+j*15,3)],dark)
		"marsh":
			for j in 6:
				var at:=p+Vector2((j%3)*19-21,(j/3)*13-8)
				_line([at+Vector2(-6,4),at+Vector2(7,4)],Color("6e8a7a"))
				_line([at+Vector2(0,4),at+Vector2(0,-8)],dark)
				_line([at+Vector2(0,-3),at+Vector2(-4,-7)],dark)
		"cape":
			_poly([p+Vector2(-6,4),p+Vector2(-4,-19),p+Vector2(4,-19),p+Vector2(6,4)],light)
			_line([p+Vector2(-7,-20),p+Vector2(7,-20)],dark,3)
		"island","cove":
			for j in 3:_line([p+Vector2(-28+j*19,8),p+Vector2(-20+j*19,-1),p+Vector2(-11+j*19,8)],dark)
		"yard":
			_line([p+Vector2(-17,-7),p+Vector2(17,-7),p+Vector2(17,10)],dark)
			_line([p+Vector2(-17,10),p+Vector2(-17,-7)],dark)

func _route_points(edge: Dictionary) -> PackedVector2Array:
	var a: Vector2=Atlas.REGIONS[edge.a].at+ORIGIN
	var b: Vector2=Atlas.REGIONS[edge.b].at+ORIGIN
	var points:=PackedVector2Array()
	var bend:=Vector2.ZERO
	if edge.mode=="ferry":bend=Vector2(0,32)
	elif [edge.a,edge.b]==["dauwbos","dorstvallei"]:bend=Vector2(0,13)
	for i in 25:
		var t:=float(i)/24.0
		points.append(a.lerp(b,t)+sin(t*PI)*bend)
	return points

func _draw_routes() -> void:
	for edge: Dictionary in Atlas.connections():
		var known:=Atlas.region_state(edge.a)>0 or Atlas.region_state(edge.b)>0
		var points:=_route_points(edge)
		var color:=Color("716e51") if known else Color(0.42,0.46,0.38,0.32)
		if edge.mode=="ferry":
			color=Color("425e65") if known else Color(0.25,0.37,0.39,0.3)
			for i in range(0,points.size()-1,3):draw_line(points[i],points[mini(i+1,points.size()-1)],color,1.5,true)
		else:
			draw_polyline(points,Color("d9d0a1") if known else Color(0.82,0.80,0.65,0.25),4,true)
			draw_polyline(points,color,1.25,true)
		if known and Atlas.connection_locked(edge):
			var middle: Vector2=points[12]
			draw_rect(Rect2(middle-Vector2(3,1),Vector2(6,6)),INK)
			draw_arc(middle-Vector2(0,1),2.5,PI,TAU,8,INK,1.5)

func _diamond(center: Vector2,radius: float,color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0)]),color)

## Measure translated labels once per language; anchors do not shift as exploration grows.
var _label_locale: String=""
var _labels: Array[Dictionary]=[]
func label_layout() -> Array[Dictionary]:
	var locale:=TranslationServer.get_locale()
	if locale==_label_locale and not _labels.is_empty():return _labels
	_label_locale=locale;_labels.clear()
	var font:=ThemeDB.fallback_font
	for id: String in Atlas.REGIONS:
		var region: Dictionary=Atlas.REGIONS[id]
		var label:=tr(str(region.label))
		var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		var at:=Vector2(float(region.get("label_x",region.at.x))-width/2.0,float(region.label_y))+ORIGIN
		var rect:=Rect2(at+Vector2(-3,-font.get_ascent(12)-1),Vector2(width+6,font.get_height(12)+2))
		var center: Vector2=region.at+ORIGIN
		_labels.append({"id":id,"text":label,"at":at,"rect":rect,"center":center,"leader":absf(float(region.get("label_x",region.at.x))-region.at.x)>0.5})
	return _labels

func _draw_regions() -> void:
	for id: String in Atlas.REGIONS:
		var p: Vector2=Atlas.REGIONS[id].at+ORIGIN
		var state:=Atlas.region_state(id)
		if id==selected_region:
			draw_circle(p,13,Color(0.19,0.26,0.24,0.75))
			draw_arc(p,15,0,TAU,32,GOLD,2.5 if not focus_locales else 1)
		if state==2:
			draw_arc(p,11+sin(time*3)*1.5,0,TAU,24,CURRENT,2)
			_diamond(p,7,CURRENT);draw_circle(p,2,PAPER)
		elif state==1:
			draw_circle(p,6,INK);draw_circle(p,4,VISITED)
		else:
			draw_circle(p,6,Color("b9bba1"));draw_arc(p,6,0,TAU,16,INK,1)
			_word(p+Vector2(-3.5,4),"?",11,INK)
		if state==2 and Atlas.gs().map_id!=id:
			draw_rect(Rect2(p+Vector2(9,-11),Vector2(9,8)),INK)
			_poly([p-ORIGIN+Vector2(7,-11),p-ORIGIN+Vector2(13,-17),p-ORIGIN+Vector2(20,-11)],INK)
	for label: Dictionary in label_layout():
		if Atlas.region_state(label.id)==0:continue
		if label.leader:
			var edge:=Vector2(clampf(label.center.x,label.rect.position.x,label.rect.end.x),clampf(label.center.y,label.rect.position.y,label.rect.end.y))
			var start: Vector2=label.center+(edge-label.center).normalized()*8
			draw_line(start,edge,Color(0.22,0.31,0.28,0.65),1,true)
		draw_rect(label.rect,Color(0.87,0.86,0.73,0.88))
		_word(label.at,label.text,12,INK)

func _draw_details() -> void:
	draw_rect(DETAIL,Color("182c34"))
	draw_rect(DETAIL, GOLD if focus_locales else Color("4d6e72"),false,2)
	draw_multiline_string(ThemeDB.fallback_font,Vector2(648,28),Atlas.region_title(selected_region),HORIZONTAL_ALIGNMENT_LEFT,288,20,2,Color("dce8df"))
	var title_height:=minf(ThemeDB.fallback_font.get_multiline_string_size(Atlas.region_title(selected_region),HORIZONTAL_ALIGNMENT_LEFT,288,20).y,48)
	var status:=tr("%d / %d plekken bezocht") % [Atlas.visited_count(selected_region),Atlas.locales(selected_region).size()]
	_word(Vector2(648,mini(title_height+31,75)),status,14,Color("a4bdb8"),288)
	var ids:=Atlas.locales(selected_region)
	for i in range(locale_scroll,mini(locale_scroll+VISIBLE_ROWS,ids.size())):
		var id: String=ids[i]
		var y:=ROW_TOP+(i-locale_scroll)*ROW_HEIGHT
		var chosen:=selected_locale==i
		if chosen:
			draw_rect(Rect2(641,y,300,ROW_HEIGHT-3),Color("35535a"))
			draw_rect(Rect2(641,y,3,ROW_HEIGHT-3),GOLD)
		var state:=Atlas.state(id)
		if state==2:_diamond(Vector2(655,y+12),5,CURRENT)
		elif state==1:draw_circle(Vector2(655,y+12),4,VISITED)
		else:draw_arc(Vector2(655,y+12),4,0,TAU,12,Color("87988c"),1)
		_word(Vector2(668,y+17),Atlas.display_title(id),14,Color("e0e5d6") if state>0 else Color("9aaea9"),259)
	if ids.size()>VISIBLE_ROWS:
		draw_rect(Rect2(945,ROW_TOP,3,ROW_HEIGHT*VISIBLE_ROWS-3),Color("395054"))
		var thumb:=maxf(22,(ROW_HEIGHT*VISIBLE_ROWS-3)*VISIBLE_ROWS/ids.size())
		var thumb_y:=ROW_TOP+float(locale_scroll)/maxi(ids.size()-VISIBLE_ROWS,1)*(ROW_HEIGHT*VISIBLE_ROWS-3-thumb)
		draw_rect(Rect2(945,thumb_y,3,thumb),GOLD)
		_word(Vector2(914,76),"%d/%d" % [selected_locale+1,ids.size()],12,Color("a4bdb8"))
	var selected:=selected_map()
	var tag:=tr("Hier binnen") if Atlas.state(selected)==2 and not Atlas.REGIONS.has(selected) else tr("Huidige plek") if Atlas.state(selected)==2 else tr("Bezocht") if Atlas.visited(selected) else tr("Nog onbekend")
	_word(Vector2(648,312),Atlas.kind(selected)+" · "+tag,13,GOLD,288)
	for line: Dictionary in hint_layout(Atlas.route_hint(selected)):_word(line.at,line.text,14,Color("c2d2c8"),288)
	_word(Vector2(648,403),tr("Binnen: %s") % Atlas.title(Atlas.gs().map_id) if Atlas.gs().map_id!=Atlas.current_region() else tr("Je bent in %s") % Atlas.title(Atlas.gs().map_id),13,Color("a4bdb8"),288)

func _draw_legend() -> void:
	_diamond(Vector2(9,402),5,CURRENT)
	_word(Vector2(21,406),tr("Huidige plek"),12,Color("d8e3d7"))
	draw_circle(Vector2(126,402),4,VISITED)
	_word(Vector2(136,406),tr("Bezocht"),12,Color("d8e3d7"))
	draw_arc(Vector2(212,402),4,0,TAU,12,Color("b1c1b0"),1)
	_word(Vector2(223,406),tr("Onbekend"),12,Color("d8e3d7"))
	draw_line(Vector2(309,402),Vector2(327,402),Color("c3c599"),2)
	_word(Vector2(334,406),tr("Pad"),12,Color("d8e3d7"))
	for j in 3:draw_line(Vector2(377+j*7,402),Vector2(381+j*7,402),Color("9cbdbe"),1)
	_word(Vector2(402,406),tr("Veerboot"),12,Color("d8e3d7"))
	draw_rect(Rect2(479,399,6,6),GOLD)
	draw_arc(Vector2(482,398),2.5,PI,TAU,8,GOLD,1.5)
	_word(Vector2(494,406),tr("Gesloten route"),12,Color("d8e3d7"))
