const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
 const browser = await chromium.launch({headless:true, channel:'chrome'});
 const root = 'design/stage1_3d/material_match';
 const prefix = process.argv[2] || 'current';
 const errors=[];
 for (const [name,width,height] of [['large',1152,1280],['phone',440,900]]) {
  const page = await browser.newPage({viewport:{width,height},deviceScaleFactor:1,hasTouch:true});
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('response',r=>{if(r.status()>=400)errors.push(`${r.status()} ${r.url()}`)});
  page.on('console',m=>{if(['error','warning'].includes(m.type()))console.log(m.type(),m.text())});
  await page.goto(`http://127.0.0.1:53000/?stage1_3d=1&cache_bust=${prefix}`);
  await page.waitForTimeout(7000);
  await page.screenshot({path:`${root}/${prefix}-${name}.png`});
  await page.close();
 }
 fs.writeFileSync(`${root}/${prefix}-browser.json`,JSON.stringify({errors},null,2));
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
