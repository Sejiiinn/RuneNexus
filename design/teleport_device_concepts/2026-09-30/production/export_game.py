"""Export approved geometry without rebuilding it; keep host terrain separate.

Blender --background --factory-startup --python export_game.py
The only authoring adjustment is the 0.0005 seam radius reduction needed to
keep evaluated geometry wholly inside its 1×1 footprint.
"""
import bpy, json, hashlib, shutil
from pathlib import Path
from mathutils import Matrix

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
SOURCE=HERE/'teleport-four-variants.blend'
OUT=ROOT/'assets/images/stage1_3d/teleport'
OUT.mkdir(parents=True,exist_ok=True)

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    before_hash=digest(SOURCE)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    authored=bpy.context.scene
    changed=[]
    for ob in authored.objects:
        if ob.type=='CURVE' and ob.name.endswith('/ bronze outer seam') and ob.data.bevel_depth>.0018:
            changed.append(ob.name)
            ob.data.bevel_depth=.0018
    if changed:
        backup=HERE/'_before-tile-boundary.blend'
        if not backup.exists():shutil.copy2(SOURCE,backup)
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    source_hash=digest(SOURCE)
    authored.frame_set(1)
    deps=bpy.context.evaluated_depsgraph_get()
    # Source bounds include evaluated curves and all moving meshes through a loop.
    source_bounds={}
    for name in ['BLUE IN','BLUE OUT','ORANGE IN','ORANGE OUT']:
        root=bpy.data.objects[name.replace(' ','_')]
        inverse=root.matrix_world.inverted()
        minimum=[1e9]*3;maximum=[-1e9]*3
        static=[o for o in root.children if o.type in {'MESH','CURVE'} and 'moving radial light' not in o.name]
        moving=[o for o in root.children if 'moving radial light' in o.name]
        def include(ob):
            evaluated=ob.evaluated_get(deps)
            data=bpy.data.meshes.new_from_object(evaluated,depsgraph=deps)
            transform=inverse@evaluated.matrix_world
            for v in data.vertices:
                p=transform@v.co
                for i in range(3):minimum[i]=min(minimum[i],p[i]);maximum[i]=max(maximum[i],p[i])
            bpy.data.meshes.remove(data)
        for ob in static:include(ob)
        for frame in range(1,98):
            authored.frame_set(frame)
            for ob in moving:include(ob)
        assert max(abs(minimum[0]),abs(maximum[0]),abs(minimum[1]),abs(maximum[1]))<=.500001
        source_bounds[name]={'min_xyz':minimum,'max_xyz':maximum,'frames_checked':[1,97]}
    authored.frame_set(1)
    target=bpy.data.scenes.new('Teleport Game Geometry')
    bpy.context.window.scene=target
    def clone(source,name,transform=None):
        data=bpy.data.meshes.new_from_object(source.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
        ob=bpy.data.objects.new(name,data);target.collection.objects.link(ob)
        ob.matrix_world=transform if transform is not None else Matrix.Identity(4)
        ob['source_object']=source.name
        return ob
    blue=bpy.data.collections['BLUE IN']
    root=bpy.data.objects['BLUE_IN']
    parts=[]
    for source in blue.objects:
        if source.type not in {'MESH','CURVE'} or any(t in source.name for t in ['stacked stone','editable 3D','moving radial']):continue
        parts.append(clone(source,'Frame component',root.matrix_world.inverted()@source.matrix_world))
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts:ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join();body=bpy.context.object;body.name='teleport_frame'
    for variant,name in [('BLUE IN','teleport_in_surface'),('BLUE OUT','teleport_out_surface')]:
        source=next(o for o in bpy.data.collections[variant].objects if 'editable 3D' in o.name)
        ob=clone(source,name)
        ob.data.materials.clear()
        mat=bpy.data.materials.new(name+'_runtime_shader_slot');mat.diffuse_color=(.004,.015,.05,1)
        ob.data.materials.append(mat)
    source=next(o for o in blue.objects if 'moving radial light' in o.name)
    particle=clone(source,'teleport_particle')
    source=next(o for o in bpy.data.collections['BLUE OUT'].objects if 'luminous emergence' in o.name)
    clone(source,'teleport_out_core',bpy.data.objects['BLUE_OUT'].matrix_world.inverted()@source.matrix_world)
    for o in target.objects:
        o.animation_data_clear()
        o['footprint_half_extent']=.5
    bpy.ops.object.select_all(action='SELECT')
    output=OUT/'teleport_device.glb'
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,use_active_scene=True,
        export_apply=True,export_normals=True,export_texcoords=True,export_tangents=True,
        export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'teleport-game-export.blend'))
    report={'source_before_sha256':before_hash,'source_sha256':source_hash,'seam_adjusted':changed,
        'seam_radius':.0018,'source_bounds':source_bounds,'glb_sha256':digest(output),'glb_bytes':output.stat().st_size,
        'source_stone_excluded':'Host chapter tile supplies side/bottom; center top only is cut at placement.',
        'effect_material':'Godot radial-flow shader; original shallow surface geometry and particle meshes retained.'}
    (HERE/'_game-export-checks.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2),flush=True)

if __name__=='__main__':main()
