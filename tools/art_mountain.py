#!/usr/bin/env python3
"""Original snow macaque sprites and mountain rock atlas, drawn pixel by pixel."""
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parent.parent

def macaques(size):
    # Native 32 px art; the 16 px atlas keeps the shared sprite/UI contract.
    atlas = Image.new('RGBA', (128, 32))
    for frame in range(4):
        img = Image.new('RGBA', (32, 32)); d = ImageDraw.Draw(img)
        bob = frame % 2
        d.ellipse((6, 12+bob, 26, 29), fill='#514c56')
        d.ellipse((7, 12+bob, 25, 27), fill='#a6a2a0')
        d.ellipse((10, 16+bob, 23, 27), fill='#c4c1b3')
        d.rectangle((4, 15+bob, 8, 27), fill='#8d8b8c')
        d.rectangle((24, 15+bob, 28, 26), fill='#8d8b8c')
        d.rectangle((5, 26, 9, 28), fill='#ad6659')
        d.rectangle((23, 25, 27, 27), fill='#ad6659')
        d.ellipse((7, 3+bob, 25, 18+bob), fill='#d6d0bf')
        d.ellipse((6, 8+bob, 10, 13+bob), fill='#ad6659')
        d.ellipse((24, 8+bob, 28, 13+bob), fill='#ad6659')
        d.ellipse((10, 5+bob, 24, 17+bob), fill='#ad514a')
        d.rectangle((13, 6+bob, 21, 14+bob), fill='#cf7562')
        d.rectangle((12, 9+bob, 14, 10+bob), fill='#342f38')
        d.rectangle((20, 9+bob, 22, 10+bob), fill='#342f38')
        d.rectangle((16, 13+bob, 18, 14+bob), fill='#f0a08b')
        d.line((15, 16+bob, 19, 16+bob), fill='#733f43')
        lift = 2 if frame in (1, 3) else 0
        d.rectangle((9, 26-lift, 13, 29-lift), fill='#615e64')
        d.rectangle((19, 26-(2-lift), 23, 29-(2-lift)), fill='#615e64')
        for x,y in [(8,12),(7,17),(23,10),(22,22),(10,25),(17,26)]:
            d.point((x,y+bob), '#e6dfcd')
        atlas.alpha_composite(img, (32*frame, 0))
    atlas.save(ROOT/'assets/pixel_snow_macaque.png')
    atlas.resize((64,16),Image.Resampling.NEAREST).save(ROOT/'assets/snow_macaque.png')

def cliffs():
    atlas=Image.new('RGBA',(96,32));d=ImageDraw.Draw(atlas)
    for variant in range(3):
        x=variant*32
        d.rectangle((x,0,x+31,31),fill='#586d7c')
        # Broken basalt planes, with no regular brick or striped-wall pattern.
        d.polygon([(x,3),(x+16,2),(x+24,10),(x+19,23),(x+1,26)],fill='#6a8392')
        d.polygon([(x+17,2),(x+31,5),(x+31,24),(x+20,30),(x+23,15)],fill='#425d71')
        d.polygon([(x,24),(x+11,20),(x+20,31),(x,31)],fill='#4b6274')
        for j in range(8):
            xx=x+(j*11+variant*5)%31; yy=6+(j*7)%25
            d.line((xx,yy,xx-2,yy+5),fill='#3e5566',width=1)
            d.line((xx+1,yy,xx+1,yy+3),fill='#9aaeba',width=1)
        if variant==0:
            d.polygon([(x,0),(x+31,0),(x+31,3),(x+25,5),(x+19,3),(x+13,6),(x+6,3),(x,5)],fill='#ecf2e8')
            for j in range(5):
                xx=x+(j*7)%30
                d.rectangle((xx,3,xx+2,5+j%3),fill='#cedfe1')
        elif variant==2:
            d.polygon([(x+2,4),(x+17,1),(x+24,6),(x+13,9),(x+4,8)],fill='#b0c8ce')
            d.polygon([(x+22,19),(x+30,16),(x+29,22),(x+20,24)],fill='#a5bfc8')
    atlas.save(ROOT/'assets/mountain_cliffs.png')

if __name__=='__main__':
    macaques(32);cliffs()
