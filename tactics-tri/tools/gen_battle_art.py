#!/usr/bin/env python3
"""Original Persian-miniature battle art. Deterministic Pillow; no input art.
TW/TH/HS = 160/80/40, shared with IsoView. Units keep the 96x128 contract.
"""
import math
import random
from PIL import Image, ImageDraw
from miniature import (Pen, INK, LAPIS, VERMILION, JADE, GOLD, PALE_GOLD, PAPER,
                       IVORY, HEROES, CLASSES, ROOT, tint, save, leaf, flower,
                       star, textile, costume, scale_emblem)
TW, TH, HS = 160, 80, 40
PALETTE = {
 'grass': ((108,142,101),(150,126,91)), 'forest': ((66,115,87),(129,118,87)),
 'stone': ((198,185,146),(157,139,107)), 'ruins': ((177,168,133),(144,127,98)),
 'wall': ((188,180,151),(144,134,112)), 'bridge': ((176,127,77),(131,87,58)),
 'water': ((36,130,158),(35,83,111)), 'snow': ((226,231,213),(160,178,170)),
 'ice': ((162,205,208),(102,145,163))}


def iso(u,v):
    return (80+(u-v)*80,(u+v)*40)


def top_image(kind,variant):
    rng=random.Random(f'folio-{kind}-{variant}')
    c=PALETTE[kind][0]; p=Pen((TW,TH))
    diamond=[(80,0),(160,40),(80,80),(0,40)]
    p.polygon(diamond,c)
    # Broad pigment washes, no granular noise.
    for _ in range(9):
        u,v=rng.random(),rng.random(); x,y=iso(u,v)
        p.ellipse((x-13,y-4,x+13,y+4),tint(c,rng.choice([-5,4,7])))
    if kind in ('grass','forest','snow'):
        for _ in range(14):
            x,y=iso(rng.uniform(.12,.88),rng.uniform(.12,.88))
            color=(92,128,96) if kind!='snow' else (153,181,173)
            p.curve([(x-3,y+1),(x-1,y-3),(x+1,y-3),(x+4,y-1)],color,.55)
            leaf(p,x,y,1.4,4,tint(color,13),-2)
        for _ in range(4):
            x,y=iso(rng.uniform(.18,.82),rng.uniform(.18,.82))
            flower(p,x,y,1.5,(229,197,133) if kind!='snow' else IVORY)
    elif kind in ('stone','wall','ruins'):
        for u in range(3):
            for v in range(3):
                a,b=u/3+.013,v/3+.013; z,w=(u+1)/3-.013,(v+1)/3-.013
                pts=[iso(a,b),iso(z,b),iso(z,w),iso(a,w)]
                col=tint(c,rng.randint(-8,7))
                p.polygon(pts,col, tint(c,-33),.7)
                p.line(pts[:2],tint(col,20),.7)
        if kind=='stone' and variant in (0,2):
            pts=[iso(.34,.34),iso(.66,.34),iso(.66,.66),iso(.34,.66)]
            p.polygon(pts,(65,126,131),GOLD,.6)
            star(p,80,40,6,PALE_GOLD)
        if kind=='ruins':
            p.line([(63,26),(70,32),(67,37)],tint(c,-43),.7)
            for x,y in [(56,47),(101,36)]: leaf(p,x,y,3,5,JADE,2)
    elif kind=='bridge':
        for i in range(11):
            p.line([iso(i/10,0),iso(i/10,1)],(113,80,50),1)
            if i<10: p.line([iso(i/10+.026,.07),iso(i/10+.026,.9)],(204,159,99),.7)
        for v in [.06,.94]:
            p.line([iso(0,v),iso(1,v)],(106,72,49),3)
            for u in [.08,.5,.92]:
                x,y=iso(u,v); p.ellipse((x-1.1,y-1,x+1.1,y+1),GOLD)
    else:
        for i in range(8):
            x,y=iso(rng.uniform(.1,.9),rng.uniform(.1,.9))
            p.curve([(x-14,y),(x-5,y-5),(x+4,y+5),(x+14,y)],(133,202,203),.65)
            p.curve([(x-9,y+2),(x-3,y-1),(x+4,y+4),(x+8,y+2)],(64,153,177),.6)
        if kind=='ice':
            p.line([(53,34),(82,28),(91,41),(114,45)],IVORY,.8)
    # Clip washes and patterned pigment to the exact diamond.
    im=p.image(); mask=Image.new('L',(TW,TH))
    ImageDraw.Draw(mask).polygon([(80,0),(159,40),(80,79),(0,40)],fill=255)
    im.putalpha(mask)
    d=ImageDraw.Draw(im)
    d.line([(0,40),(80,0),(159,40)],fill=tint(c,21),width=1)
    d.line([(0,40),(80,79),(159,40)],fill=tint(c,-31),width=1)
    return im


