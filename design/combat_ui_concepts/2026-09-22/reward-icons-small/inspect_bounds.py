"""Read-only PNG inspection. All actual crop/scale/export occurs in GIMP."""
from pathlib import Path
from PIL import Image
import json
WORK=Path(__file__).resolve().parent
items=json.loads((WORK/'inventory.json').read_text())
out=[]
for item in items:
 path=WORK/'originals'/(item['id']+'.png')
 im=Image.open(path).convert('RGBA')
 alpha=im.getchannel('A')
 assert alpha.getextrema()[0]==0, f'{item["id"]}: no transparent pixels'
 bbox=alpha.point(lambda v:255 if v>32 else 0).getbbox()
 assert bbox, item['id']
 left,top,right,bottom=bbox
 span=min(min(im.size),round(max(right-left,bottom-top)/0.9))
 cx=(left+right)/2;cy=(top+bottom)/2
 x=max(0,min(im.width-span,round(cx-span/2)))
 y=max(0,min(im.height-span,round(cy-span/2)))
 out.append(dict(item,crop=[x,y,span,span],source_size=list(im.size),alpha_bbox=list(bbox)))
 print(item['id'],im.size,'bbox',bbox,'crop',out[-1]['crop'])
(WORK/'export-bounds.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
