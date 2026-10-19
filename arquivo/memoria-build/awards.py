import json,collections,re
from datetime import datetime,timedelta
from zoneinfo import ZoneInfo
L=ZoneInfo('Europe/Lisbon')
D=lambda n: json.load(open(f'data/{n}.json'))
posts=D('posts');prof=D('profiles');rx=D('reactions');lb=D('leaderboard');tn=D('team_night_board')
tm={x['user_id']:x['team'] for x in D('team_members')}
# nomes públicos: primeiro nome + inicial do apelido; contas com o mesmo nome juntam-se
def pub(n):
    w=n.strip().split()
    return w[0]+(' '+w[-1][0].upper()+'.' if len(w)>1 else '')
by_name=collections.defaultdict(list)
for u in prof: by_name[pub(u['name'])].append(u['id'])
pid={}   # user id -> chave da pessoa
people={}
for name,ids in by_name.items():
    key=ids[0]
    for i in ids: pid[i]=key
    av=[u['avatar_path'] and u['id'] for u in prof if u['id'] in ids and u['avatar_path']]
    people[key]={'id':key,'name':name,'avatar':(av[0] if av else None),'team':next((tm[i] for i in ids if i in tm),None),'role':next(u['role'] for u in prof if u['id']==ids[0])}
LIT={'d_beer20':.2,'d_beer33':.33,'d_beer50':.5}
st=collections.defaultdict(lambda:collections.Counter())
def night(t): return (t-timedelta(hours=8)).date().isoformat()
out_posts=[];first=None;times=collections.defaultdict(list);hours=collections.Counter()
for i,p in enumerate(posts,1):
    k=pid.get(p['user_id']); t=datetime.fromisoformat(p['created_at']).astimezone(L)
    s=st[k]; s['posts']+=1; s[p['drink_id']]+=1; s['liters']+=LIT.get(p['drink_id'],0)
    times[k].append(t)
    out_posts.append({'n':f'p{i:03d}','u':k,'d':p['drink_id'],'t':t.strftime('%Y-%m-%dT%H:%M'),'night':night(t),'c':(p['caption'] or '').strip()[:120],'f':bool(p['photo_path'])})
for x in lb:
    k=pid.get(next((u['id'] for u in prof if u['name']==x['name']),None))
    if k is None: continue
    st[k]['points']+=x['points']; hours[k]+=x['hours']
# reações recebidas
pk={p['id']:pid.get(p['user_id']) for p in posts}
for r in rx: st[pk.get(r['post_id'])]['react']+=1
# post mais reagido
rc=collections.Counter(r['post_id'] for r in rx)
top_post=None
if rc:
    pidx={p['id']:i for i,p in enumerate(posts,1)}; best=rc.most_common(1)[0]; top_post={'n':f'p{pidx[best[0]]:03d}','count':best[1]}
# mais bebidas numa hora (janela deslizante), só bebidas de álcool
def maxwin(ts):
    ts=sorted(ts); best=0
    for i,a in enumerate(ts):
        n=sum(1 for b in ts[i:] if b-a<=timedelta(hours=1)); best=max(best,n)
    return best
drinks_only={k:[t for t,p in zip(times[k],[q for q in posts if pid.get(q['user_id'])==k]) if p['drink_id'] not in ('d_na','d_home')] for k in times}
for k in st: st[k]['hourwin']=maxwin(drinks_only.get(k,[]))
# coruja: último post antes das 08:00 (hora mais tarde da madrugada) e madrugador: primeiro post do dia depois das 08:00
def clock(t): return (t.hour*60+t.minute)
owl={};early={}
for k,ts in times.items():
    late=[t for t in ts if t.hour<8]; 
    if late: owl[k]=max(late,key=lambda t:t.hour*60+t.minute)
    day=[t for t in ts if t.hour>=8]
    if day: early[k]=min(day,key=lambda t:(t.hour*60+t.minute))
variety={k:len([d for d in ('d_beer20','d_beer33','d_beer50','d_sidra','d_wine','d_cock','d_shot') if st[k][d]]) for k in st}
def top(metric,n=3,fmt=lambda v:str(v),minv=1):
    rows=sorted(((k,metric(k)) for k in st if k in people),key=lambda x:-x[1])
    rows=[r for r in rows if r[1]>=minv]
    if len(rows)>n:
        lim=rows[n-1][1]; rows=[r for i,r in enumerate(rows) if i<n or (r[1]==lim and i<6)]
    return [{'u':k,'v':fmt(v),'raw':v} for k,v in rows]
