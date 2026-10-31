"""Cannon explosion flipbook source: a Mantaflow fire/smoke burst rendered from the game camera angle.

Run in background:
  Blender -b --python design/effects/cannon_explosion_flipbook/build_sim.py -- --cache <dir> --out <dir> [--res 128] [--frames 72]
Reference: PoE2 Explosive Grenade (short white-yellow fireball, then a low grey dust ring with embers).
The .blend is saved next to this script so the sim can be edited and re-baked.
"""
import argparse
import math
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--cache", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--res", type=int, default=128)
    p.add_argument("--frames", type=int, default=72)
    p.add_argument("--samples", type=int, default=64)
    p.add_argument("--size", type=int, default=512)
    p.add_argument("--only", type=int, default=0)
    p.add_argument("--no-render", action="store_true")
    return p.parse_args(argv)


def keyframe_scale(obj, keys):
    for frame, value in keys:
        obj.scale = (value, value, value)
        obj.keyframe_insert("scale", frame=frame)
    for fc in obj.animation_data.action.fcurves if hasattr(obj.animation_data.action, "fcurves") else []:
        for kp in fc.keyframe_points:
            kp.interpolation = "CONSTANT"


def flow(obj, kind, **values):
    mod = obj.modifiers.new("Fluid", "FLUID")
    mod.fluid_type = "FLOW"
    s = mod.flow_settings
    s.flow_type = kind
    s.flow_behavior = "INFLOW"
    s.flow_source = "MESH"
    s.surface_distance = values.pop("surface", 1.0)
    for key, value in values.items():
        setattr(s, key, value)
    obj.hide_render = True
    return s


VOLUME_BOUNCES = 1   # 2 lit the dust into a flat bright disc; 1 keeps shaded folds
GLOW_KEYS = ((1, 40.0), (9, 30.0), (14, 14.0), (19, 7.0), (24, 7.0), (30, 9.0))
# Large soot clumps inside the burning fireball: none during the flash, about 25-35 % of it at 0.12 s, about half at 0.27 s,
# so the fire breaks up into scarlet gaps between soot instead of fading out as one veil.
CLUMP_KEYS = ((1, -0.6), (7, -0.6), (8, -0.02), (17, 0.05), (27, 0.1))


