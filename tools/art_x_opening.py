"""Original village characters, rake and synthesized sound. No downloaded assets."""
from pathlib import Path
import math, random, struct, wave
from PIL import ImageDraw
from artlib import blank, outline, strip
ROOT=Path(__file__).resolve().parent.parent

def person(role, frame):
    im=blank(); d=ImageDraw.Draw(im); step=frame%2
    d.rectangle((5,11,7,14-step),fill='#384a48');d.rectangle((9,11,11,13+step),fill='#384a48')
    d.rectangle((4,7,11,11),fill='#548668' if role=='gardener' else '#a26b53')
    d.rectangle((6,7,9,12),fill='#d7c09a')
    d.rectangle((5,3,10,6),fill='#e9bb89');d.point((6,4),fill='#303e4e');d.point((9,4),fill='#303e4e')
    if role=='gardener':
        d.rectangle((4,1,11,2),fill='#c9a15c');d.rectangle((2,3,13,3),fill='#e8ca7c')
        d.rectangle((11,9,14,12),fill='#728e9b');d.line((13,9,15,8+step),fill='#b1cfcd')
    else:
        d.rectangle((5,1,10,2),fill='#664332');d.rectangle((3,8,12,11),fill='#a87942')
        for x in [4,7,10]:d.rectangle((x,7,x+1,9),fill='#efd39b')
    return outline(im)

def audio(name, duration, fn):
    rate=22050; rng=random.Random(9)
    values=[max(-1,min(1,fn(i/rate,rng)))*17000 for i in range(round(duration*rate))]
    with wave.open(str(ROOT/'assets/audio'/f'{name}.wav'),'wb') as f:
        f.setparams((1,2,rate,0,'NONE','not compressed'))
        f.writeframes(b''.join(struct.pack('<h',round(v)) for v in values))

if __name__=='__main__':
    for role in ['gardener','courier']:
        strip([person(role,i) for i in range(4)]).save(ROOT/'assets'/f'op_{role}.png')
    rake=blank();d=ImageDraw.Draw(rake)
    d.line((3,14,11,4),fill='#cea66a',width=2);d.line((8,1,14,7),fill='#a6c1cc',width=2)
    for x,y in [(8,1),(10,3),(12,5),(14,7)]: d.line((x,y,x-2,y+2),fill='#a6c1cc')
    outline(rake).save(ROOT/'assets/op_rake.png')
    audio('op_hammer',0.45,lambda t,r:(math.sin(t*math.tau*960)+0.4*math.sin(t*math.tau*1730))*math.exp(-t*17)*0.5)
    audio('op_rake',1.6,lambda t,r:r.uniform(-1,1)*0.3*(0.3+0.7*abs(math.sin(t*math.tau*3)))*math.sin(math.pi*t/1.6))
    audio('op_water',3,lambda t,r:r.uniform(-1,1)*0.18+0.06*math.sin(math.tau*(270*t+3*math.sin(t*math.tau*3))))
    audio('op_drip',0.7,lambda t,r:math.sin(math.tau*(850*t-270*t*t))*math.exp(-t*16)*0.55)
