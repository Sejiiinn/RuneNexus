"""Editable chapter-two stone tiles and baked native-PBR surface data.

Run in a separate background Blender. --export-only exports saved manual edits.
"""
import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector, noise

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCE = HERE / "chapter2-tiles.blend"
TARGET = ROOT / "assets/images/stage1_3d/environment/chapter2_tiles.glb"
RNG = random.Random(6026)


def save_image(image):
    image.filepath_raw = str(HERE / "maps" / (image.name + ".png"))
    image.file_format = "PNG"
    image.save()
    image.pack()


def bake_stone(name, dark, light):
    """Bake material channels on a UV plane; geometry supplies cracks and bevels."""
    bpy.ops.mesh.primitive_plane_add(size=1)
    plane = bpy.context.object
    material = bpy.data.materials.new("Source procedural " + name)
    material.use_nodes = True
    material.use_fake_user = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(bsdf.outputs[0], output.inputs["Surface"])
    uv = nodes.new("ShaderNodeTexCoord")
    broad = nodes.new("ShaderNodeTexNoise")
    broad.inputs["Scale"].default_value = 9
    broad.inputs["Detail"].default_value = 5
    broad.inputs["Roughness"].default_value = .78
    links.new(uv.outputs["UV"], broad.inputs["Vector"])
    grain = nodes.new("ShaderNodeTexNoise")
    grain.inputs["Scale"].default_value = 115
    grain.inputs["Detail"].default_value = 5.5
    links.new(uv.outputs["UV"], grain.inputs["Vector"])
    veins = nodes.new("ShaderNodeTexVoronoi")
    veins.feature = "DISTANCE_TO_EDGE"
    veins.inputs["Scale"].default_value = 18
    links.new(uv.outputs["UV"], veins.inputs["Vector"])
    # Reuse the project's authored mineral surface within one broad rock face.
    # Blender bakes the recolored physical surface, rather than painting lighting.
    coords=nodes.new("ShaderNodeVectorMath");coords.operation="MULTIPLY_ADD"
    links.new(uv.outputs["UV"],coords.inputs[0])
    coords.inputs[1].default_value=(.24,.24,.24)
    coords.inputs[2].default_value=(.51,.54,0)
    rock=nodes.new("ShaderNodeTexImage")
    rock.image=bpy.data.images.load(str(ROOT/"design/stage1_3d/environment/approved_textures/C1_natural_rock_faces_basecolor.png"),check_existing=True)
    rock.image.pack();links.new(coords.outputs[0],rock.inputs["Vector"])
    gray=nodes.new("ShaderNodeRGBToBW");links.new(rock.outputs["Color"],gray.inputs[0])
    stone_normal_tex=nodes.new("ShaderNodeTexImage")
    stone_normal_tex.image=bpy.data.images.load(str(ROOT/"design/stage1_3d/environment/approved_textures/C1_natural_rock_faces_normal.png"),check_existing=True)
    stone_normal_tex.image.colorspace_settings.name="Non-Color";stone_normal_tex.image.pack()
    links.new(coords.outputs[0],stone_normal_tex.inputs["Vector"])
    stone_normal=nodes.new("ShaderNodeNormalMap")
    stone_normal.inputs["Strength"].default_value = .32
    links.new(stone_normal_tex.outputs["Color"],stone_normal.inputs["Color"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = .03
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].position = .38
    ramp.color_ramp.elements[1].color = (*light, 1)
    links.new(gray.outputs[0], ramp.inputs["Fac"])
    color = nodes.new("ShaderNodeMixRGB")
    color.blend_type = "MULTIPLY"
    color.inputs[0].default_value = .10
    links.new(ramp.outputs["Color"], color.inputs[1])
    flecks = nodes.new("ShaderNodeValToRGB")
    flecks.color_ramp.elements[0].position = .30
    flecks.color_ramp.elements[0].color = (.25,.25,.25,1)
    flecks.color_ramp.elements[1].position = .66
    flecks.color_ramp.elements[1].color = (1.15,1.15,1.15,1)
    links.new(grain.outputs["Fac"], flecks.inputs["Fac"])
    links.new(flecks.outputs["Color"], color.inputs[2])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
    rough = nodes.new("ShaderNodeMapRange")
    rough.inputs["To Min"].default_value = .48
    rough.inputs["To Max"].default_value = .77
    links.new(broad.outputs["Fac"], rough.inputs["Value"])
    links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    grain_height = nodes.new("ShaderNodeMath")
    grain_height.operation = "MULTIPLY_ADD"
    links.new(grain.outputs["Fac"], grain_height.inputs[0])
    grain_height.inputs[1].default_value = .75
    links.new(broad.outputs["Fac"], grain_height.inputs[2])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = .28
    bump.inputs["Distance"].default_value = .005
    links.new(stone_normal.outputs["Normal"],bump.inputs["Normal"])
    links.new(grain_height.outputs[0], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    plane.data.materials.append(material)
    emission = nodes.new("ShaderNodeEmission")
    target = nodes.new("ShaderNodeTexImage")
    images = {}
    for channel in ("basecolor", "normal", "roughness"):
        im = bpy.data.images.new(name + "_" + channel, width=1024 if channel != "roughness" else 512,
                                 height=1024 if channel != "roughness" else 512, alpha=False)
        im.colorspace_settings.name = "sRGB" if channel == "basecolor" else "Non-Color"
        target.image = im
        nodes.active = target
        if channel == "normal":
            links.new(bsdf.outputs[0], output.inputs["Surface"])
            bpy.ops.object.bake(type="NORMAL", margin=8)
        else:
            links.new(emission.outputs[0], output.inputs["Surface"])
            links.new(color.outputs["Color"] if channel == "basecolor" else rough.outputs["Result"], emission.inputs["Color"])
            bpy.ops.object.bake(type="EMIT", margin=8)
        save_image(im)
        images[channel] = im
        print("BAKED", name, channel, flush=True)
    links.new(bsdf.outputs[0], output.inputs["Surface"])
    bpy.data.objects.remove(plane, do_unlink=True)
    runtime = bpy.data.materials.new(name)
    runtime.use_nodes = True
    rn, rl = runtime.node_tree.nodes, runtime.node_tree.links
    p = rn.get("Principled BSDF")
    p.inputs["Metallic"].default_value = 0
    for channel, im in images.items():
        tex = rn.new("ShaderNodeTexImage")
        tex.image = im
        tex.label = "Blender baked " + channel
        if channel == "normal":
            normal = rn.new("ShaderNodeNormalMap")
            rl.new(tex.outputs["Color"], normal.inputs["Color"])
            rl.new(normal.outputs["Normal"], p.inputs["Normal"])
        else:
            rl.new(tex.outputs["Color"], p.inputs["Base Color" if channel == "basecolor" else "Roughness"])
    return runtime


def empty(name):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj["tileFootprint"] = [1.0, 1.0]
    obj["surfaceHeightGodot"] = 0.0
    return obj


def planar_uv(obj):
    uv = obj.data.uv_layers.new(name="UVMap")
    shift = RNG.random() * .8
    for poly in obj.data.polygons:
        n = poly.normal
        for li in poly.loop_indices:
            p = obj.data.vertices[obj.data.loops[li].vertex_index].co
            if abs(n.z) > .5:
                xy = (p.x + .5, p.y + .5)
            elif abs(n.x) > abs(n.y):
                xy = (p.y + .5, p.z + .5)
            else:
                xy = (p.x + .5, p.z + .5)
            uv.data[li].uv = (xy[0] + shift, xy[1] + shift)


def stone(name, poly, bottom, top, material, parent, bevel=.008):
    """Unequal eight-ish-sided stone with fractured bands, not a plain box."""
    # Fractured edge points form irregular nicks, not a uniformly perfect bevel.
    detailed = []
    pcx = sum(p[0] for p in poly)/len(poly)
    pcy = sum(p[1] for p in poly)/len(poly)
    for i,p in enumerate(poly):
        q=poly[(i+1)%len(poly)]
        detailed.append(p)
        distance=math.hypot(q[0]-p[0],q[1]-p[1])
        if distance > .045:
            for t in (.30,.56,.73):
                x=p[0]+(q[0]-p[0])*t;y=p[1]+(q[1]-p[1])*t
                depth=RNG.uniform(.002,.009)
                toward=Vector((pcx-x,pcy-y)).normalized()
                detailed.append((x+toward.x*depth,y+toward.y*depth))
    poly=detailed
    count = len(poly)
    cx = sum(p[0] for p in poly) / count
    cy = sum(p[1] for p in poly) / count
    bevel_height=min(.015,(top-bottom)*.18)
    levels = [(bottom, .98), (bottom + (top-bottom)*.18, 1), (top-bevel_height, 1), (top, .98)]
    verts = []
    for zi, (z, scale) in enumerate(levels):
        for x, y in poly:
            jitter = RNG.uniform(-.002, .002) if zi in (1, 2) else 0
            height_jitter = RNG.uniform(-.004,.001) if zi==3 else 0
            verts.append((cx+(x-cx)*scale+jitter, cy+(y-cy)*scale+jitter, z+height_jitter))
    faces = [tuple(reversed(range(count)))]
    for row in range(len(levels)-1):
        for i in range(count):
            j = (i+1) % count
            faces.append((row*count+i, row*count+j, (row+1)*count+j, (row+1)*count+i))
    faces.append(tuple((len(levels)-1)*count+i for i in range(count)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    mesh.materials.append(material)
    planar_uv(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mod = obj.modifiers.new("Weathered edge bevel", "BEVEL")
    mod.width = bevel
    mod.segments = 1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)
    return obj


def rectangle(x0, y0, x1, y1, clip=.015):
    return [(x0+clip,y0),(x1-clip,y0),(x1,y0+clip),(x1,y1-clip),
            (x1-clip,y1),(x0+clip,y1),(x0,y1-clip),(x0,y0+clip)]


def clipped(poly, a, b):
    result = []
    def distance(p):
        return (p[0]-(a[0]+b[0])/2)*(b[0]-a[0]) + (p[1]-(a[1]+b[1])/2)*(b[1]-a[1])
    for i, p in enumerate(poly):
        q = poly[(i+1) % len(poly)]
        dp, dq = distance(p), distance(q)
        if dp <= 0:
            result.append(p)
        if (dp < 0) != (dq < 0):
            t = dp / (dp-dq)
            result.append((p[0]+(q[0]-p[0])*t, p[1]+(q[1]-p[1])*t))
    return result


def paving(parent, material, lo, hi, seeds, gap=.004):
    result=[]
    for index, a in enumerate(seeds):
        poly = [(lo,lo),(hi,lo),(hi,hi),(lo,hi)]
        for b in seeds:
            if b != a:
                poly = clipped(poly, a, b)
        if len(poly) < 3:
            continue
        cx = sum(p[0] for p in poly)/len(poly)
        cy = sum(p[1] for p in poly)/len(poly)
        inset = []
        for x, y in poly:
            d = max(.001, math.hypot(x-cx, y-cy))
            inset.append((x+(cx-x)*gap/d, y+(cy-y)*gap/d))
        result.append(stone("paving_%02d" % index, inset, -.095, RNG.uniform(-.002, .002), material, parent, .002))
    return result


def foundation(parent, material):
    # Staggered masonry in three bands makes real seams and chipped side silhouettes.
    for row in range(3):
        z = -.445 + row*.118
        for side in range(4):
            widths = [-.493, -.26+RNG.uniform(-.03,.03), .06+RNG.uniform(-.03,.03), .29, .493]
            if row % 2:
                widths = [-.493,-.36,-.07,.20,.493]
            for j in range(4):
                a, b = widths[j]+.004, widths[j+1]-.004
                poly = rectangle(a, -.490, b, -.382, .009)
                angle = side*math.pi/2
                poly = [(x*math.cos(angle)-y*math.sin(angle), x*math.sin(angle)+y*math.cos(angle)) for x,y in poly]
                stone("side_%d_%d_%d" % (row, side, j),poly,z,z+.112,material,parent,.004)
    # Dark solid grout volume behind masonry; prevents holes through the side seams.
    stone("inner_foundation", rectangle(-.478,-.478,.478,.478,.014),-.45,-.085,material,parent,.004)


def create_tiles(mats):
    path = empty("path_tile")
    foundation(path,mats["side"])
    seeds = []
    for row in range(3):
        for col in range(3):
            seeds.append((-.35+col*.34+RNG.uniform(-.08,.08), -.35+row*.34+RNG.uniform(-.07,.07)))
    paving(path,mats["path"],-.495,.495,seeds,.004)
    build = empty("build_tile")
    foundation(build,mats["side"])
    # Broad broken slab pieces keep the center empty and preserve shallow real cracks.
    slabs=paving(build,mats["build"],-.402,.402,[(-.28,-.31),(.23,-.26),(-.18,.07),(.31,.14),(-.19,.33)],.002)
    # Slightly angled diamond-shaped cutter makes a recess, preserving a flat empty center.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0,0,.0005))
    cut = bpy.context.object
    cut.name = "temporary diamond engraving"
    cut.scale = (.27,.27,.012)
    cut.rotation_euler.z = math.pi/4
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for slab in slabs:
        bpy.context.view_layer.objects.active = slab
        boolean = slab.modifiers.new("Recessed diamond", "BOOLEAN")
        boolean.operation = "DIFFERENCE"
        boolean.solver = "EXACT"
        boolean.object = cut
        bpy.ops.object.modifier_apply(modifier=boolean.name)
    bpy.data.objects.remove(cut,do_unlink=True)
    # Add the inset stone face below the carved lip rather than a black painted icon.
    diamond = [(x*math.cos(math.pi/4)-y*math.sin(math.pi/4), x*math.sin(math.pi/4)+y*math.cos(math.pi/4))
               for x,y in rectangle(-.132,-.132,.132,.132,.003)]
    stone("diamond_inlay",diamond,-.025,-.008,mats["build"],build,.002)
    for side in range(4):
        poly = rectangle(-.39,-.493,.39,-.414,.005)
        angle=side*math.pi/2
        poly=[(x*math.cos(angle)-y*math.sin(angle),x*math.sin(angle)+y*math.cos(angle)) for x,y in poly]
        stone("border_%d" % side,poly,-.098,.009,mats["build"],build,.004)
    for x in (-.445,.445):
        for y in (-.445,.445):
            stone("corner_stone",rectangle(x-.05,y-.05,x+.05,y+.05,.018),-.11,.017,mats["side"],build,.004)
    for root in (path,build):
        root["approvedConcept"]="design/chapter2_asset_concepts/01-terrain-module.png"
        root["materialContract"]="Opaque violet-grey walkway, blue-grey empty foundation, real chipped masonry sides"
    return path,build


def export_tiles():
    source_scene=bpy.context.scene
    temporary=bpy.data.scenes.new("Chapter 2 Tiles Export")
    bpy.context.window.scene=temporary
    renamed=[]
    count = 0
    try:
        for name in ("path_tile","build_tile"):
            source=bpy.data.objects[name]
            source.name="Editable " + name
            renamed.append((source,name))
            root=bpy.data.objects.new(name,None);temporary.collection.objects.link(root)
            for key in source.keys():root[key]=source[key]
            meshes=[]
            bpy.ops.object.select_all(action="DESELECT")
            for obj in source.children_recursive:
                if obj.type!="MESH":continue
                clone=obj.copy();clone.data=obj.data.copy();clone.parent=None
                clone.matrix_world=source.matrix_world.inverted() @ obj.matrix_world
                clone.hide_render=False;temporary.collection.objects.link(clone);clone.hide_set(False)
                clone.select_set(True);meshes.append(clone)
            bpy.context.view_layer.objects.active=meshes[0]
            bpy.ops.object.join()
            joined=bpy.context.object;joined.name="chapter2_"+name+"_surface";joined.parent=root
            joined.data.calc_loop_triangles();count+=len(joined.data.loop_triangles)
        bpy.ops.object.select_all(action="SELECT")
        TARGET.parent.mkdir(parents=True,exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=str(TARGET),export_format="GLB",use_selection=True,
            export_yup=True,export_materials="EXPORT",export_extras=True,export_animations=False,
            export_cameras=False,export_lights=False)
    finally:
        for obj in list(temporary.objects):bpy.data.objects.remove(obj,do_unlink=True)
        bpy.context.window.scene=source_scene
        bpy.data.scenes.remove(temporary)
        for source,name in renamed:source.name=name
    (HERE/"export_manifest.json").write_text(json.dumps({"glbBytes":TARGET.stat().st_size,
        "triangles":count,"nodes":["path_tile","build_tile"],"tileFootprint":1,"bottom":-.45,
        "top":0,"cornerRelief":.017,"exportMeshes":2,
        "maps":"Blender-baked basecolor/normal/roughness"},indent=2)+"\n")


def studio():
    scene=bpy.context.scene
    # A source-only 3x3 review arrangement, composed from actual game nodes.
    root=empty("Source review module")
    for row in range(3):
        for col in range(3):
            source=bpy.data.objects["path_tile" if row==1 else "build_tile"]
            group=empty("Review %d %d" % (row,col));group.parent=root
            for src in source.children_recursive:
                obj=src.copy();obj.data=src.data;scene.collection.objects.link(obj)
                obj.parent=group
            group.location=(col-1,row-1,0)
    for name in ("path_tile","build_tile"):
        # Originals stay at origin for export; hide only their source review visibility.
        source=bpy.data.objects[name]
        for obj in [source,*source.children_recursive]:
            obj.hide_render=True
            obj.hide_set(True)
    world=bpy.data.worlds.new("Tile Studio");world.use_nodes=True;scene.world=world
    world.node_tree.nodes["Background"].inputs[0].default_value=(.11,.13,.17,1)
    world.node_tree.nodes["Background"].inputs[1].default_value=.5
    for name,loc,power,size in [("Key",(-3,-4,6),500,4),("Fill",(4,2,5),180,4)]:
        data=bpy.data.lights.new(name,"AREA");data.energy=power;data.shape="DISK";data.size=size
        obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=loc
        obj.rotation_euler=(-obj.location).to_track_quat("-Z","Y").to_euler()
    data=bpy.data.cameras.new("Review camera");cam=bpy.data.objects.new("Review camera",data);scene.collection.objects.link(cam)
    cam.location=(4,-5,5.7);target=Vector((0,0,-.12));cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
    data.type="ORTHO";data.ortho_scale=4.8;scene.camera=cam
    scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG";scene.render.filepath=str(HERE/"tiles-source.png")
    scene.cycles.samples=32;scene.cycles.use_denoising=True
    scene.view_settings.view_transform="AgX"


def main():
    if not bpy.app.background:
        raise RuntimeError("Use separate background Blender; do not replace the open workspace")
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--export-only",action="store_true")
    parser.add_argument("--regenerate",action="store_true")
    options=parser.parse_args(args)
    if options.export_only:
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
        for name in ("path_tile","build_tile"):
            for obj in [bpy.data.objects[name],*bpy.data.objects[name].children_recursive]:
                obj.hide_set(False);obj.hide_render=False
        export_tiles()
        return
    if SOURCE.exists() and not options.regenerate:
        parser.error("Preserve edited source: use --export-only, or --regenerate after backup.")
    HERE.mkdir(parents=True,exist_ok=True);(HERE/"maps").mkdir(exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.name="Chapter 2 Stone Tiles";scene.render.engine="CYCLES";scene.cycles.samples=8
    mats={
        "path":bake_stone("chapter2_path",(.19,.169,.217),(.36,.321,.373)),
        "build":bake_stone("chapter2_build",(.060,.091,.105),(.135,.177,.188)),
        "side":bake_stone("chapter2_side",(.050,.063,.078),(.133,.156,.180)),
    }
    create_tiles(mats)
    export_tiles()
    studio()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    bpy.ops.render.render(write_still=True)
    print("CHAPTER2_TILES_READY",TARGET,flush=True)


if __name__=="__main__":
    main()
