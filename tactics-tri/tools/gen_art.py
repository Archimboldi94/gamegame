#!/usr/bin/env python3
"""Generate the complete original illuminated miniature folio with Pillow.

No reference images are read. `--battle-only` regenerates battlefield, figures,
portraits, chrome and effects. Full generation also paints story backgrounds
and launcher icons. Every isometric asset uses TW/TH/HS = 160/80/40.
"""
import math
import random
import sys
from PIL import Image
from miniature import (Pen, INK, LAPIS, VERMILION, JADE, GOLD, PALE_GOLD, PAPER,
                       IVORY, ROOT, tint, save, leaf, flower, star, scale_emblem)
from gen_battle_art import generate as gen_battle_art, cypress, TW, TH, HS


def chrome(bg, edge=GOLD):
    p=Pen((144,144),bg)
    p.rect((2,2,141,141),outline=edge,width=1.6)
    p.rect((7,7,136,136),outline=tint(edge,-33),width=.7)
    # Corner illumination remains fixed under nine-patch stretching.
    for x,y,sx,sy in [(12,12,1,1),(132,12,-1,1),(12,132,1,-1),(132,132,-1,-1)]:
        p.polygon([(x,y+14*sy),(x,y),(x+14*sx,y)],tint(bg,10),edge,.7)
        p.line([(x+3*sx,y+13*sy),(x+3*sx,y+3*sy),(x+13*sx,y+3*sy)],edge,.7)
        star(p,x+7*sx,y+7*sy,2.4,edge)
    return p.image()


def gen_ui():
    specs={'normal':LAPIS,'hover':(46,89,144),'pressed':(27,47,88),'disabled':(66,69,79)}
    for state,col in specs.items():
        im=chrome(col,GOLD if state!='disabled' else (139,130,106))
        save(im,'ui','btn_'+state)
        save(im,'ui','button' if state=='normal' else 'button_'+state)
    save(chrome((29,44,68)),'ui','panel')
    # Decorative parchment rim with dark ink centre keeps Chinese text legible.
    p=Pen((144,144),(28,43,66));p.rect((0,0,143,143),PAPER)
    p.rect((4,4,139,139),LAPIS,GOLD,1)
    p.rect((11,11,132,132),(28,43,66),GOLD,.7)
    for x,y in [(8,8),(136,8),(8,136),(136,136)]:star(p,x,y,4,GOLD)
    save(p.image(),'ui','battle_panel')
    p=Pen((64,64));p.polygon([(8,28),(35,28),(35,19),(56,32),(35,45),(35,36),(8,36)],LAPIS,GOLD,1.4)
    star(p,39,32,4,GOLD);save(p.image(),'ui','arrow')
    for name,deg in [('ne',-26.565),('se',26.565),('sw',153.435),('nw',206.565)]:
        save(p.image().rotate(-deg,resample=Image.Resampling.BICUBIC),'ui','arrow_'+name)


def gen_fx():
    for name,col in [('highlight',(103,198,199,80)),('cursor',(234,203,135,70)),('frost',(166,225,229,85))]:
        p=Pen((TW,TH));p.polygon([(80,3),(154,40),(80,77),(6,40)],col,PALE_GOLD,1)
        if name=='frost':
            for x,y in [(51,35),(81,51),(99,28)]:
                for i in range(3):
                    a=math.pi*i/3;p.line([(x-math.cos(a)*7,y-math.sin(a)*4),(x+math.cos(a)*7,y+math.sin(a)*4)],IVORY,.7)
        save(p.image(),'fx',name)
        if name=='frost':save(p.image(),'tiles','fx_ice')
    p=Pen((160,120))
    for x,y,h in [(44,92,46),(79,83,64),(107,94,38)]:
        p.curve([(x-10,y),(x-25,y-20),(x+9,y-h*.6),(x,y-h)],VERMILION,9)
        p.curve([(x-2,y),(x-12,y-20),(x+13,y-h*.55),(x,y-h+9)],GOLD,5)
        p.curve([(x+1,y),(x-5,y-10),(x+7,y-22),(x,y-32)],PALE_GOLD,2.5)
    save(p.image(),'tiles','fx_fire');save(p.image(),'fx','fire')


def border(p,w,h):
    p.rect((20,20,w-21,h-21),outline=GOLD,width=3)
    p.rect((29,29,w-30,h-30),outline=LAPIS,width=6)
    p.rect((38,38,w-39,h-39),outline=GOLD,width=1)
    for x in range(57,w-40,34):
        for y in [29,h-30]:flower(p,x,y,4,GOLD)
    for y in range(63,h-40,34):
        for x in [29,w-30]:flower(p,x,y,4,GOLD)
    for x,y in [(30,30),(w-31,30),(30,h-31),(w-31,h-31)]:star(p,x,y,13,GOLD)


