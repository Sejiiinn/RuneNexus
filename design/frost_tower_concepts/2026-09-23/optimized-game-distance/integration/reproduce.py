"""Prepare a private current-source Godot project, import the installed GLB, test it.
Does not mutate build/godot/project or user saves. Retains /tmp project for review.
"""
from pathlib import Path
import subprocess,shutil,tempfile,sys,json,hashlib
REPO=Path.cwd();OUT=Path(__file__).resolve().parent
GODOT=REPO/'build/godot-preview/tools/Godot.app/Contents/MacOS/Godot'
PREPARED=REPO/'build/godot/project'
project=Path(tempfile.mkdtemp(prefix='runenexus-frost-optimized-integration-'))/'project'
shutil.copytree(REPO/'godot',project,ignore=shutil.ignore_patterns('.godot','assets','*.uid'))
subprocess.run(['cp','-cR',str(PREPARED/'assets'),str(project/'assets')],check=True)
(project/'.godot').mkdir()
subprocess.run(['cp','-cR',str(PREPARED/'.godot/imported'),str(project/'.godot/imported')],check=True)
for name in ['global_script_class_cache.cfg','uid_cache.bin']:
    if (PREPARED/'.godot'/name).exists():shutil.copy2(PREPARED/'.godot'/name,project/'.godot'/name)
fixture=project.parent/'test/fixtures';fixture.mkdir(parents=True)
shutil.copy2(REPO/'test/fixtures/turret_stat_calculation.json',fixture/'turret_stat_calculation.json')
config=project/'project.godot';config.write_text(config.read_text().replace('config/name="RuneNexus Battlefield"','config/name="RuneNexus-Frost-Optimized-Integration"'))
asset=REPO/'assets/images/stage1_3d/turrets/frost.glb'
digest=hashlib.sha256(asset.read_bytes()).hexdigest()
assert digest=='7d71195e972710488c6912d68b1f3d5eb54ee38adf31f9a524788a8d1d3aee39'
shutil.copy2(asset,project/'assets/turrets/frost.glb')
(project/'assets/turrets/frost.glb.import').unlink(missing_ok=True)
# Same generated-asset texture sharing and lossless/mipmap policy as production.
sys.path.insert(0,str(REPO/'scripts'))
from prepare_shared_gltf_textures import externalize_textures
texture_manifest=externalize_textures(project/'assets')
from prepare_shared_gltf_textures import _read_glb
assert _read_glb(asset)[2]==_read_glb(project/'assets/turrets/frost.glb')[2], 'Staged geometry changed'
a,_,x=_read_glb(asset);b,_,y=_read_glb(project/'assets/turrets/frost.glb')
assert all(a[k]==b[k] for k in ['nodes','meshes','accessors','materials'])
(OUT/'import-check.json').write_text(json.dumps({'game_sha256':digest,'staged_sha256':hashlib.sha256((project/'assets/turrets/frost.glb').read_bytes()).hexdigest(),'binary_buffer_identical':True,'nodes_meshes_accessors_materials_identical':True,'reason_sha_diff':'standard shared texture URI externalization; BIN bytes unchanged','runtime_report':'report.json','game_glb_matches_candidate':asset.read_bytes()==(OUT.parent/'frost-optimized.glb').read_bytes()},indent=2)+'\n')
for texture in (project/'assets/shared_textures').iterdir():
    if texture.suffix in ['.png','.jpg','.jpeg','.webp'] and not texture.with_suffix(texture.suffix+'.import').exists():
        texture.with_suffix(texture.suffix+'.import').write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\ncompress/normal_map=2\nmipmaps/generate=true\ndetect_3d/compress_to=0\n')
(OUT/'project-path.json').write_text(json.dumps({'project':str(project),'game_asset_sha256':digest,'godot':str(GODOT),'save_isolation':'distinct project name for actual app session and generated project'},indent=2)+'\n')
def run(name,args):
    with (OUT/name).open('w') as stream:
        subprocess.run([str(GODOT),'--path',str(project)]+args,stdout=stream,stderr=subprocess.STDOUT,check=True,timeout=180)
run('import.log',['--headless','--editor','--import','--quit'])
run('frost-charge.log',['--resolution','440x760','--script','res://verify_frost_charge.gd','--','--fixture'])
run('capture.log',['--resolution','900x1500','--script',str(OUT/'verify_ingame.gd'),'--','--app','--detail-only'])
print('FROST_INTEGRATION_READY',project,flush=True)
