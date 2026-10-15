extends RefCounted
## Original profession and workplace identities; input conventions stay consistent.
const COLORS:={"foraging":"84b98a","woodcutting":"c79a65","mining":"91b3c7","fishing":"70bec7","smithing":"e3a273","alchemy":"b1a0d1","cooking":"d7b77c","tools":"8cba90","guide":"d6bd88","supplies":"d6bd88","compost":"b7a275","wine":"ba95c3","hive":"e4c267","bed":"91beb7","wild_grape":"9cbd82"}
const ICONS:={"foraging":"prof_herb","woodcutting":"prof_axe","mining":"prof_pickaxe","fishing":"fishing_rod","smithing":"prof_copper_bar","alchemy":"prof_tonic","cooking":"prof_stew"}
static func accent(id: String) -> Color:return Color(COLORS.get(id,"91b9b0"))
static func title(id: String) -> String:
 match id:
  "foraging":return TranslationServer.translate("Veldboek · kruiden en zaden")
  "woodcutting":return TranslationServer.translate("Houtwerkbank · gereedschap en vlechtwerk")
  "mining":return TranslationServer.translate("Ertskaart · steen en metalen")
  "fishing":return TranslationServer.translate("Visboek · hengel en vangst")
  "smithing":return TranslationServer.translate("Smidswerkbank · smelten en smeden")
  "alchemy":return TranslationServer.translate("Mengtafel · kruiden en elixers")
  "cooking":return TranslationServer.translate("Keukenboek · gerechten en proviand")
 return TranslationServer.translate("Beroepen & ambachten")
static func intro(id: String) -> String:
 match id:
  "foraging":return TranslationServer.translate("Van bosvondst naar tuinzaad; lees bij elk recept welke planten je nodig hebt.")
  "woodcutting":return TranslationServer.translate("Werk met hout en vezels; werktekeningen verbinden gereedschap, uitrusting en inrichting.")
  "mining":return TranslationServer.translate("Begin met losse vuurstenen; een stenen pikhouweel opent koper, koper en niveau 2 openen ijzer.")
  "fishing":return TranslationServer.translate("Vis bij de kringen in het Zilvermeer; iedere echte vangst telt voor dit beroep.")
  "smithing":return TranslationServer.translate("Controleer erts, brandstof en niveau; Greta's smederij is je werkplek voor metaal.")
  "alchemy":return TranslationServer.translate("Kies een mengsel en bekijk de ingrediënten; bijzondere bereidingen vragen Lena's alchemietafel.")
  "cooking":return TranslationServer.translate("Vergelijk herstel en ingrediënten; snacks maak je onderweg, warme gerechten in de herberg.")
 return ""
static func tab(id: String) -> String:
 match id:
  "foraging":return TranslationServer.translate("Zaden & bereidingen")
  "woodcutting":return TranslationServer.translate("Werktekeningen")
  "mining":return TranslationServer.translate("Gereedschap")
  "fishing":return TranslationServer.translate("Vangst & hengel")
  "smithing":return TranslationServer.translate("Smelten & smeden")
  "alchemy":return TranslationServer.translate("Mengrecepten")
  "cooking":return TranslationServer.translate("Gerechten")
 return TranslationServer.translate("Maken")
static func style_panel(panel: PanelContainer,id: String):
 var style: StyleBoxFlat=load("res://scripts/core/ui_style.gd").flat(Color(.035,.055,.065,.97).lerp(accent(id),.07),accent(id),2)
 panel.add_theme_stylebox_override("panel",style)
static func style_button(button: Button,id: String):
 var style: Script=load("res://scripts/core/ui_style.gd");var color:=accent(id)
 button.add_theme_stylebox_override("normal",style.flat(Color(.055,.075,.085).lerp(color,.16),color.darkened(.28),1))
 button.add_theme_stylebox_override("hover",style.flat(Color(.08,.11,.12).lerp(color,.26),color,2))
 button.add_theme_stylebox_override("pressed",style.flat(Color(.08,.11,.12).lerp(color,.38),color.lightened(.18),2))
 button.add_theme_stylebox_override("disabled",style.flat(Color(.055,.065,.075),color.darkened(.65),1))
