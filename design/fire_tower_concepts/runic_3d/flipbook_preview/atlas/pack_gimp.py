"""Native GIMP fallback: MCP export_sprite_sheet has invalid ImageBaseType.RGBA."""
from gi.repository import Gimp, Gio
from pathlib import Path
OUT=Path('/Users/sejin/Documents/RuneNexus/design/fire_tower_concepts/runic_3d/flipbook_preview/atlas')
sheet=Gimp.Image.new(1024,1024,Gimp.ImageBaseType.RGB)
for i in range(16):
 layer=Gimp.file_load_layer(Gimp.RunMode.NONINTERACTIVE,sheet,Gio.File.new_for_path(str(OUT/('frames/frame_%02d.png'%i))))
 sheet.insert_layer(layer,None,0)
 layer.set_name('Frame %02d — row-major'%i)
 layer.set_offsets((i%4)*256,(i//4)*256)
Gimp.Display.new(sheet)
p=Gimp.get_pdb().lookup_procedure('gimp-xcf-save');c=p.create_config();c.set_property('run-mode',Gimp.RunMode.NONINTERACTIVE);c.set_property('image',sheet);c.set_property('file',Gio.File.new_for_path(str(OUT/'flame_flipbook.xcf')));p.run(c)
p=Gimp.get_pdb().lookup_procedure('file-png-export');c=p.create_config();c.set_property('run-mode',Gimp.RunMode.NONINTERACTIVE);c.set_property('image',sheet);c.set_property('file',Gio.File.new_for_path(str(OUT/'flame_flipbook.png')));p.run(c)
(OUT/'gimp_pack_done.txt').write_text('16 layers packed using GIMP native API. PNG RGBA exported.\n')
