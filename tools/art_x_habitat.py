"""Original rooted sentinel and light moth, with quiet deterministic synthesis."""
from pathlib import Path
from PIL import Image, ImageDraw
from artlib import strip, outline
import art_x_opening as sound
import math
ROOT=Path(__file__).resolve().parent.parent
sound.ROOT=ROOT
def root(frame):
 im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
 d.polygon([(3,20),(7,16),(7,7),(10,3),(14,4),(18,8),(17,17),(22,20),(16,21),(12,19),(7,22)],fill='#64503b')
 d.polygon([(8,7),(11,4),(13,5),(11,17),(7,19)],fill='#8b7851')
 d.line((15,7,14,17),fill='#3b3c33',width=2)
 d.polygon([(5,7),(4,4),(9,3),(10,6),(15,2),(19,3),(18,7),(12,8)],fill='#5e8056')
 d.line((5,4,9,4),fill='#9fac6a');d.line((15,3,18,4),fill='#9fac6a')
 glow='#efc77c' if frame in (2,3) else '#adb88c'
 if frame==4:
  d.polygon([(9,10),(12,7),(16,10),(15,17),(11,18),(9,16)],fill='#c5a874')
  d.line((11,10,12,16),fill='#f0d59d');d.line((15,12,14,16),fill='#d7ba79')
 else:
  d.rectangle((9,10+(frame%2),10,11+(frame%2)),fill=glow)
  d.rectangle((14,10+(frame%2),15,11+(frame%2)),fill=glow)
 if frame in (2,3):
  d.line((4,18,1 if frame==3 else 3,15),fill='#b39c68',width=2)
  d.line((18,18,22 if frame==3 else 20,14),fill='#b39c68',width=2)
 return outline(im)
def moth(frame):
 im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
 spread=frame in (0,2,4)
 left=[(10,11),(2,4),(1,10),(3,16),(9,17)] if spread else [(10,11),(5,3),(5,13),(8,18)]
 right=[(14,11),(22,4),(23,10),(21,16),(15,17)] if spread else [(14,11),(19,3),(19,13),(16,18)]
 if frame==3:left=[(10,11),(2,8),(6,14),(10,17)];right=[(14,11),(22,8),(18,14),(14,17)]
 d.polygon(left,fill='#8689a0');d.polygon(right,fill='#8689a0')
 d.line(left[:-1],fill='#bec6ba');d.line(right[:-1],fill='#bec6ba')
 for x in [6,17]:
  d.ellipse((x,9,x+2,12),fill='#edce81');d.point((x+1,10),fill='#5b5e74')
 d.ellipse((10,8,14,17),fill='#586878');d.rectangle((11,9,13,13),fill='#d3cfa3')
 d.line((11,8,8,4),fill='#ded7af');d.line((13,8,16,4),fill='#ded7af')
 if frame>=4:d.point((12,15+(frame%2)),fill='#ffdf9b')
 return outline(im)
if __name__=='__main__':
 strip([root(i) for i in range(5)]).save(ROOT/'assets/hb_root.png')
 strip([moth(i) for i in range(6)]).save(ROOT/'assets/hb_moth.png')
 sound.audio('hb_root_ready',0.65,lambda t,r:(r.uniform(-1,1)*0.14+math.sin(math.tau*140*t)*0.15)*math.sin(math.pi*t/0.65))
 sound.audio('hb_root_strike',0.3,lambda t,r:(math.sin(math.tau*90*t)*0.25+r.uniform(-1,1)*0.25)*math.exp(-t*13))
 sound.audio('hb_moth_ready',0.55,lambda t,r:(math.sin(math.tau*(520*t+180*t*t))*0.18+r.uniform(-1,1)*0.06)*math.sin(math.pi*t/0.55))
