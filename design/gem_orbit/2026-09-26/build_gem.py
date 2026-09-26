"""Create the faceted satellite gem in a separate scene, preserving the open file."""
import bpy
import math
from pathlib import Path
ROOT = Path('/Users/sejin/Documents/Codex/RuneNexus')
OUT = ROOT / 'design/gem_orbit/2026-09-26'
TARGET = ROOT / 'assets/images/stage1_3d/effects/gem_orbit/gem.glb'
previous = bpy.context.window.scene
scene = bpy.data.scenes.new('RuneNexus Satellite Gem')
try:
    bpy.context.window.scene = scene
    # +X is the moving head; -X is the trailing attachment direction.
    verts = [(.5, 0, 0), (-.5, 0, 0)]
    for x, r in [(.12,.26),(-.16,.30)]:
        for i in range(6):
            a = math.tau * i/6
            verts.append((x, math.cos(a)*r, math.sin(a)*r))
    faces = []
    for i in range(6):
        n=(i+1)%6
        faces.extend([(0,2+i,2+n), (2+i,8+i,8+n), (2+i,8+n,2+n), (1,8+n,8+i)])
    mesh=bpy.data.meshes.new('SatelliteGem_facets')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj=bpy.data.objects.new('SatelliteGem',mesh)
    scene.collection.objects.link(obj)
    mat=bpy.data.materials.new('SatelliteGem_white_tintable')
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=(.85,.95,1,1)
    bsdf.inputs['Metallic'].default_value=.18
    bsdf.inputs['Roughness'].default_value=.22
    mesh.materials.append(mat)
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.export_scene.gltf(filepath=str(TARGET),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    bpy.data.libraries.write(str(OUT/'satellite-gem.blend'),{scene},fake_user=True)
    print('GEM_EXPORTED',len(verts),len(faces),TARGET.stat().st_size)
finally:
    bpy.context.window.scene=previous
