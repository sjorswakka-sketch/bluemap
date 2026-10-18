"""Draw sixteen original regional flower plants and inventory bouquets."""
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parent.parent
NAMES=['daisy','bluebell','foxglove','edelweiss','sea_aster','hollyhock','thrift','sea_lavender','horned_poppy','sea_campion','yellow_iris','forget_me_not','snowdrop','desert_marigold','loosestrife','alpine_aster']
INK='#354c48';GREEN='#6b916e';LIGHT='#a4b69a'
def flower(name,ground=True):
 im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
 if ground:d.ellipse((4,26,28,30),fill='#4c635c')
 def line(points,c=GREEN,width=1):d.line(points,fill=c,width=width)
 def leaf(x,y,side=1,c=GREEN):
  d.polygon([(x,y),(x+side*6,y-5),(x+side*8,y-4),(x+side*5,y),(x,y+1)],fill=c)
 def petal(x,y,r,c,heart='#dfc17a',thin=False):
  if thin:
   for dx,dy in [(0,-r),(r,-r//2),(r,r//2),(0,r),(-r,r//2),(-r,-r//2)]:
    line([(x,y),(x+dx,y+dy)],c,2)
  else:
   d.polygon([(x,y-r),(x+2,y-2),(x+r,y-2),(x+r,y+1),(x+2,y+2),(x+1,y+r),(x-2,y+r),(x-2,y+2),(x-r,y+1),(x-r,y-2),(x-2,y-2)],fill=c)
  d.rectangle((x-1,y-1,x+1,y+1),fill=heart)
 def bell(x,y,c):
  d.polygon([(x-2,y-3),(x+1,y-3),(x+3,y+2),(x+2,y+4),(x,y+2),(x-2,y+4),(x-4,y+1)],fill=c);line([(x-1,y-2),(x+1,y+1)],'#d0c4d7')
 if name=='daisy':
  for x,y in [(8,15),(16,9),(24,17)]:
   line([(16,28),(x,y)]);petal(x,y,5,'#e3e1cd')
  for x,y,s in [(14,25,-1),(17,24,1),(12,28,-1)]:leaf(x,y,s)
 elif name=='bluebell':
  for x,y,s in [(9,8,-1),(17,5,1),(24,11,1)]:
   line([(15,28),(x,y+2),(x+s*2,y)])
   for yy in [y+4,y+10]:bell(x+s*3,yy,'#8792c5');line([(x,yy-3),(x+s*3,yy-3)])
  d.polygon([(14,29),(4,18),(8,18),(17,28),(23,19),(25,20),(18,29)],fill='#799b83')
 elif name=='foxglove':
  line([(15,29),(17,2)],LIGHT,2)
  for x,y,s in [(13,8,-1),(20,12,1),(12,16,-1),(20,21,1),(13,24,-1)]:
   line([(16,y),(x,y)]);bell(x,y,'#b984aa');d.point((x,y+1),fill='#ead7cf')
  for y in [22,27]:leaf(16,y,-1);leaf(16,y,1)
 elif name=='edelweiss':
  line([(15,28),(16,14)],'#97ac94',2)
  for px,py in [(5,23),(12,27),(23,26)]:
   d.polygon([(15,28),(px-2,py),(px,py-4),(17,24)],fill='#96aaa0')
  d.polygon([(16,3),(19,11),(27,7),(23,16),(29,21),(20,22),(17,29),(13,22),(4,24),(8,16),(4,10),(13,12)],fill='#a6b8ac')
  d.polygon([(16,5),(18,13),(25,9),(20,16),(26,20),(19,20),(17,26),(14,20),(7,22),(11,16),(7,12),(14,14)],fill='#dce0ce')
  for x,y in [(13,15),(18,14),(16,19)]:d.ellipse((x-2,y-2,x+2,y+2),fill='#a9ab7b');d.point((x,y),fill='#e0cf93')
 elif name=='sea_aster':
  for x,y in [(6,15),(15,10),(25,16)]:
   line([(16,28),(x,y)]);petal(x,y,5,'#a6a1c4',thin=True)
  for x,y,s in [(15,25,-1),(17,25,1),(13,20,-1)]:leaf(x,y,s,'#8da59b')
 elif name=='hollyhock':
  line([(16,29),(16,3)],'#8ba57e',2)
  for x,y,r in [(15,6,4),(20,13,5),(12,20,5),(19,25,4)]:
   d.ellipse((x-r,y-r,x+r,y+r),fill='#75526b');petal(x,y,r,'#bc8290',heart='#6e5e61')
   d.point((x,y),fill='#e7bd88')
  leaf(15,16,-1);leaf(16,23,1)
 elif name=='thrift':
  for x,y in [(7,14),(15,8),(24,13)]:
   line([(16,29),(x,y)],'#99a087')
   for dx,dy in [(0,-2),(-2,0),(2,0),(0,2)]:d.ellipse((x+dx-2,y+dy-2,x+dx+2,y+dy+2),fill='#b68599')
   for dx,dy in [(-2,-2),(1,-2),(2,1),(-1,2)]:d.point((x+dx,y+dy),fill='#e6bdc7')
  for xx in range(6,28,3):line([(16,29),(xx,22-(xx%3))],'#8eaa91')
 elif name=='sea_lavender':
  for x,y in [(5,12),(11,5),(18,6),(26,12),(22,19)]:
   line([(16,28),(x,y)],'#79978e')
   for dx,dy in [(-2,-1),(0,-3),(2,1),(0,2)]:
    d.rectangle((x+dx-1,y+dy-1,x+dx+1,y+dy+1),fill='#a294bb');d.point((x+dx,y+dy-1),fill='#d0bad6')
  leaf(15,27,-1,'#93aa9d');leaf(17,28,1,'#93aa9d')
 elif name=='horned_poppy':
  line([(14,29),(12,12)],'#94a69a',2);line([(17,28),(23,13),(24,6)],'#aab69d')
  d.polygon([(12,8),(7,5),(4,8),(7,14),(12,16),(17,14),(19,9),(16,5)],fill='#caa556')
  d.ellipse((7,7,17,15),fill='#e1c16e');d.rectangle((11,10,13,12),fill='#807754')
  for x,y,s in [(12,23,-1),(17,26,1)]:leaf(x,y,s,'#9daea2')
  line([(24,6),(24,2)],'#bbc4a5',2)
 elif name=='sea_campion':
  for x,y in [(9,13),(22,10)]:
   line([(15,28),(x,y+2)],'#91a798',2);d.ellipse((x-3,y,x+3,y+7),fill='#a8bb9c')
   petal(x,y-1,5,'#e5e3d0',heart='#c8cbab')
   for xx in [x-2,x+2]:line([(xx,y+1),(xx,y+5)],'#6f997d')
  leaf(14,25,-1,'#9cad9d');leaf(17,24,1,'#9cad9d')
 elif name=='yellow_iris':
  for pts,c in [([(14,29),(7,12),(7,5),(17,28)],'#718e71'), ([(16,29),(17,4),(20,8),(18,29)],'#91aa82'), ([(18,29),(27,10),(27,18),(20,30)],'#6e9478')]:d.polygon(pts,fill=c)
  line([(15,28),(12,10)],LIGHT,2)
  d.polygon([(12,10),(9,2),(12,1),(15,7),(18,3),(20,5),(17,12),(23,11),(24,15),(16,15),(12,20),(8,17),(9,13),(4,12),(5,8)],fill='#dbc068')
  line([(12,6),(12,13)],'#f0d98b',2);d.rectangle((11,11,14,13),fill='#a18d4d')
 elif name=='forget_me_not':
  for x,y in [(7,15),(12,7),(21,9),(25,17),(16,18)]:
   line([(16,28),(x,y)],GREEN);petal(x,y,3,'#8fb9d0',heart='#e3ce92')
  leaf(14,24,-1,'#82a481');leaf(17,26,1,'#82a481')
 elif name=='snowdrop':
  for x,y,s in [(8,12,-1),(17,8,1),(25,15,1)]:
   line([(15,29),(x,y-3),(x+s*3,y-4),(x+s*4,y)],'#8cae92',2)
   d.polygon([(x+s*4-2,y),(x+s*4+2,y),(x+s*4+4,y+7),(x+s*4+1,y+10),(x+s*4-1,y+6),(x+s*4-3,y+8)],fill='#dfe8dc')
   line([(x+s*4,y+1),(x+s*4,y+6)],'#a7c6ae')
  d.polygon([(13,30),(5,20),(7,18),(17,29),(22,19),(24,20),(18,30)],fill='#8cae95')
 elif name=='desert_marigold':
  for x,y in [(10,12),(23,16)]:
   line([(16,29),(x,y)],'#a5ad96',2);petal(x,y,6,'#dcba68',thin=True);d.ellipse((x-2,y-2,x+2,y+2),fill='#b59754')
   d.line((x-1,y-1,x+1,y-1),fill='#e8d189')
  for px,py in [(6,23),(12,26),(22,25)]:
   d.polygon([(16,29),(px-3,py),(px-2,py-3),(px,py-2),(px+2,py-4),(px+4,py)],fill='#a0afa5')
 elif name=='loosestrife':
  for x,y in [(9,12),(16,3),(24,10)]:
   line([(16,29),(x,y)],'#7d9b77',2)
   for yy in range(y,y+14,3):
    width=2 if yy<y+4 else 3
    d.rectangle((x-width,yy,x-1,yy+1),fill='#b380b0');d.rectangle((x+1,yy+1,x+width,yy+2),fill='#9a79a5');d.point((x-width,yy),fill='#d8a6c5')
  leaf(16,26,-1);leaf(17,27,1)
 else:
  line([(16,29),(16,14)],'#8da693',2)
  petal(16,12,9,'#a49ac0',thin=True)
  for dx,dy in [(-6,-6),(6,-6),(-6,6),(6,6)]:line([(16,12),(16+dx,12+dy)],'#c3b1cf',2)
  d.ellipse((13,9,19,15),fill='#d7bb70');d.line((15,10,17,10),fill='#ecd5a0')
  leaf(15,25,-1,'#92a99c');leaf(17,25,1,'#92a99c')
 return im
plants=Image.new('RGBA',(512,32));items=Image.new('RGBA',(256,16))
for i,name in enumerate(NAMES):
 plants.alpha_composite(flower(name),(i*32,0))
 icon=flower(name,False).crop((2,0,31,31));icon.thumbnail((14,14),Image.Resampling.NEAREST)
 items.alpha_composite(icon,(i*16+(16-icon.width)//2,(16-icon.height)//2))
plants.save(ROOT/'assets/flower_plants.png');items.save(ROOT/'assets/flower_items.png')
review=Image.new('RGB',(512,144),'#253c41');rd=ImageDraw.Draw(review)
for i,name in enumerate(NAMES):
 x=(i%8)*64;y=(i//8)*72;crop=flower(name).resize((48,48),Image.Resampling.NEAREST)
 review.paste(crop,(x+8,y+1),crop);rd.text((x+1,y+53),name[:10],fill='#e0e3cd')
review.save(ROOT/'tools/flower_art_review.png')
print('FLOWER ART OK: sixteen original native plants and sixteen unique item bouquets')
