"""Eight original residents, working tools, travellers' book and page sound."""
from pathlib import Path
from PIL import Image, ImageDraw
from artlib import strip, outline
from art_x_opening import audio
import math
ROOT = Path(__file__).resolve().parent.parent
COATS=['#66899a','#628e5b','#bb7c57','#657db0','#977b4d','#bb9560','#9076a9','#59938b']
SKIN=['#e2b98d','#bc875f','#f0caa0','#af795b','#ceaa7f','#9b694e','#d9a889','#e2bd98']
def person(k,f):
 im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
 d.rectangle((5,3,10,7),fill=SKIN[k]);d.rectangle((4,8,11,13),fill=COATS[k])
 d.rectangle((3,9,4,11+f),fill=SKIN[k]);d.rectangle((11,9-f,12,11),fill=SKIN[k])
 d.rectangle((5,14-f,6,15),fill='#3c4350');d.rectangle((9,13+f,10,15),fill='#3c4350')
 d.point((6,5),fill='#313b42');d.point((9,5),fill='#313b42')
 d.line((6,8,8,12),fill='#eee0b0');d.line((5,12,10,12),fill='#4a5854')
 if k==0:
  d.rectangle((4,1,11,3),fill='#c6a05b');d.rectangle((3,3,12,3),fill='#a27e43');d.point((8,2),fill='#ffffa2')
 elif k==1:
  d.arc((3,0,11,8),180,340,fill='#89533d',width=3);d.rectangle((10,5,12,9),fill='#89533d')
 elif k==2:
  d.rectangle((4,1,11,2),fill='#ecdfc1');d.rectangle((3,2,12,3),fill='#ecdfc1');d.rectangle((6,9,9,12),fill='#e4c5a1')
 elif k==3:
  d.rectangle((4,2,11,3),fill='#7c5941');d.rectangle((5,1,10,2),fill='#7c5941');d.line((5,6,10,6),fill='#c3dce0')
 elif k==4:
  d.rectangle((4,1,11,3),fill='#6e7960');d.line((5,8,10,11),fill='#decc91',width=2)
 elif k==5:
  d.rectangle((4,1,11,3),fill='#e7d6ac');d.rectangle((3,3,12,3),fill='#e7d6ac');d.line((9,7,11,11),fill='#e7d6ac',width=2)
 elif k==6:
  d.rectangle((4,1,11,3),fill='#573f49');d.rectangle((3,4,4,8),fill='#573f49');d.rectangle((11,4,12,8),fill='#573f49')
 else:
  d.rectangle((4,1,11,3),fill='#49716a');d.line((4,8,11,8),fill='#e09c5e',width=2);d.rectangle((11,10,13,14),fill='#997544')
 return outline(im)
def tool(k):
 im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
 if k==0:d.line((3,13,12,3),fill='#c19762',width=2);d.line((6,2,14,8),fill='#b1c8cd',width=2)
 elif k==1:
  d.rectangle((3,6,11,12),fill='#6493a0');d.arc((0,3,7,10),80,290,fill='#99c1bd');d.polygon([(11,8),(15,6),(15,9),(11,11)],fill='#94b6b9')
 elif k==2:
  d.ellipse((2,5,13,13),fill='#52677a');d.ellipse((3,5,12,9),fill='#bca45f');d.line((7,2,10,7),fill='#e4caa0',width=2)
 elif k==3:
  d.arc((5,1,11,7),180,360,fill='#c8ab73');d.rectangle((4,6,12,13),fill='#4c6274');d.rectangle((6,7,10,11),fill='#ffd889')
 elif k==4:
  d.rectangle((1,7,12,12),fill='#b3985e');d.line((0,5,13,5),fill='#c2ab77',width=2)
  for x in (3,6,9):d.line((x,7,x,12),fill='#715d3b')
 elif k==5:
  d.rectangle((6,3,10,5),fill='#ad764c');d.ellipse((4,5,12,14),fill='#c68e5d');d.arc((0,5,8,11),90,270,fill='#c68e5d',width=2)
 elif k==6:
  d.polygon([(1,4),(7,3),(14,4),(14,13),(7,12),(1,13)],fill='#e4d0a3');d.line((7,4,7,12),fill='#b09662')
  for y in (6,9):d.line((3,y,5,y),fill='#846e57');d.line((9,y,12,y),fill='#846e57')
 elif k==8:
  d.ellipse((2,7,13,14),fill='#9c774e');d.ellipse((3,7,12,11),fill='#d4b989')
  for x,y in [(5,8),(8,9),(10,8)]:d.rectangle((x,y,x+1,y+1),fill='#547a50')
 else:
  d.rectangle((2,5,13,12),fill='#e5d6b2');d.line((2,5,8,9,13,5),fill='#a79470');d.rectangle((7,8,9,10),fill='#b16b56')
 return outline(im)
def book(f):
 im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
 d.rectangle((3,9,20,17),fill='#775941');d.rectangle((4,18,6,22),fill='#67503a');d.rectangle((17,18,19,22),fill='#67503a')
 d.rectangle((4,6,19,14),fill='#4a776d');d.rectangle((5,5,18,13),fill='#e2cda4');d.line((12,5,12,13),fill='#a38961')
 for y in (7,10):d.line((6,y,10,y),fill='#8e7957');d.line((14,y,17,y),fill='#8e7957')
 d.line((17,4,20,1+f),fill='#deb867');d.point((20,1+f),fill='#f0dcc1')
 return outline(im)
if __name__=='__main__':
 strip([person(k,f) for k in range(8) for f in range(2)]).save(ROOT/'assets/wm_people.png')
 strip([tool(k) for k in range(9)]).save(ROOT/'assets/wm_tools.png')
 strip([book(f) for f in range(2)]).save(ROOT/'assets/wm_book.png')
 audio('wm_page',.22,lambda t,r:r.uniform(-.3,.3)*math.sin(math.pi*t/.22)**2)
