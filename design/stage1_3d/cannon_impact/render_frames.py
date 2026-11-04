import bpy,os
root=os.path.dirname(bpy.data.filepath)
for name,folder in [('CannonImpact3D','body'),('CannonGround3D','ground')]:
 scene=bpy.data.scenes[name];bpy.context.window.scene=scene;os.makedirs(root+'/frames/'+folder,exist_ok=True)
 for f in range(1,13):
  scene.frame_set(f);scene.render.filepath=root+'/frames/'+folder+'/%02d.png'%(f-1);bpy.ops.render.render(write_still=True,scene=name)
