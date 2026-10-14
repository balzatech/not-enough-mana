#!/usr/bin/env python3
"""Genera assets/ui/*: iconos de estado (96/48) y marcos 9-slice. Recursos propios."""
import math, os
from PIL import Image, ImageDraw, ImageFilter
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)
S = 8  # supersample sobre 96
N = 96 * S
def P(v): return v * S
def new(): 
    im = Image.new("RGBA", (N, N), (0,0,0,0)); return im, ImageDraw.Draw(im)
DARK = (14,12,24,255)
def outline(im, color=DARK, r=3):
    a = im.split()[3].filter(ImageFilter.MaxFilter(P(r)*2+1))
    bg = Image.new("RGBA", im.size, color); bg.putalpha(a)
    bg.alpha_composite(im); return bg

def frozen():
    im, d = new(); c = N//2; col=(140,225,255,255)
    for k in range(6):
        a = math.radians(60*k)
        ex, ey = c+math.cos(a)*P(40), c+math.sin(a)*P(40)
        d.line([c,c,ex,ey], fill=col, width=P(8))
        for t in (0.55,):
            bx, by = c+math.cos(a)*P(40*t), c+math.sin(a)*P(40*t)
            for s in (-1,1):
                b = a+s*math.radians(50)
                d.line([bx,by,bx+math.cos(b)*P(14),by+math.sin(b)*P(14)], fill=col, width=P(6))
    d.ellipse([c-P(8),c-P(8),c+P(8),c+P(8)], fill=(255,255,255,255))
    return outline(im)
def blind():
    im, d = new(); c=N//2
    d.polygon([(P(6),c),(P(30),P(30)),(c,P(24)),(P(66),P(30)),(P(90),c),(P(66),P(66)),(c,P(72)),(P(30),P(66))], fill=(235,230,245,255))
    d.ellipse([c-P(15),c-P(15),c+P(15),c+P(15)], fill=(120,70,200,255))
    d.ellipse([c-P(6),c-P(6),c+P(6),c+P(6)], fill=DARK)
    im = outline(im)
    d = ImageDraw.Draw(im)
    d.line([P(14),P(84),P(82),P(12)], fill=DARK, width=P(18))
    d.line([P(14),P(84),P(82),P(12)], fill=(255,90,80,255), width=P(9))
    return im
def shield():
    im, d = new(); c=N//2
    pts=[(P(14),P(12)),(P(82),P(12)),(P(82),P(46)),(P(70),P(68)),(c,P(90)),(P(26),P(68)),(P(14),P(46))]
    d.polygon(pts, fill=(245,194,66,255))
    inner=[(P(25),P(22)),(P(71),P(22)),(P(71),P(44)),(P(62),P(61)),(c,P(78)),(P(34),P(61)),(P(25),P(44))]
    d.polygon(inner, fill=(60,110,230,255))
    d.polygon([(c,P(22)),(P(71),P(22)),(P(71),P(44)),(P(62),P(61)),(c,P(78))], fill=(110,160,255,255))
    d.line([c,P(26),c,P(74)], fill=(245,194,66,255), width=P(5))
    d.line([P(28),P(42),P(68),P(42)], fill=(245,194,66,255), width=P(5))
    return outline(im)
def cursed():
    im, d = new(); c=N//2; col=(205,110,255,255)
    d.ellipse([P(16),P(8),P(80),P(66)], fill=col)
    d.rounded_rectangle([P(28),P(52),P(68),P(86)], radius=P(6), fill=col)
    for x in (34,62): d.ellipse([P(x-9),P(30),P(x+9),P(50)], fill=DARK)
    d.polygon([(c,P(54)),(c-P(5),P(64)),(c+P(5),P(64))], fill=DARK)
    for x in (38,48,58): d.line([x*S,P(72),x*S,P(86)], fill=DARK, width=P(3))
    return outline(im)
def turn():
    im, d = new(); c=N//2
    d.ellipse([P(6),P(6),P(90),P(90)], fill=(245,194,66,255))
    d.polygon([(P(34),P(22)),(P(76),c),(P(34),P(74))], fill=DARK)
    d.rectangle([P(18),P(40),P(34),P(56)], fill=DARK)
    return outline(im)
