#!/usr/bin/env python3
"""v3 tiles: 160x80 native (1:1 in game), resampled straight from the reference diamonds,
no palette quantisation. Water: stones painted out. Bridge: plank-only periodic deck."""
import os,numpy as np
from PIL import Image,ImageFilter
from scipy import ndimage as ndi
R=os.path.join(os.path.dirname(__file__),'..');os.chdir(R);os.makedirs('tiles',exist_ok=True)
src=np.asarray(Image.open('src/ref.jpg').convert('RGB')).astype(float)
TC={'stone':140,'grassdirt':340,'bridge':542,'grass':744,'mud':942,'water':1138}
TW,TH=160,80;SS=3
yy,xx=np.mgrid[0:TH*SS,0:TW*SS]
px=(xx+.5)/SS;py=(yy+.5)/SS
dx=(px-TW/2)/(TW/2);dy=py/(TH/2);U=np.clip((dy+dx)/2,0,1);V=np.clip((dy-dx)/2,0,1)
INS=0.06  # inset: avoid the reference's bevelled rim
U=INS+U*(1-2*INS);V=INS+V*(1-2*INS)
inside=(np.abs(np.arange(TW)+.5-TW/2)[None]/(TW/2)+np.abs(np.arange(TH)+.5-TH/2)[:,None]/(TH/2))<=1.0
def sample(cx):
    top=np.array([cx,516.]);right=np.array([cx+97,588.]);bot=np.array([cx,652.]);left=np.array([cx-97,588.])
    P=((1-U)*(1-V))[...,None]*top+(U*(1-V))[...,None]*right+(U*V)[...,None]*bot+((1-U)*V)[...,None]*left
    x,y=P[...,0],P[...,1]
    out=np.stack([ndi.map_coordinates(src[...,c],[y,x],order=1) for c in range(3)],2)
    return out.reshape(TH,SS,TW,SS,3).mean((1,3))
def finish(rgb):
    im=Image.fromarray(np.clip(rgb,0,255).astype(np.uint8)).filter(ImageFilter.UnsharpMask(1.0,50,2))
    o=np.zeros((TH,TW,4),np.uint8);o[...,:3]=np.asarray(im);o[...,3]=inside*255;return o
T={k:sample(c) for k,c in TC.items()}
# --- water: paint out stones (grey/brown, not blue-dominant) from nearby water
w=T['water'];notwater=(w[...,2]<w[...,0]+30)|(w.max(2)-w.min(2)<35)
notwater=ndi.binary_dilation(notwater,iterations=3)
idx=ndi.distance_transform_edt(notwater,return_distances=False,return_indices=True)
w2=w[idx[0],idx[1]];w2=ndi.gaussian_filter(w2,(1.2,1.2,0))*np.where(notwater,1,0)[...,None]+w*np.where(notwater,0,1)[...,None]
T['water']=w2
# --- bridge: plank-only deck, periodic along the plank axis so neighbours line up
br=sample(TC['bridge'])
deck=np.array([138,96,62.]);dark=np.array([62,40,26.]);light=np.array([170,124,82.])
rng=np.random.default_rng(3);o=np.zeros((TH,TW,3))
yy,xx=np.mgrid[0:TH,0:TW];u=((yy+.5)/(TH/2)+((xx+.5)-TW/2)/(TW/2))/2;v=((yy+.5)/(TH/2)-((xx+.5)-TW/2)/(TW/2))/2
NP=8;pi=np.floor(u*NP).astype(int);fu=u*NP-pi
tone=1+0.08*np.sin(pi*2.3)+0.05*np.cos(pi*5.1)
grain=0.06*np.sin(v*90+pi*1.7)+0.04*np.sin(v*37+pi)
o=deck*(tone+grain)[...,None]
o=np.where((fu<0.10)[...,None],dark,o)             # gap between planks
o=np.where(((fu>0.10)&(fu<0.20))[...,None],o*0.85+light*0.15,o)  # lit plank edge
nail=((np.abs(v-0.12)<0.025)|(np.abs(v-0.88)<0.025))&(np.abs(fu-0.55)<0.07)
o=np.where(nail[...,None],dark*0.8,o)
T['bridge']=o
for k,rgb in T.items():
    t=finish(rgb);Image.fromarray(t).save(f'tiles/top_{k}.png')
print('tiles ok')
