"""Validate the installed frost in a private current-source production-policy app.

Uses APFS clones of prepared assets/cache; never touches shared imports or saves.
Raw logs/project location stay in checks/integration. Captures/report are retained.
"""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys, tempfile
OUT = Path(__file__).resolve().parents[2]
REPO = OUT.parents[3]
RAW = OUT / 'checks/integration'
EVIDENCE = OUT / 'integration'
RAW.mkdir(parents=True, exist_ok=True)
EVIDENCE.mkdir(exist_ok=True)
GODOT = REPO / 'build/godot-preview/tools/Godot.app/Contents/MacOS/Godot'
PREPARED = REPO / 'build/godot/project'
asset = REPO / 'assets/images/stage1_3d/turrets/frost.glb'
expected = 'efb65415c4b69e9e25ecd3625b49daed7805bd78eac25a8eda01c24cefc1221f'
assert hashlib.sha256(asset.read_bytes()).hexdigest() == expected
project = Path(tempfile.mkdtemp(prefix='runenexus-frost-rebaked-integration-')).resolve() / 'project'
shutil.copytree(REPO / 'godot', project, ignore=shutil.ignore_patterns('.godot', 'assets', '*.uid'))
subprocess.run(['cp', '-cR', str(PREPARED / 'assets'), str(project / 'assets')], check=True)
(project / '.godot').mkdir()
subprocess.run(['cp', '-cR', str(PREPARED / '.godot/imported'), str(project / '.godot/imported')], check=True)
for name in ['global_script_class_cache.cfg', 'uid_cache.bin']:
    if (PREPARED / '.godot' / name).exists(): shutil.copy2(PREPARED / '.godot' / name, project / '.godot' / name)
fixture = project.parent / 'test/fixtures'
fixture.mkdir(parents=True)
shutil.copy2(REPO / 'test/fixtures/turret_stat_calculation.json', fixture / 'turret_stat_calculation.json')
config = project / 'project.godot'
config.write_text(config.read_text().replace('config/name="RuneNexus Battlefield"', f'config/name="RuneNexus-Frost-Rebaked-Integration-{project.parent.name}"'))
shutil.copy2(asset, project / 'assets/turrets/frost.glb')
(project / 'assets/turrets/frost.glb.import').unlink(missing_ok=True)
sys.path.insert(0, str(REPO / 'scripts'))
from prepare_shared_gltf_textures import externalize_textures, _read_glb
import prepare_godot_project as production
externalize_textures(project / 'assets')
production.ASSETS = project / 'assets'
production._prepare_compressed_model_textures(project / 'assets/turrets/frost.glb', 1024)
a, _, x = _read_glb(asset)
b, _, y = _read_glb(project / 'assets/turrets/frost.glb')
assert x == y, 'Staged binary buffer differs'
assert all(a[k] == b[k] for k in ['nodes', 'meshes', 'accessors', 'materials'])
triangles = sum(a['accessors'][p['indices']]['count'] // 3 for m in a['meshes'] for p in m['primitives'])
assert triangles == 11760 and len(a['images']) == 4
texture_policy = []
for image in b['images']:
    texture = (project / 'assets/turrets' / image['uri']).resolve()
    text = texture.with_suffix(texture.suffix + '.import').read_text()
    for token in ['compress/mode=2', 'compress/high_quality=true', 'compress/normal_map=2', 'mipmaps/generate=true', 'process/size_limit=1024']: assert token in text
    texture_policy.append({'path': str(texture.relative_to(project)), 'sha256': hashlib.sha256(texture.read_bytes()).hexdigest()})
report = {'game_sha256': expected, 'staged_sha256': hashlib.sha256((project / 'assets/turrets/frost.glb').read_bytes()).hexdigest(), 'binary_buffer_identical': True, 'nodes_meshes_accessors_materials_identical': True, 'triangles': triangles, 'embedded_source_images': 4, 'texture_policy': {'compress_mode': 2, 'high_quality': True, 'normal_map': 2, 'mipmaps': True, 'size_limit': 1024}, 'textures': texture_policy}
(EVIDENCE / 'import-check.json').write_text(json.dumps(report, indent=2) + '\n')
(RAW / 'project-path.json').write_text(json.dumps({'project': str(project), 'game_asset_sha256': expected, 'godot': str(GODOT), 'source_head': subprocess.check_output(['git', '-C', str(REPO), 'rev-parse', 'HEAD'], text=True).strip()}, indent=2) + '\n')
print('FROST_PRIVATE_PROJECT', project, flush=True)
def run(name, args):
    env = dict(os.environ, FROST_INTEGRATION_OUTPUT=str(EVIDENCE))
    with (RAW / name).open('w') as stream:
        subprocess.run([str(GODOT), '--path', str(project)] + args, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=180)
    print('FROST_INTEGRATION_STEP', name, 'PASS', flush=True)
run('import.log', ['--headless', '--editor', '--import', '--quit'])
run('frost-charge.log', ['--resolution', '440x760', '--script', 'res://verify_frost_charge.gd', '--', '--fixture'])
run('capture.log', ['--resolution', '900x1500', '--script', str(Path(__file__).with_name('verify_ingame.gd')), '--', '--app'])
print('FROST_INTEGRATION_READY', project, flush=True)