def side_image(kind):
    p=Pen((TW,TH)); rng=random.Random('carved-'+kind); base=PALETTE[kind][1]
    for right in (False,True):
        def face(u,v):
            return ((80+u*80 if right else u*80),(40-u*40 if right else u*40)+v*40)
        c=tint(base,-19 if right else 0)
        p.polygon([face(0,0),face(1,0),face(1,1),face(0,1)],c)
        for row in range(2):
            for j in range(-1,4):
                a=max(0,j/3+(row%2)*.16); b=min(1,(j+1)/3+(row%2)*.16)
                if b<=a: continue
                pts=[face(a+.008,row*.5+.025),face(b-.008,row*.5+.025),face(b-.008,(row+1)*.5-.025),face(a+.008,(row+1)*.5-.025)]
                col=tint(c,rng.randint(-6,7));p.polygon(pts,col,tint(c,-22),.65)
                p.line(pts[:2],tint(col,17),.6)
                for off in [.18,.29]:
                    p.line([face(a+.035,row*.5+off),face(min(b-.02,a+.12),row*.5+off+.015)],tint(col,-9),.45)
        if kind in ('stone','wall','ruins'):
            # Small carved pointed niches within the sandstone courses.
            for u in [.16,.5,.83]:
                pts=[face(u-.055,.81),face(u-.055,.56),face(u,.43),face(u+.055,.56),face(u+.055,.81)]
                p.line(pts,tint(c,-26),.65)
                p.line([face(u-.035,.79),face(u,.53),face(u+.035,.79)],tint(c,17),.45)
        else:
            p.line([face(0,.06),face(1,.06)],tint(PALETTE[kind][0],-12),2)
    return p.image()


def cypress(p,x,y,w,h):
    p.line([(x,y),(x-1,y-h*.72)],(111,81,54),max(1,w*.07))
    for i in range(9):
        t=i/9; yy=y-h*.12-t*h*.8; span=w*.5*(1-t)**.65
        p.polygon([(x-span,yy),(x-span*.75,yy-h*.16),(x,yy-h*.25),(x+span*.7,yy-h*.13),(x+span,yy)],tint(JADE,-17+int(t*13)),INK,.45)
        for j in range(4):
            xx=x-span*.7+j*span*.45
            leaf(p,xx,yy-2,span*.18,max(4,h*.09),tint(JADE,12+j*5),(-1 if j<2 else 1)*span*.14)
    p.line([(x,y-h*.14),(x,y-h*.83)],(168,166,99),.65)


def decorations():
    p=Pen((60,82));cypress(p,30,79,49,77);save(p.image(),'tiles','deco_tree')
    p=Pen((66,48))
    for x,y,w,h in [(3,37,14,17),(24,41,18,31),(47,38,14,16)]:
        p.polygon([(x,y-h),(x+w*.5,y-h-4),(x+w,y-h),(x+w,y),(x+w*.5,y+4),(x,y)],(170,151,112),INK,.7)
        p.polygon([(x,y-h),(x+w*.5,y-h-4),(x+w,y-h),(x+w*.5,y-h+4)],PAPER,GOLD,.5)
        p.line([(x+w*.5,y-h+4),(x+w*.5,y+4)],(121,106,82),.7)
        p.line([(x+3,y-4),(x+3,y-h+6),(x+w*.3,y-h+4)],(202,183,139),.7)
    save(p.image(),'tiles','deco_rubble')


