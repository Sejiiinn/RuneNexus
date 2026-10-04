"""Add/edit the single representative 3D burst on the source scene, not game data."""
from pathlib import Path
import bpy,json,math,random
from mathutils import Vector
HERE=Path(__file__).resolve().parent
scene=bpy.data.scenes['PlacementDust3D']
puff=scene.objects['placement_dust_puff']
if bpy.data.collections.get('PlacementDust_BurstPreview'):
    raise RuntimeError('Existing burst preview must be edited instead of recreated.')
master=bpy.data.collections.new('PlacementDust_SourceGeometry')
burst=bpy.data.collections.new('PlacementDust_BurstPreview')
scene.collection.children.link(master)
scene.collection.children.link(burst)
for collection in list(puff.users_collection): collection.objects.unlink(puff)
master.objects.link(puff)
puff.hide_render=True
low=[min(v.co[i] for v in puff.data.vertices) for i in range(3)]
high=[max(v.co[i] for v in puff.data.vertices) for i in range(3)]
size=[high[i]-low[i] for i in range(3)]
particles=[]
rng=random.Random(41004)
scene.render.fps=30
scene.frame_start=1
scene.frame_end=20
for i in range(32):
    angle=math.tau*(i+rng.uniform(-.45,.45))/32
    start_radius=rng.uniform(.36,.48)
    end_radius=rng.uniform(.62,.90)
    start_width=rng.uniform(.12,.27)
    end_width=start_width*rng.uniform(1.4,1.8)
    start_height=rng.uniform(.10,.15)
    end_height=start_height*rng.uniform(1.15,1.35)
    lift=rng.uniform(.025,.05)
    spin=rng.uniform(-.42,.42)
    turn=rng.uniform(-math.pi,math.pi)
    obj=bpy.data.objects.new('PlacementDust_Burst_%02d'%i,puff.data)
    burst.objects.link(obj)
    obj.rotation_euler.z=turn
    origin=Vector((math.cos(angle)*start_radius,math.sin(angle)*start_radius,start_height*.52))
    end=Vector((math.cos(angle)*end_radius,math.sin(angle)*end_radius,end_height*.44))
    for frame,progress,travel,grow,vertical in [(1,0,0,.72,0),(4,.16,.31,.95,lift*.7),(10,.48,.75,1.0,lift),(20,1,1,1.0,0)]:
        width=(start_width+(end_width-start_width)*progress)*grow
        height=(start_height+(end_height-start_height)*progress)*grow
        obj.location=origin.lerp(end,travel)+Vector((0,0,vertical))
        obj.scale=(width/size[0],width/size[1],height/size[2])
        obj.rotation_euler.z=turn+spin*progress
        obj.keyframe_insert(data_path='location',frame=frame)
        obj.keyframe_insert(data_path='scale',frame=frame)
        obj.keyframe_insert(data_path='rotation_euler',frame=frame)
    particles.append({'angle':angle,'start_radius':start_radius,'end_radius':end_radius,
        'start_width':start_width,'end_width':end_width,'start_height':start_height,
        'end_height':end_height,'lift':lift,'rotation':turn,'spin':spin})
material=puff.data.materials[0]
nodes=material.node_tree.nodes
links=material.node_tree.links
material.node_tree.animation_data_clear()
opacity=nodes.new('ShaderNodeValue');opacity.name='Dust lifetime opacity'
geometry=nodes.new('ShaderNodeNewGeometry')
dot=nodes.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT'
links.new(geometry.outputs['Normal'],dot.inputs[0]);links.new(geometry.outputs['Incoming'],dot.inputs[1])
absolute=nodes.new('ShaderNodeMath');absolute.operation='ABSOLUTE';links.new(dot.outputs['Value'],absolute.inputs[0])
soft=nodes.new('ShaderNodeMath');soft.operation='POWER';soft.inputs[1].default_value=1.6;links.new(absolute.outputs[0],soft.inputs[0])
vertex=next(node for node in nodes if node.type=='VERTEX_COLOR')
density=nodes.new('ShaderNodeMath');density.operation='MULTIPLY';links.new(vertex.outputs['Alpha'],density.inputs[0]);links.new(soft.outputs[0],density.inputs[1])
alpha_product=nodes.new('ShaderNodeMath');alpha_product.operation='MULTIPLY';links.new(opacity.outputs[0],alpha_product.inputs[0]);links.new(density.outputs[0],alpha_product.inputs[1]);links.new(alpha_product.outputs[0],nodes['Principled BSDF'].inputs['Alpha'])
for frame,value in [(1,0),(3,.58),(10,.38),(20,0)]:
    opacity.outputs[0].default_value=value
    opacity.outputs[0].keyframe_insert(data_path='default_value',frame=frame)
for animated in [o for o in burst.objects]+[material.node_tree]:
    action=animated.animation_data.action
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for point in curve.keyframe_points: point.interpolation='LINEAR'
scene.frame_set(6)
manifest={'representation':'continuous closed 3D density puff; never camera facing','mesh':'placement_dust_puff',
    'coordinates':'glTF +Y up; center origin; transform identity','bounds_godot':[[low[0],low[2],-high[1]],[high[0],high[2],-low[1]]],
    'duration':19/30,'count':32,'height_factors':[.52,.44],'color':[.53,.485,.405],
    'alpha_curve':[[0,0],[2/19,.58],[9/19,.38],[1,0]],
    'motion_curve':[[0,0,.72,0],[3/19,.31,.95,.7],[9/19,.75,1,1],[1,1,1,0]],
    'curve_fields':['age','radial_travel','size_multiplier','lift_multiplier'],
    'particles':particles,
    'native_guidance':'shared MultiMesh, smooth PBR roughness1/specular0, COLOR_0 density and N dot V soft opacity; depth test, no sprite or extra light',
    'source_scene':scene.name,'source_collection':master.name,'burst_collection':burst.name}
previous_manifest=json.loads((HERE/'burst_manifest.json').read_text()) if (HERE/'burst_manifest.json').exists() else {}
if previous_manifest.get('volume'):manifest['volume']=previous_manifest['volume']
(HERE/'burst_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('PLACEMENT_DUST_BURST duration=',manifest['duration'],' count=',len(particles))
