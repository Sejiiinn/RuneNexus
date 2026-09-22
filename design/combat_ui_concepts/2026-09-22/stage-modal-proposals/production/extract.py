from gi.repository import Gimp, Gio
from pathlib import Path
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
WORK=ROOT/'design/combat_ui_concepts/2026-09-22/stage-modal-proposals'
OUT=ROOT/'assets/images/stage_details/v2'
def save(im,path,proc='file-png-export'):
 p=Gimp.get_pdb().lookup_procedure(proc); c=p.create_config()
 for k,v in [('run-mode',Gimp.RunMode.NONINTERACTIVE),('image',im),('file',Gio.File.new_for_path(str(path)))]:c.set_property(k,v)
 r=p.run(c)
 if r.index(0)!=Gimp.PDBStatusType.SUCCESS:raise RuntimeError(str(r.index(0)))
def crop(im,rect,path,size=None):
 p=im.duplicate();x,y,w,h=rect;p.crop(w,h,x,y)
 if size:p.scale(*size)
 save(p,path);p.delete()
Gimp.context_set_interpolation(Gimp.InterpolationType.NOHALO)
im=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(WORK/'01-four-concepts.png')))
crop(im,(627,58,565,567),WORK/'production/approved-02.png')
crop(im,(1108,85,60,58),OUT/'close_button.png',(42,41))
crop(im,(656,308,503,14),OUT/'divider.png',(352,10))
clean=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(WORK/'production/clean-surfaces.png')))
crop(clean,(87,658,1078,159),OUT/'reward_row.png',(350,52))
crop(clean,(80,991,1090,162),OUT/'action_button.png',(354,53))
crop(clean,(90,558,1070,102),OUT/'reward_heading.png',(350,33))
im.delete();clean.delete()
background=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(WORK/'production/clean-background.png')))
background.crop(1208,1170,25,30);background.scale(390,390)
layer=background.get_layers()[0];layer.add_alpha();layer.set_name('Approved 02 clean native modal surface')
Gimp.context_set_feather(False)
background.select_polygon(Gimp.ChannelOps.REPLACE,[12.,0.,378.,0.,390.,12.,390.,378.,378.,390.,12.,390.,0.,378.,0.,12.])
Gimp.Selection.invert(background);Gimp.Drawable.edit_clear(layer);Gimp.Selection.none(background)
save(background,OUT/'dialog_frame.png');save(background,WORK/'production/dialog-frame.xcf','gimp-xcf-save');background.delete()