def unit_img(cls,body,accent,hair,enemy=False):
    p=Pen((96,128)); skin=(222,176,130); steel=(174,197,193)
    # Adult proportions: small head, long embroidered coat, separated boots.
    p.ellipse((26,117,74,126),(18,35,54,65))
    if cls in ('archer','lancer','warlord'):
        for x in [35,40,45]:
            p.line([(x,82),(x-8,27)],(116,80,48),1.2)
            p.polygon([(x-8,27),(x-13,31),(x-10,23)],IVORY,INK,.5)
    cape=[(35,44),(57,43),(73,105),(54,111),(26,107)]
    textile(p,cape,tint(body,-18),accent,10)
    for x in [40,55]:
        p.polygon([(x-5,96),(x+4,97),(x+3,117),(x+8,120),(x+8,124),(x-6,124)],(69,51,44),INK,.8)
        p.line([(x-3,107),(x+3,107)],accent,1)
    robe=[(35,44),(55,43),(64,61),(59,75),(66,105),(48,109),(30,104),(34,76),(27,61)]
    if cls=='thief': robe=[(35,45),(55,44),(61,60),(54,80),(64,95),(45,101),(29,93),(34,73),(28,60)]
    textile(p,robe,body,accent,9)
    p.polygon([(46,48),(52,49),(58,101),(49,106),(42,98)],tint(body,18))
    p.line([(46,48),(43,74),(49,103)],accent,.8)
    p.line([(56,79),(59,99)],tint(body,-30),.8)
    if cls in ('swordsman','lancer','warlord'):
        p.polygon([(34,45),(53,44),(57,66),(35,68)],tint(body,14),accent,.8)
        for y in range(49,66,4):
            for x in range(36,55,4): p.arc((x-1,y-1,x+2,y+2),0,170,steel,.55)
        for x in [32,58]:
            p.polygon([(x-6,47),(x,43),(x+6,47),(x+6,55),(x-5,56)],steel,INK,.8)
            p.line([(x-4,49),(x+4,49)],accent,1)
    # Sleeves and hands with clearly separated bent arms.
    textile(p,[(29,53),(36,54),(34,69),(26,79),(19,73)],body,accent,8)
    textile(p,[(58,52),(64,55),(69,70),(63,76),(57,66)],body,accent,8)
    p.ellipse((21,74,28,81),skin,INK,.6);p.ellipse((62,71,69,78),skin,INK,.6)
    p.line([(33,74),(59,74)],accent,3)
    star(p,47,74,3,PALE_GOLD)
    # Neck and three-quarter face, ink eyes rather than oversized cartoon eyes.
    p.polygon([(42,35),(52,35),(53,46),(47,51),(40,44)],tint(skin,-10),INK,.7)
    p.polygon([(37,21),(47,16),(56,22),(57,29),(61,33),(56,35),(55,42),(48,46),(40,41),(36,32)],skin,INK,.8)
    p.polygon([(35,24),(38,17),(49,14),(57,21),(54,25),(44,22),(39,29),(38,37),(34,33)],hair,INK,.7)
    p.line([(49,29),(54,29)],INK,.85);p.line([(51,27),(54,28)],hair,.65)
    p.line([(53,38),(56,37)],(130,69,54),.6)
    if cls in ('swordsman','archer','thief'):
        p.polygon([(33,24),(36,17),(48,14),(57,21),(57,25),(45,23),(35,28)],body,INK,.7)
        p.curve([(34,23),(39,17),(51,19),(55,23)],accent,1.3)
        p.polygon([(35,25),(26,37),(30,42),(39,27)],accent,INK,.5)
        if cls=='archer':
            leaf(p,48,17,3,13,PALE_GOLD,9)
    elif cls in ('lancer','warlord'):
        p.polygon([(33,26),(35,18),(44,11),(46,6),(50,13),(56,18),(58,28)],steel,INK,.8)
        p.line([(34,25),(56,25)],accent,2)
        leaf(p,46,13,4,12,VERMILION if enemy else LAPIS,4)
    elif cls=='mage':
        textile(p,[(34,25),(38,13),(45,3),(52,12),(58,25)],body,accent,7)
        p.line([(33,26),(58,26)],accent,2)
    elif cls=='healer':
        p.polygon([(35,19),(44,13),(53,16),(59,24),(59,46),(53,51),(53,27),(42,22),(37,38),(30,49)],IVORY,accent,.8)
        p.line([(36,21),(43,17),(54,20)],JADE,1.5)
    if cls=='thief': p.polygon([(40,37),(56,35),(55,43),(48,46),(39,42)],tint(body,-12),GOLD,.5)
    # Different weapon silhouettes, with gilded fittings.
    if cls in ('lancer','warlord'):
        p.line([(75,116),(77,21)],(111,73,47),2.2)
        p.polygon([(73,23),(78,4),(82,23),(77,29)],steel,INK,.7)
        p.line([(77,10),(77,25)],IVORY,.6)
        p.polygon([(76,30),(61,33),(68,41),(60,48),(76,44)],VERMILION if enemy else LAPIS,GOLD,.7)
        for y in [50,79,109]:p.line([(73,y),(78,y)],accent,1.3)
    elif cls=='swordsman':
        p.polygon([(66,75),(82,37),(85,31),(85,42),(71,79)],steel,INK,.7)
        p.line([(70,72),(82,42)],IVORY,.7)
        p.line([(62,74),(74,80)],accent,2.2)
        p.line([(68,79),(64,88)],(78,45,37),2.3)
        p.ellipse((15,55,34,80),body,accent,1.3);star(p,24,67,6,GOLD)
    elif cls=='archer':
        p.curve([(75,40),(95,61),(88,92),(72,105)],(170,121,63),2.2)
        p.line([(75,40),(72,105)],IVORY,.6)
        p.line([(61,76),(89,67)],(191,169,117),1)
        p.polygon([(90,67),(85,65),(86,70)],steel)
    elif cls in ('mage','healer'):
        p.line([(76,115),(76,37)],(126,85,52),2.1)
        if cls=='mage':
            p.polygon([(76,24),(83,34),(76,44),(69,34)],(90,183,190),GOLD,1)
            star(p,76,34,3,IVORY)
        else:
            p.arc((69,24,84,44),35,325,accent,2)
            flower(p,76,34,4,JADE)
        p.line([(73,49),(79,49)],GOLD,2)
    elif cls=='thief':
        for x,y in [(69,79),(23,78)]:
            p.polygon([(x,y),(x+8,y+16),(x+4,y+11),(x-3,y+2)],steel,INK,.7)
            p.line([(x-4,y+2),(x+3,y-2)],accent,1.5)
    # Shared team trim: lapis & cyan allies, vermilion enemies.
    team=VERMILION if enemy else (48,160,177)
    p.line([(31,103),(48,108),(65,104)],team,2)
    p.ellipse((43,54,49,60),team,PALE_GOLD,.7)
    return p.image()


