#!/usr/bin/env python3
"""v4: all classes from approved concept sheets, same treatment as v3 swordsman.
Frame 160x200, foot y=196, centre x=80. Uniform per-class scale from the front view's
head-to-foot height (140px, warlord 170px)."""
import os,sys,numpy as np
from PIL import Image,ImageFilter
from scipy import ndimage as ndi
R=os.path.join(os.path.dirname(__file__),'..');os.chdir(R)
FW,FH,FOOT,CX=160,200,196,80
V3='/workspace/art-slice/v3'
def char_mask(a,BG):
    dist=np.abs(a-BG).sum(2);mx=a.max(2);mn=a.min(2);sat=(mx-mn)/np.maximum(mx,1)
    rb=a[...,0]-a[...,2]
    bgl=((dist<55)|((sat<0.16)&(mx>150)&(dist<130)&(rb>22)))&(rb<40)
    lab,_=ndi.label(bgl);edge=set(np.unique(np.r_[lab[0],lab[-1],lab[:,0],lab[:,-1]]))-{0}
    fg=~np.isin(lab,list(edge))
    bgi=(np.abs(a-(BG+[2,4,5])).sum(2)<32)&(rb<38)&fg
    li,ln=ndi.label(bgi);szi=ndi.sum(bgi,li,range(1,ln+1))
    fg&=~np.isin(li,[i+1 for i,v in enumerate(szi) if v>=5])
    fg=ndi.binary_opening(fg,iterations=1)
    h=fg.shape[0];L=a@np.array([.3,.59,.11])
    sh=np.zeros_like(fg);sh[int(h*0.90):]=True
    fg&=~(sh&(sat<0.22)&(L>90)&(rb>15))   # floor shadow
    fg=ndi.binary_opening(fg,iterations=1)
    lab2,n=ndi.label(fg);sz=ndi.sum(fg,lab2,range(1,n+1))
    keep=[i+1 for i,v in enumerate(sz) if v>=0.02*sz.max()]   # keep detached weapons
    fg=np.isin(lab2,keep)
    holes=ndi.binary_fill_holes(fg)&~fg
    hl,hn=ndi.label(holes)
    for i in range(1,hn+1):
        r=hl==i
        if r.sum()<12 and dist[r].mean()>90: fg|=r
    return fg
def views(name):
    a=np.asarray(Image.open(f'src/{name}.jpg').convert('RGB')).astype(float)
    BG=np.median(a[5:20,5:60].reshape(-1,3),0)
    fg=np.abs(a-BG).sum(2)>60;fg=ndi.binary_opening(fg,iterations=2)
    r=fg.sum(1)>3;runs=[];s=None
    for i,v in enumerate(list(r)+[False]):
        if v and s is None:s=i
        if not v and s is not None:
            if i-s>20:runs.append((s,i))
            s=None
    y0,y1=runs[0];c=fg[y0:y1].sum(0)>2;cr=[];s=None
    for i,v in enumerate(list(c)+[False]):
        if v and s is None:s=i
        if not v and s is not None:
            if i-s>15:cr.append((s,i))
            s=None
    out={}
    for k,(x0,x1) in zip(['S','SW','W','N'],cr):
        X0,X1,Y0,Y1=max(0,x0-12),min(a.shape[1],x1+12),max(0,y0-12),min(a.shape[0],y1+8)
        sub=a[Y0:Y1,X0:X1];m=char_mask(sub,BG)
        ys,xs=np.nonzero(m)
        out[k]=(sub[ys.min():ys.max()+1,xs.min():xs.max()+1],m[ys.min():ys.max()+1,xs.min():xs.max()+1])
    return out
def body_height(sub,m):
    # head top: topmost mask row within the central body column band (ignores side weapons)
    cols=m.sum(0);h=m.shape[0]
    low=m[int(h*0.55):]                      # torso/legs columns give body centre
    xs=np.nonzero(low.sum(0)>0)[0];cx=int(np.average(np.arange(m.shape[1]),weights=low.sum(0)))
    band=m[:,max(0,cx-12):cx+12];top=np.nonzero(band.any(1))[0].min()
    return h-top,cx
