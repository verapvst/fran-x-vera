import json,random,collections
import numpy as np
from PIL import Image
_d=open('SITE/memoria/data.js').read(); M=json.loads(_d[_d.index('=')+1:].rstrip(';'))
posts=json.load(open('data/posts.json')); rx=json.load(open('data/reactions.json'))
rc=collections.Counter(r['post_id'] for r in rx)
rows=[]
for i,p in enumerate(posts,1):
    if not p['photo_path']: continue
    a=np.asarray(Image.open(f'SITE/memoria/thumbs/p{i:03d}.webp').convert('L').resize((200,225)),dtype=float)
    lap=np.abs(a[1:-1,1:-1]*4-a[:-2,1:-1]-a[2:,1:-1]-a[1:-1,:-2]-a[1:-1,2:]).var()
    rows.append({'i':i,'u':M['posts'][i-1]['u'],'night':M['posts'][i-1]['night'],'d':p['drink_id'],'lap':lap,'br':a.mean(),'rx':rc.get(p['id'],0)})
th=np.percentile([r['lap'] for r in rows],30)
ok=[r for r in rows if 70<r['br']<215 and r['lap']>th and r['d']!='d_home']
by=collections.defaultdict(list)
for r in ok: by[r['u']].append(r)
pick=[]
for u,l in by.items():
    l.sort(key=lambda r:(-r['rx'],-r['lap'])); pick.append(l[0])
extra=[r for r in ok if r not in pick]; random.seed(11); random.shuffle(extra)
pick+=extra[:max(0,60-len(pick))]
pick.sort(key=lambda r:r['i']); json.dump(pick,open('data/pick.json','w')); print(len(pick))
