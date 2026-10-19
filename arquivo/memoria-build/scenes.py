import json,html,collections
_d=open('SITE/memoria/data.js').read(); M=json.loads(_d[_d.index('=')+1:].rstrip(';')); pick=json.load(open('data/pick.json'))
P=M['people']; posts={int(p['n'][1:]):p for p in M['posts']}
DR={'d_beer20':'🍺 Cerveja','d_beer33':'🍺 Cerveja','d_beer50':'🍺 Caneca','d_sidra':'🍏 Sidra','d_wine':'🍷 Vinho','d_cock':'🍸 Cocktail','d_shot':'🥃 Shot','d_na':'💧 Água','d_home':'🏠 Em casa'}
WD=['Segunda','Terça','Quarta','Quinta','Sexta','Sábado','Domingo']
import datetime
def when(t):
    d=datetime.datetime.fromisoformat(t); return f"{WD[d.weekday()]} {d.day} · {t[11:]}"
CSS="""
@import url('https://fonts.googleapis.com/css2?family=Archivo:wght@600;800&family=Londrina+Solid:wght@400;900&display=swap');
:root{--bg:#f4e2ea;--ink:#0d0a0b;--red:#e8421f;--card:#fbf1f5;--soft:#ead0dc}
*{box-sizing:border-box;margin:0}
body{width:1080px;height:1920px;overflow:hidden;background:var(--bg);color:var(--ink);font-family:'Archivo',sans-serif;position:relative}
.d{font-family:'Londrina Solid',Impact,sans-serif;font-weight:900}
.c{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:90px 80px}
"""
def page(body,extra=''):
    return f"<!doctype html><meta charset=utf-8><style>{CSS}{extra}</style>{body}"
scenes=[]
def add(name,body,dur,kind='card',extra=''):
    open(f'vid/scenes/{name}.html','w').write(page(body,extra)); scenes.append({'n':name,'dur':dur,'kind':kind})
PH_CSS="""
.bg{position:absolute;inset:-60px;background-size:cover;background-position:center;filter:blur(38px) brightness(.55) saturate(1.3)}
.fr{position:absolute;left:60px;top:250px;width:960px;border:14px solid #fff;box-shadow:0 30px 80px rgba(0,0,0,.5);transform:rotate(-1.6deg)}
.fr img{display:block;width:100%}
.chip{position:absolute;left:60px;right:60px;bottom:170px;background:var(--ink);color:var(--bg);padding:26px 34px;display:flex;justify-content:space-between;align-items:center;border:6px solid #fff}
.chip b{font-family:'Londrina Solid';font-weight:900;font-size:86px;line-height:1}
.chip span{font-size:34px;font-weight:800;text-align:right;line-height:1.2}
.top{position:absolute;top:90px;left:0;right:0;text-align:center;font-family:'Londrina Solid';font-weight:900;font-size:64px;color:#fff;letter-spacing:.02em}
.top i{color:var(--red);font-style:normal}
"""
def photo(i,r):
    p=posts[r['i']]; nm=html.escape(P[p['u']]['name']); src=f"SITE/memoria/fotos/{p['n']}.webp"
    add(f"ph{i:02d}",f"<div class=bg style=\"background-image:url('file://{src}')\"></div><div class=top>FRAN <i>×</i> VERA</div><div class=fr><img src='file://{src}'></div><div class=chip><b>{nm}</b><span>{DR[p['d']]}<br>{when(p['t'])}</span></div>",1.3,'photo',PH_CSS)
