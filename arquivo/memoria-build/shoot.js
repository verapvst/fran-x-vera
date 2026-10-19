const {chromium}=require('playwright');const fs=require('fs');
(async()=>{
 const S=process.argv[2];const seq=JSON.parse(fs.readFileSync(S+'/vid/seq.json'));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium',args:['--allow-file-access-from-files']});
 const p=await b.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});
 let n=0;
 for(const s of seq){
   await p.goto('file://'+S+'/vid/scenes/'+s.n+'.html',{waitUntil:'networkidle'});
   await p.evaluate(()=>document.fonts.ready);
   await p.waitForTimeout(120);
   await p.screenshot({path:S+'/vid/scenes/'+s.n+'.png'});n++;
 }
 console.log('png',n);await b.close();})();