def domain_material(domain, glow_keys=GLOW_KEYS, thin_fire=0.85, clump_keys=CLUMP_KEYS):
    mat = bpy.data.materials.new("ExplosionVolume")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    dens = nt.nodes.new("ShaderNodeAttribute"); dens.attribute_name = "density"
    flame = nt.nodes.new("ShaderNodeAttribute"); flame.attribute_name = "flame"
    dmul = nt.nodes.new("ShaderNodeMath"); dmul.operation = "MULTIPLY"; dmul.inputs[1].default_value = 22.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    # Flame value -> emission colour: deep red at the cooling edge, orange body, pale yellow-white core.
    cr = ramp.color_ramp
    # Hue stays between scarlet and yellow; cooling flame turns charcoal instead of fading to pink.
    cr.elements[0].position = 0.0; cr.elements[0].color = (0.0, 0.0, 0.0, 1)
    cr.elements[1].position = 1.0; cr.elements[1].color = (1.0, 0.9, 0.72, 1)
    for pos, c in ((0.1, (0.3, 0.035, 0.006, 1)), (0.28, (0.72, 0.13, 0.015, 1)), (0.5, (1.0, 0.36, 0.04, 1)),
                   (0.75, (1.0, 0.62, 0.16, 1))):
        e = cr.elements.new(pos); e.color = c
    # Emission strength = flame * glow(frame): overexposed white-yellow for the first 0.15 s (like the reference), then
    # low enough that the Standard view shows orange, scarlet and charcoal instead of clipping everything to lemon.
    emul = nt.nodes.new("ShaderNodeMath"); emul.operation = "MULTIPLY"
    for frame, glow in glow_keys:
        emul.inputs[1].default_value = glow
        emul.inputs[1].keyframe_insert("default_value", frame=frame)
    # Soot clump mask: object-space noise with clumps about 0.5 m across, thresholded by a keyframed offset.
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 14.0; noise.inputs["Detail"].default_value = 1.0
    shift = nt.nodes.new("ShaderNodeMath"); shift.operation = "ADD"
    for frame, offset in clump_keys:
        shift.inputs[1].default_value = offset
        shift.inputs[1].keyframe_insert("default_value", frame=frame)
    clump = nt.nodes.new("ShaderNodeMapRange"); clump.interpolation_type = "SMOOTHSTEP"
    clump.inputs["From Min"].default_value = 0.53; clump.inputs["From Max"].default_value = 0.6
    nt.links.new(noise.outputs["Fac"], shift.inputs[0]); nt.links.new(shift.outputs[0], clump.inputs["Value"])
    lit = nt.nodes.new("ShaderNodeMath"); lit.operation = "SUBTRACT"; lit.inputs[0].default_value = 1.0
    nt.links.new(clump.outputs["Result"], lit.inputs[1])
    # Burning regions are thinned so the fire is not veiled by its own smoke, except inside the soot clumps.
    burning = nt.nodes.new("ShaderNodeMath"); burning.operation = "MULTIPLY"
    nt.links.new(flame.outputs["Fac"], burning.inputs[0]); nt.links.new(lit.outputs[0], burning.inputs[1])
    thin = nt.nodes.new("ShaderNodeMath"); thin.operation = "MULTIPLY_ADD"
    thin.inputs[1].default_value = -thin_fire; thin.inputs[2].default_value = 1.0
    keep = nt.nodes.new("ShaderNodeMath"); keep.operation = "MULTIPLY"
    nt.links.new(burning.outputs[0], thin.inputs[0])
    nt.links.new(dens.outputs["Fac"], keep.inputs[0]); nt.links.new(thin.outputs[0], keep.inputs[1])
    nt.links.new(keep.outputs[0], dmul.inputs[0])
    nt.links.new(dmul.outputs[0], vol.inputs["Density"])
    # Hot smoke is black soot, cooled smoke is grey-brown dust (Mantaflow's own colour grid reads too dark).
    temp = nt.nodes.new("ShaderNodeAttribute"); temp.attribute_name = "temperature"
    soot = nt.nodes.new("ShaderNodeMapRange"); soot.interpolation_type = "SMOOTHSTEP"
    # Hot smoke stays charcoal a little longer so burnt smoke takes over the 0.30 s fire mass until about 0.45 s.
    soot.inputs["From Min"].default_value = 0.18; soot.inputs["From Max"].default_value = 0.7
    albedo = nt.nodes.new("ShaderNodeMix"); albedo.data_type = "RGBA"
    albedo.inputs["A"].default_value = (0.74, 0.69, 0.63, 1)   # warm grey-white: reads above most ground colours
    albedo.inputs["B"].default_value = (0.06, 0.05, 0.045, 1)
    nt.links.new(temp.outputs["Fac"], soot.inputs["Value"])
    # Clumps darken only where flame still burns; once it is out the smoke returns to dust grey (no black spots).
    alight = nt.nodes.new("ShaderNodeMapRange"); alight.interpolation_type = "SMOOTHSTEP"
    alight.inputs["From Min"].default_value = 0.005; alight.inputs["From Max"].default_value = 0.06
    nt.links.new(flame.outputs["Fac"], alight.inputs["Value"])
    clump_fire = nt.nodes.new("ShaderNodeMath"); clump_fire.operation = "MULTIPLY"
    nt.links.new(clump.outputs["Result"], clump_fire.inputs[0]); nt.links.new(alight.outputs["Result"], clump_fire.inputs[1])
    sooty = nt.nodes.new("ShaderNodeMath"); sooty.operation = "MAXIMUM"
    nt.links.new(soot.outputs["Result"], sooty.inputs[0]); nt.links.new(clump_fire.outputs[0], sooty.inputs[1])
    nt.links.new(sooty.outputs[0], albedo.inputs["Factor"])
    nt.links.new(albedo.outputs["Result"], vol.inputs["Color"])
    nt.links.new(flame.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], vol.inputs["Emission Color"])
    nt.links.new(burning.outputs[0], emul.inputs[0])
    nt.links.new(emul.outputs[0], vol.inputs["Emission Strength"])
    vol.inputs["Anisotropy"].default_value = 0.25
    nt.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    domain.data.materials.append(mat)


