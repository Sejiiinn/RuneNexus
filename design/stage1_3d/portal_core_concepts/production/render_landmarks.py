"""내보낸 게임 GLB 자체의 형태·공용 바닥 배치 검수 렌더."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/images/stage1_3d/environment/landmarks.glb'))
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1400
scene.render.resolution_y=950
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=True
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
world=bpy.data.worlds.new('Soft studio')
world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.20,.22,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.55
scene.world=world
for loc,power,size in [((-3,-4,6),480,4),((4,1,4),340,3),((0,4,5),380,3)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    light=bpy.context.object
    light.data.energy=power
    light.data.size=size
    light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
# 좁은 면광원 반사로 유리의 실제 하이라이트 검수. 출력 GLB에는 포함하지 않음.
bpy.ops.object.light_add(type='AREA',location=(3,-4,.6))
strip=bpy.context.object
strip.data.energy=260
strip.data.shape='RECTANGLE'
strip.data.size=.35
strip.data.size_y=3
strip.rotation_euler=(Vector((.65,0,.72))-strip.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(1.7,-4.8,6.2))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,.22))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=2.7
scene.camera=camera
roots={name:bpy.data.objects[name] for name in ('portal','core')}
roots['portal'].location.x=-.65
roots['core'].location.x=.65
scene.render.filepath=str(HERE/'models-a.png')
bpy.ops.render.render(write_still=True)
# 런타임 단위 타일 세 종류에 같은 모델을 복제. 타일은 출력 에셋에 포함되지 않음.
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/images/stage1_3d/environment/terrain.glb'))
terrain_roots=[o for o in scene.objects if o.parent is None and o.name not in ('portal','core') and o.type not in ('CAMERA','LIGHT')]
tiles={name:bpy.data.objects[name] for name in ('path_tile','build_tile','blocked_tile')}
for root in terrain_roots:
    root.hide_render=True
    for child in root.children_recursive:
        child.hide_render=True
for root in roots.values():
    root.hide_render=True
    for child in root.children_recursive:
        child.hide_render=True


def clone_tree(source,offset,parent=None):
    obj=source.copy()
    scene.collection.objects.link(obj)
    obj.hide_render=False
    obj.parent=parent
    if parent is None:
        obj.location=offset
    for child in source.children:
        clone_tree(child,offset,obj)
    return obj


for col,tile in enumerate(tiles.values()):
    for row,name in enumerate(('portal','core')):
        pos=Vector(((col-1)*1.2,(.5-row)*1.45,0))
        clone_tree(tile,pos)
        clone_tree(roots[name],pos)
camera.location=(1.3,-5.8,8.8)
camera.rotation_euler=(Vector((0,0,.10))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=4.45
scene.render.film_transparent=False
scene.render.resolution_x=1400
scene.render.resolution_y=1200
scene.render.filepath=str(HERE/'tile-compatibility-a.png')
bpy.ops.render.render(write_still=True)
print('LANDMARK_PREVIEWS_DONE')
