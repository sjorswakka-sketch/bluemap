"""Original pixel drawings and data for 16 wild fruits and 16 culinary nuts."""
from pathlib import Path
import json, math
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent.parent
# ID, Dutch item, English item, Dutch plant, English plant, biome, palette.
FRUIT=[
("blueberry","Blauwe bosbes","Blueberry","Blauwe bosbessenstruik","Blueberry bush","bos","6e83bb"),
("raspberry","Framboos","Raspberry","Frambozenstruik","Raspberry canes","bos","d86679"),
("blackberry","Braam","Blackberry","Braamstruweel","Blackberry bramble","bos","685978"),
("redcurrant","Rode bes","Redcurrant","Rodebessenstruik","Redcurrant bush","oever","d05d5d"),
("blackcurrant","Zwarte bes","Blackcurrant","Zwartebessenstruik","Blackcurrant bush","bos","63516f"),
("gooseberry","Kruisbes","Gooseberry","Kruisbessenstruik","Gooseberry bush","bos","b3bd79"),
("wild_strawberry","Bosaardbei","Wild strawberry","Bosaardbeien","Wild strawberries","bos","df775e"),
("rosehip","Rozenbottel","Rosehip","Wilde rozenbottels","Wild rosehips","kust","d6875e"),
("lingonberry","Vossenbes","Lingonberry","Vossenbessenstruik","Lingonberry bush","sneeuw","c56767"),
("cranberry","Veenbes","Cranberry","Veenbessenstruik","Cranberry runners","moeras","b85368"),
("sea_buckthorn","Duindoornbes","Sea buckthorn berry","Duindoornstruik","Sea buckthorn","kust","dba85e"),
("wild_apple","Wilde appel","Crab apple","Wilde appelboom","Crab apple tree","bos","c9a063"),
("wild_pear","Wilde peer","Wild pear","Wilde perenboom","Wild pear tree","oever","c3bc7c"),
("wild_plum","Wilde pruim","Wild plum","Wilde pruimenboom","Wild plum tree","oever","9b7ba9"),
("grape","Bosdruif","Wild grape","Wilde druivenrank","Wild grapevine","bos","a17baf"),
("cactusfig","Cactusvijg","Prickly pear","Cactusvijgen","Prickly pear cactus","woestijn","c87b86"),
]
NUTS=[
("hazelnut","Hazelnoot","Hazelnut","Hazelaar","Hazel shrub","bos","b58d60"),
("walnut","Walnoot","Walnut","Walnotenboom","Walnut tree","bos","ad986f"),
("chestnut","Tamme kastanje","Sweet chestnut","Tamme kastanjeboom","Sweet chestnut tree","bos","a46c4c"),
("beechnut","Beukennootje","Beechnut","Beukennootjes","Beech mast","bos","bc9c74"),
("pine_nut","Pijnboompit","Pine nut","Dennenappels van de parasolden","Stone pine cones","kust","c4b38a"),
("almond","Amandel","Almond","Amandelboom","Almond tree","woestijn","c5a279"),
("pistachio","Pistache","Pistachio","Pistacheboom","Pistachio tree","woestijn","b4b88a"),
("pecan","Pecannoot","Pecan","Pecannotenboom","Pecan tree","oever","aa805c"),
("black_walnut","Zwarte walnoot","Black walnut","Zwarte walnotenboom","Black walnut tree","bos","807357"),
("hickory","Hickorynoot","Hickory nut","Hickoryboom","Hickory tree","oever","c4ae7e"),
("butternut","Boternoot","Butternut","Boternotenboom","Butternut tree","bos","bea36d"),
("macadamia","Macadamianoot","Macadamia nut","Macadamiaboom","Macadamia tree","warme kust","b9b495"),
("cashew","Cashewnoot","Cashew nut","Cashewboom","Cashew tree","warme kust","d6c4a1"),
("japanese_walnut","Japanse walnoot","Japanese walnut","Japanse walnotenboom","Japanese walnut tree","warme berghelling","c39e7a"),
("coconut","Kokosnoot","Coconut","Aangespoelde kokosnoten","Washed-up coconuts","kust","b0997c"),
("cedar_nut","Siberische cedernoot","Siberian pine nut","Cederdennenappels","Siberian pine cones","sneeuw","b7b896"),
]
CATALOG=FRUIT+NUTS
ALIASES={"blueberry":"prof_berry","lingonberry":"prof_winterbes","cranberry":"prof_veenbes","grape":"hs_grape","cactusfig":"prof_cactusvijg","hazelnut":"trail_nut"}
LEGACY={"berries":"blueberry","frostberries":"lingonberry","veenbessen":"cranberry","cactusfigs":"cactusfig"}
HABITAT={
 "bos":("Zoek in lichte bosranden en beschutte open plekken.","Look along light woodland edges and sheltered clearings."),
 "oever":("Zoek op droge, voedselrijke rivier- en meeroevers.","Look on dry, fertile river and lake banks."),
 "kust":("Zoek op zonnige duinranden en droge kustoevers.","Look on sunny dune edges and dry coastal shores."),
 "moeras":("Zoek op droge veenranden naast het moeraswater.","Look on dry peat edges beside marsh water."),
 "sneeuw":("Zoek tussen lage naaldbomen en beschutte sneeuwranden.","Look among low conifers and sheltered snowy verges."),
 "woestijn":("Zoek in beschutte oasekommen en langs zonnige zandhellingen.","Look in sheltered oasis bowls and on sunny sandy slopes."),
 "warme kust":("Zoek in warme, beschutte kustkommen uit de zeewind.","Look in warm, sheltered coastal bowls out of the sea wind."),
 "warme berghelling":("Zoek op beschutte berghellingen bij warme bronnen.","Look on sheltered mountain slopes near warm springs."),
}
DARK="#334b43"; BARK="#775e4b"; LEAF="#72896a"; LIGHT="#a9b486"
def rgb(c):return "#"+c
def ellipse(d,box,col,outline=DARK):
 d.ellipse(box,fill=outline)
 if box[2]-box[0]>2 and box[3]-box[1]>2:d.ellipse((box[0]+1,box[1]+1,box[2]-1,box[3]-1),fill=col)
