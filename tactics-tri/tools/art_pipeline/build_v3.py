#!/usr/bin/env python3
"""v3: keep reference detail. Chars: area-downsample (premultiplied) by the reference's own
pixel cell so the sprite is ~140px tall, shown 1:1 in game. No palette quantisation; alpha
eroded before resampling (no bg halo), floor shadow removed, mild unsharp for crisp eyes."""
import os,numpy as np
from PIL import Image,ImageFilter
from collections import deque
from scipy import ndimage as ndi
R=os.path.join(os.path.dirname(__file__),'..');os.chdir(R)
src=np.asarray(Image.open('src/ref.jpg').convert('RGB')).astype(float)
BG=np.array([241,230,212.])
BOX={'S':(120,30,350,470),'SW':(415,30,640,470),'W':(700,30,905,470),'N':(950,30,1170,470)}
TARGET_H=140; FW,FH=120,150; FOOT=147
def char_mask(a):
    dist=np.abs(a-BG).sum(2);mx=a.max(2);mn=a.min(2);sat=(mx-mn)/np.maximum(mx,1)
    rb=a[...,0]-a[...,2]
    bgl=((dist<55)|((sat<0.16)&(mx>150)&(dist<130)&(rb>22)))&(rb<40)
    lab,_=ndi.label(bgl);edge=set(np.unique(np.r_[lab[0],lab[-1],lab[:,0],lab[:,-1]]))-{0}
    fg=~np.isin(lab,list(edge))
    BGc=np.array([243,234,217.])
    bgi=(np.abs(a-BGc).sum(2)<32)&((a[...,0]-a[...,2])<38)&fg
    li,ln=ndi.label(bgi);szi=ndi.sum(bgi,li,range(1,ln+1))
    fg&=~np.isin(li,[i+1 for i,v in enumerate(szi) if v>=5])
    fg=ndi.binary_opening(fg,iterations=1)
    lab2,n=ndi.label(fg);sz=ndi.sum(fg,lab2,range(1,n+1));fg=lab2==(np.argmax(sz)+1) if n else fg
    h=fg.shape[0];L=a@np.array([.3,.59,.11])
    sh=np.zeros_like(fg);sh[int(h*0.80):]=True
    fg&=~(sh&(sat<0.20)&(L>95)&((a[...,0]-a[...,2])>22))          # floor shadow under boots
    fg=ndi.binary_opening(fg,iterations=1)
    lab2,n=ndi.label(fg);sz=ndi.sum(fg,lab2,range(1,n+1));fg=lab2==(np.argmax(sz)+1)
    holes=ndi.binary_fill_holes(fg)&~fg
    hl,hn=ndi.label(holes)
    for i in range(1,hn+1):
        r=hl==i
        if r.sum()<12 and dist[r].mean()>90: fg|=r   # tiny non-bg pinholes only
    return fg
def build(k):
    x0,y0,x1,y1=BOX[k];a=src[y0:y1,x0:x1];m=char_mask(a)
    ys,xs=np.nonzero(m);a=a[ys.min():ys.max()+1,xs.min():xs.max()+1];m=m[ys.min():ys.max()+1,xs.min():xs.max()+1]
    # edge decontamination: replace colours in a 2px rim by nearest interior colour
    inner=ndi.binary_erosion(m,iterations=2)
    idx=ndi.distance_transform_edt(~inner,return_distances=False,return_indices=True)
    a=a[idx[0],idx[1]]
    h,w=m.shape;s=TARGET_H/h;nw,nh=max(1,round(w*s)),TARGET_H
    al=np.asarray(Image.fromarray((m*255).astype(np.uint8)).resize((nw,nh),Image.BOX)).astype(float)/255
    rgb=np.stack([np.asarray(Image.fromarray(a[...,c].astype(np.uint8)).resize((nw,nh),Image.LANCZOS)) for c in range(3)],2)
    im=Image.fromarray(rgb.astype(np.uint8)).filter(ImageFilter.UnsharpMask(radius=1.0,percent=70,threshold=2))
    rgb=np.asarray(im).astype(float);A=(al>0.45)
    out=np.zeros((FH,FW,4),np.uint8);ox=(FW-nw)//2;oy=FOOT-nh
    out[oy:oy+nh,ox:ox+nw,:3]=rgb;out[oy:oy+nh,ox:ox+nw,3]=A*255
    # 1px soft dark rim for readability on any tile
    A2=out[...,3]>0;rim=A2&~ndi.binary_erosion(A2)
    out[rim,:3]=(out[rim,:3]*0.65+np.array([20,24,30])*0.35).astype(np.uint8)
    return out
os.makedirs('chars',exist_ok=True)
nat={k:build(k) for k in BOX}
d8={'S':nat['S'],'SW':nat['SW'],'W':nat['W'],'N':nat['N'],'SE':nat['SW'][:,::-1],'E':nat['W'][:,::-1],'NW':nat['N'],'NE':nat['N'][:,::-1]}
ORDER=['S','SE','E','NE','N','NW','W','SW']
sheet=Image.new('RGBA',(FW*8,FH))
for i,k in enumerate(ORDER):
    Image.fromarray(d8[k]).save(f'chars/swordsman_{k}.png');sheet.alpha_composite(Image.fromarray(d8[k]),(i*FW,0))
sheet.save('chars/swordsman_8dir_sheet.png')
# enemy variant: shift teal cloth toward dark crimson
def enemy(n):
    o=n.astype(float).copy();r,g,b=o[...,0],o[...,1],o[...,2]
    L0=r*.3+g*.59+b*.11
    teal=(b>r+8)&(g>r+4)&(L0>78)
    L=(r*.3+g*.59+b*.11)
    o[teal,0]=np.clip(L[teal]*1.25,0,255);o[teal,1]=L[teal]*0.62;o[teal,2]=L[teal]*0.6
    return o.astype(np.uint8)
Image.fromarray(nat['SW']).save('chars/swordsman_player.png')
Image.fromarray(enemy(nat['SW'])).save('chars/swordsman_enemy.png')
print('chars ok',FW,FH)
