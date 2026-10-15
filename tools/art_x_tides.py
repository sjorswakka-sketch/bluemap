"""Original tide cove, tide gauge, chart and reusable line. No borrowed assets."""
from pathlib import Path
from PIL import Image,ImageDraw
import json, math
ROOT=Path(__file__).resolve().parent.parent
def make_map():
 w,h=52,36
 cells=[['3']*w for _ in range(h)]
 for y in range(h):
  for x in range(w):
   left=((x-12)/9)**2+((y-21)/12)**2
   right=((x-39)/9)**2+((y-19)/13)**2
   v=min(left,right)
   if v<.88:cells[y][x]='6' if v<.40 else '5' if v<.65 else '4'
   elif v<1.1:cells[y][x]='8'
 # Broad stable shores and a raised loop, separated from the sandbank.
 for y in range(12,28):
  for x in range(12,20):cells[y][x]='4' if x>16 else '5'
  for x in range(32,40):cells[y][x]='4' if x<35 else '6'
 for y in [11,12]:
  for x in range(15,37):cells[y][x]='9'
 for y in range(13,26):
  for x in [16,17,34,35]:cells[y][x]=','
 for y in [25,26]:
  for x in range(20,32):cells[y][x]='4'
 # Arrival pier and walk-in connection from Meeuweneiland.
 for y in [25,26]:
  for x in range(0,13):cells[y][x]='9'
 cells[24][3]=cells[24][4]='9'
 for x,y in [(10,16),(11,16),(40,10),(41,10),(43,14),(44,14),(9,28),(40,28)]:cells[y][x]='7'
 return dict(name="Getijdenbaai",music="coast",outdoor=True,weather="random",
  rows=[''.join(r) for r in cells],spawns=dict(start=[12,26],from_island=[3,26],from_coast=[12,26]),
  objects=[
   dict(type="portal",pos=[0,25],size=[2,2],to="gull_island",spawn="from_cove"),
   dict(type="sign",pos=[3,24],lines=["Westelijke loopbrug: Meeuweneiland","Het hoge pad langs de noordkant blijft bij ieder getij open."]),
   dict(type="coast_dock",pos=[3,26],to="coast",spawn="from_island",talk="ce_sail_coast"),
   dict(type="tide_station",pos=[12,24],role="kit"),
   dict(type="tide_station",pos=[19,19],role="line",landing=[32,20]),
   dict(type="tide_station",pos=[32,19],role="line",landing=[19,20]),
   dict(type="tide_station",pos=[18,24],role="gauge"),
   dict(type="tide_station",pos=[33,24],role="gauge"),
   dict(type="tide_station",pos=[10,24],role="routes",to="coast",spawn="from_island",routes=[dict(to="coast",spawn="from_island"),dict(to="gull_island",spawn="from_coast")])
  ])
def prop(frame):
 im=Image.new("RGBA",(24,24));d=ImageDraw.Draw(im)
 if frame==0: # tide gauge, entirely on its dry bank
  d.rectangle((10,3,13,21),fill="#ddd1a4");d.rectangle((10,13,13,21),fill="#698f96")
  for y in [6,10,14,18]:d.line((10,y,16,y),fill="#40555a")
  d.polygon([(2,7),(7,4),(7,10)],fill="#e5bb78");d.line((3,8,7,8),fill="#594f40")
 elif frame==1: # open loan box, rope coil
  d.rectangle((2,13,21,21),fill="#715c42");d.rectangle((3,8,20,15),fill="#b99d69")
  d.ellipse((6,9,18,18),outline="#e8d3a1",width=2);d.ellipse((9,11,15,16),outline="#716b4e")
  d.line((18,14,20,10),fill="#e8d3a1",width=2)
 elif frame==2: # line post
  d.rectangle((9,6,14,21),fill="#6f7463");d.ellipse((6,3,17,9),fill="#bec1a0")
  d.arc((4,7,19,17),0,350,fill="#e2c990",width=2)
 elif frame==3: # route chart on a low stand
  d.rectangle((5,15,7,22),fill="#766144");d.rectangle((17,15,19,22),fill="#766144")
  d.polygon([(2,7),(19,4),(22,15),(4,19)],fill="#c3b791")
  d.line((6,13,10,9,15,13,19,10),fill="#447a86",width=2);d.ellipse((13,7,16,10),fill="#7a956c")
 else: # low landing float, feet rest on the planks
  d.ellipse((1,13,23,22),fill=(20,55,65,120))
  for y in [10,13,16]:
   d.polygon([(2,y),(21,y-1),(23,y+3),(3,y+4)],fill="#ad8d59",outline="#665b44")
  d.line((6,9,7,19),fill="#dfc78f",width=2);d.line((18,9,19,18),fill="#dfc78f",width=2)
 return im
def main():
 data=make_map()
 (ROOT/'scripts/maps/tide_cove.gd').write_text('extends RefCounted\n## Hand-shaped by tools/art_x_tides.py.\nconst DATA := '+json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding="utf8")
 sheet=Image.new("RGBA",(120,24))
 for i in range(5):sheet.paste(prop(i),(i*24,0))
 sheet.save(ROOT/'assets/td_props.png')
 icon=Image.new("RGBA",(16,16));d=ImageDraw.Draw(icon)
 for r in range(3):
  d.ellipse((2+r*2,2+r*2,14-r*2,13-r*2),outline="#dfc38a",width=1)
 d.line((12,10,13,15,15,14),fill="#d1ddcd",width=2)
 icon.save(ROOT/'assets/items_tides.png')
if __name__=="__main__":main()
