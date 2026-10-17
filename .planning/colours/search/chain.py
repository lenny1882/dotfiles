import sys, os, math, json, itertools, time
import multiprocessing as mp
cols=dict(l.split() for l in open(sys.argv[1]))
R=float(sys.argv[2]); out=sys.argv[3]; GROUPSET=sys.argv[4] if len(sys.argv)>4 else "P1"
GROUPS={
 "P1":{"red":["col_red","col_bright_red","col_nord11","col_nord12"],
       "orange":["col_orange","col_nord13"],
       "yellow":["col_yellow","col_bright_yellow"],
       "green":["col_green","col_bright_green","col_nord14","col_emerald","col_lime"],
       "blue":["col_blue","col_bright_blue","col_nord10","col_nord9","col_cyan","col_bright_cyan"],
       "purple":["col_purple","col_violet","col_nord15","col_bright_purple","col_magenta"]},
}
GROUPS["P2"]=dict(GROUPS["P1"]); GROUPS["P2"]["red"]=GROUPS["P1"]["red"]+["col_magenta"]; GROUPS["P2"]["purple"]=[m for m in GROUPS["P1"]["purple"] if m!="col_magenta"]
GROUPS["P3"]=dict(GROUPS["P1"]); GROUPS["P3"]["warm"]=GROUPS["P1"]["orange"]+GROUPS["P1"]["yellow"]; del GROUPS["P3"]["orange"]; del GROUPS["P3"]["yellow"]
GROUPS["P4"]=dict(GROUPS["P2"]); GROUPS["P4"]["warm"]=GROUPS["P2"]["orange"]+GROUPS["P2"]["yellow"]; del GROUPS["P4"]["orange"]; del GROUPS["P4"]["yellow"]
G=GROUPS[GROUPSET]
def lin(v): v/=255; return v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4
def unlin(v): v=max(0,min(1,v)); return 255*(12.92*v if v<=0.0031308 else 1.055*v**(1/2.4)-0.055)
def to_lch(h):
    r,g,b=[lin(int(h[i:i+2],16)) for i in (1,3,5)]
    l=(0.4122214708*r+0.5363325363*g+0.0514459929*b)**(1/3); m=(0.2119034982*r+0.6806995451*g+0.1073969566*b)**(1/3); s=(0.0883024619*r+0.2817188376*g+0.6299787005*b)**(1/3)
    L=0.2104542553*l+0.7936177850*m-0.0040720468*s; a=1.9779984951*l-2.4285922050*m+0.4505937099*s; bb=0.0259040371*l+0.7827717662*m-0.8086757660*s
    return L,math.hypot(a,bb),math.degrees(math.atan2(bb,a))%360
def from_lch(L,C,H):
    for _ in range(30):
        a=C*math.cos(math.radians(H)); b=C*math.sin(math.radians(H))
        l=(L+0.3963377774*a+0.2158037573*b)**3; m=(L-0.1055613458*a-0.0638541728*b)**3; s=(L-0.0894841775*a-1.2914855480*b)**3
        r=4.0767416621*l-3.3077115913*m+0.2309699292*s; g=-1.2684380046*l+2.6097574011*m-0.3413193965*s; bl=-0.0041960863*l-0.7034186147*m+1.7076147010*s
        if all(-0.001<=v<=1.001 for v in (r,g,bl)): return (unlin(r),unlin(g),unlin(bl))
        C*=0.93
    return (unlin(r),unlin(g),unlin(bl))
def rgbh(h): return tuple(int(h[i:i+2],16) for i in (1,3,5))
def dist(a,b):
    rm=(a[0]+b[0])/2; dr=a[0]-b[0]; dg=a[1]-b[1]; db=a[2]-b[2]
    return math.sqrt((2+rm/256)*dr*dr+4*dg*dg+(2+(255-rm)/256)*db*db)
def hshift(H,sign_to,amt):
    d=(sign_to-H+180)%360-180
    return (H+(amt if d>0 else -amt))%360
WEIGHT={'col_green':float(os.environ.get('GREEN_W','4'))}
CH=["light","dark","soft","hard","pale","shade","muted","warm","cool"]
def apply(base,chain,t):
    L,C,H=base
    if chain=="light": return from_lch(L+(1-L)*min(t,0.95),C,H)
    if chain=="dark": return from_lch(L*(1-min(t,0.95)),C,H)
    if chain=="soft": return from_lch(L,C*(1-min(t,0.95)),H)
    if chain=="hard": return from_lch(L,C*(1+t),H)
    if chain=="pale":
        c=from_lch(L,C,H); return tuple(v+(255-v)*min(t,0.95) for v in c)
    if chain=="shade":
        c=from_lch(L,C,H); return tuple(v*(1-min(t,0.95)) for v in c)
    if chain=="muted":
        c=from_lch(L,C,H); y=0.2126*c[0]+0.7152*c[1]+0.0722*c[2]; return tuple(v+(y-v)*min(t,0.95) for v in c)
    if chain=="warm": return from_lch(L,C,hshift(H,60,t))
    if chain=="cool": return from_lch(L,C,hshift(H,230,t))
def invert(m,chain,t):
    L,C,H=m
    try:
        if chain=="light": return ((L-t)/(1-t),C,H) if t<0.95 else None
        if chain=="dark": return (L/(1-t),C,H) if t<0.95 else None
        if chain=="soft": return (L,C/(1-t),H) if t<0.95 else None
        if chain=="hard": return (L,C/(1+t),H)
        if chain=="warm": return (L,C,hshift(H,(60+180)%360,t))
        if chain=="cool": return (L,C,hshift(H,(230+180)%360,t))
    except ZeroDivisionError: return None
    return None
