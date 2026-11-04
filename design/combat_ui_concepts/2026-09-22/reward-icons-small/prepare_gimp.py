"""Export image-generated reward artwork through GIMP; never touches open documents."""
from pathlib import Path
import json,hashlib
from gi.repository import Gimp,Gio
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
WORK=ROOT/'design/combat_ui_concepts/2026-09-22/reward-icons-small'
OUT=ROOT/'assets/images/stage_details/rewards'
def export(im,path,proc='file-png-export'):
 p=Gimp.get_pdb().lookup_procedure(proc);c=p.create_config()
 for k,v in [('run-mode',Gimp.RunMode.NONINTERACTIVE),('image',im),('file',Gio.File.new_for_path(str(path)))]:c.set_property(k,v)
 result=p.run(c)
 if result.index(0)!=Gimp.PDBStatusType.SUCCESS:raise RuntimeError(str(result.index(0)))
Gimp.context_set_interpolation(Gimp.InterpolationType.NOHALO)
specs=json.loads((WORK/'export-bounds.json').read_text())
manifest=[]
for item in specs:
 im=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(WORK/'originals'/(item['id']+'.png'))))
 x,y,w,h=item['crop'];im.crop(w,h,x,y)
 # 4x sampling preserves edges on high-density displays; the logical slot stays 38px.
 im.scale(152,152)
 im.get_layers()[0].set_name(item['name'])
 target=OUT/(item['id']+'.png');export(im,target)
 manifest.append(dict(id=item['id'],crop=item['crop'],size=[152,152],sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
 im.delete();print('EXPORTED '+item['id'],flush=True)
(WORK/'exports.json').write_text(json.dumps(manifest,indent=2)+'\n')