nf=lambda v:str(round(v,1)).replace('.',',')
beer=lambda k: st[k]['liters']
A=[
 ('rei','👑','Rei / Rainha da festa','Mais pontos no total',top(lambda k:st[k]['points'],fmt=lambda v:f'{int(v)} pontos')),
 ('posts','📸','Paparazzi','Mais posts no BoozeFeed',top(lambda k:st[k]['posts'],fmt=lambda v:f'{int(v)} posts')),
 ('cerveja','🍺','Mestre da imperial','Mais cerveja (em litros)',top(beer,fmt=lambda v:nf(v)+' L')),
 ('vinho','🍷','Sommelier','Mais copos de vinho',top(lambda k:st[k]['d_wine'],fmt=lambda v:f'{int(v)} copos')),
 ('shots','🥃','Rei dos shots','Mais shots',top(lambda k:st[k]['d_shot'],fmt=lambda v:f'{int(v)} shots')),
 ('cock','🍸','Barman honorário','Mais cocktails',top(lambda k:st[k]['d_cock'],fmt=lambda v:f'{int(v)} cocktails')),
 ('horas','⏱️','Resistência','Mais horas na festa',top(lambda k:hours[k],fmt=lambda v:nf(v)+' h')),
 ('hora','🔥','Sprint','Mais bebidas numa só hora',top(lambda k:st[k]['hourwin'],fmt=lambda v:f'{int(v)} numa hora')),
 ('variado','🎯','Sem preconceitos','Mais tipos de bebida diferentes',top(lambda k:variety[k],fmt=lambda v:f'{int(v)} tipos')),
 ('agua','💧','MVP da hidratação','Mais águas e sumos',top(lambda k:st[k]['d_na'],fmt=lambda v:f'{int(v)} águas')),
 ('casa','🏠','Pé de boi','Mais vezes a chegar a casa em segurança',top(lambda k:st[k]['d_home'],fmt=lambda v:f'{int(v)} vezes',minv=2)),
 ('reacoes','💬','Mais comentado','Mais reações recebidas',top(lambda k:st[k]['react'],fmt=lambda v:f'{int(v)} reações')),
]
# coruja / madrugador (por hora do dia)
if owl:
    k=max(owl,key=lambda k:owl[k].hour*60+owl[k].minute); k3=sorted(owl,key=lambda k:-(owl[k].hour*60+owl[k].minute))[:3]
    A.append(('coruja','🦉','Coruja','Último post já de madrugada',[{'u':x,'v':owl[x].strftime('%Hh%M'),'raw':0} for x in k3]))
if early:
    k3=sorted(early,key=lambda k:early[k].hour*60+early[k].minute)[:3]
    A.append(('madrug','🐓','Madrugador','Primeiro post do dia mais cedo (a partir das 08h)',[{'u':x,'v':early[x].strftime('%Hh%M'),'raw':0} for x in k3]))
A=[a for a in A if a[4]]
tot=collections.Counter(p['drink_id'] for p in posts)
nights=collections.defaultdict(lambda:{'posts':0})
for p in out_posts: nights[p['night']]['posts']+=1
teams={}
for t in ('fran','vera'):
    rows=[x for x in tn if x['team']==t]
    teams[t]={'points':sum(x['points'] for x in rows),'hours':round(sum(x['hours'] for x in rows),1),'members':next(x['members'] for x in D('team_totals') if x['team']==t),
              'nights':{x['night']:{'points':x['points'],'hours':x['hours'],'people':x['people']} for x in rows}}
rank=sorted(((k,st[k]['points'],hours[k],st[k]['posts']) for k in st if k in people and st[k]['posts']),key=lambda x:(-x[1],-x[3]))
data={'people':{k:v for k,v in people.items() if k in st and st[k]['posts']},
 'posts':out_posts,'awards':[{'id':a[0],'emoji':a[1],'title':a[2],'sub':a[3],'top':a[4]} for a in A],
 'teams':teams,'rank':[{'u':k,'points':p,'hours':round(h,1),'posts':n} for k,p,h,n in rank],
 'totals':{'posts':len(posts),'players':len([k for k in st if k in people and st[k]['posts']]),'beerL':round(sum(LIT.get(p['drink_id'],0) for p in posts),1),
   'beers':tot['d_beer20']+tot['d_beer33']+tot['d_beer50'],'shots':tot['d_shot'],'wine':tot['d_wine'],'cock':tot['d_cock'],'sidra':tot['d_sidra'],'water':tot['d_na'],'home':tot['d_home'],'hours':round(sum(hours.values()),1)},
 'topPost':top_post,'nights':nights}
json.dump(data,open('data/memoria.json','w'),ensure_ascii=False)
print(json.dumps(data['totals'],ensure_ascii=False)); print({t:(v['points'],v['hours']) for t,v in teams.items()})
for a in data['awards']: print(a['emoji'],a['title'],'|',[(data['people'][x['u']]['name'],x['v']) for x in a['top']])
print('merged names:',{n:len(i) for n,i in by_name.items() if len(i)>1})

import os,shutil
keys=sorted(data['people']); m={k:f'u{i+1:02d}' for i,k in enumerate(keys)}
def rm(o):
    if isinstance(o,dict): return {(m.get(k,k) if k in m else k):rm(v) for k,v in o.items()}
    if isinstance(o,list): return [rm(x) for x in o]
    if isinstance(o,str) and o in m: return m[o]
    return o
people=data['people']
for k,v in people.items():
    v['avatar']=bool(v['avatar'])
d2=rm(data)
for k,v in d2['people'].items(): v['id']=k
# avatares: renomear ficheiros
A='SITE/memoria/avatars'
for k in keys:
    av=[u['id'] for u in prof if pid.get(u['id'])==k and u['avatar_path']]
    if av and os.path.exists(f'{A}/{av[0]}.webp'): shutil.copy(f'{A}/{av[0]}.webp',f'{A}/{m[k]}.webp')
for f in os.listdir(A):
    if not re.match(r'u\d\d\.webp',f): os.remove(f'{A}/{f}')
open('SITE/memoria/data.js','w').write('window.MEMORIA='+json.dumps(d2,ensure_ascii=False,separators=(',',':'))+';')
print('ok',len(d2['people']),'pessoas')