static func emblem(canvas: CanvasItem,id: String,center: Vector2,scale:=1.0):
 var color:=accent(id)
 canvas.draw_circle(center,25*scale,Color(color,.10))
 if id=="foraging":
  canvas.draw_line(center+Vector2(0,17)*scale,center+Vector2(0,-18)*scale,color,3*scale)
  for i in 3:
   var at:=center+Vector2(0,8-i*10)*scale
   canvas.draw_colored_polygon(PackedVector2Array([at,at+Vector2(-15,-8)*scale,at+Vector2(-9,3)*scale]),color)
   canvas.draw_colored_polygon(PackedVector2Array([at,at+Vector2(15,-8)*scale,at+Vector2(9,3)*scale]),color.lightened(.15))
 elif id=="woodcutting":
  canvas.draw_circle(center,19*scale,Color("99744f"));canvas.draw_circle(center,15*scale,Color("c49c6c"))
  for radius in [5,10,15]:canvas.draw_arc(center,radius*scale,.15,TAU-.2,24,Color("715a43"),scale)
 elif id=="mining":
  canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-22,12)*scale,center+Vector2(-11,-18)*scale,center+Vector2(7,-23)*scale,center+Vector2(23,4)*scale,center+Vector2(13,19)*scale]),Color("587482"))
  for at in [Vector2(-8,-6),Vector2(4,5),Vector2(9,-12)]:canvas.draw_rect(Rect2(center+at*scale,Vector2(7,7)*scale),color)
 elif id=="fishing":
  canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-19,0)*scale,center+Vector2(-7,-10)*scale,center+Vector2(11,-7)*scale,center+Vector2(18,0)*scale,center+Vector2(9,9)*scale,center+Vector2(-7,8)*scale]),color)
  canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-16,0)*scale,center+Vector2(-27,-9)*scale,center+Vector2(-27,9)*scale]),color.darkened(.2));canvas.draw_circle(center+Vector2(10,-2)*scale,2*scale,Color("192e36"))
 elif id=="smithing":
  canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-23,-13)*scale,center+Vector2(23,-13)*scale,center+Vector2(10,-3)*scale,center+Vector2(4,-3)*scale,center+Vector2(8,10)*scale,center+Vector2(18,16)*scale,center+Vector2(-18,16)*scale,center+Vector2(-8,10)*scale,center+Vector2(-5,-3)*scale,center+Vector2(-20,-3)*scale]),Color("a4b4b6"))
  canvas.draw_rect(Rect2(center+Vector2(-5,-20)*scale,Vector2(13,5)*scale),color)
 elif id=="alchemy":
  canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-5,-22)*scale,center+Vector2(5,-22)*scale,center+Vector2(5,-8)*scale,center+Vector2(18,15)*scale,center+Vector2(-18,15)*scale,center+Vector2(-5,-8)*scale]),Color("b8cccd"))
  canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-9,0)*scale,center+Vector2(9,0)*scale,center+Vector2(14,11)*scale,center+Vector2(-14,11)*scale]),color)
  for at in [Vector2(-2,5),Vector2(5,8)]:canvas.draw_circle(center+at*scale,2*scale,Color("e7dced"))
 else:
  canvas.draw_rect(Rect2(center+Vector2(-20,-7)*scale,Vector2(40,23)*scale),Color("9c7b55"));canvas.draw_rect(Rect2(center+Vector2(-23,-10)*scale,Vector2(46,5)*scale),color)
  for x in [-9,3,12]:canvas.draw_line(center+Vector2(x,-16)*scale,center+Vector2(x+3,-25)*scale,color.lightened(.2),2*scale)
