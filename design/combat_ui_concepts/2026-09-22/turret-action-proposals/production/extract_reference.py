from gi.repository import Gimp, Gio
from pathlib import Path
root=Path('/Users/sejin/Documents/Codex/RuneNexus')
source=root/'design/combat_ui_concepts/2026-09-22/turret-action-proposals/06-v2-upgrade-traits.png'
out=root/'assets/images/ui/hud/turret_actions'
Gimp.context_set_interpolation(Gimp.InterpolationType.CUBIC)
def load(rect):
 im=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(source)))
 im.scale(2048,705)
 x,y,w,h=rect;im.crop(w,h,x,y)
 return im
def export(im,name):
 proc=Gimp.get_pdb().lookup_procedure('file-png-export');cfg=proc.create_config()
 dest = root/'design/combat_ui_concepts/2026-09-22/turret-action-proposals/production/reference_frames' if name.startswith('reference_') else out
 dest.mkdir(exist_ok=True)
 cfg.set_property('run-mode',Gimp.RunMode.NONINTERACTIVE);cfg.set_property('image',im);cfg.set_property('file',Gio.File.new_for_path(str(dest/(name+'.png'))))
 print(name,proc.run(cfg).index(0),flush=True);im.delete()
def polygon(im,points):
 im.select_polygon(Gimp.ChannelOps.REPLACE,[float(n) for p in points for n in p])
def clipped(w,h,c):return [(c,0),(w-c,0),(w,c),(w,h-c),(w-c,h),(c,h),(0,h-c),(0,c)]
def frame(name,rect,inner,sample,corner):
 im=load(rect);orig=im.get_layers()[0];orig.add_alpha();w,h=im.get_width(),im.get_height()
 tex=load(sample);tex.scale(w,h)
 layer=Gimp.Layer.new_from_drawable(tex.get_layers()[0],im);im.insert_layer(layer,None,1);tex.delete()
 polygon(im,inner);Gimp.Drawable.edit_clear(orig);Gimp.Selection.none(im)
 merged=im.merge_visible_layers(Gimp.MergeType.CLIP_TO_IMAGE);merged.add_alpha()
 polygon(im,clipped(w,h,corner));Gimp.Selection.invert(im);Gimp.Drawable.edit_clear(merged);Gimp.Selection.none(im)
 export(im,name)
frame('reference_header',(38,202,1972,298),[(20,34),(1952,34),(1952,260),(1927,282),(45,282),(20,260)],(290,245,190,32),22)
frame('reference_upgrade',(539,242,570,225),[(60,29),(510,29),(538,56),(538,169),(510,194),(60,194),(31,167),(31,57)],(795,273,255,12),45)
frame('reference_traits',(1140,242,585,225),[(60,29),(525,29),(554,56),(554,169),(525,194),(60,194),(31,167),(31,57)],(1410,275,245,12),45)
frame('reference_sell',(1805,270,145,167),[(25,15),(121,15),(131,27),(131,140),(119,151),(24,151),(14,140),(14,27)],(1829,281,94,12),20)
frame('reference_tab_active',(255,490,754,130),[(42,15),(705,15),(737,46),(737,87),(705,115),(42,115),(15,87),(15,46)],(289,509,700,17),42)
frame('reference_tab_idle',(1020,490,766,130),[(42,15),(717,15),(749,46),(749,87),(717,115),(42,115),(15,87),(15,46)],(1058,510,678,16),42)
for name,rect in [('ref_upgrade',(613,295,106,123)),('ref_sell',(1835,296,93,70)),('ref_divider',(763,262,7,183)),('ref_trait_divider',(1386,262,8,183)),('ref_identity_divider',(505,251,8,207))]:
 export(load(rect),name)
