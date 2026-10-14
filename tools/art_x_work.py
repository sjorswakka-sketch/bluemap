"""Original clamp, herb preparation and leaf sprites plus quiet synthetic sounds."""
from pathlib import Path
from PIL import Image, ImageDraw
from artlib import strip, outline
from art_x_opening import audio
import math
ROOT=Path(__file__).resolve().parent.parent
def station(frame):
 im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
 d.ellipse((2,17,22,21),fill=(20,26,29,60))
 if frame<2:
  d.rectangle((3,15,21,19),fill='#674c37');d.line((3,15,21,15),fill='#c29c65')
  d.rectangle((7,7,10,15),fill='#879aa1');d.rectangle((6,6,11,8),fill='#d0d9d1')
  x=13 if frame else 16
  d.rectangle((x,7,x+3,15),fill='#637783');d.line((x,6,x+4,8),fill='#b9cccf',width=2)
  d.line((5,12,20,12),fill='#cba879',width=2);d.line((20,9,20,16),fill='#91acb3')
  d.rectangle((11,9,12,14),fill='#75b4a1' if frame else '#bd8359')
  if frame:d.point((11,7),fill='#d0e4cf')
 else:
  d.ellipse((4,9,19,18),fill='#536573');d.arc((4,8,19,19),0,180,fill='#9cbbbe',width=2)
  d.ellipse((5,7,18,13),fill='#879a92');d.ellipse((7,8,16,12),fill='#568967' if frame>2 else '#728c5b')
  d.line((14,4,11,12),fill='#d2c1a3',width=3)
  if frame==2:
   d.polygon([(7,9),(10,7),(11,9),(9,11)],fill='#b5c980')
  if frame==3:d.arc((7,7,16,13),25,190,fill='#ccdec4')
  if frame>=4:
   d.rectangle((18,13,22,19),fill='#4b8073');d.rectangle((19,11,21,13),fill='#bc9a68')
   d.line((19,14,19,17),fill='#b7e0cd');d.point((10 if frame==4 else 13,9),fill='#d0e6b4')
 return outline(im)
def leaf(frame):
 im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
 good=frame in (0,3)
 points=[(5,18),(5,12),(8,6),(13,3),(18,6),(19,11),(16,17),(10,20)]
 d.polygon(points,fill='#82af77' if good else '#9b895b')
 d.line((5,21,15,5),fill='#d1d89e',width=2)
 for x,y in [(9,14),(11,10),(13,7)]:d.line((x,y,x+4,y-1),fill='#b4c889' if good else '#c7ae80')
 if frame==1:
  d.polygon([(14,10),(19,9),(16,14),(12,12)],fill='#665747');d.line((5,13,10,13),fill='#675e42')
 if frame==2:
  d.polygon([(6,9),(10,11),(7,13)],fill=(0,0,0,0));d.line((15,5,18,9),fill='#685c42',width=2)
 if frame==3:d.point((16,8),fill='#e1e9bb')
 return outline(im)
if __name__=='__main__':
 strip([station(f) for f in range(6)]).save(ROOT/'assets/wt_stations.png')
 strip([leaf(f) for f in range(4)]).save(ROOT/'assets/wt_leaves.png')
 audio('wt_clamp',.22,lambda t,r:(math.sin(t*math.tau*380)*.24+r.uniform(-.08,.08))*math.exp(-t*22))
 audio('wt_grind',.7,lambda t,r:(r.uniform(-.22,.22)+math.sin(t*math.tau*180)*.05)*math.sin(t/.7*math.pi)**2)
 audio('wt_pour',.45,lambda t,r:(math.sin(t*math.tau*(560+math.sin(t*35)*150))*.12+r.uniform(-.1,.1))*math.sin(t/.45*math.pi))