def build(a):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 60
    scene.frame_start, scene.frame_end = 1, a.frames

    # Domain: 7 x 7 x 5 m standing on the ground (z = 0 is the floor, a colliding border).
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 2.5))
    domain = bpy.context.object; domain.name = "Domain"; domain.scale = (7, 7, 5)
    mod = domain.modifiers.new("Fluid", "FLUID"); mod.fluid_type = "DOMAIN"
    d = mod.domain_settings
    d.domain_type = "GAS"
    d.resolution_max = a.res
    d.cache_directory = a.cache
    d.cache_type = "ALL"
    d.cache_frame_start, d.cache_frame_end = 1, a.frames
    d.use_adaptive_domain = True
    d.use_collision_border_bottom = True
    d.alpha = -0.15          # smoke weight: dust sinks a little
    d.beta = 2.2             # heat buoyancy: the fireball climbs
    d.vorticity = 0.45
    d.burning_rate = 0.85
    d.flame_smoke = 2.4       # burnt fuel leaves soot that takes over from the fireball
    d.flame_vorticity = 0.7
    d.flame_ignition = 1.25
    d.flame_max_temp = 3.0
    d.use_dissolve_smoke = True
    d.use_dissolve_smoke_log = True
    d.dissolve_speed = 140   # frames: the smoke carries the second half of the 1.1 s effect
    d.time_scale = 1.6       # a hot, fast blast rather than a floaty campfire
    # Noise upres breaks the grid-aligned petals of the low-res base sim into turbulent detail.
    d.use_noise = True
    d.noise_scale = 2
    d.noise_strength = 1.2
    domain_material(domain)

    # Burst: a fuel-rich core pushed outward for four frames.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.6, location=(0, 0, 0.6))
    burst = bpy.context.object; burst.name = "Burst"
    # Lumpy emitter: uneven normals give uneven blast lobes instead of a clean sphere with a cross artefact.
    bpy.ops.object.modifier_add(type="SUBSURF"); burst.modifiers[-1].levels = 1
    tex = bpy.data.textures.new("BurstNoise", "CLOUDS"); tex.noise_scale = 0.35
    disp = burst.modifiers.new("Lumps", "DISPLACE"); disp.texture = tex; disp.strength = 0.35
    flow(burst, "BOTH", fuel_amount=3.0, temperature=3.0, density=1.2, smoke_color=(0.2, 0.18, 0.17),
         use_initial_velocity=True, velocity_normal=16.0)
    keyframe_scale(burst, [(1, 1.0), (5, 0.001)])

    # Dust: a low ring that throws grey-brown dust outward along the ground.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.8, minor_radius=0.18, location=(0, 0, 0.15))
    dust = bpy.context.object; dust.name = "Dust"
    # Uneven ring: a perfect torus left a compass-drawn edge on the early dust skirt.
    bpy.ops.object.modifier_add(type="SUBSURF"); dust.modifiers[-1].levels = 1
    ring_tex = bpy.data.textures.new("DustNoise", "CLOUDS"); ring_tex.noise_scale = 0.4
    ring = dust.modifiers.new("Lumps", "DISPLACE"); ring.texture = ring_tex; ring.strength = 0.65
    flow(dust, "SMOKE", temperature=0.0, density=0.8,   # faint: the dust supports the fireball, it is not the subject
         smoke_color=(0.5, 0.45, 0.4),
         use_initial_velocity=True, velocity_normal=7.0)
    keyframe_scale(dust, [(1, 0.001), (2, 1.0), (6, 0.001)])

    # Game camera: about 63 degrees above the horizon, orthographic so the sheet works as a camera-facing card.
    elev = math.radians(63)
    bpy.ops.object.camera_add(location=(0, -12 * math.cos(elev), 1.0 + 12 * math.sin(elev)))
    cam = bpy.context.object; cam.name = "GameCamera"
    cam.rotation_euler = (math.radians(90) - elev, 0, 0)
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 5.5
    scene.camera = cam

    bpy.ops.object.light_add(type="SUN", location=(0, 0, 10))
    sun = bpy.context.object; sun.data.energy = 6.0
    sun.rotation_euler = (math.radians(35), math.radians(-30), math.radians(20))
    world = bpy.data.worlds.new("World"); scene.world = world
    world.use_nodes = True; world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6

    r = scene.render
    r.engine = "CYCLES"
    scene.cycles.device = "GPU"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "METAL"; prefs.get_devices()
    for dev in prefs.devices: dev.use = dev.type == "METAL"
    scene.cycles.samples = a.samples
    scene.cycles.use_denoising = True
    scene.cycles.volume_step_rate = 1.0
    scene.cycles.volume_bounces = VOLUME_BOUNCES   # without bounces dense dust renders darker than its own colour
    r.film_transparent = True
    r.resolution_x = r.resolution_y = a.size
    r.image_settings.file_format = "PNG"; r.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"   # AgX desaturated the fireball into dull apricot
    r.filepath = str(Path(a.out) / "f####")
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "cannon_explosion_sim.blend"))
    return domain


def main():
    a = args()
    domain = build(a)
    # Always bake: switching an existing bake to REPLAY frees its cache files (the bake is only about 2 minutes).
    with bpy.context.temp_override(object=domain, active_object=domain, selected_objects=[domain]):
        bpy.ops.fluid.bake_all()
    print("BAKE_DONE", flush=True)
    # Saved after the bake so render_frames.py can re-render material changes without simulating again.
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "cannon_explosion_sim.blend"))
    if a.no_render:
        return
    if a.only:
        bpy.context.scene.frame_start = bpy.context.scene.frame_end = a.only
    bpy.ops.render.render(animation=True)
    print("RENDER_DONE", flush=True)


if __name__ == "__main__":
    main()
