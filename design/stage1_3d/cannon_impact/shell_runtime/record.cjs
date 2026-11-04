const {chromium}=require('playwright');
const fs=require('fs');
const root='design/stage1_3d/cannon_impact/shell_runtime';
(async()=>{
const browser=await chromium.launch({headless:true,channel:'chrome'});
const page=await browser.newPage({viewport:{width:800,height:1000},deviceScaleFactor:1});
const errors=[];page.on('pageerror',e=>errors.push(e.stack));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
await page.goto(`http://127.0.0.1:53013/?v=${Date.now()}`);await page.waitForTimeout(7000);
const cdp=await page.context().newCDPSession(page), frames=[],writes=[];let began;
fs.mkdirSync(`${root}/frames`,{recursive:true});
cdp.on('Page.screencastFrame',e=>{
 cdp.send('Page.screencastFrameAck',{sessionId:e.sessionId}).catch(()=>{});
 began??=e.metadata.timestamp;const file=`frames/${String(frames.length).padStart(4,'0')}.jpg`;
 frames.push({file,time:e.metadata.timestamp-began});writes.push(fs.promises.writeFile(`${root}/${file}`,Buffer.from(e.data,'base64')));
});
await cdp.send('Page.startScreencast',{format:'jpeg',quality:90,maxWidth:800,maxHeight:1000,everyNthFrame:1});
await page.waitForTimeout(4200);
await page.mouse.click(384,174);
await page.waitForTimeout(4200);
await cdp.send('Page.stopScreencast');await Promise.all(writes);
fs.writeFileSync(`${root}/frames.json`,JSON.stringify(frames));
fs.writeFileSync(`${root}/playback-check.json`,JSON.stringify({errors,frames:frames.length,duration:frames.at(-1)?.time},null,2));
console.log(JSON.stringify({errors,frames:frames.length,duration:frames.at(-1)?.time}));await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
