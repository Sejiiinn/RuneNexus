const {chromium}=require('playwright');
(async()=>{
const browser=await chromium.launch({headless:true,channel:'chrome'});
const page=await browser.newPage({viewport:{width:640,height:640},deviceScaleFactor:1});
page.on('console',m=>{if(m.type()==='error')console.log(m.text())});
page.on('pageerror',e=>console.log('ERROR',e.message));
for(const frame of [8,16]){
 await page.goto(`http://127.0.0.1:53012/?frame=${frame}&bust=${Date.now()}`);
 await page.waitForTimeout(7000);
 await page.screenshot({path:`design/stage1_3d/cannon_impact/v2/comparison/runtime-${frame}.png`});
}
await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