def berry(d,x,y,col,r=2):
 d.ellipse((x-r,y-r,x+r,y+r),fill=DARK);d.ellipse((x-r+1,y-r+1,x+r,y+r),fill=col);d.point((x,y-1),fill="#ead8bd")
def branch(d,points,col=BARK,width=2):d.line(points,fill=col,width=width)
def fruit_shape(d,k,x,y,col,scale=1):
 if k in ["raspberry","blackberry"]:
  for dx,dy in [(-2,-2),(1,-2),(-3,1),(0,1),(2,1),(-1,3)]:berry(d,x+dx*scale,y+dy*scale,col,scale)
 elif k=="wild_strawberry":
  d.polygon([(x-4,y-3),(x+4,y-3),(x+3,y+2),(x,y+6),(x-3,y+2)],fill=DARK)
  d.polygon([(x-3,y-2),(x+3,y-2),(x+2,y+2),(x,y+5),(x-2,y+2)],fill=col)
  d.line((x-4,y-3,x+4,y-3),fill="#91a77a",width=2)
  for dx,dy in [(-1,0),(1,1),(0,3)]:d.point((x+dx,y+dy),fill="#ebd69a")
 elif k in ["wild_pear","cactusfig","rosehip"]:
  ellipse(d,(x-2,y-5,x+2,y),col);ellipse(d,(x-4,y-1,x+4,y+5),col)
  d.line((x,y-6,x+1,y-8),fill=BARK)
  if k=="cactusfig":
   for dx,dy in [(-2,1),(2,2),(0,-2)]:d.point((x+dx,y+dy),fill="#f0c5aa")
 elif k=="wild_apple":
  ellipse(d,(x-5,y-3,x+1,y+5),col);ellipse(d,(x-1,y-3,x+5,y+5),col);branch(d,[(x,y-3),(x+1,y-6)],width=1);d.line((x+1,y-5,x+4,y-5),fill="#91a77a")
 elif k=="wild_plum":
  ellipse(d,(x-4,y-5,x+4,y+5),col);d.line((x+1,y-3,x+1,y+3),fill="#b69bc4")
 elif k=="grape":
  for dx,dy in [(-3,-3),(2,-3),(-4,1),(1,1),(-1,5)]:berry(d,x+dx,y+dy,col,2)
  d.line((x-1,y-6,x+2,y-8),fill=BARK)
 elif k=="gooseberry":
  ellipse(d,(x-5,y-4,x+5,y+5),col)
  for dx in [-2,1,3]:d.line((x+dx,y-2,x+dx,y+3),fill="#d4d4a5")
  d.point((x,y+5),fill="#775e4b")
 else:
  for dx,dy in [(-3,-2),(3,-1),(0,4)]:berry(d,x+dx,y+dy,col,2)
