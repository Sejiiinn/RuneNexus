"""Replay finishing on the independent design scene, never on game assets.
The caller chooses when/where to save or render. Original design remains backed up.
"""
import bpy
from pathlib import Path
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus/design/fire_tower_concepts/runic_3d')

def apply_finish(scene):
    if scene.name!='Rune Flame Turret — Design':
        raise ValueError('Open the standalone Rune Flame Turret design first.')
    for filename,entry in [('finish_geometry.py','apply_geometry_finish'),('finish_materials.py','apply_material_finish')]:
        ns={};exec(compile((ROOT/filename).read_text(),filename,'exec'),ns);ns[entry](scene)
    collection=bpy.data.collections['04 Flame Study']
    for obj in list(collection.objects):bpy.data.objects.remove(obj,do_unlink=True)
    ns={};exec(compile((ROOT/'finish_flames.py').read_text(),'finish_flames.py','exec'),ns)
    ns['build_finished_flames'](collection,scene.objects['turret_barrel'],(0,.276,.130),(0,-.68,0))
    bpy.data.lights['Large warm key'].energy=350
    bpy.data.lights['Large warm key'].color=(1,.91,.8)
    bpy.data.lights['Soft neutral fill'].energy=220
    bpy.data.lights['Bronze rim'].energy=160
    bpy.data.lights['Bronze rim'].color=(1,.85,.70)
    scene.view_settings.exposure=-.35
    ground=bpy.data.materials['Studio | desaturated forest'];ground.node_tree.nodes.clear()
    bsdf=ground.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Base Color'].default_value=(.020,.050,.039,1)
    bsdf.inputs['Roughness'].default_value=.92
    output=ground.node_tree.nodes.new('ShaderNodeOutputMaterial')
    ground.node_tree.links.new(bsdf.outputs[0],output.inputs['Surface'])
    return {'finished':True,'game_export':False}
