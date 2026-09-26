"""Prepare a private current-source Godot project, import the installed GLB, test it.
Does not mutate build/godot/project or user saves. Retains /tmp project for review.
"""
from pathlib import Path
import subprocess,shutil,tempfile,sys,json,hashlib
REPO=Path.cwd();OUT=Path(__file__).resolve().parent
GODOT=REPO/'build/godot-preview/tools/Godot.app/Contents/MacOS/Godot'
PREPARED=REPO/'build/godot/project'
project=Path(tempfile.mkdtemp(prefix='runenexus-fire-optimized-integration-'))/'project'
shutil.copytree(REPO/'godot',project,ignore=shutil.ignore_patterns('.godot','assets','*.uid'))
subprocess.run(['cp','-cR',str(PREPARED/'assets'),str(project/'assets')],check=True)
(project/'.godot').mkdir()
subprocess.run(['cp','-cR',str(PREPARED/'.godot/imported'),str(project/'.godot/imported')],check=True)
for name in ['global_script_class_cache.cfg','uid_cache.bin']:
    if (PREPARED/'.godot'/name).exists():shutil.copy2(PREPARED/'.godot'/name,project/'.godot'/name)
config=project/'project.godot';config.write_text(config.read_text().replace('config/name="RuneNexus Battlefield"','config/name="RuneNexus Fire Optimized Isolated Integration"'))
asset=REPO/'assets/images/stage1_3d/turrets/magic.glb'
digest=hashlib.sha256(asset.read_bytes()).hexdigest()
assert digest=='b46a8c2089924e73b38ed06f59039b6e85a8fea009ea4e5507144ef3a71c9a5e'
shutil.copy2(asset,project/'assets/turrets/magic.glb')
(project/'assets/turrets/magic.glb.import').unlink(missing_ok=True)
# Same generated-asset texture sharing and lossless/mipmap policy as production.
sys.path.insert(0,str(REPO/'scripts'))
from prepare_shared_gltf_textures import externalize_textures
texture_manifest=externalize_textures(project/'assets')
for texture in (project/'assets/shared_textures').iterdir():
    if texture.suffix in ['.png','.jpg','.jpeg','.webp'] and not texture.with_suffix(texture.suffix+'.import').exists():
        texture.with_suffix(texture.suffix+'.import').write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\ncompress/normal_map=2\nmipmaps/generate=true\ndetect_3d/compress_to=0\n')
(OUT/'project-path.json').write_text(json.dumps({'project':str(project),'game_asset_sha256':digest,'godot':str(GODOT),'save_isolation':'distinct project name; fixture mode; no app session'},indent=2)+'\n')
def run(name,args):
    with (OUT/name).open('w') as stream:
        subprocess.run([str(GODOT),'--path',str(project)]+args,stdout=stream,stderr=subprocess.STDOUT,check=True,timeout=180)
run('import.log',['--headless','--editor','--import','--quit'])
for script,log in [('verify_runic_fire.gd','runic-fire.log'),('verify_runic_fire_integration.gd','runic-fire-integration.log')]:
    run(log,['--resolution','440x760','--script','res://'+script,'--','--fixture'])
run('capture.log',['--resolution','440x760','--script',str(OUT/'capture_integration.gd'),'--','--fixture'])
print('FIRE_INTEGRATION_READY',project,flush=True)
