"""Import the installed props in a private current-source project; bounded stage checks.
Does not touch the shared build project, source tiles, or user saves.
"""
from pathlib import Path
import subprocess,shutil,tempfile,sys,json,hashlib,struct
REPO=Path.cwd();OUT=Path(__file__).resolve().parent
GODOT=REPO/'build/godot-preview/tools/Godot.app/Contents/MacOS/Godot'
PREPARED=REPO/'build/godot/project'
PROJECT=Path(tempfile.mkdtemp(prefix='runenexus-props-optimized-integration-'))/'project'
shutil.copytree(REPO/'godot',PROJECT,ignore=shutil.ignore_patterns('.godot','assets','*.uid'))
subprocess.run(['cp','-cR',str(PREPARED/'assets'),str(PROJECT/'assets')],check=True)
(PROJECT/'.godot').mkdir()
subprocess.run(['cp','-cR',str(PREPARED/'.godot/imported'),str(PROJECT/'.godot/imported')],check=True)
for name in ['global_script_class_cache.cfg','uid_cache.bin']:
    if (PREPARED/'.godot'/name).exists():shutil.copy2(PREPARED/'.godot'/name,PROJECT/'.godot'/name)
config=PROJECT/'project.godot';config.write_text(config.read_text().replace('config/name="RuneNexus Battlefield"','config/name="RuneNexus Props Optimized Isolated Integration"'))
asset=REPO/'assets/images/stage1_3d/environment/chapter3_props.glb'
digest=hashlib.sha256(asset.read_bytes()).hexdigest()
assert digest=='00f95bb711cfd703726bd164a73065df6007c10cac6875042d59bc113a8130bd'
staged=PROJECT/'assets/environment/chapter3_props.glb'
shutil.copy2(asset,staged);staged.with_suffix('.glb.import').unlink(missing_ok=True)
sys.path.insert(0,str(REPO/'scripts'))
from prepare_shared_gltf_textures import externalize_textures,_read_glb
externalize_textures(PROJECT/'assets')
# The production texture-sharing step rewrites JSON image URIs, never geometry BIN.
assert _read_glb(asset)[2]==_read_glb(staged)[2]
for texture in (PROJECT/'assets/shared_textures').iterdir():
    if texture.suffix in ['.png','.jpg','.jpeg','.webp'] and not texture.with_suffix(texture.suffix+'.import').exists():
        texture.with_suffix(texture.suffix+'.import').write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\ncompress/normal_map=2\nmipmaps/generate=true\ndetect_3d/compress_to=0\n')
import prepare_godot_project as prepare
prepare.PROJECT=PROJECT
prepare._prepare_battlefield_verification()
baseline=PROJECT.parent/'original-chapter3-props.glb'
data=subprocess.check_output(['git','show','0c63df5fa22c1f5b7bcfd5a3f3f9ec8b448aa047:assets/images/stage1_3d/environment/chapter3_props.glb'],cwd=REPO)
assert hashlib.sha256(data).hexdigest()=='c4eb491ef578b6e91219b75b3a854ad4bb3b4b3e565cd0d866d55a5daacd7952'
baseline.write_bytes(data)
(OUT/'project-path.json').write_text(json.dumps({'project':str(PROJECT),'game_asset_sha256':digest,'staged_geometry_bin_unchanged':True,'staged_glb_sha256':hashlib.sha256(staged.read_bytes()).hexdigest(),'baseline_git_commit':'0c63df5fa22c1f5b7bcfd5a3f3f9ec8b448aa047','godot':str(GODOT),'save_isolation':'distinct project name; fixture mode; no app session'},indent=2)+'\n')
def run(name,args):
    with (OUT/name).open('w') as stream:
        subprocess.run([str(GODOT),'--path',str(PROJECT)]+args,stdout=stream,stderr=subprocess.STDOUT,check=True,timeout=180)
run('import.log',['--headless','--editor','--import','--quit'])
run('stage-props.log',['--resolution','440x760','--script',str(OUT/'check_stage_props.gd'),'--','--fixture','--frames='+str(PROJECT.parent/'chapter_three_frames.json'),'--baseline='+str(baseline)])
print('PROPS_INTEGRATION_READY',PROJECT,flush=True)
