"""Export the saved editable stage 2~5 Blender scenes without rebuilding placements."""
from pathlib import Path
import bpy
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]

def export_stage(scene,stage):
    old_scene=bpy.context.window.scene
    root=next(o for o in scene.objects if o.name==f'chapter_stage{stage}_dressing')
    # Preserve all source objects; temporary export nodes only.
    exp=bpy.data.scenes.new('Dressing Export (temporary)'); bpy.context.window.scene=exp
    renamed=[]
    for name in ['stage1_dressing','stage1_dressing_foliage','stage1_dressing_rocks']:
        old=bpy.data.objects.get(name)
        if old: renamed.append((old,name)); old.name=name+'_preserved'
    er=bpy.data.objects.new('stage1_dressing',None); exp.collection.objects.link(er)
    for k,v in root.items(): er[k]=v
    triangle_count=0
    for group in ['foliage','rocks']:
        verts=[]; faces=[]; colors=[]; wind=[]; occupancy=[]; material=None
        for obj in root.children:
            if obj.get('dressingGroup')!=group: continue
            m=obj.data; offset=len(verts); verts.extend(tuple(v.co) for v in m.vertices)
            faces.extend(tuple(i+offset for i in f.vertices) for f in m.polygons)
            colors.extend(tuple(x.color) for x in m.color_attributes['Color'].data)
            wind.extend(tuple(x.uv) for x in m.uv_layers['Wind'].data)
            occupancy.extend(tuple(x.uv) for x in m.uv_layers['Occupancy'].data)
            material=m.materials[0]
        mesh=bpy.data.meshes.new('stage1_dressing_'+group); mesh.from_pydata(verts,[],faces); mesh.materials.append(material)
        color=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT'); mesh.color_attributes.active_color=color
        for x,v in zip(color.data,colors): x.color=v
        for name,values in [('Wind',wind),('Occupancy',occupancy)]:
            uv=mesh.uv_layers.new(name=name)
            for x,v in zip(uv.data,values): x.uv=v
        for face in mesh.polygons: face.use_smooth=group=='foliage'
        mesh.update(); mesh.calc_loop_triangles(); triangle_count+=len(mesh.loop_triangles)
        obj=bpy.data.objects.new('stage1_dressing_'+group,mesh); exp.collection.objects.link(obj); obj.parent=er
    target=ROOT/f'assets/images/stage1_3d/environment/dressing_stage{stage}.glb'
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_materials='EXPORT',export_extras=True,export_cameras=False,export_lights=False,export_animations=False,export_morph=False)
    for obj in list(exp.objects):
        mesh=obj.data if obj.type=='MESH' else None
        bpy.data.objects.remove(obj,do_unlink=True)
        if mesh: bpy.data.meshes.remove(mesh)
    bpy.context.window.scene=old_scene; bpy.data.scenes.remove(exp)
    for obj,name in renamed: obj.name=name
    return triangle_count

if __name__=='__main__':
    for stage in range(2,6):
        scene=bpy.data.scenes.get(f'Chapter1 Stage {stage} Environment')
        if scene is None: raise RuntimeError('Open chapter1-dressing.blend before export')
        print('EXPORTED',stage,export_stage(scene,stage))
