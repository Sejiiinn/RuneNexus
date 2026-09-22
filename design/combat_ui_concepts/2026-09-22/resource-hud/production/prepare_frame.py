from pathlib import Path
from gi.repository import Gimp,Gio
root=Path('/Users/sejin/Documents/Codex/RuneNexus')
im=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(root/'assets/images/ui/components/panel_frame.png')))
layer=im.get_layers()[0]
for x,y in [(0,0),(12,0),(24,0),(32,0),(56,0),(0,12),(0,24),(0,32),(0,56),(10,10),(20,20),(1503,0),(0,639),(1503,639)]:
 print('PIXEL',x,y,layer.get_pixel(x,y).get_rgba(),flush=True)
Gimp.context_set_interpolation(Gimp.InterpolationType.CUBIC)
im.scale(376,160)
layer=im.get_layers()[0];layer.add_alpha()
# Preserve the continuous inset metal rail; discard opaque exterior fringe.
Gimp.context_set_antialias(True);Gimp.context_set_feather(False)
im.select_polygon(Gimp.ChannelOps.REPLACE,[7.0,2.0,369.0,2.0,374.0,7.0,374.0,153.0,369.0,158.0,7.0,158.0,2.0,153.0,2.0,7.0])
Gimp.Selection.invert(im);Gimp.Drawable.edit_clear(layer);Gimp.Selection.none(im)
proc=Gimp.get_pdb().lookup_procedure('file-png-export');cfg=proc.create_config()
for key,value in [('run-mode',Gimp.RunMode.NONINTERACTIVE),('image',im),('file',Gio.File.new_for_path(str(root/'assets/images/ui/hud/resource_panel.png')))]:cfg.set_property(key,value)
print('EXPORT',proc.run(cfg).index(0),flush=True)
im.delete()
