import json,os,sys
from PIL import Image, ImageOps
from multiprocessing import Pool
OUT='SITE/memoria'
os.makedirs(OUT+'/fotos',exist_ok=True);os.makedirs(OUT+'/thumbs',exist_ok=True);os.makedirs(OUT+'/avatars',exist_ok=True)
posts=json.load(open('data/posts.json'));prof=json.load(open('data/profiles.json'))
jobs=[]
for i,p in enumerate(posts,1):
    if p['photo_path']: jobs.append(('post',p['photo_path'],f'p{i:03d}'))
for u in prof:
    if u['avatar_path']: jobs.append(('av',u['avatar_path'],u['id']))
def work(j):
    kind,src,name=j
    try:
        im=Image.open('raw/'+src); im=ImageOps.exif_transpose(im).convert('RGB')  # re-codificar tira o EXIF (GPS incluido)
        if kind=='post':
            w,h=im.size
            a=im.copy(); a.thumbnail((1280,1280)); a.save(f'{OUT}/fotos/{name}.jpg','JPEG',quality=86,optimize=True,progressive=True)
            t=im.copy(); t.thumbnail((480,480)); t.save(f'{OUT}/thumbs/{name}.webp','WEBP',quality=72,method=4)
            return (name,w,h,None)
        else:
            a=ImageOps.fit(im,(160,160)); a.save(f'{OUT}/avatars/{name}.webp','WEBP',quality=80,method=4); return (name,0,0,None)
    except Exception as e: return (name,0,0,str(e))
if __name__=='__main__':
    with Pool(8) as p: res=p.map(work,jobs)
    bad=[r for r in res if r[3]]; print('done',len(res),'bad',bad[:5])
    import collections
    print(collections.Counter(('portrait' if h>w else 'landscape' if w>h else 'square') for n,w,h,e in res if w))
