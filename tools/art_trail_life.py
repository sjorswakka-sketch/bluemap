"""Original small verge plants and peaceful wildlife; no external assets."""
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parent.parent
ASSETS=ROOT/'assets'
def animal(kind):
 atlas=Image.new('RGBA',(128,32))
 for f in range(4):
  im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im);bob=f%2;stride=2 if f>=2 else 1
  def poly(points,c):d.polygon([(x,y+bob) for x,y in points],fill=c)
  if kind=='hare':
   poly([(6,22),(7,16),(12,13),(20,14),(24,19),(22,24),(10,25)],'#594c42')
   d.ellipse((7,14+bob,24,25+bob),fill='#b6a28b');d.ellipse((17,11+bob,27,20+bob),fill='#cbbb9e')
   poly([(19,13),(18,2),(21,1),(23,12)],'#b7a28a');poly([(23,13),(24,3),(27,4),(26,14)],'#d2bea1')
   poly([(20,10),(20,4),(21,4),(22,11)],'#c98988');d.rectangle((9,25-stride,14,27),fill='#e0cbb1');d.rectangle((20,25,26,26+stride),fill='#d8c3a8');d.ellipse((4,19,9,24),fill='#f4e8d5')
   d.point((25,15+bob),fill='#26363a');d.point((28,18+bob),fill='#7c5d59')
  elif kind=='fox':
   poly([(3,22),(0,18),(1,12),(4,15),(9,19),(14,22)],'#c47b49');poly([(0,13),(1,11),(4,15),(2,16)],'#f1dfbc')
   poly([(8,15),(19,14),(24,17),(24,23),(11,24),(6,20)],'#a75738');poly([(8,16),(19,15),(22,19),(17,22),(9,21)],'#da9352')
   poly([(19,16),(20,6),(24,11),(27,8),(29,16),(31,18),(26,22),(22,20)],'#ce864b');poly([(21,17),(29,18),(26,21),(23,20)],'#f5dfb8')
   d.rectangle((10,23,13,27-stride),fill='#674b3e');d.rectangle((20,22,23,26+stride),fill='#674b3e');d.point((27,15+bob),fill='#182f31');d.rectangle((29,17+bob,31,18+bob),fill='#293e3b')
  elif kind=='moth':
   wing=2 if f%2 else 0
   poly([(15,15),(6,5+wing),(3,9),(5,17),(11,20),(15,18)],'#d5b47f');poly([(17,15),(26,5+wing),(29,9),(27,17),(21,20),(17,18)],'#e7cfa0')
   poly([(14,17),(8,20),(10,25-wing),(15,21)],'#aa9272');poly([(18,17),(24,20),(22,25-wing),(17,21)],'#be9b76')
   d.ellipse((7,10,10,13),fill='#947491');d.ellipse((22,10,25,13),fill='#947491');d.line((16,12,16,23),fill='#504d50',width=2);d.line((15,12,12,8),fill='#655c59');d.line((17,12,20,8),fill='#655c59')
  else:
   d.ellipse((7,14+bob,23,23+bob),fill='#797f80');poly([(8,18),(12,16),(22,19),(20,23),(12,22)],'#c8c6af')
   d.ellipse((20,8+bob,28,16+bob),fill='#e5dfc5');d.rectangle((28,12+bob,31,13+bob),fill='#6b6656');d.point((26,11+bob),fill='#263d40')
   d.line((13,22,12-stride,28),fill='#837359');d.line((20,22,21+stride,27),fill='#837359');poly([(7,16),(2,14),(4,19),(9,20)],'#505c62')
  atlas.alpha_composite(im,(f*32,0))
 atlas.save(ASSETS/('pixel_trail_'+kind+'.png'));atlas.resize((64,16),Image.Resampling.NEAREST).save(ASSETS/('trail_'+kind+'.png'))
for name in ['hare','fox','moth','gull']:animal(name)
atlas=Image.new('RGBA',(112,16))
for f in range(7):
 im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
 d.ellipse((3,12,13,14),fill='#536442')
 for x,h in [(5,5),(8,3),(11,6)]:
  d.line((8,13,x,h),fill='#60845d');d.rectangle((x-2,h+3,x,h+4),fill='#91a875')
 if f==0:
  for x,y in [(4,7),(8,4),(11,7)]:d.rectangle((x,y,x+2,y+2),fill='#c1cf9a')
 if f==1:
  for x,y in [(4,5),(8,3),(11,6)]:
   d.ellipse((x-1,y-1,x+2,y+2),fill='#dcb8d8');d.point((x,y),fill='#f4d996')
 if f==2:
  d.ellipse((3,10,7,13),fill='#96704e');d.ellipse((8,10,12,13),fill='#bf9560');d.line((5,10,5,12),fill='#ddbc82')
 if f==3:
  im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
  d.ellipse((2,10,14,14),fill='#536442')
  for x,y in [(4,11),(7,9),(11,11),(8,12)]:
   d.polygon([(x,y-1),(x+2,y),(x+1,y+2),(x-1,y+1)],fill='#8e7656')
   d.point((x,y),fill='#c5aa79')
 if f==4:
  d.polygon([(6,8),(10,8),(8,14)],fill='#d78c4f');d.line((6,9,9,9),fill='#e7b474')
 if f==5:
  d.ellipse((3,5,13,12),fill='#627c5b')
  for x,y in [(5,7),(8,6),(10,9),(6,10)]:d.rectangle((x,y,x+1,y+1),fill='#9ca3d3')
 if f==6:
  for x,y in [(4,7),(9,9)]:
   d.rectangle((x,y,x+1,13),fill='#d5bea0');d.ellipse((x-2,y-3,x+3,y),fill='#bd937a');d.line((x-1,y-2,x+1,y-2),fill='#ead4b5')
 atlas.alpha_composite(im,(16*f,0))
atlas.save(ASSETS/'trail_plants.png')
items=Image.new('RGBA',(32,16));d=ImageDraw.Draw(items)
d.ellipse((4,4,12,12),fill='#604c3e');d.ellipse((5,4,11,11),fill='#c59960');d.line((8,5,8,10),fill='#f0c98a');d.line((7,3,9,3),fill='#73916b')
for x,y in [(20,5),(24,3),(27,6)]:
 d.line((24,14,x,y),fill='#68845f');d.ellipse((x-2,y-2,x+2,y+2),fill='#d5b4cf');d.point((x,y),fill='#f3d78d')
items.save(ASSETS/'trail_items.png')
print('TRAIL ART OK: 10 original sheets')
