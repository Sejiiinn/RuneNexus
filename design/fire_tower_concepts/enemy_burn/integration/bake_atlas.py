"""Run through Blender MCP with approved enemy-burn-v3.blend loaded."""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path('/Users/sejin/Documents/Codex/RuneNexus')
OUT = ROOT / 'assets/images/stage1_3d/effects/enemy_burn'
DESIGN = ROOT / 'design/fire_tower_concepts/enemy_burn/integration'
source = bpy.context.scene
rng = random.Random(683)
data = {'version': 1, 'fps': 24, 'coordinate_system': 'Godot: Blender x,z,-y',
        'atlas_columns': 4, 'atlas_rows': 4, 'atlas_frame_count': 16,
        'atlas_size_multiplier': 1.25, 'atlas_cube_size': .22,
        'atlas_cell_world_size': .275, 'atlas_noise_w_start': .033,
        'atlas_noise_w_step': 96*.033/16, 'atlas_noise_scale': 3.4,
        'atlas_exposure': -.6, 'atlas_blend': 'additive_rgb_black_background',
        'atlas_order': 'row-major, top-left first', 'enemies': {}}
enemies = list(bpy.data.collections['01 Original enemies'].objects)
with bpy.data.libraries.load(str(ROOT/'design/stage1_3d/enemies/chapter-one-enemies-refined.blend'), link=False) as (src,dst):
    dst.objects = ['shielded','fast','boss']
for name,enemy in zip(['shielded','fast','boss'],dst.objects):
    enemy.name = name+' — attachment bake source'
    enemy.use_fake_user = True
    enemies.append(enemy)
for e in enemies:
    bv = BVHTree.FromPolygons([v.co for v in e.data.vertices],
        [tuple(p.vertices) for p in e.data.polygons if p.material_index == 0])
    h = max(v.co.z for v in e.data.vertices)
    particles = []
    for j in range(52):
        angle = rng.uniform(-math.pi, math.pi)
        if -2.15 < angle < -.98:
            angle += 1.4
        level = rng.uniform(.3, .8)
        hit, normal, _, _ = bv.find_nearest(Vector((.47*math.cos(angle), .44*math.sin(angle), h*level)))
        anchor = hit + normal*.012
        period = rng.choice([16,24,32])
        phase = rng.randrange(period)
        size = rng.uniform(.16,.26)
        drift = rng.uniform(-.10,.10)
        rise = rng.uniform(.18,.40)
        particles.append({'index':j, 'anchor':[anchor.x,anchor.z,-anchor.y],
            'period_frames':period, 'phase_frames':phase, 'size':size,
            'drift':drift, 'rise':rise})
    data['enemies'][e.name.split(' ')[0]] = {'height':h, 'particles':particles}
(OUT/'attachments.json').write_text(json.dumps(data,indent=2)+'\n')

s = bpy.data.scenes.new('Enemy burn V3 atlas bake')
bpy.context.window.scene = s
s.render.engine = 'BLENDER_EEVEE'
s.eevee.taa_render_samples = 128
s.eevee.volumetric_samples = 128
s.eevee.volumetric_tile_size = '2'
s.eevee.use_volumetric_shadows = False
s.render.resolution_x = s.render.resolution_y = 512
s.render.resolution_percentage = 100
s.render.image_settings.file_format = 'PNG'
s.render.image_settings.color_mode = 'RGBA'
s.render.film_transparent = False
s.view_settings.view_transform = 'Standard'
s.view_settings.look = 'None'
s.view_settings.exposure = source.view_settings.exposure
s.world = bpy.data.worlds.new('Black additive bake')
s.world.use_nodes = True
s.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(0,0,0,1)
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0
original = bpy.data.materials['V3 short lived turbulent fire']
for i in range(16):
    material = original.copy()
    material.name = 'V3 atlas frame %02d'%i
    material.node_tree.animation_data_clear()
    for node in material.node_tree.nodes:
        if node.type == 'TEX_NOISE':
            node.inputs['W'].default_value = .033 + (96*.033)*i/16
    bpy.ops.mesh.primitive_cube_add(size=.22, location=((i%4-1.5)*.275,0,(1.5-i//4)*.275))
    parcel = bpy.context.object
    parcel.name = 'Original V3 volume sample %02d'%i
    parcel.data.materials.append(material)
camera_data = bpy.data.cameras.new('Atlas orthographic camera')
camera = bpy.data.objects.new('Atlas camera',camera_data)
s.collection.objects.link(camera)
camera.location = (0,-3,0)
camera.rotation_euler = (Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 1.1
s.camera = camera
s.render.filepath = str(OUT/'flame_atlas.png')
text = bpy.data.texts.new('bake_atlas.py')
text.write((DESIGN/'bake_atlas.py').read_text())
bpy.ops.wm.save_as_mainfile(filepath=str(DESIGN/'enemy-burn-v3-atlas.blend'))
def render():
    bpy.ops.render.render(write_still=True)
    return None
bpy.app.timers.register(render, first_interval=.5)
