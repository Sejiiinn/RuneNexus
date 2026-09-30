"""Normalize the standalone source and render the three approved presentation views.
Blender -b sniper-c-editable.blend --python render_views.py
"""
import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
ns={'__name__':'sniper_render'}
exec(compile((OUT/'build_sniper.py').read_text(),str(OUT/'build_sniper.py'),'exec'),ns)
scene=next(s for s in bpy.data.scenes if s.name.startswith('Sniper C — Vertical production'))
bpy.context.window.scene=scene
ref=bpy.data.images.load(str(OUT.parent/'receiver-variants/01-swept-wedge.png'),check_existing=True)
ref.name='APPROVED — 01 SWIFT swept wedge';ref.pack();ref.use_fake_user=True
ns['camera']('hero')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sniper-c-editable.blend'),compress=True)
for view in ['hero','top','rear','drone']:
    ns['camera'](view);bpy.ops.render.render(write_still=True)
