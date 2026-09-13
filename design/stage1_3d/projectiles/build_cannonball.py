"""Blender source/export for the approved round iron cannonball."""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector, noise

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCE = HERE / "cannonball.blend"
TARGET = ROOT / "assets/images/stage1_3d/projectiles/cannonball.glb"


def export_existing(output_path=TARGET, manifest_path=HERE / "export_manifest.json"):
    """Export saved manual edits without rebuilding, baking, or saving the source."""
    if not bpy.app.background:
        raise RuntimeError("Use a separate Blender background process to preserve the open workspace")
    if not SOURCE.is_file():
        raise FileNotFoundError(f"Editable source is missing: {SOURCE}")
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene = bpy.data.scenes.get("Round Iron Cannonball")
    if scene is None:
        raise RuntimeError("Source scene 'Round Iron Cannonball' is missing")
    bpy.context.window.scene = scene
    root = scene.objects.get("cannonball")
    body = scene.objects.get("cannonball_body")
    heat = scene.objects.get("cannonball_heat")
    if root is None or body is None or heat is None:
        raise RuntimeError("Source must contain cannonball, cannonball_body, and cannonball_heat")
    if body.type != "MESH" or heat.type != "MESH":
        raise RuntimeError("Body and heat objects must be meshes")
    descendants = list(root.children_recursive)
    if body not in descendants or heat not in descendants:
        raise RuntimeError("Body and heat meshes must remain under the cannonball root")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [root, *descendants]:
        if obj.type in {"EMPTY", "MESH"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = body
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output_path), export_format="GLB", use_selection=True,
        export_yup=True, export_materials="EXPORT", export_extras=True,
        export_animations=False, export_cameras=False, export_lights=False,
    )
    body.data.calc_loop_triangles()
    heat.data.calc_loop_triangles()
    manifest = {
        "glbBytes": output_path.stat().st_size,
        "radiusTiles": root.get("radiusTiles", 0.14),
        "bodyTriangles": len(body.data.loop_triangles),
        "heatTriangles": len(heat.data.loop_triangles),
        "flightAxis": root.get("flightAxisGodot", "+Z"),
        "rearAxis": "-Z",
        "exportMode": "existing-source",
    }
    normal = bpy.data.images.get("Cannonball forged normal")
    if normal is not None:
        manifest["normalMapSize"] = normal.size[0]
        if normal.packed_file is not None:
            manifest["normalMapBytes"] = len(normal.packed_file.data)
        else:
            normal_path = Path(bpy.path.abspath(normal.filepath))
            if normal_path.is_file():
                manifest["normalMapBytes"] = normal_path.stat().st_size
    Path(manifest_path).write_text(json.dumps(manifest, indent=2) + "\n")
    print("CANNONBALL_EXPORTED_EXISTING", output_path)