# fotos escolhidas (32 espalhadas)
sel=[pick[int(k*len(pick)/32)] for k in range(32)]
# intro
add('intro',"<div class=c><div style='font-size:34px;font-weight:800;letter-spacing:.14em;text-transform:uppercase'>15 a 18 de outubro · Lisboa</div><div class=d style='font-size:300px;line-height:.8;margin-top:30px'>FRAN<br><span style='color:var(--red)'>×</span><br>VERA</div><div class=d style='font-size:96px;margin-top:50px'>23H30 de festa</div><div style='font-size:40px;font-weight:800;margin-top:20px'>A memória</div></div>",3.2)
T=M['totals']; nf=lambda x:str(round(x,1)).replace('.',',')
def stat(v,l): return f"<div style='background:var(--card);border:8px solid var(--ink);padding:34px 20px;width:430px'><div class=d style='font-size:128px;line-height:.9;color:var(--red)'>{v}</div><div style='font-size:30px;font-weight:800;text-transform:uppercase;letter-spacing:.05em'>{l}</div></div>"
add('numeros',f"<div class=c><div class=d style='font-size:130px;line-height:.9;margin-bottom:50px'>A noite <span style='color:var(--red)'>em números</span></div><div style='display:grid;grid-template-columns:1fr 1fr;gap:26px'>{stat(T['posts'],'posts')}{stat(T['players'],'pessoas')}{stat(nf(T['beerL'])+' L','de cerveja')}{stat(T['shots'],'shots')}{stat(T['wine'],'copos de vinho')}{stat(nf(T['hours'])+' h','de festa')}</div></div>",4.2)
AW={a['id']:a for a in M['awards']}
order=['rei','posts','cerveja','vinho','shots','cock','horas','coruja']
def av(u,sz): return f"<img src='file://SITE/memoria/avatars/{u}.webp' style='width:{sz}px;height:{sz}px;border-radius:50%;object-fit:cover;border:8px solid var(--ink);background:var(--soft)'>"
def award(k,idx):
    a=AW[k]; t=a['top']; w=t[0]; wn=html.escape(P[w['u']]['name'])
    runners=''.join(f"<div style='display:flex;align-items:center;gap:22px;font-size:44px;font-weight:800;margin-top:20px'><span class=d style='font-size:60px;width:50px'>{j+2}</span>{av(r['u'],84)}<span style='flex:1;text-align:left'>{html.escape(P[r['u']]['name'])}</span><span>{html.escape(r['v'])}</span></div>" for j,r in enumerate(t[1:3]))
    add(f"aw{idx:02d}",f"<div class=c><div style='font-size:36px;font-weight:800;letter-spacing:.16em;text-transform:uppercase'>Prémio {idx+1} de {len(order)}</div><div style='font-size:200px;line-height:1;margin:20px 0 4px'>{a['emoji']}</div><div class=d style='font-size:150px;line-height:.9'>{html.escape(a['title'])}</div><div style='font-size:38px;font-weight:600;margin:14px 0 46px'>{html.escape(a['sub'])}</div><div style='background:var(--ink);color:var(--bg);padding:36px 40px;width:100%;display:flex;align-items:center;gap:34px;border:6px solid #fff'>{av(w['u'],190).replace('var(--ink)','#fff')}<div style='text-align:left'><div class=d style='font-size:120px;line-height:.9'>{wn}</div><div class=d style='font-size:84px;color:var(--red);line-height:1'>{html.escape(w['v'])}</div></div></div><div style='width:100%;margin-top:30px'>{runners}</div></div>",3.4)
tf,tv=M['teams']['fran'],M['teams']['vera']; win='fran' if tf['points']>=tv['points'] else 'vera'
def team(t,x):
    w=t==win; bg='var(--ink)' if w else 'var(--card)'; fg='var(--bg)' if w else 'var(--ink)'
    return f"<div style='background:{bg};color:{fg};border:8px solid var(--ink);padding:40px 30px;width:470px;position:relative'>{'<div style=\"position:absolute;top:-34px;right:20px;background:var(--red);color:var(--ink);border:6px solid var(--ink);border-radius:99px;padding:6px 28px;font-weight:800;font-size:32px;letter-spacing:.08em;text-transform:uppercase\">Vencedora</div>' if w else ''}<div class=d style='font-size:80px;line-height:1'>Team {'Fran' if t=='fran' else 'Vera'}</div><div class=d style='font-size:230px;line-height:.9;color:var(--red)'>{x['points']}</div><div style='font-size:30px;font-weight:800;text-transform:uppercase;letter-spacing:.08em'>pontos</div><div style='font-size:38px;font-weight:800;margin-top:22px'>{nf(x['hours'])} h de festa</div></div>"
add('equipas',f"<div class=c><div class=d style='font-size:130px;line-height:.9;margin-bottom:60px'>A guerra das <span style='color:var(--red)'>equipas</span></div><div style='display:flex;gap:26px'>{team('fran',tf)}{team('vera',tv)}</div></div>",4.4)
add('outro',"<div class=c><div class=d style='font-size:230px;line-height:.85'>Obrigada<br><span style='color:var(--red)'>por tudo</span></div><div class=d style='font-size:100px;margin-top:60px'>FRAN × VERA</div><div style='font-size:38px;font-weight:800;margin-top:26px'>verapvst.github.io/fran-x-vera/memoria</div></div>",4.0)
# montagem da sequência: intro, 8 fotos, números, 5 fotos, prémios (2 + 3 fotos) ..., equipas, 6 fotos, outro
seq=['intro']; ph=iter(range(len(sel)))
photos={}
for i,r in enumerate(sel): photo(i,r)
def take(n): return [f'ph{next(ph):02d}' for _ in range(n)]
seq+=take(8)+['numeros']+take(4)
for k in range(0,len(order),2):
    for j in (k,k+1):
        award(order[j],j); seq.append(f'aw{j:02d}')
    seq+=take(3 if k<6 else 2)
seq+=['equipas']+take(max(0,len(sel)-sum(1 for s in seq if s.startswith('ph'))))+['outro']
by={s['n']:s for s in scenes}
json.dump([by[n] for n in seq],open('vid/seq.json','w'))
print(len(seq),'cenas; duração',round(sum(by[n]['dur'] for n in seq),1),'s; fotos usadas',sum(1 for n in seq if n.startswith('ph')))
