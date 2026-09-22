from gi.repository import Gimp, Gio
from pathlib import Path
root=Path('/Users/sejin/Documents/Codex/RuneNexus')
base=root/'assets/images/ui/hud/turret_actions'
out=base/'native';out.mkdir(exist_ok=True)
Gimp.context_set_interpolation(Gimp.InterpolationType.CUBIC)
for name,size in [('header',(424,64)),('upgrade',(123,48)),('traits',(126,48)),('sell',(31,36)),('tab_active',(162,28)),('tab_idle',(165,28))]:
 im=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(root/'design/combat_ui_concepts/2026-09-22/turret-action-proposals/production/reference_frames'/('reference_'+name+'.png'))))
 im.scale(*size)
 proc=Gimp.get_pdb().lookup_procedure('file-png-export');cfg=proc.create_config()
 cfg.set_property('run-mode',Gimp.RunMode.NONINTERACTIVE);cfg.set_property('image',im);cfg.set_property('file',Gio.File.new_for_path(str(out/(name+'.png'))))
 print(name,proc.run(cfg).index(0),flush=True);im.delete()
