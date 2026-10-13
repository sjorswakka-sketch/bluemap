"""Original first-route pixel art and synthesized field sounds; no external assets."""
from pathlib import Path
import math
from PIL import ImageDraw
from artlib import blank, outline, strip
from art_x_opening import audio
ROOT=Path(__file__).resolve().parent.parent
def beast(kind,frame):
    im=blank(); d=ImageDraw.Draw(im)
    if kind=='bramble':
        d.polygon([(1,12),(2,7),(4,8),(4,3),(7,5),(10,1),(11,6),(14,4),(14,12),(11,14),(4,14)],fill='#496c4c')
        for x,y in [(4,6),(8,4),(11,8),(6,11)]:d.line((x,y,x+2,y-2),fill='#90a565',width=2)
        if frame: d.rectangle((5,8,11,12),fill='#b29369')
        d.point((6,9),fill='#ffe5a0');d.point((10,9),fill='#ffe5a0')
        if frame==2: d.line((2,14,5,11),fill='#ccaa78',width=2);d.line((11,11,15,13),fill='#ccaa78',width=2)
    else:
        d.polygon([(2,12),(2,7),(5,3),(10,2),(14,7),(13,13),(9,15),(4,14)],fill='#727f91')
        d.polygon([(3,7),(6,4),(10,3),(12,7),(8,9)],fill='#a0b4bf')
        for x in [5,10]:d.rectangle((x,8,x+1,8+(2 if frame else 0)),fill='#90e3de')
        d.line((7,3,7,6,9,8),fill='#435669')
        if frame==2:d.rectangle((1,11,4,14),fill='#546478');d.rectangle((12,10,15,13),fill='#546478')
    return outline(im)
def bird(frame):
    im=blank();d=ImageDraw.Draw(im)
    d.ellipse((4,6,10,11),fill='#a07652');d.rectangle((8,4,11,8),fill='#638d94')
    d.point((10,5),fill='#f6e4b4');d.line((12,7,14,7),fill='#d6b578')
    d.polygon([(5,8),(1,3 if frame else 10),(7,10)],fill='#496b76')
    d.line((6,12,6,13),fill='#c6ad83');d.line((9,12,9,13),fill='#c6ad83')
    return im
def obj(index):
    im=blank();d=ImageDraw.Draw(im)
    if index==0:
        d.ellipse((2,7,13,13),fill='#587383');d.ellipse((2,5,13,10),fill='#c1b68b');d.ellipse((4,6,11,9),fill='#334f65');d.point((8,7),fill='#a4ded6')
    elif index==1:
        d.polygon([(1,4),(7,5),(14,3),(14,12),(8,14),(1,12)],fill='#bb9667')
        d.polygon([(2,3),(7,4),(12,2),(13,10),(8,12),(2,10)],fill='#e5d3a6')
        d.line((7,4,8,12),fill='#9c7859')
        for y in [5,7,9]:d.line((3,y,5,y+1),fill='#8f866e');d.line((9,y,11,y-1),fill='#8f866e')
    elif index in (2,3):
        d.rectangle((2,11,13,14),fill='#526d77');d.polygon([(4,11),(4,3),(6,1),(11,2),(12,11)],fill='#839ca2')
        if index==2:d.line((8,1,7,5,9,7,7,11),fill='#3f5666')
        else:
            for y in [4,6,8]:d.line((6,y,10,y),fill='#e4d5a3')
            d.ellipse((1,11,3,13),fill='#dda6a1');d.ellipse((12,11,14,13),fill='#d9c493')
    else:
        d.rectangle((1,2,14,13),fill='#817d72');d.rectangle((2,3,13,12),fill='#b5a486')
        d.line((5,10,5,5,11,5),fill='#566772',width=2);d.ellipse((7,6,9,8),fill='#ead5a7');d.line((8,9,11,11),fill='#566772')
    return outline(im)
def gear(index):
    im=blank();d=ImageDraw.Draw(im)
    if index==0:
        d.ellipse((3,4,12,13),outline='#dec99a',width=2);d.polygon([(6,2),(10,2),(11,5),(8,7),(5,5)],fill='#88c8cc')
    else:
        d.arc((2,0,13,11),0,180,fill='#b9ad96',width=2);d.polygon([(6,8),(10,8),(11,13),(8,15),(5,13)],fill='#779eb0');d.line((8,9,8,13),fill='#bde4d9')
    return outline(im)
if __name__=='__main__':
    for name in ['bramble','listener']:strip([beast(name,i) for i in range(3)]).save(ROOT/'assets'/f'rf_{name}.png')
    strip([bird(i) for i in range(2)]).save(ROOT/'assets/rf_bird.png')
    strip([obj(i) for i in range(5)]).save(ROOT/'assets/rf_objects.png')
    strip([gear(i) for i in range(2)]).save(ROOT/'assets/rf_gear.png')
    audio('rf_bird',0.7,lambda t,r:0.3*math.sin(math.tau*(1700*t+180*t*t))*math.sin(math.pi*t/0.7)**2*max(0,math.sin(t*math.tau*4)))
    audio('rf_rustle',0.85,lambda t,r:0.35*r.uniform(-1,1)*math.sin(math.pi*t/0.85)**2)
    audio('rf_purr',0.9,lambda t,r:0.25*math.sin(math.tau*95*t)*(0.5+0.5*math.sin(math.tau*23*t))*math.sin(math.pi*t/0.9))
    for name,hz in [('low',220),('mid',330),('high',440)]:
        audio('rf_'+name,1.5,lambda t,r,hz=hz:(math.sin(math.tau*hz*t)+0.25*math.sin(math.tau*hz*2.01*t))*0.4*math.exp(-t*3)*min(1,t*60))