def nut_shape(d,k,x,y,col):
 if k=="coconut":
  ellipse(d,(x-6,y-6,x+6,y+6),BARK);ellipse(d,(x-4,y-5,x+5,y+4),"#dbd6be");ellipse(d,(x-2,y-3,x+3,y+2),"#f0e6cd")
  d.line((x-4,y+6,x+3,y+6),fill="#ad8763")
 elif k in ["pine_nut","cedar_nut"]:
  for dx,dy in [(-3,1),(1,-3),(3,3)]:
   ellipse(d,(x+dx-2,y+dy-4,x+dx+2,y+dy+3),col);d.line((x+dx-1,y+dy-2,x+dx-1,y+dy+1),fill="#eee0bd")
 elif k=="cashew":
  d.arc((x-5,y-5,x+5,y+5),30,300,fill=DARK,width=5);d.arc((x-4,y-4,x+4,y+4),30,300,fill=col,width=3)
 elif k=="pistachio":
  ellipse(d,(x-5,y-5,x+5,y+5),"#d5c8a6");d.polygon([(x-2,y-4),(x+2,y-3),(x+3,y+2),(x,y+4),(x-2,y+2)],fill="#8eaa69");d.line((x-1,y-4,x-2,y+3),fill="#755a6c")
 elif k in ["almond","pecan","butternut"]:
  d.polygon([(x,y-7),(x+4,y-3),(x+5,y+2),(x+2,y+6),(x-2,y+6),(x-4,y+2),(x-3,y-3)],fill=DARK)
  d.polygon([(x,y-6),(x+3,y-2),(x+3,y+2),(x+1,y+5),(x-1,y+4),(x-3,y+1),(x-2,y-3)],fill=col)
  for dx in [-1,1]:d.line((x+dx,y-3,x+dx,y+3),fill="#e0c399" if k!="pecan" else "#725741")
 elif k=="beechnut":
  d.polygon([(x,y-6),(x+6,y+4),(x-5,y+5)],fill=DARK);d.polygon([(x,y-4),(x+4,y+3),(x-3,y+4)],fill=col);d.line((x,y-3,x,y+3),fill="#e6cc9b")
 elif k=="chestnut":
  d.polygon([(x,y-6),(x+5,y-1),(x+5,y+4),(x+2,y+6),(x-4,y+5),(x-5,y+1)],fill=DARK)
  d.polygon([(x,y-5),(x+4,y),(x+4,y+4),(x-3,y+4),(x-4,y)],fill=col);d.line((x-3,y+5,x+3,y+5),fill="#dbbd8e");d.line((x-2,y-1,x-2,y+2),fill="#d8a176")
 elif k in ["walnut","black_walnut","japanese_walnut"]:
  ellipse(d,(x-5,y-6,x+5,y+6),col)
  d.line((x,y-5,x+1,y-2,x-1,y+1,x+1,y+4),fill="#6b604c")
  for dx,dy in [(-3,-2),(2,0),(-2,3)]:d.line((x+dx,y+dy,x+dx+1,y+dy+1),fill="#e1c4a0")
  if k=="japanese_walnut":d.line((x-1,y+5,x+1,y+5),fill="#e5c197")
 elif k=="hazelnut":
  ellipse(d,(x-5,y-3,x+5,y+6),col);d.polygon([(x-6,y-3),(x-3,y-6),(x+2,y-5),(x+6,y-2),(x+2,y),(x-2,y-1)],fill="#85936c");d.line((x-2,y+2,x-2,y+4),fill="#e9c795")
 elif k=="hickory":
  ellipse(d,(x-5,y-5,x+5,y+5),col);d.line((x,y-4,x,y+4),fill="#71664f");d.line((x-4,y,x+4,y),fill="#71664f");d.point((x-2,y-2),fill="#eddbaf")
 else:
  ellipse(d,(x-5,y-5,x+5,y+5),col);ellipse(d,(x-2,y-2,x+3,y+3),"#e9dbb7");d.line((x-4,y-2,x-2,y-4),fill="#c9c58c")
