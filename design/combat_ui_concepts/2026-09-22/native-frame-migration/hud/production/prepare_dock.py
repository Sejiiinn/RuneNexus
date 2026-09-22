from pathlib import Path
from gi.repository import Gimp,Gio
import json,hashlib
root=Path('/Users/sejin/Documents/Codex/RuneNexus')
work=root/'design/combat_ui_concepts/2026-09-22/native-frame-migration/hud/production'
source=root/'assets/images/ui/components/panel_frame.png'
original=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(source)))
Gimp.context_set_interpolation(Gimp.InterpolationType.CUBIC)
body=original.duplicate();body.crop(1392,528,56,56);body.scale(348,132)
body.get_layers()[0].set_name('Original dock interior, no corner caps')
# Match the original 56px -> 4px GPU bilinear sample centers (7,21,35,49).
# Full-area cubic downsampling averages away the approved rail contrast.
for row,source_y in enumerate([6,20,34,48]):
 rail=original.duplicate();rail.crop(1392,2,56,source_y);rail.scale(348,1)
 layer=Gimp.Layer.new_from_drawable(rail.get_layers()[0],body);body.insert_layer(layer,None,0)
 layer.set_offsets(0,row);layer.set_name('Metal rail GPU sample row '+str(row))
 rail.delete()
for name,path in [('gimp-xcf-save',work/'dock-panel.xcf'),('file-png-export',root/'assets/images/ui/hud/dock_panel.png')]:
 p=Gimp.get_pdb().lookup_procedure(name);c=p.create_config()
 for k,v in [('run-mode',Gimp.RunMode.NONINTERACTIVE),('image',body),('file',Gio.File.new_for_path(str(path)))]:c.set_property(k,v)
 r=p.run(c)
 if r.index(0)!=Gimp.PDBStatusType.SUCCESS:raise RuntimeError(str(r.index(0)))
 print('EXPORTED',path,flush=True)
asset=root/'assets/images/ui/hud/dock_panel.png'
(work/'dock.json').write_text(json.dumps({'source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'interior_crop':[56,56,1392,528],'interior_size':[348,132],'rail_crop':[56,0,1392,56],'rail_size':[348,4],'rail_offset':[0,0],'bilinear_source_rows':[[6,7],[20,21],[34,35],[48,49]],'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest()},indent=2)+'\n')
body.delete();original.delete()