def bot():
    im, d = new(); c=N//2; col=(150,170,200,255)
    d.line([c,P(8),c,P(24)], fill=col, width=P(6)); d.ellipse([c-P(7),P(4),c+P(7),P(18)], fill=(255,120,90,255))
    d.rectangle([P(14),P(24),P(82),P(76)], fill=col)
    d.rectangle([P(6),P(40),P(14),P(58)], fill=col); d.rectangle([P(82),P(40),P(90),P(58)], fill=col)
    for x in (34,62): d.rectangle([P(x-9),P(38),P(x+9),P(52)], fill=DARK); d.rectangle([P(x-4),P(41),P(x+4),P(49)], fill=(120,230,255,255))
    d.rectangle([P(30),P(62),P(66),P(68)], fill=DARK)
    d.rectangle([P(26),P(78),P(70),P(90)], fill=col)
    return outline(im)
def eliminado():
    im, d = new(); c=N//2; col=(170,176,190,255)
    d.rectangle([P(8),P(80),P(88),P(90)], fill=(110,90,70,255))
    d.rounded_rectangle([P(22),P(8),P(74),P(84)], radius=P(4), fill=col)
    d.ellipse([P(22),P(8),P(74),P(60)], fill=col)
    d.rectangle([P(22),P(34),P(74),P(82)], fill=col)
    d.rectangle([P(42),P(22),P(54),P(66)], fill=DARK)
    d.rectangle([P(31),P(33),P(65),P(43)], fill=DARK)
    d.rectangle([P(22),P(72),P(74),P(76)], fill=(120,126,142,255))
    return outline(im)

ICONS = {"congelado":frozen,"cegado":blind,"campo_fuerza":shield,"maldito":cursed,"turno":turn,"bot":bot,"eliminado":eliminado}
def save(im, path):
    im.save(path, optimize=True)
def icons():
    for n,f in ICONS.items():
        big = f().resize((96,96), Image.LANCZOS)
        small = f().resize((48,48), Image.LANCZOS)
        save(big, f"{OUT}/icon_{n}_96.png"); save(small, f"{OUT}/icon_{n}_48.png")

def frame(kind, size=64, m=14):
    k=4; W=size*k; im=Image.new("RGBA",(W,W),(0,0,0,0)); d=ImageDraw.Draw(im)
    if kind=="jugable":
        glow=Image.new("RGBA",(W,W),(0,0,0,0)); g=ImageDraw.Draw(glow)
        g.rounded_rectangle([6*k,6*k,W-6*k,W-6*k], radius=8*k, outline=(120,255,160,200), width=6*k)
        glow=glow.filter(ImageFilter.GaussianBlur(3*k)); im.alpha_composite(glow)
        d.rounded_rectangle([5*k,5*k,W-5*k,W-5*k], radius=7*k, outline=(150,255,185,255), width=3*k)
        d.rounded_rectangle([8*k,8*k,W-8*k,W-8*k], radius=5*k, outline=(20,70,40,200), width=1*k)
    else:
        col=(255,205,80,255); vio=(190,100,255,255)
        d.rectangle([4*k,4*k,W-4*k,W-4*k], outline=vio, width=3*k)
        d.rectangle([8*k,8*k,W-8*k,W-8*k], outline=col, width=2*k)
        for x,y in ((6,6),(W//k-6,6),(6,W//k-6),(W//k-6,W//k-6)):
            r=6*k; cx,cy=x*k,y*k
            d.polygon([(cx,cy-r),(cx+r,cy),(cx,cy+r),(cx-r,cy)], fill=col, outline=DARK)
    return im.resize((size,size), Image.LANCZOS)
def frames():
    for n in ("jugable","evento"): save(frame(n), f"{OUT}/frame_{n}_9slice.png")

def sheet():
    bg=(0.11*255,0.11*255,0.17*255); bg=tuple(int(v) for v in bg)
    pad=16; names=list(ICONS)
    W=pad+len(names)*(96+pad); H=pad*4+96+48+120
    im=Image.new("RGB",(W,H),bg); 
    for i,n in enumerate(names):
        x=pad+i*(96+pad)
        for sub,(sz,y) in enumerate(((96,pad),(48,pad*2+96))):
            ic=Image.open(f"{OUT}/icon_{n}_{sz}.png"); im.paste(ic,(x,y),ic)
    y=pad*3+96+48
    for j,n in enumerate(("jugable","evento")):
        fr=Image.open(f"{OUT}/frame_{n}_9slice.png").resize((100,100)); 
        # carta simulada
        card=Image.new("RGBA",(100,100),(120,90,60,255)); card.alpha_composite(fr)
        im.paste(card.convert("RGB"),(pad+j*(100+pad),y))
    im.save(os.path.join(os.path.dirname(__file__),"..","docs","arte","iconos-estado.png"))
if __name__=="__main__":
    icons(); frames(); sheet()
