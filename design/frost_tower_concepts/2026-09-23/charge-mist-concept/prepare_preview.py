from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[4]
SOURCE=Path(__file__).resolve().parent
TARGET=ROOT/'build/godot/frost-charge-concept'
TARGET.mkdir(parents=True,exist_ok=True)
for name in ['project.godot','main.tscn','concept.gd','charge.gdshader','mist.gdshader','mist-volume.glb']:
 shutil.copy2(SOURCE/name,TARGET/name)
shutil.copy2(ROOT/'assets/images/stage1_3d/turrets/frost.glb',TARGET/'frost.glb')
shutil.copy2(ROOT/'assets/images/stage1_3d/enemies/normal.glb',TARGET/'enemy.glb')
print(TARGET)
