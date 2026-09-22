from gi.repository import Gimp,Gio,Gegl
from pathlib import Path
root=Path('/Users/sejin/Documents/Codex/RuneNexus')
base=root/'assets/images/ui/hud/turret_actions'
backup=root/'design/combat_ui_concepts/2026-09-22/turret-action-proposals/production/reference_frames'
import shutil
for name,color,threshold in [('ref_upgrade','#082e35',60),('ref_sell','#12232a',50)]:
 path=base/(name+'.png');original=backup/(name+'-opaque.png')
 if not original.exists():shutil.copy2(path,original)
 im=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(original)))
 layer=im.get_layers()[0];layer.add_alpha()
 Gimp.context_set_antialias(True);Gimp.context_set_feather(False)
 Gimp.context_set_sample_threshold_int(threshold)
 Gimp.context_set_sample_merged(False);Gimp.context_set_sample_transparent(False)
 proc=Gimp.get_pdb().lookup_procedure('gimp-image-select-color');cfg=proc.create_config()
 for key,value in [('image',im),('drawable',layer),('color',Gegl.Color.new(color)),('operation',Gimp.ChannelOps.REPLACE)]:cfg.set_property(key,value)
 proc.run(cfg);Gimp.Drawable.edit_clear(layer);Gimp.Selection.none(im)
 proc=Gimp.get_pdb().lookup_procedure('file-png-export');cfg=proc.create_config()
 for key,value in [('run-mode',Gimp.RunMode.NONINTERACTIVE),('image',im),('file',Gio.File.new_for_path(str(path)))]:cfg.set_property(key,value)
 print(name,proc.run(cfg).index(0),flush=True);im.delete()