def render(sub,m,s,cx_src):
    inner=ndi.binary_erosion(m,iterations=2)
    if inner.sum()==0: inner=m
    idx=ndi.distance_transform_edt(~inner,return_distances=False,return_indices=True)
    a=sub[idx[0],idx[1]]
    h,w=m.shape;nw,nh=max(1,round(w*s)),max(1,round(h*s))
    al=np.asarray(Image.fromarray((m*255).astype(np.uint8)).resize((nw,nh),Image.BOX)).astype(float)/255
    rgb=np.stack([np.asarray(Image.fromarray(a[...,c].astype(np.uint8)).resize((nw,nh),Image.LANCZOS)) for c in range(3)],2)
    rgb=np.asarray(Image.fromarray(rgb.astype(np.uint8)).filter(ImageFilter.UnsharpMask(radius=1.0,percent=70,threshold=2))).astype(float)
    A=al>0.45
    out=np.zeros((FH,FW,4),np.uint8);ox=CX-round(cx_src*s);oy=FOOT-nh
    # clip into frame
    sx0=max(0,-ox);sy0=max(0,-oy);sx1=min(nw,FW-ox);sy1=min(nh,FH-oy)
    if (sx0,sy0,sx1,sy1)!=(0,0,nw,nh): print('  clipped',sx0,sy0,nw-sx1,nh-sy1)
    out[oy+sy0:oy+sy1,ox+sx0:ox+sx1,:3]=rgb[sy0:sy1,sx0:sx1];out[oy+sy0:oy+sy1,ox+sx0:ox+sx1,3]=A[sy0:sy1,sx0:sx1]*255
    A2=out[...,3]>0;rim=A2&~ndi.binary_erosion(A2)
    out[rim,:3]=(out[rim,:3]*0.65+np.array([20,24,30])*0.35).astype(np.uint8)
    return out
def crimson(o,sel,k=1.25,add=10,gk=0.55,bk=0.55):
    r,g,b=o[...,0],o[...,1],o[...,2];L=r*.3+g*.59+b*.11
    o[sel,0]=np.clip(L[sel]*k+add,0,255);o[sel,1]=L[sel]*gk;o[sel,2]=L[sel]*bk
def recolour(name,n,team,cut=None):
    o=n.astype(float).copy();r,g,b=o[...,0],o[...,1],o[...,2]
    mx=o[...,:3].max(2);mn=o[...,:3].min(2);sat=(mx-mn)/np.maximum(mx,1);L=r*.3+g*.59+b*.11
    ys=np.nonzero(n[...,3].any(1))[0];top=ys.min();hh=FOOT-top
    below=np.zeros(r.shape,bool);below[int(cut if cut is not None else top+hh*(0.30 if name!='warlord' else 0.25)):]=True
    if name=='warlord':
        red=(r>g+25)&(r>b+20)&(g<r*0.62)&(np.abs(g-b)<28)&below
        if team=='player':   # red war-robe -> deep indigo
            o[red,2]=np.clip(L[red]*1.35+15,0,255);o[red,1]=L[red]*0.8;o[red,0]=L[red]*0.55
        else:
            o[red,0]=np.clip(r[red]*0.8,0,255);o[red,1]*=0.55;o[red,2]*=0.6
        return o.astype(np.uint8)
    if team=='player': return n
    if name in('swordsman','lancer','mage'): sel=(b>r+4)&(g>=r-6)&(L>18)&below
    elif name=='archer': sel=(g>=r-12)&(g>b+1)&(L>20)&below&~((r>g+20)&(r>b+30))
    elif name=='healer': sel=(sat<0.20)&(L>120)&(abs(r-b)<30)&below
    elif name=='thief': sel=(L<85)&(sat<0.35)&(L>18)&below&~((r>g+30))
    if name=='healer': crimson(o,sel,0.78,8,0.16,0.20)      # deep crimson, not pink
    elif name=='thief':  crimson(o,sel,1.9,28,0.42,0.30)      # brighter blood-red so it reads vs. shadow
    else: crimson(o,sel)
    return o.astype(np.uint8)