def mountains(p,w,h,night=False,snow=False):
    # Scalloped strata from manuscript landscapes; no photographic shading.
    colors=[(155,164,157),(116,146,138),(69,122,111)]
    if night:colors=[(70,85,123),(51,80,112),(38,70,91)]
    if snow:colors=[(195,203,190),(171,190,182),(136,169,160)]
    for row,col in enumerate(colors):
        rng=random.Random('ridge'+str(row));base=h*(.36+row*.16)
        pts=[(0,h)]
        for x in range(-70,w+100,100):
            yy=base+rng.randint(-55,55)
            pts.extend([(x,yy+50),(x+22,yy+9),(x+44,yy-12),(x+62,yy+14),(x+82,yy+6)])
        pts.extend([(w,h)]);p.polygon(pts,col,GOLD,.8)
        for x,y in pts[2:-2:4]:
            p.curve([(x,y+15),(x+10,y+45),(x-14,y+60),(x+9,y+85)],tint(col,25),1)
            p.curve([(x+12,y+13),(x+22,y+38),(x+9,y+50),(x+20,y+65)],tint(col,-16),.8)


def pavilion(p,x,y,s=1):
    def pts(values):return [(x+a*s,y+b*s) for a,b in values]
    p.polygon(pts([(-80,0),(-80,-140),(80,-140),(80,0)]),PAPER,INK,1.3)
    p.polygon(pts([(-93,-140),(0,-197),(93,-140)]),LAPIS,GOLD,2)
    p.line(pts([(-85,-144),(0,-188),(85,-144)]),PALE_GOLD,1)
    for xx in [-52,0,52]:
        p.polygon(pts([(xx-15,0),(xx-15,-83),(xx,-104),(xx+15,-83),(xx+15,0)]),LAPIS,GOLD,1)
    for yy in [-126,-114]:p.line(pts([(-78,yy),(78,yy)]),JADE,3)
    for xx in range(-60,70,20):
        a,b=pts([(xx,-121)])[0];star(p,a,b,4*s,GOLD)


def gen_backgrounds():
    w,h=1920,1080
    for name in ['title','camp','field','village','night','battle','ford','snow']:
        night=name in ['title','camp','night']; snow=name=='snow'
        bg=(35,59,99) if night else ((208,220,205) if snow else PAPER)
        p=Pen((w,h),bg,scale=2);rng=random.Random('page-'+name)
        if name=='battle':
            # Quiet folio page around the playable diorama.
            for x,y in [(180,280),(1730,270),(160,690),(1740,700)]:
                for j in range(5):
                    leaf(p,x+j*7,y-j*19,10,35,(191,180,143),-15)
                    flower(p,x+j*7-8,y-j*19-20,5,(192,174,124))
            for i in range(18):
                x,y=rng.randrange(70,1850),rng.randrange(65,1000)
                p.line([(x,y),(x+30,y+3)],(217,201,161),.5)
        else:
            mountains(p,w,h,night,snow)
            for x,y in [(140,820),(300,960),(1670,930),(1770,700)]:
                cypress(p,x,y,70,230)
            if name in ['ford','field','snow']:
                p.polygon([(1100,580),(1330,580),(1180,725),(1400,1080),(1110,1080),(950,740)],(42,119,148),GOLD,1)
                for i in range(24):
                    x=1140+rng.randrange(-55,80);y=660+i*17
                    p.curve([(x-22,y),(x,y-8),(x+7,y+7),(x+35,y)],(148,200,193),1)
                pavilion(p,430,690,1.6);pavilion(p,1510,650,1)
            elif name in ['village','camp']:pavilion(p,450,770,1.4);pavilion(p,1490,730,1.3)
            if night:
                p.ellipse((1510,113,1580,183),PALE_GOLD)
                for i in range(55):star(p,rng.randrange(80,w-80),rng.randrange(70,370),rng.choice([1.5,2,3]),GOLD)
            if name=='title':
                p.ellipse((715,100,1205,590),LAPIS,GOLD,2)
                p.ellipse((729,114,1191,576),outline=GOLD,width=.8)
                scale_emblem(p,960,200,250)
                for a in range(24):
                    t=a*math.tau/24;flower(p,960+math.cos(t)*228,345+math.sin(t)*228,5,GOLD)
        border(p,w,h);save(p.image().convert('RGB'),'bg',name)


def gen_icons():
    p=Pen((512,512),LAPIS);p.rect((18,18,493,493),outline=GOLD,width=5)
    for x,y in [(41,41),(471,41),(41,471),(471,471)]:star(p,x,y,22,GOLD)
    scale_emblem(p,256,135,270)
    img=p.image();img.save(ROOT/'icon.png');save(img.resize((192,192)),'icons','icon_192')
    fg=Pen((432,432));scale_emblem(fg,216,114,204);save(fg.image(),'icons','icon_fg_432')
    save(Image.new('RGB',(432,432),LAPIS),'icons','icon_bg_432')


if __name__=='__main__':
    gen_battle_art();gen_ui();gen_fx()
    if '--battle-only' not in sys.argv:
        gen_backgrounds();gen_icons()
    print('Original miniature folio generated; all assets use one pigment/pattern library.')
