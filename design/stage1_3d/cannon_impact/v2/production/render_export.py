import bpy,sys
from pathlib import Path
root=Path(bpy.data.filepath).parent
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='METAL';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='METAL'
probe='--probe' in sys.argv
for kind,name in [('body','ProductionCannonBody'),('ground','ProductionCannonGround')]:
 scene=bpy.data.scenes[name];bpy.context.window.scene=scene;scene.cycles.device='GPU';folder=root/'frames'/kind;folder.mkdir(parents=True,exist_ok=True)
 for frame in ([8] if probe else range(1,33)):
  scene.frame_set(frame);scene.render.filepath=str(folder/('%02d.png'%(frame-1)));bpy.ops.render.render(write_still=True,scene=scene.name)
