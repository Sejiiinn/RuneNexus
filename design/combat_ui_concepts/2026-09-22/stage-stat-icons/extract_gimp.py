from pathlib import Path
from gi.repository import Gimp,Gio
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
WORK=ROOT/'design/combat_ui_concepts/2026-09-22/stage-stat-icons'
OUT=ROOT/'assets/images/stage_details/stats'
def save(im,path,proc='file-png-export'):
 p=Gimp.get_pdb().lookup_procedure(proc);c=p.create_config()
 for k,v in [('run-mode',Gimp.RunMode.NONINTERACTIVE),('image',im),('file',Gio.File.new_for_path(str(path)))]:c.set_property(k,v)
 r=p.run(c)
 if r.index(0)!=Gimp.PDBStatusType.SUCCESS:raise RuntimeError(str(r.index(0)))
original=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(WORK/'04-gold-border.png')))
Gimp.context_set_antialias(True);Gimp.context_set_feather(False)
Gimp.context_set_sample_threshold(0.18)
Gimp.context_set_interpolation(Gimp.InterpolationType.NOHALO)
specs=[('best_record',(116,165,380,340),[(5,5),(82,105),(300,105)]),('total_rounds',(652,138,290,364),[(5,5)]),('rune_reward',(1100,140,320,375),[(5,5),(85,155),(220,155)])]
for name,(x,y,w,h),seeds in specs:
 im=original.duplicate();im.crop(w,h,x,y);layer=im.get_layers()[0];layer.add_alpha();layer.set_name('Approved 04 gold border '+name)
 for px,py in seeds:im.select_contiguous_color(Gimp.ChannelOps.ADD,layer,px,py)
 Gimp.Drawable.edit_clear(layer);Gimp.Selection.none(im)
 save(im,WORK/(name+'-cutout.png'));save(im,WORK/(name+'.xcf'),'gimp-xcf-save')
 # Preserve aspect ratio and include a two-pixel logical safety inset.
 scale=88/max(w,h);nw=round(w*scale);nh=round(h*scale)
 im.scale(nw,nh);im.resize(96,96,(96-nw)//2,(96-nh)//2)
 save(im,OUT/(name+'.png'));im.delete();print('EXPORTED '+name,flush=True)
original.delete()