def portrait(name,sub,m):
    # bust from front-3/4 at near-native resolution, 320x400 transparent
    hb,cx=body_height(sub,m);h,w=m.shape;top=h-hb
    crop_h=int(hb*0.62);y0=max(0,top-int(hb*0.04));y1=y0+crop_h
    x0=max(0,cx-int(crop_h*0.4));x1=min(w,cx+int(crop_h*0.4))
    inner=ndi.binary_erosion(m,iterations=2);idx=ndi.distance_transform_edt(~inner,return_distances=False,return_indices=True)
    a=sub[idx[0],idx[1]][y0:y1,x0:x1];mm=m[y0:y1,x0:x1]
    s=min(320/(x1-x0),400/(y1-y0));nw,nh=round((x1-x0)*s),round((y1-y0)*s)
    rgb=Image.fromarray(a.astype(np.uint8)).resize((nw,nh),Image.LANCZOS)
    al=Image.fromarray((mm*255).astype(np.uint8)).resize((nw,nh),Image.LANCZOS).point(lambda v:0 if v<100 else (255 if v>200 else v))
    rgb.putalpha(al);out=Image.new('RGBA',(320,400));out.alpha_composite(rgb,((320-nw)//2,400-nh));return out
ORDER=['S','SE','E','NE','N','NW','W','SW']
def emit(name,nat):
    d8={'S':nat['S'],'SW':nat['SW'],'W':nat['W'],'N':nat['N'],'SE':nat['SW'][:,::-1],'E':nat['W'][:,::-1],'NW':nat['N'],'NE':nat['N'][:,::-1]}
    sheet=Image.new('RGBA',(FW*8,FH))
    for i,k in enumerate(ORDER):
        Image.fromarray(d8[k]).save(f'chars/{name}_{k}.png');sheet.alpha_composite(Image.fromarray(d8[k]),(i*FW,0))
    sheet.save(f'chars/{name}_8dir_sheet.png')
    cut=None
    for t in('player','enemy'):
        Image.fromarray(recolour(name,nat['SW'],t)).save(f'chars/{name}_{t}.png')
        for k in ORDER: Image.fromarray(recolour(name,d8[k],t)).save(f'chars/{name}_{t}_{k}.png')
names=sys.argv[1:] or 'lancer archer healer mage thief warlord'.split()
for name in names:
    if name=='swordsman':
        # re-centre v3 natives (120x150, foot 147) into the v4 frame
        nat={}
        for k in['S','SW','W','N']:
            im=Image.open(f'{V3}/chars/swordsman_{k}.png');f=Image.new('RGBA',(FW,FH));f.alpha_composite(im,(CX-60,FOOT-147));nat[k]=np.asarray(f)
        emit(name,nat)
        from PIL import Image as I
        a=np.asarray(I.open(f'{V3}/src/ref.jpg').convert('RGB')).astype(float)
        sub=a[30:470,415:640];m=char_mask(sub,np.array([241,230,212.]));ys,xs=np.nonzero(m)
        portrait(name,sub[ys.min():ys.max()+1,xs.min():xs.max()+1],m[ys.min():ys.max()+1,xs.min():xs.max()+1]).save(f'portraits/{name}.png')
        portrait(name,sub[ys.min():ys.max()+1,xs.min():xs.max()+1],m[ys.min():ys.max()+1,xs.min():xs.max()+1])
        continue
    v=views(name);target=170 if name=='warlord' else (132 if name=='lancer' else 140)
    hb,_=body_height(*v['S']);s=target/hb;print(name,'body',hb,'scale',round(s,3))
    nat={k:render(sub,m,s,body_height(sub,m)[1]) for k,(sub,m) in v.items()}
    emit(name,nat)
    portrait(name,*v['SW']).save(f'portraits/{name}.png')
for name in ['swordsman']+'lancer archer healer mage thief warlord'.split():
    p=np.asarray(Image.open(f'portraits/{name}.png'))
    for t in('player','enemy'): Image.fromarray(recolour(name,p,t,cut=400*0.5)).save(f'portraits/{name}_{t}.png')
print('ok')
