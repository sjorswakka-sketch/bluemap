"""Original quiet interior pixel art. Deterministic Pillow primitives; no downloaded assets."""
from pathlib import Path
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parent.parent/'assets'
palettes=[('#6b9184','#c7c9a2','#c2a477'),('#b89958','#ebdbb0','#ccad78'),('#687e9b','#bbb0c5','#bba281')]
sheet=Image.new('RGBA',(13*64,3*64))
for row,(fabric,light,wood) in enumerate(palettes):
 for frame in range(13):
  im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im)
  def r(box,c):d.rectangle(box,fill=c)
  def line(xy,c,w=1):d.line(xy,fill=c,width=w)
  dark='#392f2b';edge='#674a35';gold='#d8b979'
  if frame==0:
   r((17,2,46,63),dark);r((19,3,44,61),wood);r((20,7,43,59),'#e0d6ba')
   r((22,9,41,19),'#f0e5cd');line((23,10,40,10),'#fbefd7')
   r((20,23,43,56),fabric);r((21,24,42,27),light)
   for y in (32,42,52):line((22,y,41,y),light)
   r((18,59,45,62),edge);r((19,58,44,59),gold)
  elif frame==1:
   for x in (5,53):r((x,54,x+4,63),edge)
   r((1,33,62,56),dark);r((2,34,61,53),wood);r((4,35,59,51),'#b99361')
   for y in (40,47):line((4,y,59,y),'#a57e51')
   r((11,37,20,48),fabric);line((12,37,19,37),light)
   d.ellipse((41,38,51,47),fill='#ebe0be');d.ellipse((44,40,48,44),fill='#9c7753')
   line((3,54,60,54),gold)
  elif frame in (2,8):
   r((2,1,61,63),dark);r((4,2,59,60),wood);r((7,5,56,56),edge)
   for y in (7,27,47):
    if frame==2:
     for i in range(8):
      c=[fabric,light,'#9b7d82','#a9ae85'][i%4];r((9+i*6,y,12+i*6,y+15),c);line((10+i*6,y+2,11+i*6,y+2),'#d7c79d')
    else:
     for x in (16,36):d.ellipse((x,y+4,x+13,y+15),fill=light);d.ellipse((x+3,y+6,x+10,y+12),outline=fabric)
    r((7,y+16,56,y+18),'#c9a879')
   r((5,60,11,63),edge);r((52,60,58,63),edge)
  elif frame==3:
   r((21,32,42,51),dark);r((23,33,40,48),wood)
   for y in (35,43):line((24,y,39,y),fabric,2)
   r((19,48,44,58),edge);r((20,49,43,54),fabric);line((22,50,41,50),light)
   for x in (21,39):r((x,58,x+3,63),dark)
  elif frame in (4,5):
   d.ellipse((18,57,45,63),fill='#263b3650')
   r((23,48,40,60),'#a56f50');r((21,47,42,50),wood);line((24,52,25,58),'#d5a277')
   for x,y in ((32,34),(22,41),(42,40)):
    line((31,49,x,y),'#57745b',2);d.ellipse((x-7,y-5,x+5,y+2),fill=fabric)
    line((x-4,y-2,x+2,y-1),'#9fba83')
    if frame==5:
     d.ellipse((x-3,y-6,x+4,y+1),fill=['#d4b47e','#b9a7c5','#e0cf9d'][row]);r((x,y-3,x+1,y-2),gold)
  elif frame==6:
   d.ellipse((20,57,43,63),fill=dark);d.ellipse((22,57,41,61),fill=wood)
   r((30,20,33,58),edge);line((31,22,31,56),gold)
   d.polygon([(23,7),(40,7),(47,24),(16,24)],fill=dark)
   d.polygon([(24,8),(39,8),(44,21),(19,21)],fill=light)
   line((23,22,41,22),gold,2);r((30,3,33,7),wood)
   line((24,11,21,19),'#eee3bd');line((38,11,41,19),fabric)
  elif frame==7:
   for x in (7,52):r((x,56,x+4,63),edge)
   r((2,40,61,56),dark);r((3,41,60,52),wood);r((6,38,57,49),fabric)
   line((9,39,54,39),light);line((6,49,57,49),light)
   for x in (10,49):r((x,42,x+2,43),light)
  elif frame>=10:
   r((19,57,44,62),dark);r((21,55,42,59),wood);r((24,52,39,55),gold)
   if frame==10:
    d.polygon([(31,33),(42,39),(35,51),(24,48),(21,40)],fill=fabric)
    line((25,45,38,37),light,2);d.polygon([(31,39),(35,43),(31,48),(27,43)],fill='#8dc6cd')
   elif frame==11:
    d.ellipse((21,32,42,53),outline=wood,width=3);d.ellipse((29,40,34,45),fill=gold)
    for xy in [(22,42,41,42),(31,33,31,52),(24,35,39,49),(24,49,39,35)]:line(xy,gold,2)
   else:
    d.pieslice((20,31,43,52),180,360,fill=light);r((23,42,40,48),light)
    for x in (24,28,32,36,40):line((32,49,x,36),fabric)
    line((23,48,40,48),gold,2)
  sheet.alpha_composite(im,(frame*64,row*64))
