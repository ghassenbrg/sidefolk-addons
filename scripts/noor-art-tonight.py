# Overview's Tonight strip (light from the approved P01 board: its hills and mosque with no words on them; dark the cut of the night picture it already showed).
import sys
from PIL import Image, ImageFilter
board,night,out=sys.argv[1:4]
b=Image.open(board).convert('RGB')
W,H=2600,280
y0,y1=761,820
k=W/1251; bandH=round((y1-y0)*k)
clean=b.crop((1102,y0,1500,y1))
band=Image.new('RGB',(1251,y1-y0))
x=0; flip=True
while x<1251:
    p=clean.transpose(Image.FLIP_LEFT_RIGHT) if flip else clean
    band.paste(p,(x,0)); x+=p.width; flip=not flip
band=band.resize((W,bandH),Image.LANCZOS)
im=Image.new('RGB',(W,H),(250,247,253))
hp=band.crop((0,1,W,2)).filter(ImageFilter.GaussianBlur(60)).load()
px=im.load(); top=(250,247,253); skyH=H-bandH
for x in range(W):
    for y in range(skyH):
        t=(y/skyH)**1.4
        px[x,y]=tuple(round(top[i]+(hp[x,0][i]-top[i])*t) for i in range(3))
im.paste(band,(0,skyH))
# the mosque, lifted off its sky by how dark it is
mx0,mx1,my0=880,1102,754
m=b.crop((mx0,my0,mx1,y1)); m=m.resize((round(m.width*k),round(m.height*k)),Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=2,percent=60,threshold=2))
lum=m.convert('L')
mask=lum.point(lambda v: 255 if v<135 else (0 if v>160 else round((160-v)/25*255)))
# fades out sideways so the far hills it carries don't end in a line
w,h=m.size
fade=Image.new('L',(w,h),255); fp=fade.load()
for x in range(w):
    e=min(1,min(x,w-1-x)/40)
    for y in range(h): fp[x,y]=round(255*e)
from PIL import ImageChops
mask=ImageChops.multiply(mask,fade)
im.paste(m,(round((mx0-265)*k),H-h),mask)
im.save(out+'-l.jpg',quality=88,optimize=True,progressive=True)
d=Image.open(night).convert('RGB'); dw,dh=d.size
d.crop((0,round(dh*.155),round(dw*.833),round(dh*.686))).resize((W,H),Image.LANCZOS).save(out+'-d.jpg',quality=88,optimize=True,progressive=True)
