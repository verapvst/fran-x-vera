import json,subprocess,os,sys
from concurrent.futures import ThreadPoolExecutor
os.chdir(sys.argv[1]+'/vid'); seq=json.load(open('seq.json')); FPS=30
os.makedirs('clips',exist_ok=True)
def mk(a):
    i,s=a; n=int(round(s['dur']*FPS)); out=f"clips/{i:03d}.mp4"
    if s['kind']=='photo': z = f"min(1.0+0.10*on/{n},1.10)" if i%2==0 else f"max(1.10-0.10*on/{n},1.0)"
    elif s['n']=='intro': z=f"1.0+0.05*on/{n}"
    else: z=f"1.0+0.025*on/{n}"
    fd='0.08' if s['kind']=='photo' else '0.12'
    vf=f"scale=1620:2880,zoompan=z='{z}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={n}:s=1080x1920:fps={FPS},fade=t=in:st=0:d={fd},format=yuv420p"
    subprocess.run(['ffmpeg','-y','-loglevel','error','-i',f"scenes/{s['n']}.png",'-vf',vf,'-frames:v',str(n),'-c:v','libx264','-preset','veryfast','-crf','23','-r',str(FPS),out],check=True); return out
with ThreadPoolExecutor(4) as ex: outs=list(ex.map(mk,list(enumerate(seq))))
open('list.txt','w').write(''.join(f"file '{o}'\n" for o in outs))
subprocess.run('ffmpeg -y -loglevel error -f concat -safe 0 -i list.txt -f lavfi -i anullsrc=r=44100:cl=stereo -shortest -c:v libx264 -preset slow -crf 27 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 64k festa.mp4',shell=True,check=True)
print('ok')
