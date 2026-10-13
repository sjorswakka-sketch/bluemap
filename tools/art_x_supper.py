"""Original pixel-art furniture, food and synthesized kitchen sounds. No third-party assets."""
from pathlib import Path
from PIL import Image, ImageDraw
from artlib import blank, outline, strip
from art_x_opening import audio
import math
ROOT=Path(__file__).resolve().parent.parent

def item(i):
    im=blank();d=ImageDraw.Draw(im)
    if i==0:
        d.arc((2,1,13,12),180,360,fill='#d1b078',width=2)
        d.polygon([(1,6),(14,6),(12,14),(3,14)],fill='#ad7c49')
        for y in (8,11,13):d.line((3,y,12,y),fill='#e2b877')
        for x in (4,7,10):d.line((x,7,x,13),fill='#745537')
        d.polygon([(4,5),(8,3),(12,5),(8,7)],fill='#a7c7bd');d.point((10,5),fill='#334854')
        d.line((4,4,3,2),fill='#729858',width=2)
    else:
        d.ellipse((1,6,14,14),fill='#738691');d.ellipse((1,4,14,11),fill='#e2d0ac')
        d.ellipse((3,5,12,9),fill='#c68c4f' if i==1 else '#91a16a')
        for x,y in [(5,6),(9,7),(7,8)]:d.point((x,y),fill='#e7cf97')
        d.line((12,2,10,6),fill='#ba9b76')
    return outline(im)

def stove(frame):
    im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
    d.rectangle((3,8,20,21),fill='#767c85');d.rectangle((2,7,21,10),fill='#abb1ae')
    d.rectangle((6,12,16,20),fill='#303e4b');d.rectangle((7,14,15,19),fill='#ab6440')
    for x in [8,11,14]: d.polygon([(x-1,18),(x,12+(x+frame)%3),(x+2,18)],fill='#e7ad59')
    d.rectangle((4,22,6,23),fill='#414952');d.rectangle((17,22,19,23),fill='#414952')
    d.ellipse((6,3,18,10),fill='#3d5664');d.ellipse((6,2,18,6),fill='#a8b8b4');d.ellipse((8,3,16,5),fill='#a78356')
    d.line((17,0,14,5),fill='#c4a47e',width=2)
    return im

def table(full):
    im=Image.new('RGBA',(48,32));d=ImageDraw.Draw(im)
    for x in (5,39):d.rectangle((x,17,x+3,29),fill='#513f38')
    d.rounded_rectangle((2,5,45,23),radius=3,fill='#6b4c36')
    d.rectangle((3,5,44,19),fill='#ab8153')
    for y in (8,12,16):d.line((4,y,43,y),fill='#c79b66')
    d.rectangle((19,5,27,21),fill='#638a8a')
    for x,y in [(9,9),(34,9),(10,16),(34,16)]:
        d.ellipse((x-3,y-2,x+3,y+2),fill='#e2d4b4')
        if full:d.ellipse((x-2,y-1,x+2,y+1),fill='#91a16a' if full==2 else '#b4834f')
    d.ellipse((20,10,26,15),fill='#ddc79b' if full else '#bdac89')
    if full:
        d.ellipse((14,10,18,13),fill='#d5a863');d.line((15,11,17,11),fill='#8e6943')
        d.rectangle((23,7,24,10),fill='#eed698');d.point((24,6),fill='#ffd786')
    return im

def net(fixed):
    im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
    for x in (2,21):d.rectangle((x,3,x+1,23),fill='#90734e')
    d.line((2,5,22,5),fill='#c4a16b',width=2)
    for x in range(4,22,3):d.line((x,6,x-2,17),fill='#a0a68a')
    for y in range(7,19,3):d.line((4,y,19,y),fill='#d3c6a1')
    if not fixed:
        d.rectangle((9,10,15,15),fill=(0,0,0,0));d.line((9,9,11,13),fill='#ebc97e')
    else:d.line((9,9,11,13,14,10,15,16),fill='#ebc97e')
    return im

def notice():
    im=blank();d=ImageDraw.Draw(im)
    d.rectangle((7,9,8,15),fill='#826647');d.rectangle((1,1,14,11),fill='#92764f')
    d.rectangle((3,2,12,10),fill='#e1cea0');d.ellipse((5,4,10,7),fill='#657e83');d.line((4,9,11,9),fill='#a18059')
    return outline(im)

if __name__=='__main__':
    for name,frames in [('items',[item(i) for i in range(3)]),('stove',[stove(i) for i in range(2)]),('table',[table(i) for i in range(3)]),('net',[net(i) for i in range(2)]),('notice',[notice()])]:
        strip(frames).save(ROOT/'assets'/('ls_'+name+'.png'))
    audio('ls_reel',1.0,lambda t,r:0.15*r.uniform(-1,1)*max(0,math.sin(t*math.tau*16))*math.sin(math.pi*t))
    audio('ls_chop',0.6,lambda t,r:0.25*(math.sin(math.tau*180*t)+r.uniform(-0.3,0.3))*math.exp(-30*(t%0.2)))
    audio('ls_simmer',1.0,lambda t,r:0.14*r.uniform(-1,1)*math.sin(math.pi*t)**2+0.08*math.sin(math.tau*(260*t+80*t*t))*max(0,math.sin(t*35))**6)
    audio('ls_serve',0.8,lambda t,r:0.22*(math.sin(math.tau*660*t)+0.4*math.sin(math.tau*880*t))*math.exp(-t*6)*min(1,t*100))
