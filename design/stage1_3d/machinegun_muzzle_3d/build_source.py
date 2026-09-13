"""Blender MCP에서 실행하는 기관총 입체 포구 원본·공유 연기장 제작."""
from pathlib import Path
import json
import math
import random

import bpy
from mathutils import Vector, noise

ROOT = Path(__file__).resolve().parents[3]
PRODUCTION = Path(__file__).resolve().parent / "production"
ASSETS = ROOT / "assets/images/stage1_3d/effects"
PRODUCTION.mkdir(parents=True, exist_ok=True)
ASSETS.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new("MachineGunMuzzle3D")
previous_scene = bpy.context.window.scene
rng = random.Random(2701)
material = bpy.data.materials.new("Muzzle warm emission")
material.diffuse_color = (1.0, 0.33, 0.04, 1.0)
material.use_nodes = True
bsdf = material.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Base Color"].default_value = (1.0, 0.30, 0.025, 1.0)
bsdf.inputs["Emission Color"].default_value = (1.0, 0.44, 0.07, 1.0)
bsdf.inputs["Emission Strength"].default_value = 3.0


def jet(name, direction, length, radius, core=False):
    forward = Vector(direction).normalized()
    right = forward.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(forward).normalized()
    rings = [(0, .22), (.12, .64), (.28, 1), (.47, .72), (.70, .36), (1, .005)]
    vertices, faces = [], []
    for ring, (distance, width) in enumerate(rings):
        center = forward * length * distance + right * math.sin(distance * 7) * radius * .1
        for side in range(8):
            angle = side * math.tau / 8 + ring * .09
            spread = radius * width * rng.uniform(.80, 1.16)
            vertices.append(center + (right * math.cos(angle) + up * math.sin(angle)) * spread)
    for ring in range(len(rings) - 1):
        for side in range(8):
            faces.append((ring * 8 + side, ring * 8 + (side + 1) % 8,
                          (ring + 1) * 8 + (side + 1) % 8, (ring + 1) * 8 + side))
    faces.append(tuple(reversed(range(8))))
    faces.append(tuple((len(rings) - 1) * 8 + side for side in range(8)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    uv = mesh.uv_layers.new(name="Flame heat")
    for polygon in mesh.polygons:
        polygon.use_smooth = True
        for loop in polygon.loop_indices:
            ring = mesh.loops[loop].vertex_index // 8
            uv.data[loop].uv = (1.0 if core else 0.0, rings[ring][0])
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    return obj


try:
    bpy.context.window.scene = scene
    # Blender -Y → glTF/Godot +Z. UV.x: 중심 열도, UV.y: 총구에서의 거리.
    jet("White-hot core", (0, -1, 0), .36, .035, core=True)
    jet("Forward flame", (.015, -1, .025), .52, .065)
    for index in range(4):
        angle = index * math.tau / 4 + .35
        jet("Pressure tongue %d" % index,
            (.38 * math.cos(angle), -1, .38 * math.sin(angle)),
            .25 + rng.random() * .10, .027 + rng.random() * .008)
    scene["runtime"] = "godot/effects/machinegun_muzzle.gd"
    scene["dimensions"] = "1 tile = 1 unit; +Z forward after glTF export"
    scene["animation"] = "55 ms flash; 320 ms detached 3D smoke; 150 ms sparks"
    for obj in scene.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = next(iter(scene.objects))
    bpy.ops.export_scene.gltf(filepath=str(ASSETS / "machinegun_muzzle.glb"),
                              export_format="GLB", use_selection=True, use_active_scene=True,
                              export_animations=False, export_extras=True)
    bpy.data.libraries.write(str(PRODUCTION / "machinegun-muzzle.blend"), {scene}, fake_user=True)
    # 32³ R8 공간 잡음. 런타임에서 모든 포탑이 같은 텍스처를 공유.
    grid = 32
    data = bytearray()
    for z in range(grid):
        for y in range(grid):
            for x in range(grid):
                p = Vector((x / grid * 5.5 + 1.7, y / grid * 5.5 + 9.3, z / grid * 5.5 + 3.1))
                value = .70 * noise.noise(p, noise_basis="PERLIN_ORIGINAL")
                value += .30 * noise.noise(p * 2.1, noise_basis="PERLIN_ORIGINAL")
                data.append(round(max(0, min(1, .5 + value * .75)) * 255))
    (ASSETS / "machinegun_muzzle_noise.bin").write_bytes(data)
    print(json.dumps({"source": str(PRODUCTION / "machinegun-muzzle.blend"),
                      "model": str(ASSETS / "machinegun_muzzle.glb"),
                      "meshes": len(scene.objects), "noiseBytes": len(data)}))
finally:
    bpy.context.window.scene = previous_scene
