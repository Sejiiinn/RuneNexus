"""편집 원본의 부품을 보존하고 런타임 복사본만 병합·GLB 출력."""
import bpy
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
if not bpy.app.background:
    raise RuntimeError('독립 Blender background 프로세스 전용입니다.')
if Path(bpy.data.filepath) != HERE/'rune-landmarks.blend':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'rune-landmarks.blend'))

bpy.context.window.scene = bpy.data.scenes['RuneLandmarks']
# 부품을 공유하는 검수 Scene이 병합 전 객체를 붙잡지 않도록 출력 복사본에서만 제거.
for source_view in list(bpy.data.scenes):
    if source_view != bpy.context.scene:
        bpy.data.scenes.remove(source_view)


def join_parts(objects, name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    objects[0].name=name
    return objects[0]


crystal=bpy.data.objects['core_crystal']
join_parts([crystal]+list(crystal.children_recursive),'core_crystal')
# Godot 기본 glTF importer가 생략하는 유리 속성만 원본 BSDF에서 전달.
glass=bpy.data.materials['core_crystal_facets'].node_tree.nodes.get('Principled BSDF')
crystal['glass_transmission']=float(glass.inputs['Transmission Weight'].default_value)
crystal['glass_ior']=float(glass.inputs['IOR'].default_value)
for root_name in ('portal','core'):
    root=bpy.data.objects[root_name]
    groups={}
    for obj in list(root.children):
        if obj.type=='MESH' and obj.name not in ('portal_vortex','core_crystal'):
            groups.setdefault(obj.data.materials[0].name,[]).append(obj)
    for mat,objects in groups.items():
        join_parts(objects,root_name+'_'+mat)
bpy.ops.object.select_all(action='DESELECT')
report={}
for name in ('portal','core'):
    root=bpy.data.objects[name]
    root.select_set(True)
    points=[]
    triangles=0
    for obj in root.children_recursive:
        obj.select_set(True)
        if obj.type=='MESH':
            obj.data.calc_loop_triangles()
            triangles+=len(obj.data.loop_triangles)
            points.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
    report[name]={
        'bounds_blender_z_up':[[min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]],
        'triangles':triangles,
        'meshes':len([o for o in root.children_recursive if o.type=='MESH']),
    }
    assert max(abs(p.x) for p in points)<.49 and max(abs(p.y) for p in points)<.49,name
    assert min(p.z for p in points)>-.001,name
asset=ROOT/'assets/images/stage1_3d/environment/landmarks.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,
                          export_materials='EXPORT',export_cameras=False,export_lights=False,export_extras=True)
report['bytes']=asset.stat().st_size
report['coordinates']='glTF +Y up, XZ plane, tile center origin, 1 unit tile, no terrain'
(HERE/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('LANDMARKS_EXPORTED',json.dumps(report))
