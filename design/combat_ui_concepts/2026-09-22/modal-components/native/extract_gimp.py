from gi.repository import Gimp, Gio
from pathlib import Path
import json, hashlib
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
WORK=ROOT/'design/combat_ui_concepts/2026-09-22/modal-components/native'
OUT=ROOT/'assets/images/ui/combat_components/native'
SOURCE=WORK.parent/'nine-slice-source-v3.png'
specs={'modal':(90,86,1595,389,58),'primary':(64,496,529,145,44),'secondary':(624,497,527,144,44),'danger':(1181,495,533,148,44),'selected':(345,665,529,141,44),'disabled':(900,665,531,141,44)}
def save(image,path,proc='file-png-export'):
 p=Gimp.get_pdb().lookup_procedure(proc); c=p.create_config(); c.set_property('run-mode',Gimp.RunMode.NONINTERACTIVE); c.set_property('image',image); c.set_property('file',Gio.File.new_for_path(str(path))); r=p.run(c)
 if r.index(0)!=Gimp.PDBStatusType.SUCCESS: raise RuntimeError(str(r.index(0)))
original=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(SOURCE)))
Gimp.context_set_interpolation(Gimp.InterpolationType.NOHALO)
records={}
preview=Gimp.Image.new(440,360,Gimp.ImageBaseType.RGB)
py=12
for name,(x,y,w,h,m) in specs.items():
 piece=original.duplicate();piece.crop(w,h,x,y);piece.get_layers()[0].set_name(name+' original V3 crop')
 save(piece,WORK/(name+'-source.xcf'),'gimp-xcf-save')
 fw,fh=round(w*.25),round(h*.25);piece.scale(fw,fh)
 path=OUT/(name+'.png');save(piece,path)
 layer=Gimp.Layer.new_from_drawable(piece.get_layers()[0],preview);preview.insert_layer(layer,None,0);layer.set_offsets(12,py);layer.set_name(name);py+=fh+8
 records[name]={'file':str(path.relative_to(ROOT)),'source_rect':[x,y,w,h],'size':[fw,fh],'texture_margins':[round(m*.25)]*4,'safe_padding':[18,16,18,16] if name=='modal' else [14,7,14,7],'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 piece.delete()
 print('EXPORTED '+name,flush=True)
save(preview,WORK/'native-preview.png');save(preview,WORK/'native-preview.xcf','gimp-xcf-save')
(WORK/'extraction.json').write_text(json.dumps({'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'method':'Original V3 intact crops; GIMP NoHalo scaling to 25%, rounded integer dimensions. No redraw, no regeneration. Original transparent crop margins retained.','components':records},indent=2)+'\n')
original.delete();preview.delete()
