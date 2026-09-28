from pathlib import Path
from PIL import Image
import numpy as np
import hashlib,json
root=Path.cwd();p=root/'design/stage_background_concepts/2026-09-28/chapter-palettes'
images=[np.asarray(Image.open(p/f'background-{theme}-frozen.png').convert('RGB')).astype(float) for theme in ['chapterOne','chapterTwoRift','chapterThreeForge']]
weights=np.array([.2126,.7152,.0722]);lumas=[a@weights for a in images]
bright=np.maximum.reduce(lumas)>=102.0
center=np.zeros(bright.shape,dtype=bool);center[:,150:290]=True
checks=[]
for i in [1,2]:
 diff=np.max(np.abs(images[0]-images[i]),axis=2)
 entry={'palette':i+1,'changed_pixels':int(np.count_nonzero(diff)),'bright_star_pixels':int(bright.sum()),'bright_star_changed_pixels':int(np.count_nonzero(diff[bright])),'central_pixels':int(center.sum()),'central_changed_pixels':int(np.count_nonzero(diff[center])),'max_luminance_difference':float(np.abs(lumas[0]-lumas[i]).max()),'mean_luminance_difference':float(np.abs(lumas[0]-lumas[i]).mean()),'mean_luminance':float(lumas[i].mean())}
 assert entry['bright_star_changed_pixels']==0,entry
 assert entry['central_changed_pixels']==0,entry
 checks.append(entry)
a=np.asarray(Image.open(p/'background-forge-time0.png').convert('RGB')).astype(float);b=np.asarray(Image.open(p/'background-forge-time3.png').convert('RGB')).astype(float)
diff=np.max(np.abs(a-b),axis=2);changed=diff>0
assert 0<changed.sum()<a.shape[0]*a.shape[1]*.005
names=['godot/main.gd','godot/environment/combat_space_background.gd','godot/environment/combat_space_twinkle.gdshader','assets/images/backgrounds/combat_space_nebula.png']
files=[]
for name in names:
 source=root/name;runtime=root/'build/godot/project'/ (name.removeprefix('godot/') if name.startswith('godot/') else 'assets/backgrounds/combat_space_nebula.png')
 sha=hashlib.sha256(source.read_bytes()).hexdigest();rsha=hashlib.sha256(runtime.read_bytes()).hexdigest();assert sha==rsha
 files.append({'source':name,'sha256':sha,'runtime_resource':'res://'+str(runtime.relative_to(root/'build/godot/project')),'runtime_sha256':rsha,'runtime_matches_source':True})
result={'engine':'Godot 4.7.2.stable.official.ed1daf0bf','renderer':'Metal 4.0 Forward Mobile Apple M4','viewport':[440,900],'source_files':files,'palette_comparison':checks,'chapter1_mean_luminance':float(lumas[0].mean()),'time_difference':{'seconds':3,'pixels':int(changed.size),'changed_pixels':int(changed.sum()),'max_channel_difference':float(diff.max()),'changed_min_luminance':float((a@weights)[changed].min())},'comparison_method':'Actual rendering; production shader and identical chapterThreeForge tint asserted/logged before both time-pair captures. Afterwards only, shader TIME replaced with 0.0 in validation material for palette comparisons','map_reset':'PASS runtime asserts chapterOne -> chapterTwoRift -> chapterThreeForge -> chapterOne tint reset','central_region':'Source UV |x-0.5| <=0.12; inspected safe interior screen x 150..289','isolated_checkpoint_directory':str(p/'isolated-save'),'evidence':['visual.log','import.log','chapter1-drone25.png','chapter2-drone25.png','chapter3-drone25.png','chapter1-return-from3.png','background-chapterOne-frozen.png','background-chapterTwoRift-frozen.png','background-chapterThreeForge-frozen.png','background-forge-time0.png','background-forge-time3.png','verify_chapter_palettes.gd','analyze_palettes.py']}
result['evidence_sha256']={name:hashlib.sha256((p/name).read_bytes()).hexdigest() for name in result['evidence']}
(p/'runtime-inputs.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result['palette_comparison'],indent=2));print(result['time_difference'])
