const { chromium } = require('playwright');
const fs = require('fs');
const root = 'design/stage1_3d/cannon_impact/shell_runtime';
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome'});
 const page=await browser.newPage({viewport:{width:800,height:1000},deviceScaleFactor:1});
 const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 page.on('response',r=>{if(r.status()>=400)errors.push(`${r.status()} ${r.url()}`)});
 for(const [view,time] of [['angled',.12],['drone',.12],['angled',.55],['drone',.80]]){
  await page.goto(`http://127.0.0.1:53013/?view=${view}&time=${time}&paused=1&v=${Date.now()}`);
  await page.waitForTimeout(6500);
  await page.screenshot({path:`${root}/${view}-${time}.png`});
 }
 fs.writeFileSync(`${root}/browser-check.json`,JSON.stringify({errors},null,2));
 console.log(JSON.stringify({errors}));
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