def portrait(cls,body,accent,hair,elder=False,enemy=False):
    p=Pen((320,400));skin=(218,173,129);shadow=(190,139,107)
    # Flat illuminated niche; same mineral ground as the battlefield.
    p.rect((0,0,320,400),tint(body,-18))
    p.polygon([(12,400),(12,111),(42,58),(160,8),(278,58),(308,111),(308,400)],tint(body,-6),GOLD,1.4)
    for x,y in [(34,117),(286,117),(34,231),(286,231),(46,343),(273,343)]:
        leaf(p,x,y,6,17,tint(body,18),-6);flower(p,x,y-12,3,GOLD)
    p.arc((41,21,278,305),183,356,tint(GOLD,-27),.8)
    # Long patterned caftan, crossed collar, sash and embroidered shoulders.
    textile(p,[(21,400),(32,309),(92,275),(134,266),(198,266),(266,292),(302,329),(314,400)],body,accent,17)
    textile(p,[(194,274),(265,295),(300,329),(314,400),(230,400),(203,329)],tint(body,-17),accent,16)
    p.polygon([(119,246),(119,285),(153,312),(191,282),(184,237)],shadow,INK,1)
    p.polygon([(94,275),(125,271),(154,308),(137,338),(107,315)],accent,INK,1)
    p.polygon([(192,270),(218,281),(169,345),(151,311)],accent,INK,1)
    p.line([(129,288),(148,317),(139,329)],PALE_GOLD,1)
    for y in [341,364,387]:
        star(p,164,y,4,GOLD)
        p.line([(146,y),(156,y)],tint(body,35),.8)
    if cls in ('lancer','warlord','swordsman'):
        for x in [48,225]:
            p.polygon([(x-13,302),(x+12,285),(x+45,302),(x+37,332),(x-9,329)],(130,159,155),INK,1.2)
            p.line([(x-9,304),(x+13,292),(x+40,305)],GOLD,2)
            for xx in range(x,x+35,7):p.arc((xx,307,xx+7,315),0,170,PALE_GOLD,1)
    # Modest head, long nose, small almond eye: manuscript portrait proportions.
    p.polygon([(110,107),(181,82),(209,110),(213,152),(227,174),(212,180),(207,211),(184,238),(162,247),(124,225),(109,186)],skin,INK,1.5)
    p.polygon([(204,115),(213,154),(227,174),(212,180),(207,211),(184,238),(164,245),(180,222),(195,199)],shadow)
    p.ellipse((98,155,118,185),skin,INK,1)
    p.line([(105,162),(110,171),(105,177)],shadow,1)
    p.curve([(133,161),(140,154),(151,154),(159,159)],INK,1.7)
    p.curve([(135,161),(146,168),(155,164),(159,159)],(127,83,67),.8)
    p.ellipse((147,157,151,163),INK)
    p.line([(135,149),(147,145),(160,148)],hair,2)
    p.curve([(184,156),(191,150),(200,151),(206,155)],INK,1.5)
    p.ellipse((197,153,201,159),INK)
    p.line([(184,145),(196,142),(206,147)],hair,1.7)
    p.line([(180,165),(177,190),(185,194),(194,190)],(157,105,81),1)
    p.curve([(168,214),(179,211),(190,214),(200,209)],(137,68,58),1)
    p.line([(176,224),(190,222)],(234,191,145),.8)
    p.polygon([(104,160),(99,126),(112,93),(161,73),(192,84),(208,112),(190,106),(163,99),(131,113),(119,151),(116,198),(103,215)],hair,INK,1)
    for i in range(5):p.curve([(109+i*4,144),(104+i*5,109),(131+i*7,91),(153+i*6,89)],tint(hair,22),.8)
    if elder or cls=='warlord':
        p.polygon([(120,206),(142,215),(164,228),(203,203),(197,243),(170,269),(139,253)],hair,INK,1)
        for x in range(139,195,6):p.line([(x,230),(x-3,249)],tint(hair,30),.8)
        p.line([(134,176),(144,179)],shadow,1)
    if cls in ('swordsman','archer','thief'):
        # Wrapped silk turban with fine gold seams (no oversized fantasy hair).
        p.polygon([(94,132),(94,107),(112,76),(152,62),(192,72),(214,103),(216,129),(181,118),(134,119)],body,INK,1.4)
        for off in [0,12,24]:
            p.curve([(97,123-off*.5),(127,103-off),(176,82+off*.2),(207,111+off*.4)],accent,2.3)
        p.polygon([(103,126),(74,172),(83,209),(101,174),(117,129)],body,accent,1)
        star(p,174,100,8,GOLD)
        if cls=='archer':leaf(p,177,85,8,49,PALE_GOLD,27)
    elif cls in ('lancer','warlord'):
        textile(p,[(92,135),(94,100),(114,72),(152,48),(166,26),(177,61),(201,81),(216,115),(215,135)],(122,158,160),GOLD,13)
        p.line([(94,125),(158,119),(215,127)],GOLD,5)
        p.line([(164,43),(163,116)],PALE_GOLD,1.5)
        leaf(p,164,51,10,48,VERMILION if enemy else LAPIS,23)
    elif cls=='mage':
        textile(p,[(94,124),(106,81),(134,46),(158,20),(189,70),(213,124)],body,accent,13)
        p.line([(94,126),(212,126)],GOLD,5)
        star(p,156,76,11,GOLD)
    elif cls=='healer':
        p.polygon([(89,130),(94,91),(129,61),(170,60),(202,80),(220,121),(227,249),(207,270),(199,121),(174,102),(132,100),(116,143),(104,254),(82,263)],IVORY,accent,1.6)
        p.curve([(94,123),(99,59),(198,52),(216,120)],GOLD,3)
        p.curve([(99,123),(106,70),(194,64),(209,120)],JADE,2)
        for x,y in [(98,151),(96,184),(94,217),(214,150),(215,182),(218,217)]:flower(p,x,y,3,JADE)
    if cls=='thief':
        textile(p,[(114,207),(164,228),(206,205),(207,236),(171,261),(121,237)],body,accent,11)
    p.ellipse((149,313,175,339),accent,INK,1)
    star(p,162,326,9,LAPIS if not enemy else VERMILION)
    for x in [7,313]:p.line([(x,14),(x,386)],GOLD,1)
    p.line([(7,386),(313,386)],GOLD,1)
    return p.image()