def plant(index,entry):
 k,n,en,p,ep,biome,c=entry;col=rgb(c);im=Image.new("RGBA",(32,32));d=ImageDraw.Draw(im)
 d.ellipse((4,26,28,30),fill="#596b54")
 if biome in ["sneeuw","warme berghelling"]:d.line((4,27,10,28),fill="#c7dbe0",width=2);d.line((25,28,29,27),fill="#c7dbe0",width=2)
 if k=="coconut":
  branch(d,[(10,27),(9,24),(15,23),(19,26),(25,27)],width=1)
  nut_shape(d,k,16,21,col);d.line((22,17,28,11),fill="#9baa77",width=2);return im
 if k=="cactusfig":
  for box in [(12,9,20,28),(5,14,13,23),(21,12,28,22)]:ellipse(d,box,"#81996e")
  for x,y in [(9,17),(16,13),(16,22),(24,15)]:d.point((x,y),fill="#d5d0a0")
  for x,y in [(8,13),(17,8),(25,11)]:ellipse(d,(x-2,y-3,x+2,y+1),col)
  return im
 low=k in ["wild_strawberry","lingonberry","cranberry","beechnut","pine_nut","cedar_nut"]
 if low:
  branch(d,[(4,25),(12,22),(20,24),(27,21)],width=1)
  if k in ["pine_nut","cedar_nut"]:
   for x,y in [(8,17),(17,15),(24,19)]:
    branch(d,[(x,y),(x-4,y-4)],"#6f8d7e",1);branch(d,[(x,y),(x+4,y-5)],"#8ea899",1)
    for yy in [y,y+2,y+4]:
     d.polygon([(x,yy-2),(x+3,yy),(x,yy+3),(x-3,yy)],fill=col);d.point((x-1,yy),fill="#e1cba1")
  elif k=="beechnut":
   for x,y in [(8,24),(17,21),(24,25)]:
    d.line((x-4,y-4,x+3,y+3),fill="#a4ae7c",width=2);d.polygon([(x,y-3),(x+3,y+2),(x-2,y+3)],fill=col);d.point((x,y),fill="#e8cba1")
  else:
   for x,y in [(7,20),(15,17),(24,21)]:
    ellipse(d,(x-4,y-4,x+3,y),"#7b9872")
    if k=="wild_strawberry":d.polygon([(x-3,y+1),(x+2,y+1),(x,y+5)],fill=col);d.point((x,y+2),fill="#e9d1a0")
    else:berry(d,x+1,y+3,col,2)
  return im
 if k in ["rosehip","sea_buckthorn","grape","raspberry","blackberry"]:
  stems=[[(15,28),(11,16),(6,8)],[(16,28),(19,15),(25,7)],[(15,23),(17,9),(15,3)]]
  for pts in stems:branch(d,pts)
  leaves=[(5,10),(10,16),(17,9),(23,11),(20,19),(11,23)]
  for x,y in leaves:
   if k=="sea_buckthorn":d.polygon([(x-3,y+2),(x+4,y-2),(x+2,y+2)],fill="#9cae9b")
   else:ellipse(d,(x-3,y-2,x+3,y+2),"#79966e")
  for x,y in [(7,14),(23,15),(16,11),(13,22)]:
   if k=="grape":
    for dx,dy in [(-2,0),(1,0),(0,3)]:berry(d,x+dx,y+dy,col,1)
   else:berry(d,x,y,col,2)
  return im
 if index>=16:
  def leaf(x,y,dx,dy,color="#80976c"):
   # A pointed leaf, its midrib and one lit edge are all drawn on the pixel grid.
   ex=x+dx;ey=y+dy
   side=2 if abs(dx)+abs(dy)>5 else 1
   if abs(dx)>abs(dy):
    points=[(x,y),(x+dx//2,y+dy//2-side),(ex,ey),(x+dx//2,y+dy//2+side)]
   else:
    points=[(x,y),(x+dx//2-side,y+dy//2),(ex,ey),(x+dx//2+side,y+dy//2)]
   d.polygon(points,fill=DARK)
   d.line((x,y,ex,ey),fill=color,width=2 if side==2 else 1)
   d.point((ex,ey),fill="#bbbf91")
  def kernel(x,y):
   ellipse(d,(x-2,y-2,x+2,y+2),col);d.point((x-1,y-1),fill="#e8caa1")
  if k=="hazelnut":
   branch(d,[(14,28),(12,17),(8,9)]);branch(d,[(14,27),(20,17),(25,12)])
   for x,y in [(6,10),(12,15),(22,12),(21,19)]:ellipse(d,(x-4,y-3,x+4,y+3),"#8ca379")
   for x,y in [(8,19),(17,22),(25,20)]:
    kernel(x,y);d.line((x-3,y-2,x+2,y-2),fill="#a0a97a",width=2)
  elif k=="walnut":
   branch(d,[(4,27),(13,20),(25,9)],width=2)
   for x,y in [(9,23),(13,19),(17,15),(21,11)]:
    leaf(x,y,-5,-4);leaf(x,y,5,0,"#94a77b")
   for x,y in [(8,27),(21,24)]:kernel(x,y);d.line((x,y-2,x,y+2),fill="#77684d")
  elif k=="chestnut":
   branch(d,[(4,26),(15,19),(24,8)])
   for x,y in [(9,23),(16,17),(22,11)]:
    leaf(x,y,-7,-4,"#9ca876");leaf(x,y,6,2,"#7f9765")
    d.point((x-5,y-4),fill="#b8bd82")
   for x,y in [(10,25),(25,23)]:
    d.polygon([(x,y-4),(x+2,y-3),(x+4,y),(x+3,y+2),(x,y+4),(x-3,y+2),(x-4,y),(x-2,y-3)],fill="#8fa06c")
    d.polygon([(x,y-2),(x+2,y+2),(x-2,y+2)],fill=col)
  elif k=="almond":
   branch(d,[(14,28),(14,14),(10,4)]);branch(d,[(14,18),(22,9)]);branch(d,[(14,22),(5,16)])
   for x,y,dx,dy in [(10,8,-4,-3),(14,12,3,-6),(21,10,5,0),(9,18,-4,3),(18,17,5,3)]:leaf(x,y,dx,dy,"#a3aa7d")
   for x,y in [(8,13),(23,13),(17,24)]:ellipse(d,(x-1,y-3,x+2,y+2),col);d.line((x,y-1,x,y+1),fill="#e4c69a")
   d.line((9,5,12,5),fill="#d7b5b0")
  elif k=="pistachio":
   branch(d,[(8,27),(12,13),(22,7)],width=2)
   for x,y in [(11,12),(17,9),(23,7)]:
    for dx,dy in [(-5,1),(1,-5),(5,3)]:leaf(x,y,dx,dy,"#99aa7c")
   for x,y in [(10,21),(19,17),(25,13)]:
    ellipse(d,(x-2,y-2,x+2,y+2),"#caa09d");d.line((x,y-1,x,y+1),fill="#9ba86d")
  elif k=="pecan":
   branch(d,[(3,25),(14,18),(27,17)],width=2)
   for x,y in [(7,22),(12,19),(18,17),(24,17)]:
    leaf(x,y,-2,-7,"#8fa473");leaf(x,y,3,5,"#6f9369")
   for x,y in [(8,26),(19,25),(26,23)]:ellipse(d,(x-1,y-3,x+2,y+2),col);d.line((x,y-2,x,y+1),fill="#6c5744")
  elif k=="black_walnut":
   branch(d,[(4,27),(15,12),(26,10)],width=2)
   for x,y in [(9,20),(13,14),(18,11),(24,10)]:
    leaf(x,y,-4,-5,"#63866b");leaf(x,y,4,4,"#89a076")
   for x,y in [(8,26),(21,23)]:
    ellipse(d,(x-3,y-3,x+3,y+3),"#718260");kernel(x,y)
    d.point((x+1,y+1),fill="#534e3e")
  elif k=="hickory":
   branch(d,[(15,28),(15,16)],width=2)
   for dx,dy in [(-10,-2),(-7,-8),(0,-12),(7,-8),(11,-1)]:leaf(15,17,dx,dy,"#9cae7e")
   for x,y in [(10,25),(21,25)]:
    kernel(x,y);d.line((x-1,y,x+1,y),fill="#7a6b4e");d.line((x,y-1,x,y+1),fill="#7a6b4e")
  elif k=="butternut":
   branch(d,[(15,27),(8,17),(4,11)],width=2);branch(d,[(15,25),(22,16),(27,10)],width=2)
   for x,y in [(5,12),(9,17),(21,17),(26,11)]:
    leaf(x,y,-3,-6,"#9ca77a");leaf(x,y,4,3,"#7f9465")
   for x,y in [(11,24),(21,23)]:ellipse(d,(x-1,y-4,x+2,y+2),col);d.line((x,y-2,x,y+1),fill="#e6c697")
  elif k=="macadamia":
   branch(d,[(16,28),(17,16),(18,7)],width=3)
   for x,y in [(17,9),(17,17)]:
    for dx,dy in [(-9,-3),(7,-5),(8,3)]:leaf(x,y,dx,dy,"#96ab7b")
   for x,y in [(9,23),(23,22)]:
    ellipse(d,(x-3,y-3,x+3,y+3),"#7e9b72");ellipse(d,(x-1,y-1,x+2,y+2),col)
  elif k=="cashew":
   branch(d,[(16,28),(17,17),(24,9)],width=2);branch(d,[(17,19),(7,11)],width=2)
   for x,y in [(6,10),(15,6),(24,9)]:ellipse(d,(x-4,y-3,x+4,y+3),"#97aa7a");d.line((x-2,y,x+2,y),fill="#c1c994")
   for x,y in [(9,20),(24,19)]:
    ellipse(d,(x-3,y-4,x+3,y+2),"#cf9863");d.arc((x-1,y+2,x+3,y+6),10,300,fill=col,width=2)
  elif k=="japanese_walnut":
   branch(d,[(14,28),(14,15),(20,7)],width=2);branch(d,[(14,20),(6,12)],width=2)
   for x,y in [(6,12),(12,16),(18,10),(23,7)]:
    leaf(x,y,-5,-5,"#83a080");leaf(x,y,5,2,"#a1b28b")
   for x,y in [(10,24),(23,23)]:
    d.polygon([(x-3,y-2),(x,y-1),(x+3,y-2),(x+3,y+1),(x,y+4),(x-3,y+1)],fill=col);d.line((x,y,x,y+2),fill="#795f51")
  else:
   branch(d,[(5,26),(17,18),(26,10)],width=2)
   for x,y in [(8,24),(13,20),(20,15),(25,11)]:
    for dx,dy in [(-5,-5),(0,-7),(5,0)]:branch(d,[(x,y),(x+dx,y+dy)],"#8aa9a0",1)
   for x,y in [(11,24),(23,19)]:
    for yy in [y-3,y-1,y+1,y+3]:
     d.polygon([(x,yy-2),(x+3,yy),(x,yy+2),(x-3,yy)],fill=col);d.point((x-1,yy),fill="#ede0b4")
  return im
 tree=index>=16 or k in ["wild_apple","wild_pear","wild_plum"]
 branch(d,[(16,28),(15,18),(12,10)],width=3 if tree else 2)
 branch(d,[(15,21),(23,11)],width=2);branch(d,[(14,19),(6,14)],width=2)
 # Different species have distinctly cut crowns and branch heights.
 shape=index%4
 if shape==0:
  for box in [(3,11,15,22),(10,4,22,16),(18,10,29,22)]:ellipse(d,box,"#78956c")
 elif shape==1:
  d.polygon([(4,19),(7,7),(15,3),(26,8),(29,20),(22,24),(12,22)],fill=DARK)
  d.polygon([(6,18),(9,8),(15,5),(24,9),(26,18),(21,21),(12,20)],fill="#8da16f")
 elif shape==2:
  for box in [(2,15,13,23),(8,6,18,17),(18,7,29,19),(12,14,24,24)]:ellipse(d,box,"#6e8c68")
 else:
  d.polygon([(3,21),(8,10),(13,5),(17,3),(22,9),(28,20),(24,24),(12,23)],fill=DARK)
  d.polygon([(5,20),(10,11),(14,7),(17,5),(20,10),(26,19),(23,22),(13,21)],fill="#8a9e78")
 if k in ["redcurrant","blackcurrant"]:
  for x,y in [(8,13),(20,10),(24,18)]:
   d.line((x,y,x,y+5),fill="#a9ba84")
   for dx,dy in [(-1,1),(1,3),(0,5)]:berry(d,x+dx,y+dy,col,1)
 elif k=="gooseberry":
  for x,y in [(8,17),(15,10),(23,17)]:ellipse(d,(x-2,y-2,x+2,y+2),col);d.line((x,y-1,x,y+1),fill="#e2e1aa")
 elif k in ["wild_apple","wild_pear","wild_plum"]:
  for x,y in [(9,16),(16,10),(23,17)]:ellipse(d,(x-2,y-2,x+2,y+3 if k=="wild_pear" else y+2),col)
 elif index>=16:
  for x,y in [(7,22),(15,13),(24,21)]:
   if k in ["pecan","almond","butternut"]:ellipse(d,(x-1,y-3,x+2,y+2),col)
   elif k=="pistachio":ellipse(d,(x-2,y-2,x+2,y+2),"#b8bb83");d.point((x,y),fill="#dfc7b7")
   else:ellipse(d,(x-2,y-2,x+2,y+2),col)
 else:
  for x,y in [(8,17),(16,10),(23,19),(15,21)]:berry(d,x,y,col,2)
 return im

def write_assets():
 plants=Image.new("RGBA",(32*32,32));icons=Image.new("RGBA",(32*16,16))
 for i,entry in enumerate(CATALOG):
  plants.paste(plant(i,entry),(i*32,0));im=Image.new("RGBA",(16,16));d=ImageDraw.Draw(im)
  if i<16:fruit_shape(d,entry[0],8,8,rgb(entry[6]))
  else:nut_shape(d,entry[0],8,8,rgb(entry[6]))
  icons.paste(im,(i*16,0))
 plants.save(ROOT/"assets/forest_food_plants.png");icons.save(ROOT/"assets/forest_food_items.png")
 # A labelled contact sheet is review evidence, not an asset loaded in game.
 sheet=Image.new("RGB",(960,1280),(35,46,43));dr=ImageDraw.Draw(sheet)
 for i,e in enumerate(CATALOG):
  x=(i%4)*240;y=(i//4)*160
  dr.rectangle((x+4,y+4,x+235,y+154),fill="#3e5047",outline="#5f7161")
  plant_image=plants.crop((i*32,0,i*32+32,32)).resize((96,96),Image.Resampling.NEAREST)
  icon_image=icons.crop((i*16,0,i*16+16,16)).resize((48,48),Image.Resampling.NEAREST)
  sheet.paste(plant_image,(x+12,y+14),plant_image);sheet.paste(icon_image,(x+150,y+38),icon_image)
  dr.text((x+12,y+124),e[1],fill="#e1d9bc")
 sheet.save(ROOT/"tools/forest_food_art_review.png")

def gd(value):
 if isinstance(value,dict):return "{"+",".join(json.dumps(k,ensure_ascii=False)+":"+gd(v) for k,v in value.items())+"}"
 if isinstance(value,list):return "["+",".join(gd(v) for v in value)+"]"
 if isinstance(value,str) and value.startswith("@color:"):return 'Color("'+value[7:]+'")'
 return json.dumps(value,ensure_ascii=False,separators=(",",":"))

def write_data():
 species={};items={};overrides={};resources={};resource_overrides={};translations={}
 for i,(k,n,en,p,ep,bio,col) in enumerate(CATALOG):
  category="fruit" if i<16 else "nut";item=ALIASES.get(k,"ff_"+k)
  note,note_en=HABITAT[bio];stamina=8 if i<16 else 12
  desc=note+" Herstelt 1 hartje en "+str(stamina)+" uithoudingsvermogen."
  desc_en=note_en+" Restores 1 heart and "+str(stamina)+" stamina."
  translations[n]=en;translations[p]=ep;translations[desc]=desc_en
  species[k]={"category":category,"item":item,"kind":"ff_"+k,"name":n,"plant":p,"biome":bio,"frame":i,"color":"@color:"+col}
  item_def={"name":n,"type":"use","sheet":"forest_food_items","icon":i,"heal":1,"stamina":stamina,"sell":3 if i<16 else 4,"wild_category":category,"species":k,"desc":desc}
  (overrides if k in ALIASES else items)[item]=item_def
  resources["ff_"+k]={"name":p,"skill":"foraging","item":item,"amount":2,"xp":5,"cooldown":180.0 if i<16 else 210.0,"duration":.65,"color":"@color:"+col,"sheet":"forest_food_plants","frame":i,"cell":32,"wild_category":category,"species":k}
 for old,k in LEGACY.items():
  r=resources["ff_"+k]
  resource_overrides[old]={f:r[f] for f in ["name","color","sheet","frame","cell","wild_category","species"]}
 src="extends RefCounted\n## Hand-authored species, icons and shrubs. Existing recipe item IDs are retained.\n"
 for name,value in [("SPECIES",species),("ITEMS",items),("ITEM_OVERRIDES",overrides),("RESOURCES",resources),("RESOURCE_OVERRIDES",resource_overrides)]:
  src+="const "+name+":="+gd(value)+"\n"
 (ROOT/"scripts/data/ext/forest_food_species.gd").write_text(src,encoding="utf-8")
 (ROOT/"tools/forest-food-translations.json").write_text(json.dumps(translations,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 (ROOT/"tools/forest-food-catalog.json").write_text(json.dumps({k:{f:v for f,v in spec.items() if f!="color"} for k,spec in species.items()},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print("Original art: 32 plants + 32 item icons; species:",len(species),"new items:",len(items),"legacy item aliases:",len(overrides))

if __name__=="__main__":write_assets();write_data()
