"""Run with Blender --background --python this_file. Original GLBs are read-only."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'design/hud_turret_icons_fixed'
OUT=ROOT/'assets/images/ui/hud/turrets_3d'
KINDS=['arrow','cannon','magic','frost','sniper','lightning']
bpy.ops.wm.read_factory_settings(use_empty=True)
records={}
for kind in KINDS:
    scene=bpy.data.scenes.new('HUD_'+kind)
    bpy.context.window.scene=scene
    source=ROOT/'assets/images/stage1_3d/turrets'/f'{kind}.glb'
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(source))
    objects=list(set(bpy.data.objects)-before)
    # glTF importer converts +Y-up/+Z-forward to Blender +Z-up/-Y-forward.
    root=next(o for o in objects if o.name.split('.')[0]=='turret_root')
    head=next(o for o in objects if o.name.split('.')[0]=='turret_head')
    muzzle=next(o for o in objects if o.name.split('.')[0]=='muzzle')
    bpy.context.view_layer.update()
    # Contracted source forward, independently verified using physical muzzle horizontal displacement.
    forward=root.matrix_world.to_3x3() @ Vector((0,-1,0))
    heading=math.atan2(forward.x,-forward.y)
    normalize=Matrix.Rotation(-heading,4,'Z')
    root.matrix_world=normalize @ root.matrix_world
    bpy.context.view_layer.update()
    for o in objects:o.name=kind+'_'+o.name
    cam_data=bpy.data.cameras.new(kind+'_fixed_camera')
    camera=bpy.data.objects.new(kind+'_fixed_camera',cam_data)
    scene.collection.objects.link(camera)
    target=Vector((0,0,.40));camera.location=target+Vector((4,-4,5.1))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    cam_data.type='ORTHO';cam_data.ortho_scale=1.45;scene.camera=camera
    world=bpy.data.worlds.new(kind+'_studio');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.21,.26,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.55;scene.world=world
    for name,loc,power,size,color in [('key',(-3,-4,6),650,4,(1,.92,.8)),('fill',(4,-1,4),440,4,(.70,.85,1)),('rim',(1,4,5),750,3,(.68,.88,1))]:
        d=bpy.data.lights.new(kind+'_'+name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color
        o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
    scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100
    scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
    scene.render.filepath=str(OUT/f'{kind}.png')
    bpy.context.view_layer.update()
    origin=world_to_camera_view(scene,camera,Vector((0,0,.4)))
    endpoint=world_to_camera_view(scene,camera,Vector((0,-1,.4)))
    delta=Vector((endpoint.x-origin.x,-(endpoint.y-origin.y)));delta.normalize()
    physical=muzzle.matrix_world.translation-head.matrix_world.translation
    physical.z=0
    meshes=[o for o in objects if o.type=='MESH']
    coords=[world_to_camera_view(scene,camera,o.matrix_world@Vector(c)) for o in meshes for c in o.bound_box]
    records[kind]={'source':str(source.relative_to(ROOT)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_forward_blender':[0,-1,0],'whole_model_rotation_z_rad':-heading,'screen_forward_xy_down':list(delta),'screen_angle_deg':math.degrees(math.atan2(delta.y,delta.x)),'muzzle_horizontal_blender':list(physical),'bounds_uv':[min(c.x for c in coords),min(c.y for c in coords),max(c.x for c in coords),max(c.y for c in coords)],'camera_position':list(camera.location),'camera_target':list(target),'orthographic_scale':cam_data.ortho_scale}
    assert delta.x<0 and delta.y>0
    if physical.length>.01:assert abs(physical.normalized().x)<.025 and physical.y<0,(kind,physical)
    bpy.ops.render.render(write_still=True)
    print('HUD_RENDER_DONE',kind,flush=True)
bpy.context.window.scene=bpy.data.scenes['HUD_arrow']
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'fixed-camera-turret-icons.blend'))
(WORK/'direction-verification.json').write_text(json.dumps(records,indent=2))
print('HUD_ALL_DONE',flush=True)