def fit_group(args):
    members,nom=args
    mlch=[to_lch(cols[m]) for m in members]; mrgb=[rgbh(cols[m]) for m in members]
    cands=[]
    for ml in mlch: cands.append(ml)
    for ml in mlch:
        for ch in CH:
            if ch in ("pale","shade","muted"): continue
            for k in (1,2,3):
                for f in (1-R,1,1+R):
                    t=nom[ch]*f*k
                    b=invert(ml,ch,t)
                    if b and 0.2<b[0]<0.97 and 0<b[1]<0.33: cands.append(b)
    hs=[m[2] for m in mlch]; ref=hs[0]
    rel=[((h-ref+180)%360-180) for h in hs]; hm=(ref+sum(rel)/len(rel))%360; span=max(rel)-min(rel)
    for Lg in (0.45,0.5,0.55,0.6,0.65,0.7,0.75,0.8):
        for Cg in (0.08,0.12,0.16,0.2,0.24):
            for dh in range(-int(span/2)-6,int(span/2)+7,6):
                cands.append((Lg,Cg,(hm+dh)%360))
    def score_base(b):
        errs=[];assign=[]
        for i,m in enumerate(members):
            bestm=(dist(from_lch(*b),mrgb[i]),("none",0,0))
            for ch in CH:
                for f in (1-R,1,1+R):
                    for k in (1,2,3):
                        t=nom[ch]*f*k
                        d=dist(apply(b,ch,t),mrgb[i])
                        if d<bestm[0]: bestm=(d,(ch,k,nom[ch]*f))
            errs.append(bestm[0]); assign.append(bestm[1])
        w=[WEIGHT.get(m,1.0) for m in members]; we=[e*x for e,x in zip(errs,w)]
        return (max(we),sum(we)),b,assign,errs
    best=None
    scored=sorted((score_base(b) for b in cands),key=lambda r:r[0])[:6]
    import random
    rnd=random.Random(5)
    for cand in scored:
        cur=cand
        for step in (0.04,0.02,0.01):
            for _ in range(40):
                b=(min(0.97,max(0.2,cur[1][0]+rnd.uniform(-step,step))),min(0.33,max(0.01,cur[1][1]+rnd.uniform(-step,step))),(cur[1][2]+rnd.uniform(-step,step)*200)%360)
                r=score_base(b)
                if r[0]<cur[0]: cur=r
        if best is None or cur[0]<best[0]: best=cur
    return best
    for b in cands:
        errs=[];assign=[]
        for i,m in enumerate(members):
            bestm=(dist(from_lch(*b),mrgb[i]),("none",0,0))
            for ch in CH:
                for f in (1-R,1,1+R):
                    for k in (1,2,3):
                        t=nom[ch]*f*k
                        d=dist(apply(b,ch,t),mrgb[i])
                        if d<bestm[0]: bestm=(d,(ch,k,nom[ch]*f))
            errs.append(bestm[0]); assign.append(bestm[1])
        sc=(max(errs),sum(errs))
        if best is None or sc<best[0]: best=(sc,b,assign,errs)
    return best
GRID={"light":[0.08,0.12,0.16,0.2],"dark":[0.08,0.12,0.16],"soft":[0.15,0.2,0.25,0.3],"hard":[0.15,0.25,0.35],"pale":[0.1,0.13,0.16,0.2],"shade":[0.08,0.12,0.16],"muted":[0.15,0.25,0.35],"warm":[8,10,12,15],"cool":[8,10,12,15]}
def evaluate(nom,pool):
    res=pool.map(fit_group,[(G[g],nom) for g in G])
    worst=max(r[0][0] for r in res); mean=sum(sum(r[3]) for r in res)/sum(len(r[3]) for r in res)
    return (round(worst,1),round(mean,1)),res
if __name__=="__main__":
    pool=mp.get_context("fork").Pool(6)
    nom={c:GRID[c][len(GRID[c])//2] for c in CH}
    score,res=evaluate(nom,pool); t0=time.time()
    print("start",score,nom,flush=True)
    for sweep in range(2):
        for c in CH:
            for v in GRID[c]:
                if v==nom[c]: continue
                n2=dict(nom); n2[c]=v
                s2,r2=evaluate(n2,pool)
                if s2<score: score,res,nom=s2,r2,n2; print(f"  {c}={v} -> {score}",flush=True)
        print("sweep",sweep,score,round(time.time()-t0),flush=True)
    outd={"R":R,"nominal":nom,"score":score,"groups":{}}
    for (g,mem),r in zip(G.items(),res):
        sc,b,assign,errs=r
        outd["groups"][g]={"members":mem,"base":[b[0],b[1],b[2]],"base_hex":"#%02X%02X%02X"%tuple(round(min(255,max(0,v))) for v in from_lch(*b)),"assign":assign,"errs":errs}
    json.dump(outd,open(out,"w"))
    print("DONE",score,nom)
    for g,d in outd["groups"].items():
        print(f"== {g}: base {d['base_hex']}")
        for m,a,e in zip(d["members"],d["assign"],d["errs"]): print(f"    {m:18s} {a[0]} level {a[1]} step {a[2]:.3f}  err {e:.0f}")
