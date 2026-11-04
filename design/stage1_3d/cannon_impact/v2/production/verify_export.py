from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parent;report={}
for kind,filename in [('body','cannon_impact.png'),('ground','cannon_shockwave.png')]:
 atlas=Image.open(root.parents[4]/'assets/images/stage1_3d/effects'/filename).convert('RGBA')
 assert atlas.size==(2048,1024)
 frames=[]
 for f in range(32):
  source=Image.open(root/'frames'/kind/('%02d.png'%f)).convert('RGBA');cell=atlas.crop((f%8*256,f//8*256,f%8*256+256,f//8*256+256));assert source.getchannel('A').tobytes()==cell.getchannel('A').tobytes(),(kind,f,'alpha mismatch');assert all(a==b for a,b in zip(source.getdata(),cell.getdata()) if a[3]>0),(kind,f,'visible RGB mismatch');a=source.getchannel('A');edges=[a.crop(b).getextrema()[1] for b in [(0,0,256,1),(0,255,256,256),(0,0,1,256),(255,0,256,256)]]
  frames.append({'frame':f,'alpha_bbox':a.getbbox(),'edge_alpha_max':max(edges)})
 assert frames[-1]['alpha_bbox'] is None,(kind,'last frame nonempty')
 report[kind]=frames
(root/'frame_qa.json').write_text(json.dumps(report,indent=2));print('64 atlas cells match visible RGBA source; 32nd frames empty');print('Border coverage:',{k:[x['frame'] for x in v if x['edge_alpha_max']] for k,v in report.items()})
