"""Read-only asset checks and a QA contact sheet; does not modify game assets."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
ROOT=Path(__file__).resolve().parents[2];WORK=ROOT/'design/hud_turret_icons_fixed'
meta=json.loads((WORK/'direction-verification.json').read_text())
sheet=Image.new('RGB',(768,664),'#071b25');draw=ImageDraw.Draw(sheet)
report={}
for i,(kind,record) in enumerate(meta.items()):
    path=ROOT/'assets/images/ui/hud/turrets_3d'/f'{kind}.png';im=Image.open(path)
    assert im.mode=='RGBA' and im.size==(256,256)
    box=im.getchannel('A').getbbox();assert box and box[0]>0 and box[1]>0 and box[2]<256 and box[3]<256
    assert hashlib.sha256((ROOT/record['source']).read_bytes()).hexdigest()==record['sha256']
    assert record['screen_forward_xy_down']==meta['arrow']['screen_forward_xy_down']
    x=(i%3)*256;y=(i//3)*332
    sheet.paste(im,(x,y),im);draw.text((x+12,y+258),kind,fill='white')
    small=im.resize((64,64),Image.Resampling.LANCZOS);sheet.paste(small,(x+176,y+258),small)
    draw.text((x+12,y+282),'forward: 146.194 deg',fill='#8ab7bc')
    report[kind]={'alpha_bbox':box,'bytes':path.stat().st_size,'size':im.size,'format':im.mode,'source_unchanged':True,'exact_same_screen_forward':True}
sheet.save(WORK/'contact-sheet.png')
(WORK/'image-verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
