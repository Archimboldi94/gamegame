"""Shared original Persian-miniature grammar. Pillow only, no source images.

Fine ink contours, opaque mineral pigments, botanical repeats and gold details.
All coordinates are logical pixels; drawing is supersampled for fine brushwork.
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
INK = (30, 37, 62)
LAPIS = (35, 66, 125)
VERMILION = (181, 60, 46)
JADE = (47, 115, 91)
GOLD = (213, 175, 91)
PALE_GOLD = (240, 212, 149)
PAPER = (226, 210, 171)
IVORY = (245, 234, 207)


def tint(c, n):
    return tuple(max(0, min(255, int(v + n))) for v in c[:3])


class Pen:
    def __init__(self, size, bg=(0, 0, 0, 0), scale=3):
        self.scale = scale
        self.size = size
        self.im = Image.new('RGBA', tuple(v * scale for v in size), bg)
        self.draw = ImageDraw.Draw(self.im)

    def coords(self, pts):
        if isinstance(pts[0], (tuple, list)):
            return [(round(x*self.scale), round(y*self.scale)) for x, y in pts]
        return tuple(round(x*self.scale) for x in pts)

    def polygon(self, pts, fill=None, outline=None, width=1):
        self.draw.polygon(self.coords(pts), fill=fill)
        if outline:
            self.line(list(pts) + [pts[0]], outline, width)

    def line(self, pts, fill, width=1):
        self.draw.line(self.coords(pts), fill=fill, width=max(1, round(width*self.scale)), joint='curve')

    def ellipse(self, box, fill=None, outline=None, width=1):
        self.draw.ellipse(self.coords(box), fill=fill, outline=outline, width=max(1, round(width*self.scale)))

    def rect(self, box, fill=None, outline=None, width=1):
        self.draw.rectangle(self.coords(box), fill=fill, outline=outline, width=max(1, round(width*self.scale)))

    def arc(self, box, start, end, fill, width=1):
        self.draw.arc(self.coords(box), start, end, fill=fill, width=max(1, round(width*self.scale)))

    def curve(self, pts, fill, width=1):
        a,b,c,d = pts
        path=[]
        for i in range(25):
            t=i/24; u=1-t
            path.append((u*u*u*a[0]+3*u*u*t*b[0]+3*u*t*t*c[0]+t*t*t*d[0],
                         u*u*u*a[1]+3*u*u*t*b[1]+3*u*t*t*c[1]+t*t*t*d[1]))
        self.line(path, fill, width)

    def image(self):
        return self.im.resize(self.size, Image.Resampling.LANCZOS)


def save(img, folder, name):
    path = ROOT / 'assets' / folder / (name + '.png')
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def leaf(p, x, y, w, h, color, tilt=0):
    p.polygon([(x,y), (x-w+tilt,y-h*.45), (x+tilt,y-h), (x+w+tilt,y-h*.45)], color)
    p.line([(x,y-1), (x+tilt,y-h+2)], tint(color,28), .4)


def flower(p, x, y, r, color=GOLD):
    for a in range(5):
        t=a*math.tau/5
        cx,cy=x+math.cos(t)*r*.6,y+math.sin(t)*r*.6
        p.ellipse((cx-r*.35,cy-r*.35,cx+r*.35,cy+r*.35), color)
    p.ellipse((x-r*.22,y-r*.22,x+r*.22,y+r*.22), PALE_GOLD)


def star(p, x, y, r, color=GOLD):
    pts=[]
    for i in range(16):
        a=i*math.pi/8; s=r if i%2==0 else r*.48
        pts.append((x+math.cos(a)*s,y+math.sin(a)*s))
    p.polygon(pts,color)


def textile(p, pts, base, accent=GOLD, spacing=13):
    """Clip a woven floral repeat inside a garment, preserving its ink contour."""
    p.polygon(pts,base)
    layer=Pen(p.size,scale=p.scale)
    xs,ys=zip(*pts)
    for row,y in enumerate(range(int(min(ys))+4,int(max(ys)),spacing)):
        for x in range(int(min(xs))+3,int(max(xs)),spacing):
            x+=spacing*.5*(row%2)
            layer.line([(x-2,y+2),(x,y-3),(x+2,y+2)], tint(base,27), .5)
            flower(layer,x,y,1.6,accent)
    mask=Image.new('L',p.im.size)
    ImageDraw.Draw(mask).polygon(p.coords(pts),fill=255)
    alpha=layer.im.getchannel('A')
    from PIL import ImageChops
    layer.im.putalpha(ImageChops.multiply(alpha,mask))
    p.im.alpha_composite(layer.im)
    p.polygon(pts,outline=INK,width=.8)


HEROES = {
    'linyan': ('swordsman', LAPIS, GOLD, (43, 34, 38)),
    'gelan': ('lancer', (53, 103, 117), GOLD, (174, 170, 146)),
    'suzhi': ('archer', JADE, (233, 186, 98), (91, 49, 35)),
    'wenzhou': ('mage', (99, 56, 119), GOLD, (40, 33, 47)),
    'baitang': ('healer', (229, 222, 189), JADE, (87, 48, 34)),
    'moqi': ('thief', (36, 91, 98), GOLD, (40, 32, 36)),
}
CLASSES = ['swordsman','lancer','archer','mage','healer','thief','warlord']


def costume(cls, enemy=False):
    data=next((v[1:] for v in HEROES.values() if v[0]==cls), (LAPIS,GOLD,INK))
    if enemy:
        bodies={'swordsman':VERMILION,'lancer':(142,60,53),'archer':(141,82,51),
                'mage':(123,43,77),'healer':(177,123,100),'thief':(112,49,61),'warlord':(141,39,48)}
        return bodies[cls],GOLD,(44,30,37)
    return data


def scale_emblem(p,cx,cy,s,col=GOLD):
    p.line([(cx,cy),(cx,cy+s)],col,s*.04)
    p.line([(cx-s*.65,cy+s*.18),(cx+s*.65,cy+s*.18)],col,s*.035)
    for x in [cx-s*.65,cx+s*.65]:
        p.line([(x,cy+s*.18),(x-s*.22,cy+s*.56),(x+s*.22,cy+s*.56),(x,cy+s*.18)],col,s*.02)
        p.arc((x-s*.22,cy+s*.43,x+s*.22,cy+s*.72),0,180,col,s*.03)
    p.polygon([(cx-s*.3,cy+s*1.06),(cx,cy+s*.88),(cx+s*.3,cy+s*1.06)],col)
    star(p,cx,cy,s*.10,col)