sheet.save(root/'house_furniture.png')
rug=Image.new('RGBA',(384,64))
for i,(fabric,light,wood) in enumerate(palettes):
 d=ImageDraw.Draw(rug);x=i*128
 d.rectangle((x+1,3,x+126,60),fill='#303b38');d.rectangle((x+3,5,x+124,58),fill=fabric)
 d.rectangle((x+8,10,x+119,53),outline=light,width=2)
 for xx in range(10,120,8):
  d.line((x+xx,4,x+xx,0),fill=light);d.line((x+xx,59,x+xx,63),fill=light)
 for xx in range(20,112,22):d.polygon([(x+xx,26),(x+xx+6,32),(x+xx,38),(x+xx-6,32)],outline=wood)
rug.save(root/'house_rugs.png')
surfaces=Image.new('RGBA',(8*32,32))
for mode in range(8):
 im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
 base=['#a1825e','#b8a47d','#657b7c','#a7816d','#ad9574','#708c7d','#c8bc9d','#81959b'][mode]
 d.rectangle((0,0,31,31),fill=base)
 if mode==0:
  for y in (0,8,16,24):d.line((0,y,31,y),fill='#806447');d.line((0,y+1,31,y+1),fill='#b7976d')
  d.line((10,1,10,7),fill='#806447');d.line((24,9,24,15),fill='#806447');d.line((5,17,5,23),fill='#806447')
  for x,y in [(4,4),(18,12),(26,20),(11,28)]:d.line((x,y,x+4,y),fill='#9d7c56')
 elif mode==1:
  for y in range(-32,64,8):d.line((0,y,32,y+32),fill='#8f805e')
  for x in (8,24):d.line((x,0,x,32),fill='#cbb78d')
 elif mode in (2,3):
  for y in (0,16):d.line((0,y,31,y),fill='#425d60' if mode==2 else '#7d5d50')
  d.line((16,0,16,15),fill='#425d60' if mode==2 else '#7d5d50');d.line((7,16,7,31),fill='#425d60' if mode==2 else '#7d5d50')
  d.line((2,2,12,2),fill='#7e9290' if mode==2 else '#bb9780');d.line((18,18,29,18),fill='#7e9290' if mode==2 else '#bb9780')
 else:
  for x,y in [(4,6),(24,12),(17,24),(6,27)]:d.point((x,y),fill=['#c2ac88','#8fa493','#d9ccae','#99abb0'][mode-4])
  d.rectangle((0,26,31,31),fill='#7a624b');d.line((0,26,31,26),fill='#d0b98d');d.line((0,30,31,30),fill='#584938')
 surfaces.alpha_composite(im,(mode*32,0))
surfaces.save(root/'house_surfaces.png')
print('house_furniture.png, house_rugs.png, house_surfaces.png')