def rebuild():
    """Recreate the authored source, baked normal, export, and studio preview."""
    if not bpy.app.background:
        raise RuntimeError("Use a separate Blender background process to preserve the open workspace")
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene; scene.name='Round Iron Cannonball'
    root=bpy.data.objects.new('cannonball',None); scene.collection.objects.link(root)
    root['flightAxisGodot']='+Z'; root['radiusTiles']=.14
    root['approvedConcept']='design/stage1_3d/projectile_concepts/04-round-ironball.png'
    root['materialContract']='Opaque dark forged iron, continuous round silhouette, small rear heat accents'
    # Subtle forged dents change the surface, never the spherical silhouette.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=32,radius=.14)
    body=bpy.context.object; body.name='cannonball_body'; body.parent=root
    for v in body.data.vertices:
        unit=v.co.normalized(); n=noise.noise_vector(unit*13.0).x
        v.co*=1.0-.010*abs(n)
    for face in body.data.polygons: face.use_smooth=True
    color=body.data.color_attributes.new(name='Iron',type='FLOAT_COLOR',domain='POINT'); body.data.color_attributes.active_color=color
    for v,c in zip(body.data.vertices,color.data):
        n=noise.noise_vector(v.co*190.0+Vector((2,5,8))).z
        base=.055+n*.013
        c.color=(base*.87,base*.95,base*1.04,1)
    metal=bpy.data.materials.new('Forged dark iron'); metal.use_nodes=True
    bsdf=metal.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Metallic'].default_value=.78; bsdf.inputs['Roughness'].default_value=.55
    attr=metal.node_tree.nodes.new('ShaderNodeVertexColor'); attr.layer_name='Iron'
    metal.node_tree.links.new(attr.outputs['Color'],bsdf.inputs['Base Color'])
    body.data.materials.append(metal)
    # Bake fine forged metal relief into a native tangent normal map.
    tex=metal.node_tree.nodes.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=110;tex.inputs['Detail'].default_value=2.5;tex.inputs['Roughness'].default_value=.72
    bump=metal.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.35;bump.inputs['Distance'].default_value=.0018
    metal.node_tree.links.new(tex.outputs['Fac'],bump.inputs['Height']);metal.node_tree.links.new(bump.outputs['Normal'],bsdf.inputs['Normal'])
    normal_image=bpy.data.images.new('Cannonball forged normal',width=512,height=512,alpha=False)
    normal_image.colorspace_settings.name='Non-Color'
    image_node=metal.node_tree.nodes.new('ShaderNodeTexImage');image_node.image=normal_image;metal.node_tree.nodes.active=image_node
    scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.bake.margin=8
    bpy.context.view_layer.objects.active=body
    bpy.ops.object.bake(type='NORMAL')
    normal_image.filepath_raw=str(HERE/'cannonball-normal.png');normal_image.file_format='PNG';normal_image.save();normal_image.pack()
    metal.node_tree.links.remove(bsdf.inputs['Normal'].links[0])
    normal=metal.node_tree.nodes.new('ShaderNodeNormalMap');metal.node_tree.links.new(image_node.outputs['Color'],normal.inputs['Color']);metal.node_tree.links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])

    # Short uneven hot scratches behind the body. Blender +Y exports as Godot -Z.
    verts=[];faces=[];colors=[]
    for band in range(7):
        phi=band*2*math.pi/7+.13*math.sin(band*1.71)
        for step in range(7):
            theta=.25+step*.075+.04*math.sin(band*3.1+step*.9)
            width=.025*(.8+.2*math.sin(step))
            for side in [-1,1]:
                angle=phi+side*width+.03*math.sin(step*1.8+band)
                p=Vector((math.sin(theta)*math.cos(angle),math.cos(theta),math.sin(theta)*math.sin(angle)))
                p*=.14025
                verts.append(p); heat=.35+.3*math.sin(step*.53+band)**2
                colors.append((heat,.055+.06*(1-step/7),.005,1))
            if step:
                i=len(verts)-4; faces.append((i,i+1,i+3,i+2))
    mesh=bpy.data.meshes.new('Short rear heat seams'); mesh.from_pydata(verts,[],faces); mesh.update()
    heat=bpy.data.objects.new('cannonball_heat',mesh);scene.collection.objects.link(heat);heat.parent=root
    col=mesh.color_attributes.new(name='Heat',type='FLOAT_COLOR',domain='POINT');mesh.color_attributes.active_color=col
    for item,c in zip(col.data,colors):item.color=c
    mat=bpy.data.materials.new('Rear embers');mat.use_nodes=True
    p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.2,.022,.002,1);p.inputs['Metallic'].default_value=.35;p.inputs['Roughness'].default_value=.63
    attr=mat.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='Heat'
    mat.node_tree.links.new(attr.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=.9
    mesh.materials.append(mat)
    # glTF color attributes carry native base color; emission has a uniform low orange level.
    # The source seams preserve a small rear patch, not a luminous outline.
    p.inputs['Emission Color'].default_value=(.45,.055,.003,1)
    for link in list(mat.node_tree.links):mat.node_tree.links.remove(link)
    bpy.ops.object.select_all(action='DESELECT')
    for o in [root,body,heat]:o.select_set(True)
    bpy.context.view_layer.objects.active=body
    bpy.ops.export_scene.gltf(filepath=str(TARGET),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_extras=True,export_animations=False,export_cameras=False,export_lights=False)
    # Editable source includes a studio camera and lighting, excluded from game GLB.
    world=bpy.data.worlds.new('Cannonball Studio');world.use_nodes=True;scene.world=world
    world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.24,.30,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.5
    for name,loc,power,size in [('Key',(-.5,-.6,.8),22,.4),('Fill',(.5,.2,.4),8,.55)]:
        light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size
        o=bpy.data.objects.new(name,light);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    cam=bpy.data.cameras.new('Source Review');o=bpy.data.objects.new('Source Review',cam);scene.collection.objects.link(o)
    o.location=(.55,-.65,.75);o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler();cam.type='ORTHO';cam.ortho_scale=.44;scene.camera=o
    scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
    scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(HERE/'cannonball-source.png')
    scene.view_settings.view_transform='AgX'
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'cannonball.blend'))
    body.data.calc_loop_triangles();mesh.calc_loop_triangles()
    (HERE/'export_manifest.json').write_text(json.dumps({'glbBytes':TARGET.stat().st_size,'radiusTiles':.14,'bodyTriangles':len(body.data.loop_triangles),'heatTriangles':len(mesh.loop_triangles),'normalMapSize':512,'normalMapBytes':(HERE/'cannonball-normal.png').stat().st_size,'flightAxis':'+Z','rearAxis':'-Z'},indent=2)+'\n')
    bpy.ops.render.render(write_still=True)
    print('CANNONBALL_EXPORTED',TARGET)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--export-only", action="store_true",
        help="Export saved cannonball.blend edits; do not rebuild, bake, or save the source",
    )
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    if args.export_only:
        export_existing()
    else:
        rebuild()


if __name__ == "__main__":
    main()
