"""Export approved curved flame tongues with native-material UV/vertex masks."""
import bpy
from pathlib import Path
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
P=ROOT/'design/fire_tower_concepts/runic_3d'
def export():
    ns={};exec(compile((P/'finish_flames.py').read_text(),'finish_flames.py','exec'),ns)
    s=bpy.data.scenes.new('Runic Native Flame Meshes');bpy.context.window.scene=s
    mat=bpy.data.materials.new('Native flame vertex mask');mat.use_nodes=True
    attr=mat.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='Flame Mask'
    bs=mat.node_tree.nodes.get('Principled BSDF')
    mat.node_tree.links.new(attr.outputs['Color'],bs.inputs['Base Color'])
    mat.node_tree.links.new(attr.outputs['Alpha'],bs.inputs['Alpha'])
    for name,width,bend,phase in [('fire_tongue_outer',.40,.57,.2),('fire_tongue_core',.38,.49,.3),('fire_ember',.22,.35,.3)]:
        old=bpy.data.objects.get(name)
        if old:old.name=name+'__previous'
        o=ns['_tongue'](s.collection,None,name,(0,0,0),(0,0,1),1,width,bend,phase,mat)
        colors=o.data.color_attributes.new(name='Flame Mask',type='FLOAT_COLOR',domain='POINT')
        for v,c in zip(o.data.vertices,colors.data):
            t=max(0,min(1,v.co.z));c.color=(1,1,1,.8*(1-t*t))
        o.data.color_attributes.active_color=colors
        uv=o.data.uv_layers.new(name='Flame Flow UV')
        for poly in o.data.polygons:
            ids=list(poly.vertices);us=[(i%20)/20 if i<800 else .5 for i in ids]
            seam=max(us)-min(us)>.8
            for li,vi,u in zip(poly.loop_indices,ids,us):
                if seam and u<.1:u+=1
                uv.data[li].uv=(u,o.data.vertices[vi].co.z)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/images/stage1_3d/effects/runic_fire.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_cameras=False,export_lights=False,export_all_vertex_colors=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(P/'migration/runic-flame-native-meshes.blend'))