def units_and_portraits():
    for key,(cls,body,accent,hair) in HEROES.items():
        img=portrait(cls,body,accent,hair,key=='gelan')
        save(img,'battle_portraits',key);save(img,'portraits',key)
        save(unit_img(cls,body,accent,hair),'units',key)
    for cls in CLASSES:
        for team in ('player','enemy'):
            enemy=team=='enemy';body,accent,hair=costume(cls,enemy)
            save(unit_img(cls,body,accent,hair,enemy),'units',cls+'_'+team)
            save(portrait(cls,body,accent,hair,cls=='lancer' and not enemy,enemy),'battle_portraits',cls+'_'+team)
        icon=Pen((64,64));star(icon,32,32,28,LAPIS);star(icon,32,32,25,GOLD);star(icon,32,32,21,LAPIS)
        icon.im.alpha_composite(unit_img(cls,*costume(cls)).resize((42,56)).resize((126,168)),(33,12))
        save(icon.image(),'icons',cls)
    for key,cls in [('soldier','swordsman'),('tieh','warlord'),('leader_a','warlord'),('leader_b','lancer')]:
        save(portrait(cls,*costume(cls,True),enemy=True),'portraits',key)
    # Keep earlier asset paths valid, with the new art.
    for old,new in {'qinlie':'gelan','suqing':'suzhi','shenmo':'wenzhou','wenlan':'baitang','ali':'moqi'}.items():
        (ROOT/'assets/portraits'/f'{old}.png').write_bytes((ROOT/'assets/portraits'/f'{new}.png').read_bytes())
        (ROOT/'assets/units'/f'{old}.png').write_bytes((ROOT/'assets/units'/f'{new}.png').read_bytes())
    for key,cls in [('bandit','swordsman'),('spear','lancer'),('crossbow','archer'),('shaman','mage'),('medic','healer'),('leader_a','warlord'),('leader_b','lancer')]:
        save(unit_img(cls,*costume(cls,True),enemy=True),'units',key)
    p=Pen((320,400),LAPIS);p.rect((8,8,312,392),outline=GOLD,width=1)
    scale_emblem(p,160,128,130);save(p.image(),'battle_portraits','empty')


def generate():
    for kind in PALETTE:
        for variant in range(4):
            img=top_image(kind,variant);save(img,'tiles',f'top_{kind}_{variant}')
            if variant==0:save(img,'tiles','top_'+kind)
        img=side_image(kind);save(img,'tiles','side_'+kind);save(img,'tiles','sidetop_'+kind)
        # Older column paths remain usable, also at 160/80/40. Runtime uses
        # the split top/side textures so it can stack arbitrary map heights.
        for h in range(9):
            column=Image.new('RGBA',(TW,48+TH+(h+1)*HS))
            for i in range(h,-1,-1):column.alpha_composite(img,(0,48+TH//2+i*HS))
            column.alpha_composite(top_image(kind,0),(0,48))
            save(column,'tiles',f'{kind}_{h}')
    decorations();units_and_portraits()
    print('Miniature battle art: 160/80/40, matching figures/portraits, botanical terrain.')


if __name__=='__main__':
    generate()
