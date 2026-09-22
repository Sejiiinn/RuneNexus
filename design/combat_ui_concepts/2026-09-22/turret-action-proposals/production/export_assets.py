from gi.repository import Gimp, Gio
from pathlib import Path
root = Path('/Users/sejin/Documents/Codex/RuneNexus')
src = root / 'design/combat_ui_concepts/2026-09-22/turret-action-proposals/production'
out = src / 'rejected-v2'
out.mkdir(exist_ok=True)
Gimp.context_set_interpolation(Gimp.InterpolationType.CUBIC)
def export(image, path):
    proc = Gimp.get_pdb().lookup_procedure('file-png-export')
    cfg = proc.create_config()
    cfg.set_property('run-mode', Gimp.RunMode.NONINTERACTIVE)
    cfg.set_property('image', image)
    cfg.set_property('file', Gio.File.new_for_path(str(path)))
    result = proc.run(cfg)
    print(str(path), str(result.index(0)), image.get_width(), image.get_height(), flush=True)
    image.delete()
for name, rect, size in [
    ('upgrade',(80,5,980,291),(245,73)),
    ('traits',(1075,5,991,291),(248,73)),
    ('sell',(90,298,254,238),(64,60)),
    ('tab_active',(14,538,1050,180),(263,45)),
    ('tab_idle',(1077,538,1051,180),(263,45)),
]:
    im=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(src/'frames-master.png')))
    x,y,w,h=rect
    im.crop(w,h,x,y)
    im.scale(*size)
    export(im,out/(name+'.png'))
im=Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,Gio.File.new_for_path(str(src/'traits-master.png')))
im.scale(256,256)
export(im,out/'traits-icon.png')
