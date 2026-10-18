"""Original hand-drawn winter plants and foods; no downloaded or generated source assets."""
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parent.parent
NAMES=['kale','broccoli','cauliflower','sprouts','beet','carrot','parsnip','leek','savoy','red_cabbage','spinach','lambs_lettuce','purslane','swede','celeriac','salsify']
DARK='#344c46'; SOIL='#677374'; SNOW='#c2d7df'; STEM='#698967'
def plant(kind):
 im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
 d.ellipse((4,25,28,30),fill=SOIL);d.line((5,27,10,28),fill=SNOW,width=2);d.line((25,27,28,27),fill=SNOW,width=2)
 def leaf(box,fill,vein=True):
  d.ellipse(box,fill=DARK);inner=(box[0]+1,box[1]+1,box[2]-1,box[3]-1);d.ellipse(inner,fill=fill)
  if vein:d.line(((box[0]+box[2])//2,box[1]+2,(box[0]+box[2])//2,box[3]-1),fill='#a9c09b')
 def frill(points,fill):
  d.polygon(points,fill=DARK);d.polygon([(x,y+1 if y<15 else y) for x,y in points],fill=fill)
 def tops(purple=False):
  for pts,c in [([(15,24),(6,14),(7,7),(12,9),(16,21)],'#698c6b'), ([(16,24),(13,7),(16,3),(19,7),(18,24)],'#8bac7a'), ([(17,23),(21,8),(27,6),(26,15)],'#638968')]:
   d.polygon(pts,fill=c);d.line((16,24,pts[1][0]+1,pts[1][1]),fill='#a47486' if purple else '#a7bc8b')
 if kind=='kale':
  for px,py in [(4,12),(10,5),(17,7),(20,14)]:
   frill([(px,py+5),(px+2,py+2),(px+4,py+3),(px+6,py),(px+9,py+3),(px+9,py+6),(px+11,py+8),(px+8,py+10),(px+8,py+13),(px+4,py+12),(px+2,py+14),(px,py+10)],'#6d9270')
   d.line((px+4,py+4,16,27),fill='#acc399')
 elif kind in ['broccoli','cauliflower']:
  d.polygon([(12,14),(20,14),(19,26),(13,26)],fill='#88a27a')
  d.polygon([(13,24),(5,18),(4,12),(11,15)],fill='#698465');d.polygon([(19,24),(28,16),(26,11),(20,16)],fill='#81a074')
  col='#709b78' if kind=='broccoli' else '#d5d4b4';shade='#436e57' if kind=='broccoli' else '#adba9e';hi='#a0bd8b' if kind=='broccoli' else '#f0e3c8'
  for x,y,r in [(9,12,5),(14,8,5),(21,10,6),(25,15,4),(17,15,6),(9,17,5)]:
   d.ellipse((x-r,y-r,x+r,y+r),fill=shade);d.ellipse((x-r+1,y-r+1,x+r-1,y+r-1),fill=col);d.line((x-2,y-2,x+1,y-2),fill=hi)
 elif kind=='sprouts':
  d.line((16,5,16,28),fill='#93ac7c',width=3)
  leaf((11,2,20,10),'#83a36f');d.line((16,7,16,27),fill='#c1cd9c')
  for x,y in [(9,10),(20,12),(9,17),(20,20),(10,24)]:
   d.ellipse((x-3,y-3,x+3,y+3),fill=DARK);d.ellipse((x-2,y-2,x+2,y+2),fill='#9eb978');d.line((x,y-1,x,y+1),fill='#d2d8a0')
 elif kind in ['beet','carrot','parsnip']:
  tops(kind=='beet')
  if kind=='beet':
   d.ellipse((10,19,23,29),fill='#744451');d.ellipse((11,19,22,27),fill='#b36e83');d.line((12,22,14,21),fill='#dc9ca4');d.line((17,27,17,30),fill='#ab7181')
  else:
   col='#d89252' if kind=='carrot' else '#d9c79b'
   d.polygon([(10,21),(22,21),(17,31),(15,30)],fill='#695b49');d.polygon([(11,21),(21,21),(16,30)],fill=col);d.line((12,23,16,23),fill='#edc087' if kind=='carrot' else '#f0dfba');d.line((17,26,19,26),fill='#b87c48' if kind=='carrot' else '#acaa86')
 elif kind=='leek':
  for pts,c in [([(13,26),(3,8),(7,5),(16,24)],'#6b9691'), ([(15,26),(11,3),(15,1),(18,25)],'#9db8a3'), ([(16,26),(22,2),(26,4),(19,27)],'#588f86'), ([(18,25),(29,11),(29,15),(19,28)],'#85ac96')]:d.polygon(pts,fill=c)
  d.polygon([(13,20),(18,20),(20,29),(13,29)],fill='#dedcc0');d.line((14,22,14,28),fill='#f2e6cc');d.line((14,30,12,31),fill='#a79e85');d.line((18,30,20,31),fill='#a79e85')
 elif kind in ['savoy','red_cabbage']:
  col='#839b69' if kind=='savoy' else '#9a7594';shadow='#526952' if kind=='savoy' else '#614e70';hi='#b1be87' if kind=='savoy' else '#c69caf'
  d.ellipse((3,14,27,29),fill=shadow);d.ellipse((7,7,25,26),fill=shadow);d.ellipse((9,8,24,24),fill=col);d.arc((10,9,25,25),60,300,fill=hi,width=2);d.arc((11,10,22,22),150,420,fill=shadow,width=2)
  d.polygon([(3,17),(7,17),(14,26),(10,28),(5,25)],fill=col);d.line((6,20,12,25),fill=hi);d.line((20,14,21,19),fill=hi)
 elif kind=='spinach':
  for pts in [[(15,27),(3,20),(3,11),(9,12),(17,25)],[(15,27),(10,11),(12,4),(17,8),(18,27)],[(17,27),(21,10),(28,8),(28,18)]]:
   d.polygon(pts,fill=DARK);d.polygon([(x+1 if x<16 else x-1,y+1 if y<26 else y) for x,y in pts],fill='#639873')
  d.line((7,15,16,27),fill='#b2c38b');d.line((14,9,16,27),fill='#9eb986');d.line((25,13,17,27),fill='#a9bf8c')
 elif kind=='lambs_lettuce':
  for box in [(4,15,15,25),(7,7,16,20),(16,7,25,20),(16,16,28,25),(11,14,22,28)]:leaf(box,'#9bb67e')
 elif kind=='purslane':
  for x,y in [(6,15),(12,6),(22,9),(25,20),(14,19)]:
   d.line((16,28,x,y),fill='#a6bf9a')
   d.polygon([(x,y+5),(x-5,y),(x-4,y-3),(x-1,y-3),(x,y-1),(x+2,y-3),(x+5,y-2),(x+5,y+1)],fill='#77aa92');d.line((x,y+3,x,y),fill='#bcceb0')
 elif kind=='swede':
  tops();d.ellipse((8,17,25,29),fill='#6f685b');d.ellipse((9,18,24,29),fill='#c7af7e');d.pieslice((9,16,24,28),180,360,fill='#9e7e9c');d.line((12,25,17,26),fill='#ead09a');d.line((17,28,17,31),fill='#9e9377')
 elif kind=='celeriac':
  tops();d.ellipse((7,17,26,29),fill='#7f806c');d.ellipse((8,17,25,28),fill='#bfb69a')
  for x,y in [(10,20),(19,18),(23,24),(13,26),(17,23)]:d.rectangle((x,y,x+1,y+1),fill='#8f937c')
  for x in [11,15,21,24]:d.line((x,27,x-1,31),fill='#b4ae93')
  d.line((10,19,13,18),fill='#dfd3af')
 else:
  for x,y in [(10,8),(15,4),(19,7),(24,9)]:
   d.line((16,25,x,y),fill='#77996a',width=2);d.line((x,y,x-2,y-3),fill='#9eb587')
  for x,y in [(9,17),(15,18),(20,17)]:
   d.polygon([(x,y),(x+4,y),(x+2,30),(x,31)],fill='#574c45');d.line((x+1,y+1,x+1,28),fill='#9b846a');d.line((x+1,y+6,x+2,y+6),fill='#c2ae86')
 return im

def food(kind):
 im=plant(kind)
 # A clean, enlarged crop detail makes a readable inventory icon without the snow bed.
 if kind in ['beet','carrot','parsnip','swede','celeriac','salsify']:im=im.crop((6,11,28,32))
 elif kind=='leek':im=im.crop((5,1,28,30))
 else:im=im.crop((3,1,30,27))
 im.thumbnail((14,14),Image.Resampling.NEAREST)
 result=Image.new('RGBA',(16,16));result.alpha_composite(im,((16-im.width)//2,(16-im.height)//2));return result

plants=Image.new('RGBA',(32*len(NAMES),32));items=Image.new('RGBA',(16*len(NAMES),16))
for i,name in enumerate(NAMES):
 plants.alpha_composite(plant(name),(i*32,0));items.alpha_composite(food(name),(i*16,0))
plants.save(ROOT/'assets'/'winter_plants.png');items.save(ROOT/'assets'/'winter_items.png')
# Contact sheet is useful for reviewing silhouettes; it is never shipped into the world.
review=Image.new('RGB',(512,144),'#21353b');rd=ImageDraw.Draw(review)
for i,name in enumerate(NAMES):
 x=(i%8)*64;y=(i//8)*72
 review.paste(plant(name).resize((48,48),Image.Resampling.NEAREST),(x+8,y+2),plant(name).resize((48,48),Image.Resampling.NEAREST))
 rd.text((x+2,y+53),name[:10],fill='#d8e5d5')
review.save(ROOT/'tools'/'winter_art_review.png')
print('WINTER ART OK: sixteen original crop silhouettes and sixteen food icons')
